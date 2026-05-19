import SwiftUI
import SwiftData
import CloudKit

@main
struct CadenceApp: App {

    /// Build 19: the container can fail to initialize (Build 18 hotfix
    /// taught us this the hard way). We hold it as Optional and surface
    /// the failure to the user via a recoverable error screen instead of
    /// fatal-erroring. Once recovery succeeds, this gets populated.
    @State private var container: ModelContainer?
    @State private var containerError: ContainerInitError?
    @AppStorage(PrefsKey.themeChoice) private var themeRaw: String = ThemeChoice.system.rawValue
    /// Build 24: re-rendering the tree when the AppTheme picker changes
    /// hangs off this @AppStorage. ThemeManager.shared.current is updated
    /// in-place by `applyTheme` below; SwiftUI re-renders because this
    /// property is read by `resolvedColorScheme` (via prefersForceDark)
    /// and any view that reads it cascades.
    @AppStorage(PrefsKey.themeKey) private var themeKey: String = AppTheme.violet.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var notifications = NotificationManager.shared
    @StateObject private var cloudSync = CloudKitSyncManager.shared
    @StateObject private var authSession = AuthSession.shared

    init() {
        let result = Self.attemptContainerInit()
        _container = State(initialValue: result.container)
        _containerError = State(initialValue: result.error)

        if let container = result.container {
            Self.finishLaunch(with: container)
        }
        if AppLaunchArgs.skipOnboarding {
            UserDefaults.standard.set(true, forKey: PrefsKey.hasOnboarded)
        }
    }

    /// Tries to build the container. On failure, returns the captured error
    /// in lieu of crashing. Called both at first launch and after a user
    /// taps "Retry" / "Reset local cache".
    private static func attemptContainerInit() -> (container: ModelContainer?, error: ContainerInitError?) {
        do {
            let c = try CadenceContainer.makeContainer()
            return (c, nil)
        } catch {
            NSLog("[Cadence-Boot] ModelContainer init FAILED: %@", String(describing: error))
            return (nil, ContainerInitError(underlying: error))
        }
    }

    private static func finishLaunch(with container: ModelContainer) {
        SeedData.bootstrapIfNeeded(container.mainContext)
        GoogleCalendarService.shared.bindContext(container.mainContext)
        SharedListMirror.shared.bind(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                RootView()
                    .preferredColorScheme(resolvedColorScheme)
                    .environmentObject(notifications)
                    .task {
                        await notifications.refreshAuthorizationStatus()
                        await cloudSync.bootstrap()
                        await GoogleCalendarService.shared.fetchAllEvents()
                        await SharedListMirror.shared.pullAllSharedZones()
                    }
                    .environmentObject(cloudSync)
                    .environmentObject(authSession)
                    .onOpenURL { url in
                        handleOpenURL(url)
                    }
                    .onContinueUserActivity(CKShare.SystemType.share) { userActivity in
                        handleCloudShareAcceptance(userActivity)
                    }
                    .modelContainer(container)
            } else if let containerError {
                ContainerRecoveryView(
                    error: containerError,
                    onRetry: retryContainerInit,
                    onResetCache: resetLocalCacheAndRetry
                )
            } else {
                // Vanishingly brief — container init runs synchronously in
                // App.init, so by the time SwiftUI renders we have either a
                // container or an error.
                Color(.systemBackground).ignoresSafeArea()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard let container else { return }
            if newPhase == .active {
                Task {
                    await notifications.refreshAuthorizationStatus()
                    await notifications.rescheduleEverything(context: container.mainContext)
                    await GoogleCalendarService.shared.fetchAllEvents()
                    await cloudSync.refreshAccountStatus()
                    await SharedListMirror.shared.pullAllSharedZones()
                }
            }
        }
        .onChange(of: themeKey, initial: true) { _, newValue in
            // Build 24: keep ThemeManager's singleton in sync with the
            // @AppStorage value. The @AppStorage itself triggers the
            // SwiftUI re-render that lets Tokens.Color.accent return the
            // new theme's color.
            if let theme = AppTheme(rawValue: newValue) {
                ThemeManager.shared.apply(theme)
            }
        }
    }

    // MARK: Recovery actions

    private func retryContainerInit() {
        let result = Self.attemptContainerInit()
        if let c = result.container {
            Self.finishLaunch(with: c)
        }
        container = result.container
        containerError = result.error
    }

    /// Last-resort recovery: nuke the on-disk SwiftData store(s) and try
    /// again. CloudKit-backed data re-downloads automatically on the next
    /// sync tick, so this is safe IF the user has been syncing.
    /// Local-only data (CachedEvent — Google Calendar cache) is lost but
    /// re-fetched from Google on the next foreground.
    private func resetLocalCacheAndRetry() {
        let fm = FileManager.default
        if let groupURL = fm.containerURL(
            forSecurityApplicationGroupIdentifier: CadenceContainer.appGroupID
        ) {
            for name in [CadenceContainer.storeName, CadenceContainer.localStoreName] {
                let storeURL = groupURL.appendingPathComponent(name)
                // SwiftData/CoreData stores write three sibling files
                // (.sqlite, .sqlite-wal, .sqlite-shm); remove all three.
                for suffix in ["", "-wal", "-shm"] {
                    let target = URL(fileURLWithPath: storeURL.path + suffix)
                    try? fm.removeItem(at: target)
                }
            }
        }
        NSLog("[Cadence-Boot] local SwiftData stores wiped — retrying container init")
        retryContainerInit()
    }

    /// Resolves the user's `themeRaw` @AppStorage choice to a ColorScheme
    /// or nil (System). Logs to help diagnose the "theme doesn't change"
    /// reports that have shown up in TestFlight.
    private var resolvedColorScheme: ColorScheme? {
        // Build 24: Mono + High Contrast themes force dark regardless of
        // the Light/Dark/System picker, since they're aesthetic statements
        // that don't bend to system appearance.
        let theme = AppTheme(rawValue: themeKey) ?? .violet
        if theme.prefersForceDark { return .dark }
        let choice = ThemeChoice(rawValue: themeRaw) ?? .system
        let scheme = choice.colorScheme
        NSLog("[THEME] applying theme=%@ choice=%@ scheme=%@",
              theme.rawValue,
              choice.rawValue,
              scheme == .dark ? "dark" : scheme == .light ? "light" : "system")
        return scheme
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
                let share = try await CloudKitSharingService.shared.accept(shareMetadata: metadata)
                NSLog("[Cadence-Share] share accepted; mirroring records into SwiftData")
                await SharedListMirror.shared.handleShareAccepted(share, metadata: metadata)
            } catch {
                NSLog("[Cadence-Share] accept failed: %@", error.localizedDescription)
            }
        }
    }
}

// MARK: - Container recovery (Build 19)

struct ContainerInitError: Identifiable {
    let id = UUID()
    let underlying: Error
    var message: String { String(describing: underlying) }
}

/// Shown in place of RootView when ModelContainer init fails. Gives the
/// user two recovery affordances: a non-destructive Retry, and a
/// confirmed "Reset local cache" that wipes the on-disk store so SwiftData
/// can rebuild from CloudKit on next launch.
struct ContainerRecoveryView: View {
    let error: ContainerInitError
    let onRetry: () -> Void
    let onResetCache: () -> Void

    @State private var showingResetConfirm = false
    @State private var isResetting = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.18))
                        .frame(width: 96, height: 96)
                    Image(systemName: "exclamationmark.icloud.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                VStack(spacing: 8) {
                    Text("Cadence had trouble loading")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("Your data is safe in iCloud. Tap Retry, or Reset local cache to rebuild from iCloud.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                if isResetting {
                    ProgressView("Rebuilding cache…")
                        .padding(.top, 8)
                }
                Spacer()
                VStack(spacing: 12) {
                    Button {
                        onRetry()
                    } label: {
                        Text("Retry")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.486, green: 0.361, blue: 1.0),
                                             Color(red: 0.357, green: 0.235, blue: 0.980)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingResetConfirm = true
                    } label: {
                        Text("Reset local cache")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)

                DisclosureGroup("Error details") {
                    ScrollView {
                        Text(error.message)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 120)
                }
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .alert("Reset local cache?", isPresented: $showingResetConfirm) {
            Button("Reset", role: .destructive) {
                isResetting = true
                onResetCache()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Cadence will delete the local SwiftData store and re-download from iCloud on next launch. Any unsynced local changes will be lost.")
        }
    }
}
