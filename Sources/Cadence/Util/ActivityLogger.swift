import Foundation
import SwiftData

/// Records what happened on shared TaskList contents. No-op for private
/// lists (no need to log activity nobody else will see).
///
/// Call from the same lifecycle hooks that write tasks: AddTaskSheet.save,
/// TaskDetailSheet.persist/.deleteTask, TaskRowActionContainer.toggleComplete
/// and the swipe-delete confirmation.
enum ActivityLogger {

    /// Caller passes `kind` and the task whose lifecycle is being recorded.
    /// We silently skip when the task isn't in a shared list.
    static func record(_ kind: ActivityKind, for task: TaskItem, in context: ModelContext, actor: String = "me") {
        guard let list = task.list, list.isShared else { return }
        let entry = Activity(
            actor: actor,
            actorName: nil,
            taskID: task.id.uuidString,
            taskTitleSnapshot: task.title,
            kind: kind,
            at: .now,
            list: list
        )
        context.insert(entry)
    }
}
