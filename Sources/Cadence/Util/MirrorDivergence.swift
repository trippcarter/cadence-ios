import Foundation

/// Detects when a Cadence task's mirrored Google Calendar event has been
/// edited externally — the event's start time no longer matches the task's
/// due date. Used by TaskRow and TaskDetailSheet to show a "modified in
/// Google" badge with an Adopt action.
///
/// Comparison rule: if `mirroredEventId` is set and a matching CachedEvent
/// exists, compare `event.start` against `task.dueDate` (within 30s
/// tolerance to absorb floating-point / round-trip drift). If different,
/// surface as diverged.
enum MirrorDivergence {

    /// Returns the new start time from Google if the task's mirror has been
    /// externally edited. nil = no divergence.
    static func divergedStart(for task: TaskItem, among events: [CachedEvent]) -> Date? {
        guard task.hasActiveMirror,
              let eventID = task.mirroredEventId,
              let due = task.dueDate,
              let event = events.first(where: { $0.id == eventID })
        else { return nil }
        let drift = abs(event.start.timeIntervalSince(due))
        if drift < 30 { return nil }
        return event.start
    }
}
