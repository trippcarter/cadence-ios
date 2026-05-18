import SwiftUI
import SwiftData

/// Shared selection coordinator used by TodayView, ListDetailView, and any
/// future task-listing surface that wants multi-select.
///
/// Lifecycle:
///   - Owned by each list view as a @StateObject (per-view, not global).
///   - `enter()` activates select mode → rows render the checkmark column.
///   - `toggle(taskID:)` mutates the selectedIDs set.
///   - `cancel()` exits, wipes selection.
///   - Batch action methods take a ModelContext and perform the operation
///     for every selected task in one save() — Google Calendar mirror
///     deletes + CloudKit shared-zone deletes are awaited best-effort.
@MainActor
final class TaskSelectionState: ObservableObject {
    @Published var isActive: Bool = false
    @Published var selectedIDs: Set<UUID> = []

    var selectedCount: Int { selectedIDs.count }

    func enter() {
        Haptics.tap()
        isActive = true
    }

    func cancel() {
        Haptics.tap()
        withAnimation(.smooth(duration: 0.3)) {
            isActive = false
            selectedIDs.removeAll()
        }
    }

    func contains(_ task: TaskItem) -> Bool {
        selectedIDs.contains(task.id)
    }

    func toggle(_ task: TaskItem) {
        Haptics.tap()
        withAnimation(.bouncy(duration: 0.25)) {
            if selectedIDs.contains(task.id) {
                selectedIDs.remove(task.id)
            } else {
                selectedIDs.insert(task.id)
            }
        }
    }

    func selectAll(_ tasks: [TaskItem]) {
        Haptics.tap()
        withAnimation(.smooth(duration: 0.3)) {
            selectedIDs.formUnion(tasks.map { $0.id })
        }
    }

    func deselectAll() {
        Haptics.tap()
        withAnimation(.smooth(duration: 0.3)) {
            selectedIDs.removeAll()
        }
    }

    // MARK: Batch operations

    func completeAll(in context: ModelContext, allTasks: [TaskItem]) {
        let targets = allTasks.filter { selectedIDs.contains($0.id) }
        Haptics.success()
        withAnimation(.bouncy(duration: 0.45)) {
            for task in targets where task.status != .completed {
                task.status = .completed
                task.completedAt = .now
                task.modifiedAt = .now
                ActivityLogger.record(.completed, for: task, in: context)
            }
        }
        try? context.save()
        let snapshot = targets // captured by value for the @Sendable task
        Task {
            for task in snapshot {
                await GoogleCalendarService.shared.syncTaskToCalendar(task)
                await SharedListMirror.shared.taskChanged(task)
            }
        }
        WidgetReloader.reload()
        cancel()
    }

    func moveAll(to list: TaskList, in context: ModelContext, allTasks: [TaskItem]) {
        let targets = allTasks.filter { selectedIDs.contains($0.id) }
        Haptics.success()
        var deletionPayloads: [SharedListMirror.DeletionPayload] = []
        withAnimation(.bouncy(duration: 0.45)) {
            for task in targets {
                if task.list?.isShared == true,
                   let p = SharedListMirror.shared.captureDeletionPayload(for: task) {
                    deletionPayloads.append(p)
                }
                task.list = list
                task.cloudRecordName = nil
                task.modifiedAt = .now
            }
        }
        try? context.save()
        let snapshot = targets
        Task {
            for p in deletionPayloads { await SharedListMirror.shared.performDeletion(p) }
            for task in snapshot { await SharedListMirror.shared.taskChanged(task) }
        }
        WidgetReloader.reload()
        cancel()
    }

    func setPriorityAll(_ priority: Priority, in context: ModelContext, allTasks: [TaskItem]) {
        let targets = allTasks.filter { selectedIDs.contains($0.id) }
        Haptics.tap()
        withAnimation(.smooth(duration: 0.25)) {
            for task in targets {
                task.priority = priority
                task.modifiedAt = .now
            }
        }
        try? context.save()
        let snapshot = targets
        Task {
            for task in snapshot { await SharedListMirror.shared.taskChanged(task) }
        }
        cancel()
    }

    func duplicateAll(in context: ModelContext, allTasks: [TaskItem]) {
        let targets = allTasks.filter { selectedIDs.contains($0.id) }
        Haptics.success()
        var clones: [TaskItem] = []
        for task in targets {
            let clone = TaskItem(
                title: task.title,
                notes: task.notes,
                dueDate: nil,
                allDay: false,
                priority: task.priority,
                tags: task.tags,
                list: task.list
            )
            clone.sortOrder = task.sortOrder + 1
            context.insert(clone)
            clones.append(clone)
        }
        try? context.save()
        let snapshot = clones
        Task {
            for task in snapshot { await SharedListMirror.shared.taskChanged(task) }
        }
        WidgetReloader.reload()
        cancel()
    }

    func deleteAll(in context: ModelContext, allTasks: [TaskItem]) {
        let targets = allTasks.filter { selectedIDs.contains($0.id) }
        Haptics.warning()
        struct DeleteRecord {
            let taskID: UUID
            let mirroredEventId: String?
            let mirrorCalendarId: String?
            let sharedPayload: SharedListMirror.DeletionPayload?
        }
        let records: [DeleteRecord] = targets.map { task in
            DeleteRecord(
                taskID: task.id,
                mirroredEventId: task.mirroredEventId,
                mirrorCalendarId: task.mirrorCalendarId,
                sharedPayload: SharedListMirror.shared.captureDeletionPayload(for: task)
            )
        }
        withAnimation(.smooth(duration: 0.3)) {
            for task in targets {
                ActivityLogger.record(.deleted, for: task, in: context)
                context.delete(task)
            }
        }
        try? context.save()
        Task {
            for r in records {
                await NotificationManager.shared.cancelReminders(forTaskID: r.taskID)
                await GoogleCalendarService.shared.deleteMirrorIfNeeded(
                    taskID: r.taskID,
                    eventID: r.mirroredEventId,
                    calendarID: r.mirrorCalendarId
                )
                if let p = r.sharedPayload {
                    await SharedListMirror.shared.performDeletion(p)
                }
            }
        }
        WidgetReloader.reload()
        cancel()
    }
}
