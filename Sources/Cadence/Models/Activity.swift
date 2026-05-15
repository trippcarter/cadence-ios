import Foundation
import SwiftData

/// Audit-log entry for actions taken on a shared list. Surfaces in the
/// per-list "Recent activity" sheet. Stored only when the parent
/// TaskList is shared (otherwise creating noise on private lists).
///
/// CloudKit-compatible: every attribute has a declaration-level default
/// and the inverse relationship is optional.
@Model
final class Activity {
    var id: UUID = UUID()
    /// CKShare participant identifier — the iCloud user ID who performed
    /// the action. Stored as a string so we can match across devices.
    var actor: String = ""
    /// Display name of the actor (best effort — populated when we know).
    var actorName: String?
    /// UUID of the TaskItem this entry refers to. Stored as String for
    /// CloudKit portability and to survive task deletion.
    var taskID: String = ""
    /// Snapshot of the task title at the time of the action (for activity
    /// display after the task may have been edited/deleted).
    var taskTitleSnapshot: String = ""
    var kind: ActivityKind = ActivityKind.created
    var at: Date = Date.now

    /// Parent list. Inverse declared on TaskList.activity if we want it.
    var list: TaskList?

    init(
        id: UUID = UUID(),
        actor: String,
        actorName: String? = nil,
        taskID: String,
        taskTitleSnapshot: String,
        kind: ActivityKind,
        at: Date = .now,
        list: TaskList? = nil
    ) {
        self.id = id
        self.actor = actor
        self.actorName = actorName
        self.taskID = taskID
        self.taskTitleSnapshot = taskTitleSnapshot
        self.kind = kind
        self.at = at
        self.list = list
    }
}

enum ActivityKind: String, Codable {
    case created
    case completed
    case edited
    case deleted

    var displayLabel: String {
        switch self {
        case .created:   return "added"
        case .completed: return "completed"
        case .edited:    return "edited"
        case .deleted:   return "deleted"
        }
    }

    var iconName: String {
        switch self {
        case .created:   return "plus.circle"
        case .completed: return "checkmark.circle"
        case .edited:    return "pencil.circle"
        case .deleted:   return "minus.circle"
        }
    }
}
