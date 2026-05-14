import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Invoked when the user taps a task's complete circle in an interactive
/// widget on iOS 17+. Runs inside the widget extension process, mutates the
/// shared SwiftData store, and asks WidgetKit to redraw.
///
/// We accept the task ID as a String to keep the AppIntent parameter type
/// simple. The task is fetched in the widget's own ModelContainer (mounted
/// from the App Group), so the change is immediately visible to the main app.
struct CompleteTaskFromWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"
    static var description = IntentDescription("Marks the selected task as complete from a Cadence widget.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: taskID) else {
            return .result()
        }
        do {
            let container = try CadenceContainer.makeContainer()
            let context = ModelContext(container)
            // SwiftData @Model UUIDs aren't directly queryable via #Predicate
            // for unique attributes in every iOS 17 release, so fetch all open
            // tasks and filter in Swift. The cardinality here is tiny.
            let descriptor = FetchDescriptor<TaskItem>()
            let all = try context.fetch(descriptor)
            if let task = all.first(where: { $0.id == uuid }) {
                if task.status == .completed {
                    task.status = .open
                    task.completedAt = nil
                } else {
                    task.status = .completed
                    task.completedAt = .now
                }
                try context.save()
            }
        } catch {
            // Surface as a silent no-op; the widget will simply not update.
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
