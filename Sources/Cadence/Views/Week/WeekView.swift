import SwiftUI
import SwiftData

struct WeekView: View {
    @Query private var allTasks: [TaskItem]
    @Query private var allEvents: [CachedEvent]

    @State private var weekStart: Date = .now
    @State private var selectedDay: Date = .now
    @State private var detailTask: TaskItem?
    @State private var detailEvent: CachedEvent?

    var body: some View {
        ZStack {
            Tokens.Color.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                header
                WeekDayStrip(days: days, selectedDay: $selectedDay) { day in
                    dots(for: day)
                }
                .padding(.horizontal, Tokens.Space.lg)

                Divider().background(Tokens.Color.borderSoft)

                ScrollView {
                    WeekTimeline(
                        tasks: tasksForSelectedDay,
                        events: eventsForSelectedDay,
                        day: selectedDay,
                        onTapTask: { detailTask = $0 },
                        onTapEvent: { detailEvent = $0 }
                    )
                    Color.clear.frame(height: 120)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.top, Tokens.Space.lg)
        }
        .onAppear {
            weekStart = .now
            selectedDay = .now
        }
        .sheet(item: $detailTask) { task in
            TaskDetailSheet(task: task)
        }
        .sheet(item: $detailEvent) { event in
            EventDetailSheet(event: event)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("THIS WEEK")
                        .font(Tokens.Font.label)
                        .kerning(1.2)
                        .foregroundStyle(Tokens.Color.text3)
                    Text(WeekMath.rangeLabel(for: days))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Tokens.Color.text)
                }
                Spacer()
                Text(selectedDayLabel)
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.accent2)
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
    }

    private var selectedDayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: selectedDay).uppercased()
    }

    // MARK: Derived data

    private var days: [Date] {
        WeekMath.weekDays(for: weekStart)
    }

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

    /// Up to 3 dots per day:
    /// - violet for open task on this day
    /// - teal for calendar event on this day
    /// - amber if the day is in the past and had carried-over work
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
