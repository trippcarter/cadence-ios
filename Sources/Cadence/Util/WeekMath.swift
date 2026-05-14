import Foundation

/// Date helpers for the Week view.
enum WeekMath {

    /// The seven days of the calendar week containing `reference`, starting Monday.
    static func weekDays(for reference: Date = .now, calendar: Calendar = .current) -> [Date] {
        var cal = calendar
        cal.firstWeekday = 2  // Monday
        let weekday = cal.component(.weekday, from: reference)
        // Convert Sun-based weekday (1=Sun,2=Mon...) to Mon-offset (Mon=0, Sun=6)
        let daysSinceMonday = (weekday + 5) % 7
        let startOfWeek = cal.date(byAdding: .day, value: -daysSinceMonday, to: cal.startOfDay(for: reference)) ?? reference
        return (0..<7).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: startOfWeek)
        }
    }

    /// Friendly range string like "May 11 – 17".
    static func rangeLabel(for week: [Date]) -> String {
        guard let first = week.first, let last = week.last else { return "" }
        let cal = Calendar.current
        let firstMonth = cal.component(.month, from: first)
        let lastMonth = cal.component(.month, from: last)
        let monthFmt = DateFormatter()
        monthFmt.dateFormat = "MMM"
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "d"
        let firstMonthStr = monthFmt.string(from: first)
        let lastMonthStr = monthFmt.string(from: last)
        let firstDayStr = dayFmt.string(from: first)
        let lastDayStr = dayFmt.string(from: last)
        if firstMonth == lastMonth {
            return "\(firstMonthStr) \(firstDayStr) – \(lastDayStr)"
        }
        return "\(firstMonthStr) \(firstDayStr) – \(lastMonthStr) \(lastDayStr)"
    }
}
