import Foundation
import SwiftData

/// Helper that materializes the next occurrence of a recurring task into a
/// new SwiftData TaskItem after the user completes (or skips) the current
/// instance.
///
/// Why a new TaskItem per occurrence: keeps the Today / Carried-over / List
/// queries simple — each fetched item is one occurrence. The flip side is
/// that history accumulates over time; if that becomes a problem we'd add
/// a `historicalParentID` link and surface them in a dedicated history
/// view instead of the active lists.
///
/// Google Calendar two-way sync interaction:
///   - The PARENT task (the one the user originally created) carries the
///     mirrored event ID. That mirror is sent with the full RRULE, so
///     Google renders ONE recurring event covering every future occurrence.
///   - Subsequent instances generated here have mirroredEventId = nil so
///     they don't trigger a duplicate mirror. The user's Google Calendar
///     keeps showing the single recurring event.
enum TaskRepeater {

    /// Produce and insert the next instance. Returns nil when the
    /// recurrence rule has no more future occurrences (past endDate, etc.)
    /// or when the task isn't recurring.
    @discardableResult
    static func generateNextInstance(of task: TaskItem, in context: ModelContext) -> TaskItem? {
        guard let recurrence = task.recurrence,
              let currentDue = task.dueDate else { return nil }

        // Find the next occurrence that's actually in the future.
        // Loop forward in case the rule says e.g. "every Mon/Wed/Fri" and
        // the current due is a Friday + we want Monday's date.
        var candidate = currentDue
        for _ in 0..<32 {
            guard let next = recurrence.nextOccurrence(after: candidate) else {
                return nil
            }
            if next > Date() {
                return materialize(from: task, dueDate: next, in: context)
            }
            candidate = next
        }
        return nil
    }

    private static func materialize(from source: TaskItem, dueDate: Date, in context: ModelContext) -> TaskItem {
        let copy = TaskItem(
            title: source.title,
            notes: source.notes,
            dueDate: dueDate,
            allDay: source.allDay,
            priority: source.priority,
            status: .open,
            tags: source.tags,
            reminderOffsets: source.reminderOffsets,
            createdBy: source.createdBy,
            list: source.list,
            // Time-block intentionally NOT copied: the parent task's recurring
            // Google event already covers every future occurrence. Mirroring
            // each generated instance individually would create duplicate
            // events in the user's calendar. User can manually re-enable on
            // a specific instance if they want to deviate.
            isTimeBlocked: false,
            mirrorCalendarId: nil,
            mirrorDurationSeconds: source.mirrorDurationSeconds
        )
        copy.rruleString = source.rruleString
        context.insert(copy)
        return copy
    }
}
