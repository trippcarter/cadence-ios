import SwiftUI
import SwiftData

/// Single-day timeline with all tasks + events. Swipes left/right to move
/// between consecutive days.
struct CalendarDayView: View {
    @Binding var referenceDate: Date
    var onTapTask: (TaskItem) -> Void
    var onTapEvent: (CachedEvent) -> Void

    @Query private var allTasks: [TaskItem]
    @Query private var allEvents: [CachedEvent]

    private let pageRange = -120...120  // ~4 months in each direction

    var body: some View {
        TabView(selection: Binding(
            get: { Calendar.current.startOfDay(for: referenceDate) },
            set: { referenceDate = $0 }
        )) {
            ForEach(pageDates, id: \.self) { day in
                dayPage(day)
                    .tag(day)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var pageDates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return pageRange.compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: today)
        }
    }

    @ViewBuilder
    private func dayPage(_ day: Date) -> some View {
        let cal = Calendar.current
        let untimedTasks = allTasks.filter { task in
            guard task.parent == nil,
                  task.status == .open,
                  let due = task.dueDate,
                  cal.isDate(due, inSameDayAs: day) else { return false }
            return task.allDay
        }
        let timedTasks = allTasks.filter { task in
            guard task.parent == nil,
                  task.status == .open,
                  let due = task.dueDate,
                  cal.isDate(due, inSameDayAs: day) else { return false }
            return !task.allDay
        }
        let timedEvents = allEvents.filter { event in
            !event.isAllDay && cal.isDate(event.start, inSameDayAs: day)
        }
        let allDayEvents = allEvents.filter { event in
            event.isAllDay && cal.isDate(event.start, inSameDayAs: day)
        }

        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                if !untimedTasks.isEmpty || !allDayEvents.isEmpty {
                    unscheduledStrip(tasks: untimedTasks, events: allDayEvents)
                        .padding(.horizontal, Tokens.Space.lg)
                        .padding(.top, Tokens.Space.md)
                }
                DayHourTimeline(
                    day: day,
                    tasks: timedTasks,
                    events: timedEvents,
                    onTapTask: onTapTask,
                    onTapEvent: onTapEvent
                )
                Color.clear.frame(height: 120)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func unscheduledStrip(tasks: [TaskItem], events: [CachedEvent]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ALL DAY")
                .font(Tokens.Font.label)
                .kerning(1.0)
                .foregroundStyle(Tokens.Color.text3)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tokens.Space.sm) {
                    ForEach(events) { event in
                        Button { onTapEvent(event) } label: {
                            allDayChip(title: event.title, tint: Tokens.Color.teal, icon: "calendar")
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(tasks) { task in
                        let tint = ListPalette.color(for: task.list?.colorKey ?? "violet")
                        Button { onTapTask(task) } label: {
                            allDayChip(title: task.title, tint: tint, icon: nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(Tokens.Space.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
        )
    }

    private func allDayChip(title: String, tint: Color, icon: String?) -> some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).font(.system(size: 9, weight: .semibold)) }
            Circle().fill(tint).frame(width: 6, height: 6).opacity(icon == nil ? 1 : 0)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Tokens.Color.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.14))
        .foregroundStyle(tint)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.4), lineWidth: 0.5))
    }
}

// MARK: - Hour timeline (used by Day view)

private struct DayHourTimeline: View {
    let day: Date
    let tasks: [TaskItem]
    let events: [CachedEvent]
    var onTapTask: (TaskItem) -> Void
    var onTapEvent: (CachedEvent) -> Void

    private let startHour = 5
    private let endHour = 23
    private let hourHeight: CGFloat = 60
    private let labelColumnWidth: CGFloat = 56

    var body: some View {
        ZStack(alignment: .topLeading) {
            hourGrid
            taskBlocks
            eventBlocks
            if showsNowLine {
                nowLine
            }
        }
        .frame(height: CGFloat(endHour - startHour) * hourHeight)
    }

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    Text(hourLabel(hour))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Tokens.Color.text3)
                        .kerning(0.4)
                        .frame(width: labelColumnWidth, alignment: .leading)
                        .padding(.top, -6)
                        .padding(.leading, Tokens.Space.lg)
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Tokens.Color.borderSoft)
                            .frame(height: 0.5)
                        Spacer()
                    }
                }
                .frame(height: hourHeight)
            }
        }
    }

    private var taskBlocks: some View {
        ForEach(tasks) { task in
            if let positioned = position(for: task.dueDate, duration: 30 * 60) {
                let tint = ListPalette.color(for: task.list?.colorKey ?? "violet")
                blockView(title: task.title,
                          subtitle: task.dueDate.map { $0.formatted(.dateTime.hour().minute()) } ?? "",
                          tint: tint,
                          icon: nil,
                          height: positioned.height)
                    .offset(x: labelColumnWidth + Tokens.Space.lg, y: positioned.y)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, labelColumnWidth + Tokens.Space.lg + Tokens.Space.lg)
                    .onTapGesture { onTapTask(task) }
            }
        }
    }

    private var eventBlocks: some View {
        ForEach(events) { event in
            let duration = max(event.end.timeIntervalSince(event.start), 1800)
            if let positioned = position(for: event.start, duration: min(duration, 4 * 3600)) {
                blockView(title: event.title,
                          subtitle: "\(event.start.formatted(.dateTime.hour().minute())) – \(event.end.formatted(.dateTime.hour().minute()))",
                          tint: Tokens.Color.teal,
                          icon: "calendar",
                          height: positioned.height)
                    .offset(x: labelColumnWidth + Tokens.Space.lg, y: positioned.y)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, labelColumnWidth + Tokens.Space.lg + Tokens.Space.lg)
                    .onTapGesture { onTapEvent(event) }
            }
        }
    }

    private struct PositionedBlock {
        let y: CGFloat
        let height: CGFloat
    }

    private func position(for date: Date?, duration: TimeInterval) -> PositionedBlock? {
        guard let date else { return nil }
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        guard hour >= startHour, hour < endHour else { return nil }
        let hoursIntoDay = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
        let y = hoursIntoDay * hourHeight
        let height = CGFloat(duration / 3600.0) * hourHeight
        return PositionedBlock(y: y, height: max(height, 28))
    }

    private func blockView(title: String, subtitle: String, tint: Color, icon: String?, height: CGFloat) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(tint)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if let icon { Image(systemName: icon).font(.system(size: 9, weight: .semibold)) }
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Tokens.Color.text)
                        .lineLimit(1)
                }
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Tokens.Color.text3)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: height, alignment: .top)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tint.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.4), lineWidth: 0.5)
        )
    }

    private func hourLabel(_ hour: Int) -> String {
        let isPM = hour >= 12
        let display = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(display) \(isPM ? "PM" : "AM")"
    }

    // MARK: Now line (only when viewing today)

    private var showsNowLine: Bool {
        Calendar.current.isDateInToday(day)
    }

    private var nowLine: some View {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: .now)
        let minute = cal.component(.minute, from: .now)
        let yOffset = (CGFloat(hour - startHour) + CGFloat(minute) / 60.0) * hourHeight

        return HStack(spacing: 0) {
            Circle()
                .fill(Tokens.Color.rose)
                .frame(width: 8, height: 8)
                .padding(.leading, labelColumnWidth - 4)
            Rectangle()
                .fill(Tokens.Color.rose)
                .frame(height: 1.5)
                .padding(.trailing, Tokens.Space.lg)
        }
        .offset(y: yOffset - 4)
        .opacity(0.85)
    }
}
