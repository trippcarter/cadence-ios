import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: [SortDescriptor(\TaskItem.dueDate, order: .forward)])
    private var allTasks: [TaskItem]
    @Query(sort: [SortDescriptor(\CachedEvent.start, order: .forward)])
    private var allEvents: [CachedEvent]

    @ObservedObject private var calendarService = GoogleCalendarService.shared
    @EnvironmentObject private var cloudSync: CloudKitSyncManager

    /// Set by RootView via env to flip the selected tab when the user taps
    /// the "Reconnect Google Calendar" banner.
    var onRequestSettingsTab: (() -> Void)? = nil
    /// Build 13: lets the empty-state "Add something" CTA reuse the same
    /// AddTaskSheet that the floating + tab-bar button presents.
    var onRequestQuickAdd: (() -> Void)? = nil
    /// Build 25: opens the cross-entity search sheet — wired from
    /// RootView, shared with the ⌘F keyboard shortcut.
    var onRequestSearch: (() -> Void)? = nil

    /// Refreshed on appear so tasks recompute against the current date if the
    /// app stays open past midnight.
    @State private var now: Date = .now
    @State private var detailTask: TaskItem?
    @State private var detailEvent: CachedEvent?
    @State private var hasAppeared = false

    // Build 25: section collapse state. Defaults match Settings toggles
    // (autoCollapseCarriedThreshold). Carried-over auto-collapses when
    // it has more than the threshold; Coming up always defaults closed
    // (it's a sneak peek, not the focus).
    @State private var carriedExpanded: Bool = false
    @State private var comingUpExpanded: Bool = false

    @AppStorage(PrefsKey.showComingUpSection) private var showsComingUpSection: Bool = true
    @AppStorage(PrefsKey.comingUpWindowDays) private var comingUpWindowDays: Int = 7
    @AppStorage(PrefsKey.autoCollapseCarriedThreshold) private var autoCollapseCarriedThreshold: Int = 3

    var body: some View {
        ZStack {
            // Build 13: subtle radial gradient at the top — adds depth without
            // being noisy. The adaptive Tokens.Color.bg / bg2 mean this also
            // looks right in light mode.
            RadialGradient(
                colors: [Tokens.Color.bg2, Tokens.Color.bg],
                center: .top,
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()

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

                    if showsCloudSignInBanner {
                        cloudSignInBanner
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: Tokens.Space.md, leading: Tokens.Space.lg, bottom: 0, trailing: Tokens.Space.lg))
                    }

                    GreetingHeader(
                        date: now,
                        completedCount: completedToday.count,
                        totalCount: completedToday.count + pinnedTasks.count + carriedTasks.count + timedTasks.count + unscheduledTasks.count,
                        onTapAvatar: { onRequestSettingsTab?() },
                        onTapSearch: { onRequestSearch?() }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Tokens.Space.md, leading: Tokens.Space.lg, bottom: Tokens.Space.sm, trailing: Tokens.Space.lg))

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

                // Build 25 reorg: Pinned → Today → Coming up → Carried over
                // → Completed. Carried over no longer dominates the top of
                // the screen even when there are old tasks lingering.

                if !pinnedTasks.isEmpty {
                    taskSection(
                        title: "Pinned",
                        count: pinnedTasks.count,
                        accent: Tokens.Color.amber,
                        tasks: pinnedTasks
                    )
                }

                if !timelineItems.isEmpty {
                    timelineSection
                }

                if !unscheduledTasks.isEmpty {
                    anytimeSection(tasks: unscheduledTasks)
                }

                if showsComingUpSection, !comingUpTasks.isEmpty {
                    collapsibleSection(
                        title: "Coming up",
                        count: comingUpTasks.count,
                        accent: Tokens.Color.indigo,
                        tasks: comingUpTasks,
                        isExpanded: $comingUpExpanded
                    )
                }

                if !carriedTasks.isEmpty {
                    collapsibleSection(
                        title: "Carried over",
                        count: carriedTasks.count,
                        accent: Tokens.Color.amber,
                        tasks: carriedTasks,
                        isExpanded: $carriedExpanded,
                        showsCarriedChip: true
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

                if pinnedTasks.isEmpty && carriedTasks.isEmpty && timelineItems.isEmpty && unscheduledTasks.isEmpty && completedToday.isEmpty && comingUpTasks.isEmpty {
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
                // Build 25: auto-collapse Carried Over on first appear if
                // there are enough items to be visually noisy. Coming up
                // also defaults collapsed — it's a sneak peek, not the
                // focus.
                carriedExpanded = carriedTasks.count <= autoCollapseCarriedThreshold
                comingUpExpanded = false
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
                        TaskRowActionContainer(task: task, onEdit: { detailTask = task }) {
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

    // MARK: Anytime today (Upgrade 1)

    /// Untimed tasks for today. Build 12 rename: "Unscheduled" → "Anytime
    /// today". When the bucket grows past 5, swap from full-width rows to
    /// a 2-column compact grid so the list doesn't visually overwhelm.
    @ViewBuilder
    private func anytimeSection(tasks: [TaskItem]) -> some View {
        let useGrid = tasks.count > 5
        if useGrid {
            Section {
                anytimeGrid(tasks: tasks)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: Tokens.Space.lg, bottom: 4, trailing: Tokens.Space.lg))
            } header: {
                GroupHeader(title: "Anytime today",
                            count: tasks.count,
                            accent: Tokens.Color.text2,
                            trailingLabel: "\(tasks.count) anytime")
                    .padding(.bottom, 4)
                    .textCase(nil)
            }
            .listSectionSeparator(.hidden)
        } else {
            taskSection(
                title: "Anytime today",
                count: tasks.count,
                accent: Tokens.Color.text2,
                tasks: tasks
            )
        }
    }

    private func anytimeGrid(tasks: [TaskItem]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: Tokens.Space.sm),
            GridItem(.flexible(), spacing: Tokens.Space.sm)
        ]
        return LazyVGrid(columns: columns, spacing: Tokens.Space.sm) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                TaskRowActionContainer(task: task, onEdit: { detailTask = task }) {
                    AnytimeGridCard(task: task) {
                        detailTask = task
                    }
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 12)
                .animation(
                    .bouncy(duration: 0.5).delay(Double(index) * 0.03),
                    value: hasAppeared
                )
            }
        }
    }

    // MARK: Section builder

    /// Build 25: a section that renders the same row layout as taskSection
    /// but with a tappable header that toggles a binding-controlled expand
    /// state. Tap the header → spring animation collapses/expands the
    /// rows. Header shows a chevron + count when collapsed.
    @ViewBuilder
    private func collapsibleSection(
        title: String,
        count: Int,
        accent: Color,
        tasks: [TaskItem],
        isExpanded: Binding<Bool>,
        showsCarriedChip: Bool = false
    ) -> some View {
        Section {
            if isExpanded.wrappedValue {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    TaskRowActionContainer(task: task, onEdit: { detailTask = task }) {
                        TaskRow(
                            task: task,
                            showsCarriedOverChip: showsCarriedChip,
                            onTitleTap: { detailTask = task }
                        )
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 12)
                    .animation(
                        .bouncy(duration: 0.5).delay(Double(index) * 0.04),
                        value: hasAppeared
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: Tokens.Space.lg, bottom: 4, trailing: Tokens.Space.lg))
                }
            }
        } header: {
            Button {
                Haptics.tap()
                withAnimation(.bouncy(duration: 0.4)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Tokens.Color.text3)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                        .animation(.smooth(duration: 0.25), value: isExpanded.wrappedValue)
                    GroupHeader(title: title, count: count, accent: accent)
                        .textCase(nil)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
        }
        .listSectionSeparator(.hidden)
    }

    private func taskSection(title: String, count: Int, accent: Color, tasks: [TaskItem], showsCarriedChip: Bool = false) -> some View {
        Section {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                TaskRowActionContainer(task: task, onEdit: { detailTask = task }) {
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

    // MARK: Empty state (Build 13 polish)

    /// Friendly empty state with a layered moon+stars illustration and a
    /// "Add something" CTA that opens AddTaskSheet.
    private var emptyStateRow: some View {
        VStack(spacing: Tokens.Space.lg) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Tokens.Color.accent.opacity(0.22), Tokens.Color.accent.opacity(0.04)],
                            center: .center,
                            startRadius: 8,
                            endRadius: 70
                        )
                    )
                    .frame(width: 110, height: 110)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Tokens.Color.accent2, Tokens.Color.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Tokens.Color.accentGlow, radius: 12, x: 0, y: 6)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Tokens.Color.amber)
                    .offset(x: 38, y: -32)
            }

            VStack(spacing: 6) {
                Text("Nothing on your plate today")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Color.text)
                Text("Enjoy the quiet.")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text3)
                    .multilineTextAlignment(.center)
            }

            Button {
                Haptics.tap()
                onRequestQuickAdd?()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add something")
                        .font(Tokens.Font.bodyEmphasis)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.vertical, Tokens.Space.sm + 2)
                .background(
                    LinearGradient(
                        colors: [Tokens.Color.accent, Tokens.Color.accentDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Tokens.Color.accentGlow, radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Tokens.Space.xxl)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: Derived task buckets

    /// Pinned section (Build 12, Upgrade 6). Shows above everything else
    /// on Today. Pinned tasks are EXCLUDED from the other buckets so the
    /// user doesn't see them twice.
    private var pinnedTasks: [TaskItem] {
        allTasks
            .filter { $0.isPinned && $0.parent == nil && $0.status != .completed }
            .sorted(by: taskOrdering)
    }

    private var carriedTasks: [TaskItem] {
        allTasks
            .filter { $0.isCarriedOver && !$0.isPinned }
            .sorted(by: { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) })
    }

    private var timedTasks: [TaskItem] {
        allTasks.filter { task in
            task.status == .open
                && !task.isCarriedOver
                && !task.isPinned
                && task.dueDate != nil
                && Calendar.current.isDateInToday(task.dueDate!)
                && !task.allDay
        }
    }

    private var unscheduledTasks: [TaskItem] {
        allTasks
            .filter { task in
                task.status == .open
                    && !task.isCarriedOver
                    && !task.isPinned
                    && task.dueDate != nil
                    && Calendar.current.isDateInToday(task.dueDate!)
                    && task.allDay
            }
            .sorted(by: taskOrdering)
    }

    /// Build 25: tasks due in the next N days (excluding today + carried
    /// over). Surfaced in a collapsible "Coming up" section below Today.
    /// Window is user-configurable (Settings → Today → Coming up window).
    private var comingUpTasks: [TaskItem] {
        let cal = Calendar.current
        let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now)) ?? .now
        let windowEnd = cal.date(byAdding: .day, value: comingUpWindowDays, to: startOfTomorrow) ?? .now
        return allTasks
            .filter { task in
                guard task.status == .open,
                      task.parent == nil,
                      !task.isPinned,
                      let due = task.dueDate else { return false }
                // Strictly between tomorrow's start and the configured
                // window end. Today's own tasks are excluded; so is
                // anything carried over from before.
                return due >= startOfTomorrow && due < windowEnd
            }
            .sorted(by: taskOrdering)
    }

    /// Build 12 sort: explicit sortOrder first (so drag-reorder wins), then
    /// dueDate, then createdAt as a stable tiebreaker.
    private func taskOrdering(_ a: TaskItem, _ b: TaskItem) -> Bool {
        if a.sortOrder != b.sortOrder { return a.sortOrder < b.sortOrder }
        let aDue = a.dueDate ?? .distantFuture
        let bDue = b.dueDate ?? .distantFuture
        if aDue != bDue { return aDue < bDue }
        return a.createdAt < b.createdAt
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

    private var showsCloudSignInBanner: Bool {
        cloudSync.accountStatus == .noAccount
    }

    private var cloudSignInBanner: some View {
        Button {
            onRequestSettingsTab?()
        } label: {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: "cloud.slash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in to iCloud to sync")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    Text("Your tasks stay on this device until you do.")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .background(Tokens.Color.amber.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.amber.opacity(0.4), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
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
