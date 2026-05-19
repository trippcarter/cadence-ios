import AppIntents
import SwiftData
import Foundation

/// Build 20: "Hey Siri, add to Cadence: call insurance broker tomorrow at 3pm"
///
/// The title is run through `NaturalLanguageTaskParser` so spoken phrases
/// like "tomorrow at 3pm" / "#personal" / "!high" inside the title still
/// get parsed into structured fields — same UX as the in-app composer.
@available(iOS 17.0, *)
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add task"
    static var description = IntentDescription(
        "Add a task to Cadence. Title can include natural-language modifiers like 'tomorrow at 3pm'."
    )
    static var openAppWhenRun = false

    @Parameter(title: "Title", description: "What's the task?")
    var taskTitle: String

    @Parameter(title: "List", description: "Which list?")
    var list: TaskListEntity?

    @Parameter(title: "Due date", description: "When is it due?")
    var explicitDueDate: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$taskTitle) to \(\.$list)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try CadenceContainer.makeContainer()
        let context = ModelContext(container)

        let parsed = NaturalLanguageTaskParser.parse(taskTitle)
        let finalTitle: String = {
            let candidate = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return candidate.isEmpty
                ? taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                : candidate
        }()

        // Resolve list. Priority order:
        //   1. Explicit `list` parameter from Siri
        //   2. Parsed #tag (NL parser found "#personal" in the title)
        //   3. Inbox default
        let resolvedList = try resolveList(parsed: parsed, context: context)

        let task = TaskItem(
            title: finalTitle,
            dueDate: explicitDueDate ?? parsed.dueDate,
            allDay: parsed.allDay,
            priority: parsed.priority ?? .none,
            tags: parsed.tags,
            list: resolvedList
        )
        context.insert(task)
        try context.save()

        // Donate so Siri can offer suggestions on Lock Screen / Spotlight.
        let donation = AddTaskIntent()
        donation.taskTitle = finalTitle
        if let resolvedList {
            donation.list = TaskListEntity(id: resolvedList.id, name: resolvedList.name, iconKey: resolvedList.iconKey)
        }
        try? await donation.donate()

        let dialog: IntentDialog = {
            if let listName = resolvedList?.name {
                if let due = task.dueDate {
                    return IntentDialog("Added \"\(finalTitle)\" to \(listName), due \(formattedDue(due, allDay: task.allDay)).")
                }
                return IntentDialog("Added \"\(finalTitle)\" to \(listName).")
            }
            return IntentDialog("Added \"\(finalTitle)\".")
        }()
        return .result(dialog: dialog)
    }

    @MainActor
    private func resolveList(parsed: NaturalLanguageTaskParser.Result, context: ModelContext) throws -> TaskList? {
        if let explicit = list {
            let id = explicit.id
            let d = FetchDescriptor<TaskList>(predicate: #Predicate { $0.id == id })
            return try context.fetch(d).first
        }
        if let token = parsed.listToken {
            let d = FetchDescriptor<TaskList>()
            let allLists = (try? context.fetch(d)) ?? []
            if let matched = NaturalLanguageTaskParser.fuzzyMatch(
                token: token,
                against: allLists.map { $0.name }
            ), let list = allLists.first(where: { $0.name.caseInsensitiveCompare(matched) == .orderedSame }) {
                return list
            }
        }
        // Default: Inbox
        let d = FetchDescriptor<TaskList>(predicate: #Predicate { $0.name == "Inbox" })
        return try context.fetch(d).first
    }

    private func formattedDue(_ date: Date, allDay: Bool) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = allDay ? .none : .short
        return f.string(from: date)
    }
}
