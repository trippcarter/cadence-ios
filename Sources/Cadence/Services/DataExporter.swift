import Foundation
import SwiftData

/// Build 26: GDPR-style data export. Produces a single JSON file
/// containing every row the user owns: tasks, lists, spaces, focus
/// sessions, habits, reviews, intentions, and wins. Cached Google
/// Calendar events are excluded (they're derived data that re-fetches
/// from Google).
///
/// Used by Settings → Account → "Export my data" — the result is
/// shared via ShareLink so the user can save to Files, email it, etc.
enum DataExporter {

    /// Top-level envelope written to JSON.
    struct Export: Codable {
        let exportedAt: Date
        let appVersion: String
        let buildNumber: String
        let user: ExportUser?
        let tasks: [ExportTask]
        let lists: [ExportList]
        let spaces: [ExportSpace]
        let focusSessions: [ExportFocusSession]
        let habitCompletions: [ExportHabitCompletion]
        let reviewLogs: [ExportReviewLog]
        let intentions: [ExportIntention]
        let wins: [ExportWin]
    }

    struct ExportUser: Codable {
        let displayName: String?
        let email: String?
        let isUsingHiddenEmail: Bool
        let memberSince: Date?
    }

    struct ExportTask: Codable {
        let id: UUID
        let title: String
        let notes: String?
        let dueDate: Date?
        let allDay: Bool
        let priority: Int
        let status: String
        let completedAt: Date?
        let createdAt: Date
        let modifiedAt: Date
        let tags: [String]
        let isPinned: Bool
        let isHabit: Bool
        let isRecurring: Bool
        let rrule: String?
        let listID: UUID?
        let parentTaskID: UUID?
        let assignedTo: String?
        let assignedAt: Date?
    }

    struct ExportList: Codable {
        let id: UUID
        let name: String
        let colorKey: String
        let iconKey: String
        let isSeeded: Bool
        let isSharedAsParticipant: Bool
        let ownerDisplayName: String?
        let spaceID: UUID?
        let sortOrder: Int
        let modifiedAt: Date
    }

    struct ExportSpace: Codable {
        let id: UUID
        let name: String
        let iconKey: String
        let colorKey: String
        let createdAt: Date
    }

    struct ExportFocusSession: Codable {
        let id: UUID
        let taskID: UUID?
        let startedAt: Date
        let endedAt: Date?
        let plannedDuration: TimeInterval
        let actualDuration: TimeInterval
        let wasCompleted: Bool
    }

    struct ExportHabitCompletion: Codable {
        let id: UUID
        let taskID: UUID?
        let date: Date
    }

    struct ExportReviewLog: Codable {
        let id: UUID
        let date: Date
        let completedAt: Date
        let hasIntention: Bool
        let hasWin: Bool
    }

    struct ExportIntention: Codable {
        let id: UUID
        let date: Date
        let text: String
    }

    struct ExportWin: Codable {
        let id: UUID
        let date: Date
        let text: String
    }

    // MARK: - Build the export

    @MainActor
    static func buildExport(context: ModelContext, user: AuthenticatedUser?) -> Export {
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let lists = (try? context.fetch(FetchDescriptor<TaskList>())) ?? []
        let households = (try? context.fetch(FetchDescriptor<Household>())) ?? []
        let focusSessions = (try? context.fetch(FetchDescriptor<FocusSession>())) ?? []
        let habits = (try? context.fetch(FetchDescriptor<HabitCompletion>())) ?? []
        let reviews = (try? context.fetch(FetchDescriptor<ReviewLog>())) ?? []
        let intentions = (try? context.fetch(FetchDescriptor<TomorrowIntention>())) ?? []
        let wins = (try? context.fetch(FetchDescriptor<DailyWin>())) ?? []

        return Export(
            exportedAt: .now,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?",
            user: user.map(serializeUser),
            tasks: tasks.map(serializeTask),
            lists: lists.map(serializeList),
            spaces: households.map(serializeSpace),
            focusSessions: focusSessions.map(serializeFocus),
            habitCompletions: habits.map(serializeHabit),
            reviewLogs: reviews.map(serializeReview),
            intentions: intentions.map(serializeIntention),
            wins: wins.map(serializeWin)
        )
    }

    static func writeExport(_ export: Export) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(export)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let stamp = formatter.string(from: .now).replacingOccurrences(of: ":", with: "-")
        let filename = "Cadence-export-\(stamp).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Per-model serializers

    private static func serializeUser(_ user: AuthenticatedUser) -> ExportUser {
        ExportUser(
            displayName: user.displayName,
            email: user.email,
            isUsingHiddenEmail: user.isUsingHiddenEmail,
            memberSince: user.memberSince
        )
    }

    private static func serializeTask(_ task: TaskItem) -> ExportTask {
        ExportTask(
            id: task.id,
            title: task.title,
            notes: task.notes,
            dueDate: task.dueDate,
            allDay: task.allDay,
            priority: task.priority.rawValue,
            status: task.status.rawValue,
            completedAt: task.completedAt,
            createdAt: task.createdAt,
            modifiedAt: task.modifiedAt,
            tags: task.tags,
            isPinned: task.isPinned,
            isHabit: task.isHabit,
            isRecurring: task.isRecurring,
            rrule: task.rruleString,
            listID: task.list?.id,
            parentTaskID: task.parent?.id,
            assignedTo: task.assignedTo,
            assignedAt: task.assignedAt
        )
    }

    private static func serializeList(_ list: TaskList) -> ExportList {
        ExportList(
            id: list.id,
            name: list.name,
            colorKey: list.colorKey,
            iconKey: list.iconKey,
            isSeeded: list.isSeeded,
            isSharedAsParticipant: list.isSharedAsParticipant,
            ownerDisplayName: list.ownerDisplayName,
            spaceID: list.household?.id,
            sortOrder: list.sortOrder,
            modifiedAt: list.modifiedAt
        )
    }

    private static func serializeSpace(_ household: Household) -> ExportSpace {
        ExportSpace(
            id: household.id,
            name: household.name,
            iconKey: household.iconKey,
            colorKey: household.colorKey,
            createdAt: household.createdAt
        )
    }

    private static func serializeFocus(_ session: FocusSession) -> ExportFocusSession {
        ExportFocusSession(
            id: session.id,
            taskID: session.task?.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            plannedDuration: session.plannedDuration,
            actualDuration: session.actualDuration,
            wasCompleted: session.wasCompleted
        )
    }

    private static func serializeHabit(_ habit: HabitCompletion) -> ExportHabitCompletion {
        ExportHabitCompletion(
            id: habit.id,
            taskID: habit.task?.id,
            date: habit.completedOn
        )
    }

    private static func serializeReview(_ review: ReviewLog) -> ExportReviewLog {
        ExportReviewLog(
            id: review.id,
            date: review.date,
            completedAt: review.completedAt,
            hasIntention: review.hasIntention,
            hasWin: review.hasWin
        )
    }

    private static func serializeIntention(_ intention: TomorrowIntention) -> ExportIntention {
        ExportIntention(
            id: intention.id,
            date: intention.date,
            text: intention.text
        )
    }

    private static func serializeWin(_ win: DailyWin) -> ExportWin {
        ExportWin(
            id: win.id,
            date: win.date,
            text: win.text
        )
    }
}
