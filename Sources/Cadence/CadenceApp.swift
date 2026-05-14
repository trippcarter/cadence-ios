import SwiftUI
import SwiftData

@main
struct CadenceApp: App {

    let container: ModelContainer
    @AppStorage(PrefsKey.themeChoice) private var themeRaw: String = ThemeChoice.dark.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var notifications = NotificationManager.shared

    init() {
        do {
            container = try CadenceContainer.makeContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        SeedData.bootstrapIfNeeded(container.mainContext)

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
                    // Background-fetch events on every cold start so cached
                    // events stay roughly within the 15-min freshness budget.
                    await GoogleCalendarService.shared.fetchAllEvents()
                }
                .onOpenURL { url in
                    handleOpenURL(url)
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await notifications.refreshAuthorizationStatus()
                    await notifications.rescheduleEverything(context: container.mainContext)
                    await GoogleCalendarService.shared.fetchAllEvents()
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
}
