import Foundation
import WidgetKit

/// Build 29 overhaul: one snapshot of "what Cadence should show right
/// now." Previously the entry only carried tasks due TODAY (carried-over
/// were tracked as a count but never displayed), and calendar events
/// were never queried at all. The new entry carries a mixed list of
/// tasks AND events sorted by time so the medium/large widgets can
/// render the actual day at a glance.
struct CadenceWidgetEntry: TimelineEntry {
    let date: Date

    /// Mixed list of open tasks (today + carried-over) and today's
    /// calendar events, sorted by start time (overdue → all-day →
    /// timed in order). Callers prefix this for their size (Small 1,
    /// Medium 4, Large 6).
    let items: [WidgetItem]

    /// Counts for the stat strip / small widget / lock screen. Kept
    /// separate so the views don't have to re-aggregate `items`.
    let openTaskCount: Int       // open tasks with dueDate ≤ end of today
    let carriedCount: Int        // subset of above with dueDate < start of today
    let eventsCount: Int         // events whose start lies inside today

    /// Whichever of the next-up task or the next-up event arrives
    /// sooner. Used by accessoryRectangular and SmallWidgetView's
    /// "Next" block.
    let nextItem: WidgetItem?

    static let placeholder = CadenceWidgetEntry(
        date: .now,
        items: [
            .task(WidgetTaskInfo(
                id: UUID(), title: "Sam Quarterly Sync prep", dueDate: .now,
                allDay: false, colorKey: "amber", listName: "Business",
                isCompleted: false, isCarriedOver: false)),
            .event(WidgetEventInfo(
                id: UUID().uuidString, title: "Team standup",
                start: .now.addingTimeInterval(3600), end: .now.addingTimeInterval(5400),
                isAllDay: false, calendarColorKey: "teal")),
            .task(WidgetTaskInfo(
                id: UUID(), title: "Review Q2 numbers",
                dueDate: .now.addingTimeInterval(3600 * 4), allDay: false,
                colorKey: "teal", listName: "Joint Business",
                isCompleted: false, isCarriedOver: false)),
            .task(WidgetTaskInfo(
                id: UUID(), title: "Pick up dry cleaning",
                dueDate: .now.addingTimeInterval(-86400), allDay: false,
                colorKey: "violet", listName: "Personal",
                isCompleted: false, isCarriedOver: true))
        ],
        openTaskCount: 3,
        carriedCount: 1,
        eventsCount: 1,
        nextItem: .event(WidgetEventInfo(
            id: UUID().uuidString, title: "Team standup",
            start: .now.addingTimeInterval(3600), end: .now.addingTimeInterval(5400),
            isAllDay: false, calendarColorKey: "teal"))
    )
}

/// Discriminated union of the two kinds of things shown in the
/// task/event list. WidgetItem.id is stable across reloads so
/// SwiftUI ForEach diffing works.
enum WidgetItem: Identifiable, Hashable {
    case task(WidgetTaskInfo)
    case event(WidgetEventInfo)

    var id: String {
        switch self {
        case .task(let t):  return "task-\(t.id.uuidString)"
        case .event(let e): return "event-\(e.id)"
        }
    }

    /// Sort key — the time we display next to the row, or the start
    /// of day for all-day items so they appear at the top.
    var sortDate: Date {
        switch self {
        case .task(let t):
            // Carried-over: bubble to the very top (use .distantPast).
            // All-day today: start of today.
            // Timed: dueDate.
            if t.isCarriedOver { return .distantPast }
            if t.allDay { return Calendar.current.startOfDay(for: .now) }
            return t.dueDate ?? .distantFuture
        case .event(let e):
            if e.isAllDay { return Calendar.current.startOfDay(for: .now).addingTimeInterval(1) }
            return e.start
        }
    }

    var isAllDay: Bool {
        switch self {
        case .task(let t):  return t.allDay
        case .event(let e): return e.isAllDay
        }
    }
}

/// Snapshot of a single task. We deliberately copy the fields we need
/// rather than passing the @Model instance through the timeline, because
/// SwiftData model instances are tied to a ModelContext and aren't safe
/// to hold across widget-extension process boundaries.
struct WidgetTaskInfo: Identifiable, Hashable {
    let id: UUID
    let title: String
    let dueDate: Date?
    let allDay: Bool
    let colorKey: String
    let listName: String
    let isCompleted: Bool
    /// Build 29: true when dueDate is before today's startOfDay. Drives
    /// the small "carried" chip in the widget row.
    let isCarriedOver: Bool

    var timeText: String? {
        guard let due = dueDate, !allDay else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: due)
    }
}

/// Snapshot of a calendar event. Build 29 — widgets render these
/// alongside tasks in the medium/large variants.
struct WidgetEventInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarColorKey: String

    var timeText: String? {
        guard !isAllDay else { return nil }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: start)
    }
}
