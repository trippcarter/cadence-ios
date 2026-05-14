import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .today
    @State private var showingAddTask = false

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
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .today:
            TodayView()
        case .week:
            PlaceholderView(
                title: "Week view",
                subtitle: "Coming next session. Tasks and events laid out across the next seven days."
            )
        case .lists:
            PlaceholderView(
                title: "Lists",
                subtitle: "Inbox, Personal, Business, and Joint Business. Tap to drill in — coming next session."
            )
        case .you:
            PlaceholderView(
                title: "You",
                subtitle: "Settings, connected accounts, notifications, and AI preferences live here."
            )
        }
    }
}
