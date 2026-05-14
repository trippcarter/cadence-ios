import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: [SortDescriptor(\TaskItem.dueDate, order: .forward)])
    private var allTasks: [TaskItem]

    /// Refreshed on appear so tasks recompute against the current date if the
    /// app stays open past midnight.
    @State private var now: Date = .now
    @State private var detailTask: TaskItem?
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            Tokens.Color.bg.ignoresSafeArea()

            List {
                Section {
                    TodayHeader(date: now)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Tokens.Space.md, leading: Tokens.Space.lg, bottom: 0, trailing: Tokens.Space.lg))

                    StatStrip(
                        todayCount: timedTasks.count + unscheduledTasks.count,
                        eventsCount: 0,  // Calendar events arrive in Phase 3
                        carriedCount: carriedTasks.count
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Tokens.Space.lg, leading: Tokens.Space.lg, bottom: Tokens.Space.md, trailing: Tokens.Space.lg))
                }

                if !carriedTasks.isEmpty {
                    taskSection(
                        title: "Carried over",
                        count: carriedTasks.count,
                        accent: Tokens.Color.amber,
                        tasks: carriedTasks,
                        showsCarriedChip: true
                    )
                }

                if !timedTasks.isEmpty {
                    taskSection(
                        title: "Today",
                        count: timedTasks.count,
                        accent: Tokens.Color.accent,
                        tasks: timedTasks
                    )
                }

                if !unscheduledTasks.isEmpty {
                    taskSection(
                        title: "Unscheduled",
                        count: unscheduledTasks.count,
                        accent: Tokens.Color.text3,
                        tasks: unscheduledTasks
                    )
                }

                if !completedToday.isEmpty {
                    taskSection(
                        title: "Completed",
                        count: completedToday.count,
                        accent: Tokens.Color.mint,
                        tasks: completedToday
                    )
                }

                if carriedTasks.isEmpty && timedTasks.isEmpty && unscheduledTasks.isEmpty && completedToday.isEmpty {
                    emptyStateRow
                }

                // Breathing room above the floating tab bar
                Color.clear
                    .frame(height: 120)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .refreshable {
                try? await _Concurrency.Task.sleep(for: .milliseconds(600))
                now = .now
                Haptics.tap()
            }
        }
        .onAppear {
            now = .now
            if !hasAppeared {
                withAnimation(.bouncy(duration: 0.55).delay(0.05)) {
                    hasAppeared = true
                }
            }
        }
        .sheet(item: $detailTask) { task in
            TaskDetailSheet(task: task)
        }
    }

    // MARK: Section builder

    @ViewBuilder
    private func taskSection(title: String, count: Int, accent: Color, tasks: [TaskItem], showsCarriedChip: Bool = false) -> some View {
        Section {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                TaskRowActionContainer(task: task) {
                    TaskRow(
                        task: task,
                        showsCarriedOverChip: showsCarriedChip,
                        onTitleTap: { detailTask = task }
                    )
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 12)
                .animation(
                    .bouncy(duration: 0.5).delay(Double(index) * 0.05),
                    value: hasAppeared
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: Tokens.Space.lg, bottom: 4, trailing: Tokens.Space.lg))
            }
        } header: {
            GroupHeader(title: title, count: count, accent: accent)
                .padding(.bottom, 4)
                .textCase(nil)
        }
        .listSectionSeparator(.hidden)
    }

    // MARK: Empty state

    private var emptyStateRow: some View {
        VStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Color.accent.opacity(0.12))
                    .frame(width: 76, height: 76)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
            }
            Text("Nothing on your plate today")
                .font(Tokens.Font.title)
                .foregroundStyle(Tokens.Color.text)
            Text("Tap the + below to add a task, or pull down to refresh.")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.xxl)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Tokens.Space.xxxl)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: Derived task buckets

    private var carriedTasks: [TaskItem] {
        allTasks
            .filter { $0.isCarriedOver }
            .sorted(by: { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) })
    }

    private var timedTasks: [TaskItem] {
        allTasks.filter { task in
            task.status == .open
                && !task.isCarriedOver
                && task.dueDate != nil
                && Calendar.current.isDateInToday(task.dueDate!)
                && !task.allDay
        }
    }

    private var unscheduledTasks: [TaskItem] {
        allTasks.filter { task in
            task.status == .open
                && !task.isCarriedOver
                && task.dueDate != nil
                && Calendar.current.isDateInToday(task.dueDate!)
                && task.allDay
        }
    }

    private var completedToday: [TaskItem] {
        allTasks.filter { task in
            task.status == .completed
                && task.completedAt != nil
                && Calendar.current.isDateInToday(task.completedAt!)
        }
        .sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) })
    }
}
