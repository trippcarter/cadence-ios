import SwiftUI
import SwiftData

/// Build 18: grid of habit cards reachable from the Lists tab's "Habits"
/// smart filter card. Each card shows current streak (big flame + number),
/// longest streak (subtle), and a 30-day mini-calendar of dots.
///
/// Tap a card → opens the underlying task's detail sheet (same flow as a
/// normal task tap) so the user can edit, snooze, or stop-tracking from
/// the existing surface.
struct HabitsDashboardView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\TaskItem.title, order: .forward)])
    private var allTasks: [TaskItem]

    private var habits: [TaskItem] {
        allTasks.filter { $0.isHabit && $0.parent == nil }
    }

    @State private var detailTask: TaskItem?

    var body: some View {
        ZStack {
            Tokens.Color.bg.ignoresSafeArea()
            if habits.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .navigationTitle("Habits")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Tokens.Color.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(item: $detailTask) { task in
            TaskDetailSheet(task: task)
        }
    }

    private var grid: some View {
        let columns = [
            GridItem(.flexible(), spacing: Tokens.Space.md),
            GridItem(.flexible(), spacing: Tokens.Space.md)
        ]
        return ScrollView {
            LazyVGrid(columns: columns, spacing: Tokens.Space.md) {
                ForEach(habits) { habit in
                    HabitCard(task: habit) {
                        detailTask = habit
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.top, Tokens.Space.md)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: Tokens.Space.lg) {
            ZStack {
                Circle()
                    .fill(Tokens.Color.amber.opacity(0.18))
                    .frame(width: 96, height: 96)
                Image(systemName: "flame")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Tokens.Color.amber)
            }
            VStack(spacing: 6) {
                Text("No habits yet")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Color.text)
                Text("Open any recurring task → toggle \"Track as habit\" to start a streak.")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.xxl)
            }
        }
    }
}

private struct HabitCard: View {
    let task: TaskItem
    var onTap: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let current = HabitTracker.currentStreak(for: task, in: modelContext)
        let longest = HabitTracker.longestStreak(for: task, in: modelContext)
        let days = HabitTracker.recentDays(for: task, in: modelContext, count: 30)
        let tint = streakTint(current)

        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(tint)
                    Text("\(current)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Tokens.Color.text)
                        .monospacedDigit()
                    Spacer()
                    if longest > current {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("BEST")
                                .font(Tokens.Font.label)
                                .kerning(0.6)
                                .foregroundStyle(Tokens.Color.text3)
                            Text("\(longest)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Tokens.Color.text2)
                                .monospacedDigit()
                        }
                    }
                }
                Text(task.title)
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                miniCalendar(days: days, tint: tint)
            }
            .padding(Tokens.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(current > 0 ? tint.opacity(0.35) : Tokens.Color.borderSoft,
                            lineWidth: current > 0 ? 1 : 0.5)
            )
            .shadow(color: current >= 7 ? tint.opacity(0.12) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func miniCalendar(days: [(date: Date, done: Bool)], tint: Color) -> some View {
        // 30 days, 5 columns × 6 rows. Reverse so oldest is top-left.
        let chronological = days.reversed()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 5)
        return LazyVGrid(columns: columns, spacing: 3) {
            ForEach(Array(chronological.enumerated()), id: \.offset) { _, day in
                Circle()
                    .fill(day.done ? tint : Tokens.Color.text3.opacity(0.18))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func streakTint(_ streak: Int) -> Color {
        switch streak {
        case 100...: return Tokens.Color.mint
        case 30...:  return Tokens.Color.orange
        case 7...:   return Tokens.Color.amber
        default:     return Tokens.Color.text3
        }
    }
}
