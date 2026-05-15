import Foundation
import SwiftData

// MARK: - Enums

enum Priority: Int, Codable, CaseIterable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
}

enum TaskStatus: String, Codable {
    case open
    case completed
    case snoozed
    /// Used for recurring tasks the user explicitly skipped (vs. completed).
    /// Filtered like `.completed` everywhere (no Today / Carried over presence).
    case skipped
}

enum RolloverPolicy: String, Codable, CaseIterable {
    case on    // default — appears in carried-over section today
    case ask   // first launch of day asks user what to do
    case off   // appears as overdue with red chip; doesn't move
}

// MARK: - TaskItem
//
// Named `TaskItem` (not `Task`) because Swift's concurrency framework already
// exposes `Task` as a top-level type. Everywhere the user sees it, it's still
// called "task".

@Model
final class TaskItem {
    // CloudKit-backed SwiftData requires every attribute to be optional or
    // have a default value at declaration. To-many relationships must be
    // optional. The constraints below pre-fill defaults that match init()
    // so the SwiftData→CoreData migration produces a CloudKit-compatible
    // schema. We still expose id as a stable Identifiable / lookup key.
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?

    /// Date+time when present. When `allDay == true`, only the date portion is meaningful.
    var dueDate: Date?
    var allDay: Bool = false

    var priority: Priority = Priority.none
    var status: TaskStatus = TaskStatus.open
    var completedAt: Date?
    var snoozeUntil: Date?

    var tags: [String] = []
    /// Seconds before due date to fire a reminder. `0` = at due time, `-1800` = 30 min before.
    var reminderOffsets: [TimeInterval] = []

    var createdAt: Date = Date.now
    var createdBy: String = ""       // CKRecord user ID (string)
    var completedBy: String?

    // Recurrence (Phase 7b)
    /// RFC 5545 RRULE string, e.g. "FREQ=WEEKLY;BYDAY=MO,WE,FR".
    /// nil = one-shot task. Sent verbatim to Google Calendar's event.recurrence
    /// when mirrored, so the same string drives both Cadence and Google.
    var rruleString: String?

    // Two-way calendar sync (Phase 7a)
    /// When true and dueDate has a specific time, the task is mirrored to
    /// `mirrorCalendarId` as a Google Calendar event.
    var isTimeBlocked: Bool = false
    /// Google calendar ID to mirror to. nil when not mirroring.
    var mirrorCalendarId: String?
    /// Google event ID returned from the most recent mirror create — used
    /// for subsequent PATCH/DELETE operations.
    var mirroredEventId: String?
    /// Duration in seconds for the mirrored event. Default 1800 (30 min).
    var mirrorDurationSeconds: TimeInterval = 1800
    /// Snapshot of the start time the last time we synced. Used to detect
    /// when the user edited the event directly in Google Calendar (lets us
    /// show the "modified in Google" badge).
    var lastSyncedStart: Date?

    // Relationships
    var list: TaskList?
    var parent: TaskItem?

    /// Optional to satisfy CloudKit-backed SwiftData. App code reads via
    /// `task.subtasks ?? []` — see TaskItem.subtaskList helper below.
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.parent)
    var subtasks: [TaskItem]?

    /// Convenience non-optional accessor that callers use everywhere.
    var subtaskList: [TaskItem] { subtasks ?? [] }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        allDay: Bool = false,
        priority: Priority = .none,
        status: TaskStatus = .open,
        completedAt: Date? = nil,
        snoozeUntil: Date? = nil,
        tags: [String] = [],
        reminderOffsets: [TimeInterval] = [],
        createdAt: Date = .now,
        createdBy: String = "",
        completedBy: String? = nil,
        list: TaskList? = nil,
        parent: TaskItem? = nil,
        isTimeBlocked: Bool = false,
        mirrorCalendarId: String? = nil,
        mirrorDurationSeconds: TimeInterval = 1800
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.allDay = allDay
        self.priority = priority
        self.status = status
        self.completedAt = completedAt
        self.snoozeUntil = snoozeUntil
        self.tags = tags
        self.reminderOffsets = reminderOffsets
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.completedBy = completedBy
        self.list = list
        self.parent = parent
        self.isTimeBlocked = isTimeBlocked
        self.mirrorCalendarId = mirrorCalendarId
        self.mirrorDurationSeconds = mirrorDurationSeconds
    }

    // MARK: Computed helpers

    /// True if the task is open and its due date has already passed (started before today).
    var isCarriedOver: Bool {
        guard status == .open, let due = dueDate else { return false }
        let cal = Calendar.current
        return cal.startOfDay(for: due) < cal.startOfDay(for: .now)
    }

    /// True if the task is due today (open, dueDate within today's calendar day).
    var isDueToday: Bool {
        guard let due = dueDate else { return false }
        return Calendar.current.isDateInToday(due)
    }

    /// Whether this task is currently mirrored to a Google Calendar event.
    var hasActiveMirror: Bool {
        isTimeBlocked && mirroredEventId != nil && mirrorCalendarId != nil
    }

    /// In-memory representation of the recurrence rule. nil = one-shot.
    var recurrence: RecurrenceRule? {
        get { RecurrenceRule(rrule: rruleString) }
        set { rruleString = newValue?.toRRULE() }
    }

    var isRecurring: Bool { rruleString != nil && !rruleString!.isEmpty }
}

// MARK: - TaskList

@Model
final class TaskList {
    var id: UUID = UUID()
    var name: String = ""
    var colorKey: String = "neutral"   // palette key — see ListPalette
    var iconKey: String = "tray.fill"  // SF Symbol name
    var sortOrder: Int = 0
    var rolloverPolicy: RolloverPolicy = RolloverPolicy.on
    var defaultReminderOffsets: [TimeInterval] = []
    var isHidden: Bool = false

    /// Set when shared via CKShare (Phase 4).
    var shareRecordName: String?

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.list)
    var tasks: [TaskItem]?

    @Relationship(deleteRule: .cascade, inverse: \Activity.list)
    var activities: [Activity]?

    var taskList: [TaskItem] { tasks ?? [] }

    init(
        id: UUID = UUID(),
        name: String,
        colorKey: String,
        iconKey: String,
        sortOrder: Int,
        rolloverPolicy: RolloverPolicy = .on,
        defaultReminderOffsets: [TimeInterval] = [],
        isHidden: Bool = false,
        shareRecordName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.colorKey = colorKey
        self.iconKey = iconKey
        self.sortOrder = sortOrder
        self.rolloverPolicy = rolloverPolicy
        self.defaultReminderOffsets = defaultReminderOffsets
        self.isHidden = isHidden
        self.shareRecordName = shareRecordName
    }
}
