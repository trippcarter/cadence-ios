import SwiftUI
import SwiftData
import CloudKit

@main
struct CadenceApp: App {

    let container: ModelContainer
    @AppStorage(PrefsKey.themeChoice) private var themeRaw: String = ThemeChoice.dark.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var notifications = NotificationManager.shared
    @StateObject private var cloudSync = CloudKitSyncManager.shared
    @StateObject private var authSession = AuthSession.shared

    init() {
        do {
            container = try CadenceContainer.makeContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        SeedData.bootstrapIfNeeded(container.mainContext)

        // Share the App's mainContext with the calendar service so SwiftData
        // writes from sign-in / sign-out / sync are visible to @Query views.
        GoogleCalendarService.shared.bindContext(container.mainContext)

        if AppLaunchArgs.skipOnboarding {
            UserDefaults.standard.set(true, forKey: PrefsKey.hasOnboarded)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(ThemeChoice(rawValue: themeRaw)?.colorScheme ?? .dark)
                .environmentObject(notifications)
                .task {
                    await notifications.refreshAuthorizationStatus()
                    await cloudSync.bootstrap()
                    // Background-fetch events on every cold start so cached
                    // events stay roughly within the 15-min freshness budget.
                    await GoogleCalendarService.shared.fetchAllEvents()
                }
                .environmentObject(cloudSync)
                .environmentObject(authSession)
                .onOpenURL { url in
                    handleOpenURL(url)
                }
                .onContinueUserActivity(CKShare.SystemType.share) { userActivity in
                    handleCloudShareAcceptance(userActivity)
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await notifications.refreshAuthorizationStatus()
                    await notifications.rescheduleEverything(context: container.mainContext)
                    await GoogleCalendarService.shared.fetchAllEvents()
                    await cloudSync.refreshAccountStatus()
                }
            }
        }
    }

    private func handleOpenURL(_ url: URL) {
        NSLog("[Cadence-OAuth] .onOpenURL received: %@", url.absoluteString)
        // Route Google OAuth redirects back to AppAuth via the calendar service.
        // Call synchronously on the main run loop — Task @MainActor scheduling
        // can race with AppAuth's internal timeout.
        _ = GoogleCalendarService.shared.resumeAuthFlow(with: url)
    }

    /// Handle a CloudKit share invitation. iOS hands us an NSUserActivity
    /// when the user taps an https://www.icloud.com/share/... link. The
    /// userInfo dict carries a `CKShare.Metadata` under a key Apple doesn't
    /// publicly expose; we scan the values for the first match instead of
    /// hard-coding the private key string.
    private func handleCloudShareAcceptance(_ userActivity: NSUserActivity) {
        let metadata = userActivity.userInfo?.values.first { $0 is CKShare.Metadata } as? CKShare.Metadata
        guard let metadata else {
            NSLog("[Cadence-Share] continueUserActivity without CKShare.Metadata")
            return
        }
        NSLog("[Cadence-Share] accepting share from %@", metadata.ownerIdentity.userRecordID?.recordName ?? "<unknown>")
        Task {
            do {
                _ = try await CloudKitSharingService.shared.accept(shareMetadata: metadata)
                NSLog("[Cadence-Share] share accepted; SwiftData will mirror records on next sync tick")
            } catch {
                NSLog("[Cadence-Share] accept failed: %@", error.localizedDescription)
            }
        }
    }
}
