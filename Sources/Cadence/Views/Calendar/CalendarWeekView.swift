import SwiftUI
import SwiftData

/// Week mode: day strip at top, selected day's timeline below. Swipes
/// between weeks; tap a day to select it.
struct CalendarWeekView: View {
    @Binding var referenceDate: Date
    var onTapTask: (TaskItem) -> Void
    var onTapEvent: (CachedEvent) -> Void

    @State private var selectedDay: Date = .now
    @Query private var allTasks: [TaskItem]
    @Query private var allEvents: [CachedEvent]

    private let pageRange = -52...52

    var body: some View {
        TabView(selection: Binding(
            get: { weekStart(of: referenceDate) },
            set: { newStart in
                referenceDate = newStart
                // If selected day is outside the new week, jump to its Monday.
                if !Calendar.current.isDate(selectedDay, equalTo: newStart, toGranularity: .weekOfYear) {
                    selectedDay = newStart
                }
            }
        )) {
            ForEach(pageStarts, id: \.self) { start in
                weekPage(start: start)
                    .tag(start)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onAppear {
            if Calendar.current.isDate(selectedDay, equalTo: .distantPast, toGranularity: .day) {
                selectedDay = .now
            }
        }
    }

    private var pageStarts: [Date] {
        pageRange.compactMap { offset in
            Calendar.current.date(byAdding: .weekOfYear, value: offset, to: weekStart(of: .now))
        }
    }

    private func weekStart(of date: Date) -> Date {
        WeekMath.weekDays(for: date).first ?? Calendar.current.startOfDay(for: date)
    }

    @ViewBuilder
    private func weekPage(start: Date) -> some View {
        let days = WeekMath.weekDays(for: start)
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            WeekDayStrip(days: days, selectedDay: $selectedDay) { day in
                dots(for: day)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.top, Tokens.Space.md)

            Divider().background(Tokens.Color.borderSoft)

            ScrollView {
                WeekTimeline(
                    tasks: tasksForSelectedDay,
                    events: eventsForSelectedDay,
                    day: selectedDay,
                    onTapTask: onTapTask,
                    onTapEvent: onTapEvent
                )
                Color.clear.frame(height: 120)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            // When this week page becomes visible, default selectedDay into it.
            if !days.contains(where: { Calendar.current.isDate($0, inSameDayAs: selectedDay) }) {
                selectedDay = days.first { Calendar.current.isDateInToday($0) } ?? days[0]
            }
        }
    }

    // MARK: Derived

    private var tasksForSelectedDay: [TaskItem] {
        let cal = Calendar.current
        return allTasks.filter { task in
            guard let due = task.dueDate, task.parent == nil else { return false }
            return cal.isDate(due, inSameDayAs: selectedDay)
        }
    }

    private var eventsForSelectedDay: [CachedEvent] {
        let cal = Calendar.current
        return allEvents.filter { cal.isDate($0.start, inSameDayAs: selectedDay) }
    }

    private func dots(for day: Date) -> [Color] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let todayStart = cal.startOfDay(for: .now)
        let tasksOnDay = allTasks.filter { t in
            guard let due = t.dueDate, t.parent == nil else { return false }
            return cal.isDate(due, inSameDayAs: day)
        }
        let eventsOnDay = allEvents.filter { cal.isDate($0.start, inSameDayAs: day) }
        let openCount = tasksOnDay.filter { $0.status == .open }.count
        let hadCarried = dayStart < todayStart && openCount > 0
        var result: [Color] = []
        if openCount > 0 { result.append(Tokens.Color.accent) }
        if !eventsOnDay.isEmpty { result.append(Tokens.Color.teal) }
        if hadCarried { result.append(Tokens.Color.amber) }
        return Array(result.prefix(3))
    }
}
