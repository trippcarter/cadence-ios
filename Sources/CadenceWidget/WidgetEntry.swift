import Foundation
import WidgetKit

/// One snapshot of "what Cadence should show right now". Built by the
/// TimelineProvider and consumed by every widget view.
struct CadenceWidgetEntry: TimelineEntry {
    let date: Date

    /// Open top-level tasks due today, sorted by start time. Caps where the
    /// caller decides (Small shows 1, Medium 4, Large 6).
    let todaysTasks: [WidgetTaskInfo]

    /// Open tasks that have rolled over from previous days.
    let carriedCount: Int

    /// Phase 3 will populate this; for now it stays at 0.
    let eventsCount: Int

    static let placeholder = CadenceWidgetEntry(
        date: .now,
        todaysTasks: [
            WidgetTaskInfo(id: UUID(), title: "Sam Quarterly Sync prep", dueDate: .now, allDay: false, colorKey: "amber", listName: "Business", isCompleted: false),
            WidgetTaskInfo(id: UUID(), title: "Review Q2 numbers", dueDate: .now.addingTimeInterval(3600 * 4), allDay: false, colorKey: "teal", listName: "Joint Business", isCompleted: false),
            WidgetTaskInfo(id: UUID(), title: "Pick up dry cleaning", dueDate: .now.addingTimeInterval(3600 * 7), allDay: false, colorKey: "violet", listName: "Personal", isCompleted: false),
            WidgetTaskInfo(id: UUID(), title: "Email Jenny re: birthday plans", dueDate: .now.addingTimeInterval(3600 * 8), allDay: false, colorKey: "violet", listName: "Personal", isCompleted: false),
        ],
        carriedCount: 2,
        eventsCount: 0
    )
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

    var timeText: String? {
        guard let due = dueDate, !allDay else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: due)
    }
}
