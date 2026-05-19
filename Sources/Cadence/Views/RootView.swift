import SwiftUI
import SwiftData

struct RootView: View {
    @State private var selectedTab: AppTab = AppLaunchArgs.initialTab
    @State private var showingAddTask = false
    @State private var listsPath = NavigationPath()
    @State private var pendingTaskDetail: TaskItem?
    @State private var didHandleLaunchArgs = false

    @AppStorage(PrefsKey.hasOnboarded) private var hasOnboarded: Bool = false

    @State private var showingTemplateGalleryFromAuth = false
    @State private var showingNamePromptFromAuth = false
    /// Latched whenever a sign-in flagged `needsNamePrompt`, used to drive
    /// the post-name-prompt template gallery presentation. Without this we'd
    /// race the AuthSession flag, which clears on commit.
    @State private var pendingTemplateGalleryAfterName = false
    /// Build 18: shown when the user taps the daily-review notification OR
    /// manually triggers via You tab → "Run today's review".
    @State private var showingDailyReview: Bool = false

    @EnvironmentObject private var notifications: NotificationManager
    @EnvironmentObject private var authSession: AuthSession
    @Query private var allLists: [TaskList]
    @Query private var allTasks: [TaskItem]

    var body: some View {
        Group {
            if let preview = AppLaunchArgs.widgetPreview {
                WidgetGalleryView(preview: preview)
            } else if !hasOnboarded {
                OnboardingView()
                    .transition(.opacity)
            } else if !authSession.state.isSignedIn {
                SignInView()
                    .transition(.opacity)
            } else {
                appContent
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.smooth(duration: 0.45), value: hasOnboarded)
        .animation(.smooth(duration: 0.45), value: authSession.state)
        .overlay {
            if authSession.showWelcomeSplash, let user = authSession.state.user {
                WelcomeSplashView(
                    firstName: user.firstNameOrFallback,
                    isReturning: authSession.lastSignInWasReturning
                ) {
                    withAnimation(.smooth(duration: 0.45)) {
                        authSession.showWelcomeSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .task {
            await authSession.refreshCredentialState()
        }
        .onChange(of: authSession.state) { oldState, newState in
            NSLog("[Cadence-Auth] RootView observed state change: isSignedIn=%@",
                  newState.isSignedIn ? "true" : "false")
            guard !oldState.isSignedIn,
                  case .signedIn(let user) = newState else { return }

            let needsNamePrompt = authSession.needsNamePrompt
            let hasSeenGallery = UserScopedPrefs.hasSeenTemplateGallery(for: user.appleUserIdentifier)

            // 0.6s delay so the welcome splash + main-app fade settle
            // before we cover the screen with another sheet.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if needsNamePrompt {
                    // Name prompt first; the template gallery (if needed)
                    // will be presented after the name prompt dismisses.
                    pendingTemplateGalleryAfterName = !hasSeenGallery
                    showingNamePromptFromAuth = true
                } else if !hasSeenGallery {
                    showingTemplateGalleryFromAuth = true
                }
            }
        }
        .sheet(isPresented: $showingNamePromptFromAuth, onDismiss: {
            // Chain: after the name prompt closes, present the template
            // gallery if it was queued.
            if pendingTemplateGalleryAfterName {
                pendingTemplateGalleryAfterName = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingTemplateGalleryFromAuth = true
                }
            }
        }) {
            DisplayNameEditSheet(mode: .firstRun)
        }
        .sheet(isPresented: $showingTemplateGalleryFromAuth) {
            TemplateGallerySheet()
        }
        .sheet(isPresented: $showingDailyReview) {
            DailyReviewSheet()
        }
        .onChange(of: notifications.deepLinkOpenReview) { _, newValue in
            guard newValue else { return }
            showingDailyReview = true
            notifications.deepLinkOpenReview = false
        }
    }

    private var appContent: some View {
        ZStack(alignment: .bottom) {
            content
            BottomTabBar(selected: $selectedTab) {
                showingAddTask = true
            }
            // Build 24: hidden buttons hold the global keyboard shortcuts
            // for hardware keyboards (Magic Keyboard on iPad, USB on
            // iPhone). Invisible to touch users, surface in the iOS
            // "Hold ⌘" keyboard discoverability HUD.
            keyboardShortcutShelf
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .ignoresSafeArea(.keyboard)
        .background(Tokens.Color.bg.ignoresSafeArea())
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet(prefill: AppLaunchArgs.addTaskPrefill)
        }
        .sheet(item: $pendingTaskDetail) { task in
            TaskDetailSheet(task: task)
        }
        .onAppear {
            applyLaunchArgsOnce()
        }
        .onChange(of: notifications.deepLinkTaskID) { _, newValue in
            guard let id = newValue,
                  let task = allTasks.first(where: { $0.id == id })
            else { return }
            pendingTaskDetail = task
            notifications.deepLinkTaskID = nil
        }
        .onChange(of: notifications.deepLinkRequestedTab) { _, newValue in
            guard let tab = newValue else { return }
            selectedTab = tab
            notifications.deepLinkRequestedTab = nil
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .today:
            TodayView(
                onRequestSettingsTab: { selectedTab = .you },
                onRequestQuickAdd: { showingAddTask = true }
            )
        case .week:
            CalendarView()
        case .lists:
            NavigationStack(path: $listsPath) {
                ListsView()
            }
        case .you:
            SettingsView()
        }
    }

    /// Build 24: hardware-keyboard shortcuts. Each Button below is
    /// rendered with zero size but its `.keyboardShortcut` modifier
    /// registers the key combo with UIKit's first-responder chain.
    /// Visible in iOS's "Hold ⌘" discoverability HUD.
    @ViewBuilder
    private var keyboardShortcutShelf: some View {
        Group {
            Button("New task") { showingAddTask = true }
                .keyboardShortcut("n", modifiers: .command)
            Button("Today")    { selectedTab = .today }
                .keyboardShortcut("1", modifiers: .command)
            Button("Calendar") { selectedTab = .week }
                .keyboardShortcut("2", modifiers: .command)
            Button("Lists")    { selectedTab = .lists }
                .keyboardShortcut("3", modifiers: .command)
            Button("You")      { selectedTab = .you }
                .keyboardShortcut("4", modifiers: .command)
        }
    }

    private func applyLaunchArgsOnce() {
        guard !didHandleLaunchArgs else { return }
        didHandleLaunchArgs = true

        if let listName = AppLaunchArgs.openListName,
           let list = allLists.first(where: { $0.name.caseInsensitiveCompare(listName) == .orderedSame }) {
            selectedTab = .lists
            listsPath.append(ListSource.list(list))
        }

        if let taskMatch = AppLaunchArgs.openTaskMatching {
            let needle = taskMatch.lowercased()
            if let task = allTasks.first(where: { $0.title.lowercased().contains(needle) }) {
                pendingTaskDetail = task
            }
        }

        if AppLaunchArgs.addTaskPrefill != nil {
            showingAddTask = true
        }
    }
}
