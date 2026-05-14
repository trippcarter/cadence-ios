import Foundation

enum CalendarMode: String, CaseIterable, Identifiable {
    case day, week, month, year

    var id: String { rawValue }

    var label: String {
        switch self {
        case .day:   return "Day"
        case .week:  return "Week"
        case .month: return "Month"
        case .year:  return "Year"
        }
    }

    /// The Calendar.Component the mode increments by when paging.
    var period: Calendar.Component {
        switch self {
        case .day:   return .day
        case .week:  return .weekOfYear
        case .month: return .month
        case .year:  return .year
        }
    }

    /// Friendly title for the date header — e.g. "Wed, May 14", "Week of May 11".
    func headerTitle(for date: Date) -> String {
        let cal = Calendar.current
        switch self {
        case .day:
            return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .week:
            guard let weekStart = WeekMath.weekDays(for: date).first else { return "" }
            return "Week of " + weekStart.formatted(.dateTime.month(.abbreviated).day())
        case .month:
            return date.formatted(.dateTime.month(.wide).year())
        case .year:
            return date.formatted(.dateTime.year())
        }
    }

    /// Normalizes a date to the start of the relevant period so TabView page
    /// IDs land on the same value within a period.
    func normalize(_ date: Date) -> Date {
        let cal = Calendar.current
        switch self {
        case .day:
            return cal.startOfDay(for: date)
        case .week:
            return WeekMath.weekDays(for: date).first ?? cal.startOfDay(for: date)
        case .month:
            let comps = cal.dateComponents([.year, .month], from: date)
            return cal.date(from: comps) ?? date
        case .year:
            let comps = cal.dateComponents([.year], from: date)
            return cal.date(from: comps) ?? date
        }
    }
}
