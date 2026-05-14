import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: [SortDescriptor(\TaskItem.dueDate, order: .forward)])
    private var allTasks: [TaskItem]
    @Query(sort: [SortDescriptor(\CachedEvent.start, order: .forward)])
    private var allEvents: [CachedEvent]

    @ObservedObject private var calendarService = GoogleCalendarService.shared

    /// Set by RootView via env to flip the selected tab when the user taps
    /// the "Reconnect Google Calendar" banner.
    var onRequestSettingsTab: (() -> Void)? = nil

    /// Refreshed on appear so tasks recompute against the current date if the
    /// app stays open past midnight.
    @State private var now: Date = .now
    @State private var detailTask: TaskItem?
    @State private var detailEvent: CachedEvent?
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            Tokens.Color.bg.ignoresSafeArea()

            List {
                Section {
                    if showsReconnectBanner {
                        ReconnectBanner {
                            onRequestSettingsTab?()
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Tokens.Space.md, leading: Tokens.Space.lg, bottom: 0, trailing: Tokens.Space.lg))
                    }

                    TodayHeader(date: now)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Tokens.Space.md, leading: Tokens.Space.lg, bottom: 0, trailing: Tokens.Space.lg))

                    if !allDayEventsToday.isEmpty {
                        AllDayEventStrip(events: allDayEventsToday) { event in
                            detailEvent = event
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Tokens.Space.sm, leading: Tokens.Space.lg, bottom: 0, trailing: Tokens.Space.lg))
                    }

                    StatStrip(
                        todayCount: timedTasks.count + unscheduledTasks.count,
                        eventsCount: timedEventsToday.count + allDayEventsToday.count,
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

                if !timelineItems.isEmpty {
                    timelineSection
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

                if carriedTasks.isEmpty && timelineItems.isEmpty && unscheduledTasks.isEmpty && completedToday.isEmpty {
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
                await calendarService.fetchAllEvents()
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
        .sheet(item: $detailEvent) { event in
            EventDetailSheet(event: event)
        }
    }

    // MARK: Mixed timeline (tasks + events, sorted by time)

    enum TimelineItem: Identifiable {
        case task(TaskItem)
        case event(CachedEvent)

        var id: String {
            switch self {
            case .task(let t): return "task-\(t.id)"
            case .event(let e): return "event-\(e.id)"
            }
        }

        var sortKey: Date {
            switch self {
            case .task(let t): return t.dueDate ?? .distantFuture
            case .event(let e): return e.start
            }
        }
    }

    private var timelineItems: [TimelineItem] {
        let tasks = timedTasks.map { TimelineItem.task($0) }
        let events = timedEventsToday.map { TimelineItem.event($0) }
        return (tasks + events).sorted { $0.sortKey < $1.sortKey }
    }

    @ViewBuilder
    private var timelineSection: some View {
        Section {
            ForEach(Array(timelineItems.enumerated()), id: \.element.id) { index, item in
                Group {
                    switch item {
                    case .task(let task):
                        TaskRowActionContainer(task: task) {
                            TaskRow(
                                task: task,
                                onTitleTap: { detailTask = task }
                            )
                        }
                    case .event(let event):
                        EventRow(event: event) { detailEvent = event }
                    }
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
            GroupHeader(title: "Today", count: timelineItems.count, accent: Tokens.Color.accent)
                .padding(.bottom, 4)
                .textCase(nil)
        }
        .listSectionSeparator(.hidden)
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

    // MARK: Event buckets

    private var timedEventsToday: [CachedEvent] {
        allEvents.filter { event in
            !event.isAllDay && Calendar.current.isDateInToday(event.start)
        }
    }

    private var allDayEventsToday: [CachedEvent] {
        allEvents.filter { event in
            event.isAllDay && Calendar.current.isDateInToday(event.start)
        }
    }

    private var showsReconnectBanner: Bool {
        if case .tokenExpired = calendarService.lastError { return true }
        return false
    }
}

// MARK: - All-day event strip

struct AllDayEventStrip: View {
    let events: [CachedEvent]
    var onTap: (CachedEvent) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.sm) {
                ForEach(events) { event in
                    Button { onTap(event) } label: {
                        HStack(spacing: 6) {
                            Circle().fill(Tokens.Color.teal).frame(width: 6, height: 6)
                            Text(event.title)
                                .font(Tokens.Font.chip)
                                .foregroundStyle(Tokens.Color.text)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Tokens.Color.teal.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Tokens.Color.teal.opacity(0.3), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
