import SwiftUI
import SwiftData

/// Standard month grid. Tap a day to switch into Day view for that date.
struct CalendarMonthView: View {
    @Binding var referenceDate: Date
    var onTapDay: (Date) -> Void

    @Query private var allTasks: [TaskItem]
    @Query private var allEvents: [CachedEvent]

    private let pageRange = -24...24

    var body: some View {
        TabView(selection: Binding(
            get: { monthStart(of: referenceDate) },
            set: { referenceDate = $0 }
        )) {
            ForEach(pageStarts, id: \.self) { start in
                monthPage(start: start).tag(start)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var pageStarts: [Date] {
        let cal = Calendar.current
        return pageRange.compactMap { offset in
            cal.date(byAdding: .month, value: offset, to: monthStart(of: .now))
        }
    }

    private func monthStart(of date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }

    @ViewBuilder
    private func monthPage(start: Date) -> some View {
        let cells = monthCells(start: start)
        ScrollView {
            VStack(spacing: Tokens.Space.md) {
                weekdayHeader
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(cells, id: \.self) { day in
                        if let day {
                            MonthDayCell(
                                day: day,
                                isInMonth: Calendar.current.isDate(day, equalTo: start, toGranularity: .month),
                                dots: dots(for: day)
                            ) {
                                Haptics.tap()
                                onTapDay(day)
                            }
                        } else {
                            Color.clear.frame(height: 60)
                        }
                    }
                }
                Color.clear.frame(height: 120)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.top, Tokens.Space.md)
        }
        .scrollIndicators(.hidden)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { letter in
                Text(letter)
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(Tokens.Color.text3)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Returns 6 weeks × 7 days = 42 cells, including leading/trailing
    /// neighboring-month days so the grid is rectangular.
    private func monthCells(start: Date) -> [Date?] {
        let cal = Calendar.current
        guard let monthRange = cal.range(of: .day, in: .month, for: start) else { return [] }
        let firstWeekday = cal.component(.weekday, from: start)
        // Convert Sun-based (1) to Mon-based (0): shift by -2, then mod 7.
        let leadingBlanks = (firstWeekday + 5) % 7

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<monthRange.count {
            cells.append(cal.date(byAdding: .day, value: offset, to: start))
        }
        while cells.count < 42 {
            cells.append(nil)
        }
        return cells
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

// MARK: - Single day cell

private struct MonthDayCell: View {
    let day: Date
    let isInMonth: Bool
    let dots: [Color]
    var onTap: () -> Void

    private var isToday: Bool {
        Calendar.current.isDateInToday(day)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(day, format: .dateTime.day(.defaultDigits))
                    .font(.system(size: 13, weight: isToday ? .bold : .semibold))
                    .foregroundStyle(textColor)
                    .padding(.top, 5)
                    .padding(.leading, 8)
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    ForEach(0..<min(dots.count, 3), id: \.self) { idx in
                        Circle().fill(dots[idx]).frame(width: 4, height: 4)
                    }
                }
                .padding(.bottom, 6)
                .padding(.leading, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 60)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var textColor: Color {
        if isToday { return Tokens.Color.text }
        if !isInMonth { return Tokens.Color.text3.opacity(0.55) }
        return Tokens.Color.text2
    }

    @ViewBuilder
    private var background: some View {
        if isToday {
            LinearGradient(
                colors: [Tokens.Color.accent.opacity(0.24), Tokens.Color.accent.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if isInMonth {
            Tokens.Color.surface
        } else {
            Tokens.Color.bg2
        }
    }

    private var borderColor: Color {
        isToday ? Tokens.Color.accent.opacity(0.5) : Tokens.Color.borderSoft
    }

    private var borderWidth: CGFloat { isToday ? 1 : 0.5 }

    private var accessibilityLabel: String {
        let base = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let dotInfo = dots.isEmpty ? "" : ", \(dots.count) item\(dots.count == 1 ? "" : "s") scheduled"
        return base + (isToday ? ", today" : "") + dotInfo
    }
}
