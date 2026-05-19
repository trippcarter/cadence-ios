import AppIntents
import SwiftData
import Foundation

/// Build 20: "Hey Siri, mark call insurance broker done in Cadence."
///
/// Confirms before completing if the fuzzy-matched task title isn't an
/// exact match — `RequestValueAction` would prompt the user to pick, but
/// the simpler approach is to let App Intents handle disambiguation via
/// EntityStringQuery returning multiple candidates.
@available(iOS 17.0, *)
struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete task"
    static var description = IntentDescription(
        "Mark a task done in Cadence."
    )
    static var openAppWhenRun = false

    @Parameter(title: "Task", description: "Which task?")
    var task: TaskEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$task) done")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try CadenceContainer.makeContainer()
        let context = ModelContext(container)

        let targetID = task.id
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.id == targetID }
        )
        guard let item = try context.fetch(descriptor).first else {
            return .result(dialog: "I couldn't find that task.")
        }

        if item.status == .completed {
            return .result(dialog: "\"\(item.title)\" was already done.")
        }

        item.status = .completed
        item.completedAt = .now
        item.modifiedAt = .now
        HabitTracker.recordCompletionIfNeeded(for: item, in: context)
        try context.save()

        // Donate so Siri can offer this task name for completion in future.
        try? await donate()

        return .result(dialog: "Marked \"\(item.title)\" done.")
    }
}
