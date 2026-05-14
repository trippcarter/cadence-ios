import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: [SortDescriptor(\TaskItem.dueDate, order: .forward)])
    private var allTasks: [TaskItem]

    /// Refreshed on appear so tasks recompute against the current date if the
    /// app stays open past midnight.
    @State private var now: Date = .now

    var body: some View {
        ZStack {
            Tokens.Color.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                    TodayHeader(date: now)

                    StatStrip(
                        todayCount: timedTasks.count + unscheduledTasks.count,
                        eventsCount: 0,  // Calendar events arrive in Phase 3
                        carriedCount: carriedTasks.count
                    )

                    if !carriedTasks.isEmpty {
                        section(
                            header: GroupHeader(
                                title: "Carried over",
                                count: carriedTasks.count,
                                accent: Tokens.Color.amber
                            ),
                            tasks: carriedTasks,
                            showsCarriedChip: true
                        )
                    }

                    if !timedTasks.isEmpty {
                        section(
                            header: GroupHeader(
                                title: "Today",
                                count: timedTasks.count,
                                accent: Tokens.Color.accent
                            ),
                            tasks: timedTasks
                        )
                    }

                    if !unscheduledTasks.isEmpty {
                        section(
                            header: GroupHeader(
                                title: "Unscheduled",
                                count: unscheduledTasks.count,
                                accent: Tokens.Color.text3
                            ),
                            tasks: unscheduledTasks
                        )
                    }

                    if !completedToday.isEmpty {
                        section(
                            header: GroupHeader(
                                title: "Completed",
                                count: completedToday.count,
                                accent: Tokens.Color.mint
                            ),
                            tasks: completedToday
                        )
                    }

                    // Breathing room above the floating tab bar
                    Color.clear.frame(height: 120)
                }
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.top, Tokens.Space.lg)
            }
            .refreshable {
                try? await _Concurrency.Task.sleep(for: .milliseconds(600))
                now = .now
            }
            .scrollIndicators(.hidden)
        }
        .onAppear { now = .now }
    }

    // MARK: Section builder

    private func section(header: GroupHeader, tasks: [TaskItem], showsCarriedChip: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            header
            VStack(spacing: Tokens.Space.sm) {
                ForEach(tasks) { task in
                    TaskRow(task: task, showsCarriedOverChip: showsCarriedChip)
                }
            }
        }
    }

    // MARK: Derived task buckets

    /// Carried-over: status == .open AND dueDate is before today's start-of-day.
    private var carriedTasks: [TaskItem] {
        allTasks
            .filter { $0.isCarriedOver }
            .sorted(by: { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) })
    }

    /// Today + has a specific time (not all-day).
    private var timedTasks: [TaskItem] {
        allTasks.filter { task in
            task.status == .open
                && !task.isCarriedOver
                && task.dueDate != nil
                && Calendar.current.isDateInToday(task.dueDate!)
                && !task.allDay
        }
    }

    /// Today + all-day (no specific time).
    private var unscheduledTasks: [TaskItem] {
        allTasks.filter { task in
            task.status == .open
                && !task.isCarriedOver
                && task.dueDate != nil
                && Calendar.current.isDateInToday(task.dueDate!)
                && task.allDay
        }
    }

    /// Completed within the last 24 hours so the user sees their wins.
    private var completedToday: [TaskItem] {
        allTasks.filter { task in
            task.status == .completed
                && task.completedAt != nil
                && Calendar.current.isDateInToday(task.completedAt!)
        }
        .sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) })
    }
}
