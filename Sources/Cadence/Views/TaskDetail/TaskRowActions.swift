import SwiftUI
import SwiftData

/// Shared swipe behavior + sheet/alert presentation for a TaskRow.
/// Use in any screen that lists tasks (Today, List Detail, future Smart filters)
/// so all three actions (complete / snooze / delete) feel identical.
struct TaskRowActionContainer<Content: View>: View {
    let task: TaskItem
    let content: () -> Content
    @Environment(\.modelContext) private var modelContext

    @State private var snoozingTask: TaskItem?
    @State private var deletingTask: TaskItem?

    var body: some View {
        content()
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    toggleComplete()
                } label: {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                }
                .tint(Tokens.Color.mint)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    deletingTask = task
                    Haptics.warning()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(Tokens.Color.rose)
                Button {
                    snoozingTask = task
                } label: {
                    Label("Snooze", systemImage: "moon.zzz.fill")
                }
                .tint(Tokens.Color.accent)
                if task.isRecurring {
                    Button {
                        skipOccurrence()
                    } label: {
                        Label("Skip", systemImage: "forward.end.fill")
                    }
                    .tint(Tokens.Color.teal)
                }
            }
            .sheet(item: $snoozingTask) { task in
                SnoozeSheet(task: task)
            }
            .alert(
                "Delete this task?",
                isPresented: Binding(
                    get: { deletingTask != nil },
                    set: { if !$0 { deletingTask = nil } }
                ),
                presenting: deletingTask
            ) { task in
                Button("Delete", role: .destructive) {
                    let taskID = task.id
                    let mirroredEventId = task.mirroredEventId
                    let mirrorCalendarId = task.mirrorCalendarId
                    modelContext.delete(task)
                    try? modelContext.save()
                    Task {
                        await NotificationManager.shared.cancelReminders(forTaskID: taskID)
                        await GoogleCalendarService.shared.deleteMirrorIfNeeded(
                            taskID: taskID,
                            eventID: mirroredEventId,
                            calendarID: mirrorCalendarId
                        )
                    }
                    WidgetReloader.reload()
                    deletingTask = nil
                }
                Button("Cancel", role: .cancel) {
                    deletingTask = nil
                }
            } message: { task in
                Text("\"\(task.title)\" will be removed permanently.")
            }
    }

    private func toggleComplete() {
        let wasCompleted = task.status == .completed
        let wasRecurring = task.isRecurring
        var nextInstance: TaskItem?

        withAnimation(Tokens.Motion.spring) {
            if wasCompleted {
                task.status = .open
                task.completedAt = nil
            } else {
                task.status = .completed
                task.completedAt = .now
                if wasRecurring {
                    nextInstance = TaskRepeater.generateNextInstance(of: task, in: modelContext)
                }
                Haptics.success()
            }
        }
        try? modelContext.save()
        Task {
            if wasCompleted {
                // Re-opened — reschedule pending reminders.
                await NotificationManager.shared.scheduleReminders(for: task)
            } else {
                // Just completed — cancel pending reminders.
                await NotificationManager.shared.cancelReminders(forTaskID: task.id)
                if let nextInstance {
                    await NotificationManager.shared.scheduleReminders(for: nextInstance)
                }
            }
            // Mirror the title change ("✓ " prefix) to Google Calendar if
            // this task has a mirrored event. Per spec, we DON'T delete on
            // completion — history matters.
            await GoogleCalendarService.shared.syncTaskToCalendar(task)
        }
        WidgetReloader.reload()
    }

    private func skipOccurrence() {
        guard task.isRecurring else { return }
        var nextInstance: TaskItem?
        withAnimation(Tokens.Motion.spring) {
            task.status = .skipped
            task.completedAt = .now   // doubles as "skipped at"
            nextInstance = TaskRepeater.generateNextInstance(of: task, in: modelContext)
            Haptics.tap()
        }
        try? modelContext.save()
        Task {
            await NotificationManager.shared.cancelReminders(forTaskID: task.id)
            if let nextInstance {
                await NotificationManager.shared.scheduleReminders(for: nextInstance)
            }
        }
        WidgetReloader.reload()
    }
}
