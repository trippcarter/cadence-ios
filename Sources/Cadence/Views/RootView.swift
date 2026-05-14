import SwiftUI
import SwiftData

struct RootView: View {
    @State private var selectedTab: AppTab = AppLaunchArgs.initialTab
    @State private var showingAddTask = false
    @State private var listsPath = NavigationPath()
    @State private var pendingTaskDetail: TaskItem?
    @State private var didHandleLaunchArgs = false

    @AppStorage(PrefsKey.hasOnboarded) private var hasOnboarded: Bool = false

    @Query private var allLists: [TaskList]
    @Query private var allTasks: [TaskItem]

    var body: some View {
        ZStack(alignment: .bottom) {
            content
            BottomTabBar(selected: $selectedTab) {
                showingAddTask = true
            }
        }
        .ignoresSafeArea(.keyboard)
        .background(Tokens.Color.bg.ignoresSafeArea())
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet()
        }
        .sheet(item: $pendingTaskDetail) { task in
            TaskDetailSheet(task: task)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasOnboarded },
            set: { if !$0 { hasOnboarded = true } }
        )) {
            OnboardingView()
        }
        .onAppear {
            applyLaunchArgsOnce()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .today:
            TodayView()
        case .week:
            WeekView()
        case .lists:
            NavigationStack(path: $listsPath) {
                ListsView()
            }
        case .you:
            SettingsView()
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
    }
}
