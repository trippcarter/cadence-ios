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
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String?

    /// Date+time when present. When `allDay == true`, only the date portion is meaningful.
    var dueDate: Date?
    var allDay: Bool

    var priority: Priority
    var status: TaskStatus
    var completedAt: Date?
    var snoozeUntil: Date?

    var tags: [String]
    /// Seconds before due date to fire a reminder. `0` = at due time, `-1800` = 30 min before.
    var reminderOffsets: [TimeInterval]

    var createdAt: Date
    var createdBy: String       // CKRecord user ID (string)
    var completedBy: String?

    // Relationships
    var list: TaskList?
    var parent: TaskItem?

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.parent)
    var subtasks: [TaskItem] = []

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
        parent: TaskItem? = nil
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
}

// MARK: - TaskList

@Model
final class TaskList {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorKey: String   // palette key — see ListPalette
    var iconKey: String    // SF Symbol name
    var sortOrder: Int
    var rolloverPolicy: RolloverPolicy
    var defaultReminderOffsets: [TimeInterval]
    var isHidden: Bool

    /// Set when shared via CKShare (Phase 4).
    var shareRecordName: String?

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.list)
    var tasks: [TaskItem] = []

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
