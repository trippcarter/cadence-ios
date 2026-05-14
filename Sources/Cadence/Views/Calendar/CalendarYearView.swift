import SwiftUI
import SwiftData

/// 12 mini-month grids per page. Tap a month to drill into Month view.
struct CalendarYearView: View {
    @Binding var referenceDate: Date
    var onTapMonth: (Date) -> Void

    @Query private var allTasks: [TaskItem]
    @Query private var allEvents: [CachedEvent]

    private let pageRange = -5...5

    var body: some View {
        TabView(selection: Binding(
            get: { yearStart(of: referenceDate) },
            set: { referenceDate = $0 }
        )) {
            ForEach(pageStarts, id: \.self) { yearStart in
                yearPage(start: yearStart).tag(yearStart)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var pageStarts: [Date] {
        pageRange.compactMap { offset in
            Calendar.current.date(byAdding: .year, value: offset, to: yearStart(of: .now))
        }
    }

    private func yearStart(of date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year], from: date)
        return cal.date(from: comps) ?? date
    }

    @ViewBuilder
    private func yearPage(start: Date) -> some View {
        let months = (0..<12).compactMap { offset in
            Calendar.current.date(byAdding: .month, value: offset, to: start)
        }
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.md), count: 3), spacing: Tokens.Space.lg) {
                ForEach(months, id: \.self) { month in
                    MiniMonth(month: month, activity: activity(for: month)) {
                        Haptics.tap()
                        onTapMonth(month)
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.top, Tokens.Space.lg)
            Color.clear.frame(height: 120)
        }
        .scrollIndicators(.hidden)
    }

    /// For each day index (1-based) in the month, true if any task or event
    /// is scheduled. Used to render the tiny activity dots in MiniMonth.
    private func activity(for month: Date) -> Set<Int> {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        var result = Set<Int>()
        let monthComponents = cal.dateComponents([.year, .month], from: month)
        let allItems = allTasks.compactMap { $0.dueDate } + allEvents.map { $0.start }
        for date in allItems {
            let comps = cal.dateComponents([.year, .month, .day], from: date)
            guard comps.year == monthComponents.year, comps.month == monthComponents.month,
                  let day = comps.day, range.contains(day) else { continue }
            result.insert(day)
        }
        return result
    }
}

// MARK: - Mini month

private struct MiniMonth: View {
    let month: Date
    /// Day-of-month numbers (1-based) that have any activity.
    let activity: Set<Int>
    var onTap: () -> Void

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: .now, toGranularity: .month)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(month, format: .dateTime.month(.abbreviated))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isCurrentMonth ? Tokens.Color.accent2 : Tokens.Color.text2)
                grid
            }
            .padding(8)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .stroke(isCurrentMonth ? Tokens.Color.accent.opacity(0.4) : Tokens.Color.borderSoft,
                            lineWidth: isCurrentMonth ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var grid: some View {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: month) ?? 1..<28
        let firstWeekday = cal.component(.weekday, from: month)
        let leadingBlanks = (firstWeekday + 5) % 7
        var cells: [Int?] = Array(repeating: nil, count: leadingBlanks)
        for day in range { cells.append(day) }
        while cells.count < 42 { cells.append(nil) }

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
            ForEach(0..<cells.count, id: \.self) { idx in
                if let day = cells[idx] {
                    miniCell(day: day)
                } else {
                    Color.clear.frame(height: 10)
                }
            }
        }
    }

    private func miniCell(day: Int) -> some View {
        let hasActivity = activity.contains(day)
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: month)
        let date = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: day))
        let isToday = date.map { cal.isDateInToday($0) } ?? false

        return ZStack {
            if isToday {
                Circle().fill(Tokens.Color.accent.opacity(0.4)).frame(width: 14, height: 14)
            }
            Text("\(day)")
                .font(.system(size: 8, weight: hasActivity ? .bold : .regular))
                .foregroundStyle(isToday ? Tokens.Color.text : (hasActivity ? Tokens.Color.accent2 : Tokens.Color.text3))
        }
        .frame(height: 10)
    }

    private var accessibilityLabel: String {
        let name = month.formatted(.dateTime.month(.wide).year())
        return name + (isCurrentMonth ? ", current month" : "") + ", \(activity.count) day\(activity.count == 1 ? "" : "s") with activity"
    }
}
