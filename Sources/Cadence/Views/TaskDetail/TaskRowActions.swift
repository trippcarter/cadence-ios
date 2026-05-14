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
                    modelContext.delete(task)
                    try? modelContext.save()
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
        withAnimation(Tokens.Motion.spring) {
            if task.status == .completed {
                task.status = .open
                task.completedAt = nil
            } else {
                task.status = .completed
                task.completedAt = .now
                Haptics.success()
            }
        }
        try? modelContext.save()
    }
}
