import SwiftUI
import SwiftData

/// Build 21: the only screen on the Watch in v1. Shows today's open tasks
/// (including carried-over from prior days), each with a tap-to-complete
/// circle. Future builds will add Lists drill-down, voice add, Settings.
struct WatchTodayView: View {
    @Query(sort: [SortDescriptor(\TaskItem.dueDate, order: .forward)])
    private var allTasks: [TaskItem]

    /// Open tasks due today (timed + all-day) + carried over from prior
    /// days. Excludes subtasks and pinned-section tasks render same as any
    /// other Today task on the small screen.
    private var visibleTasks: [TaskItem] {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: .now)
        return allTasks.filter { task in
            guard task.parent == nil, task.status == .open else { return false }
            guard let due = task.dueDate else { return false }
            return cal.isDateInToday(due) || due < startOfToday
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 6) {
                    headerStrip
                    if visibleTasks.isEmpty {
                        emptyState
                    } else {
                        ForEach(visibleTasks) { task in
                            WatchTaskRow(task: task)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
            }
            .navigationTitle("Today")
        }
    }

    /// Compact stats: 3 numbers (open / carried / completed today) with
    /// color coding. No labels — the dot color tells the story.
    private var headerStrip: some View {
        let openToday = visibleTasks.count
        let cal = Calendar.current
        let completedToday = allTasks.filter { t in
            guard let completedAt = t.completedAt else { return false }
            return t.status == .completed && cal.isDateInToday(completedAt)
        }.count
        let carried = visibleTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due < cal.startOfDay(for: .now)
        }.count
        return HStack(spacing: 8) {
            statPill(value: openToday, tint: .purple, label: "today")
            statPill(value: carried, tint: .orange, label: "back")
            statPill(value: completedToday, tint: .mint, label: "done")
        }
        .padding(.bottom, 4)
    }

    private func statPill(value: Int, tint: Color, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(tint.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 32))
                .foregroundStyle(.purple)
            Text("Nothing today")
                .font(.system(size: 14, weight: .semibold))
            Text("Enjoy the quiet.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }
}
