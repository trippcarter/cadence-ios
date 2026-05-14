import Foundation

/// In-memory representation of a task's repeat schedule.
///
/// Serializes to/from RFC 5545 RRULE strings (e.g.
/// "FREQ=WEEKLY;BYDAY=MO,WE,FR;INTERVAL=1") so the same string we persist
/// in SwiftData can be sent verbatim to Google Calendar as the `recurrence`
/// field on an event. That single representation means Google's recurring
/// event behaves exactly like Cadence's repeat schedule.
struct RecurrenceRule: Equatable, Codable {

    enum Frequency: String, Codable, CaseIterable {
        case daily   = "DAILY"
        case weekly  = "WEEKLY"
        case monthly = "MONTHLY"
        case yearly  = "YEARLY"
    }

    enum Weekday: String, CaseIterable, Codable {
        case mon = "MO", tue = "TU", wed = "WE", thu = "TH"
        case fri = "FR", sat = "SA", sun = "SU"

        /// Maps to Calendar.current.component(.weekday, from:) values
        /// (1 = Sunday, 2 = Monday, ..., 7 = Saturday).
        var calendarWeekday: Int {
            switch self {
            case .sun: return 1
            case .mon: return 2
            case .tue: return 3
            case .wed: return 4
            case .thu: return 5
            case .fri: return 6
            case .sat: return 7
            }
        }

        var shortName: String {
            switch self {
            case .mon: return "Mon"
            case .tue: return "Tue"
            case .wed: return "Wed"
            case .thu: return "Thu"
            case .fri: return "Fri"
            case .sat: return "Sat"
            case .sun: return "Sun"
            }
        }
    }

    var frequency: Frequency
    var interval: Int = 1
    /// For weekly: the specific weekdays to repeat on. Empty = inherit from dueDate.
    var byDay: [Weekday] = []
    /// For monthly: day-of-month (1..31). nil = use day-of-month from dueDate.
    var byMonthDay: Int? = nil
    /// Stop on or before this date.
    var endDate: Date? = nil
    /// Stop after this many occurrences. Not enforced internally — UI hint.
    var count: Int? = nil

    // MARK: RRULE serialization

    func toRRULE() -> String {
        var parts: [String] = ["FREQ=\(frequency.rawValue)"]
        if interval > 1 { parts.append("INTERVAL=\(interval)") }
        if !byDay.isEmpty {
            let days = byDay.map { $0.rawValue }.joined(separator: ",")
            parts.append("BYDAY=\(days)")
        }
        if let byMonthDay { parts.append("BYMONTHDAY=\(byMonthDay)") }
        if let endDate {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            fmt.timeZone = TimeZone(identifier: "UTC")
            parts.append("UNTIL=\(fmt.string(from: endDate))")
        }
        if let count { parts.append("COUNT=\(count)") }
        return parts.joined(separator: ";")
    }

    init(
        frequency: Frequency,
        interval: Int = 1,
        byDay: [Weekday] = [],
        byMonthDay: Int? = nil,
        endDate: Date? = nil,
        count: Int? = nil
    ) {
        self.frequency = frequency
        self.interval = max(interval, 1)
        self.byDay = byDay
        self.byMonthDay = byMonthDay
        self.endDate = endDate
        self.count = count
    }

    init?(rrule: String?) {
        guard let rrule, !rrule.isEmpty else { return nil }
        let pairs = rrule.split(separator: ";").map { $0.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false) }
        var freq: Frequency?
        var interval = 1
        var byDay: [Weekday] = []
        var byMonthDay: Int?
        var endDate: Date?
        var count: Int?

        for pair in pairs where pair.count == 2 {
            let key = String(pair[0]).uppercased()
            let value = String(pair[1])
            switch key {
            case "FREQ":
                freq = Frequency(rawValue: value.uppercased())
            case "INTERVAL":
                interval = Int(value) ?? 1
            case "BYDAY":
                byDay = value.split(separator: ",").compactMap {
                    Weekday(rawValue: String($0).uppercased())
                }
            case "BYMONTHDAY":
                byMonthDay = Int(value)
            case "UNTIL":
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
                fmt.timeZone = TimeZone(identifier: "UTC")
                endDate = fmt.date(from: value)
            case "COUNT":
                count = Int(value)
            default:
                break
            }
        }

        guard let freq else { return nil }
        self.frequency = freq
        self.interval = interval
        self.byDay = byDay
        self.byMonthDay = byMonthDay
        self.endDate = endDate
        self.count = count
    }

    // MARK: Next-occurrence math

    /// Compute the next due date after `currentDue` that matches the rule.
    /// Returns nil if no future occurrence exists (past endDate, etc.).
    func nextOccurrence(after currentDue: Date) -> Date? {
        let cal = Calendar.current
        let candidate: Date?
        switch frequency {
        case .daily:
            candidate = cal.date(byAdding: .day, value: interval, to: currentDue)
        case .weekly:
            if !byDay.isEmpty {
                candidate = nextWeeklyOnDays(after: currentDue, days: byDay)
            } else {
                candidate = cal.date(byAdding: .weekOfYear, value: interval, to: currentDue)
            }
        case .monthly:
            candidate = cal.date(byAdding: .month, value: interval, to: currentDue)
        case .yearly:
            candidate = cal.date(byAdding: .year, value: interval, to: currentDue)
        }
        guard let next = candidate else { return nil }
        if let endDate, next > endDate { return nil }
        return next
    }

    private func nextWeeklyOnDays(after currentDue: Date, days: [Weekday]) -> Date? {
        let cal = Calendar.current
        var candidate = cal.date(byAdding: .day, value: 1, to: currentDue) ?? currentDue
        let allowed = Set(days.map { $0.calendarWeekday })
        // Look ahead up to (interval × 7) + a small buffer for the next match.
        for _ in 0..<(interval * 7 + 7) {
            let weekday = cal.component(.weekday, from: candidate)
            if allowed.contains(weekday) { return candidate }
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return nil
    }

    // MARK: Human-readable description

    var displayLabel: String {
        switch frequency {
        case .daily:
            return interval == 1 ? "Repeats daily" : "Repeats every \(interval) days"
        case .weekly:
            if !byDay.isEmpty {
                let days = byDay.map { $0.shortName }.joined(separator: ", ")
                let prefix = interval == 1 ? "Repeats weekly on" : "Repeats every \(interval) weeks on"
                return "\(prefix) \(days)"
            }
            return interval == 1 ? "Repeats weekly" : "Repeats every \(interval) weeks"
        case .monthly:
            if let day = byMonthDay {
                return interval == 1 ? "Repeats monthly on the \(daySuffix(day))" : "Repeats every \(interval) months on the \(daySuffix(day))"
            }
            return interval == 1 ? "Repeats monthly" : "Repeats every \(interval) months"
        case .yearly:
            return interval == 1 ? "Repeats yearly" : "Repeats every \(interval) years"
        }
    }

    private func daySuffix(_ n: Int) -> String {
        let mod100 = n % 100
        if (11...13).contains(mod100) { return "\(n)th" }
        switch n % 10 {
        case 1: return "\(n)st"
        case 2: return "\(n)nd"
        case 3: return "\(n)rd"
        default: return "\(n)th"
        }
    }
}
