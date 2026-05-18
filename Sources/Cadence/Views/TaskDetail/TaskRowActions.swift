import SwiftUI
import SwiftData

/// Shared swipe behavior + sheet/alert presentation for a TaskRow.
/// Use in any screen that lists tasks (Today, List Detail, future Smart filters)
/// so all three actions (complete / snooze / delete) feel identical.
///
/// Build 12 (Upgrade 2 + 8): adds a long-press `.contextMenu` exposing every
/// per-task action — complete, snooze, edit, move-to-list, set priority, set
/// due time, duplicate, repeat-as-new-today, pin/unpin, share, delete.
struct TaskRowActionContainer<Content: View>: View {
    let task: TaskItem
    var onEdit: (() -> Void)? = nil
    let content: () -> Content
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\TaskList.sortOrder, order: .forward)])
    private var allLists: [TaskList]

    @State private var snoozingTask: TaskItem?
    @State private var deletingTask: TaskItem?
    @State private var settingDueTime: Bool = false

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
            .contextMenu {
                contextMenuItems
            }
            .sheet(item: $snoozingTask) { task in
                SnoozeSheet(task: task)
            }
            .sheet(isPresented: $settingDueTime) {
                SetDueTimeSheet(task: task)
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
                    let deletionPayload = SharedListMirror.shared.captureDeletionPayload(for: task)
                    ActivityLogger.record(.deleted, for: task, in: modelContext)
                    modelContext.delete(task)
                    try? modelContext.save()
                    Task {
                        await NotificationManager.shared.cancelReminders(forTaskID: taskID)
                        await GoogleCalendarService.shared.deleteMirrorIfNeeded(
                            taskID: taskID,
                            eventID: mirroredEventId,
                            calendarID: mirrorCalendarId
                        )
                        if let deletionPayload {
                            await SharedListMirror.shared.performDeletion(deletionPayload)
                        }
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

    // MARK: Context menu items (Build 12)

    @ViewBuilder
    private var contextMenuItems: some View {
        // Complete / re-open
        Button {
            toggleComplete()
        } label: {
            Label(task.status == .completed ? "Mark Incomplete" : "Complete",
                  systemImage: task.status == .completed ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
        }

        // Edit (opens detail)
        if let onEdit {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }

        // Pin / Unpin
        Button {
            togglePin()
        } label: {
            Label(task.isPinned ? "Unpin from top" : "Pin to top",
                  systemImage: task.isPinned ? "star.slash" : "star.fill")
        }

        Divider()

        // Snooze (opens SnoozeSheet which has its own preset choices)
        Button {
            snoozingTask = task
        } label: {
            Label("Snooze…", systemImage: "moon.zzz.fill")
        }

        // Set due time
        Button {
            settingDueTime = true
        } label: {
            Label("Set due time…", systemImage: "clock")
        }

        // Move to list submenu
        Menu {
            ForEach(allLists.filter { !$0.isHidden }) { list in
                Button {
                    move(to: list)
                } label: {
                    Label(list.name, systemImage: list.iconKey)
                }
            }
        } label: {
            Label("Move to list", systemImage: "tray.and.arrow.up")
        }

        // Set priority submenu
        Menu {
            priorityMenuItem(.none, label: "None")
            priorityMenuItem(.low, label: "Low")
            priorityMenuItem(.medium, label: "Medium")
            priorityMenuItem(.high, label: "High")
        } label: {
            Label("Set priority", systemImage: "flag")
        }

        Divider()

        // Duplicate
        Button {
            duplicate(asTodayCopy: false)
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        // Repeat as new today (Upgrade 8)
        Button {
            duplicate(asTodayCopy: true)
        } label: {
            Label("Repeat as new today", systemImage: "calendar.badge.plus")
        }

        // Share
        ShareLink(item: shareText, subject: Text(task.title)) {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Divider()

        // Delete
        Button(role: .destructive) {
            deletingTask = task
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func priorityMenuItem(_ priority: Priority, label: String) -> some View {
        Button {
            setPriority(priority)
        } label: {
            if task.priority == priority {
                Label("\(label) ✓", systemImage: priorityIcon(priority))
            } else {
                Label(label, systemImage: priorityIcon(priority))
            }
        }
    }

    private func priorityIcon(_ priority: Priority) -> String {
        switch priority {
        case .none: return "flag"
        case .low: return "flag.fill"
        case .medium: return "flag.checkered"
        case .high: return "exclamationmark.triangle.fill"
        }
    }

    // MARK: Actions

    private func togglePin() {
        Haptics.tap()
        withAnimation(.bouncy(duration: 0.35)) {
            task.isPinned.toggle()
            task.modifiedAt = .now
        }
        try? modelContext.save()
        Task { await SharedListMirror.shared.taskChanged(task) }
        WidgetReloader.reload()
    }

    private func move(to list: TaskList) {
        Haptics.tap()
        let oldList = task.list
        let deletionPayload = (oldList?.isShared == true)
            ? SharedListMirror.shared.captureDeletionPayload(for: task)
            : nil
        withAnimation(.bouncy(duration: 0.4)) {
            task.list = list
            task.cloudRecordName = nil // reset so SharedListMirror writes a fresh record in the new zone
            task.modifiedAt = .now
        }
        try? modelContext.save()
        Task {
            // Remove from old shared zone if it was previously shared.
            if let deletionPayload {
                await SharedListMirror.shared.performDeletion(deletionPayload)
            }
            await SharedListMirror.shared.taskChanged(task)
        }
        WidgetReloader.reload()
    }

    private func setPriority(_ priority: Priority) {
        Haptics.tap()
        withAnimation(.smooth(duration: 0.25)) {
            task.priority = priority
            task.modifiedAt = .now
        }
        try? modelContext.save()
        Task { await SharedListMirror.shared.taskChanged(task) }
    }

    /// Clones a task. When `asTodayCopy` is true, the clone is due today —
    /// used by "Repeat as new today" for daily-routine workflows that
    /// aren't proper recurring tasks.
    private func duplicate(asTodayCopy: Bool) {
        Haptics.success()
        let clone = TaskItem(
            title: task.title,
            notes: task.notes,
            dueDate: asTodayCopy ? Calendar.current.startOfDay(for: .now) : nil,
            allDay: asTodayCopy ? true : false,
            priority: task.priority,
            tags: task.tags,
            list: task.list,
            isTimeBlocked: false,
            mirrorCalendarId: nil
        )
        clone.sortOrder = (task.sortOrder) + 1
        modelContext.insert(clone)
        try? modelContext.save()
        Task { await SharedListMirror.shared.taskChanged(clone) }
        WidgetReloader.reload()
    }

    private var shareText: String {
        var lines: [String] = [task.title]
        if let notes = task.notes, !notes.isEmpty { lines.append(notes) }
        if let due = task.dueDate {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = task.allDay ? .none : .short
            lines.append("Due: \(f.string(from: due))")
        }
        if let listName = task.list?.name { lines.append("List: \(listName)") }
        return lines.joined(separator: "\n")
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
        if !wasCompleted {
            ActivityLogger.record(.completed, for: task, in: modelContext)
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
            await SharedListMirror.shared.taskChanged(task)
            if let nextInstance {
                await SharedListMirror.shared.taskChanged(nextInstance)
            }
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
            await SharedListMirror.shared.taskChanged(task)
            if let nextInstance {
                await SharedListMirror.shared.taskChanged(nextInstance)
            }
        }
        WidgetReloader.reload()
    }
}

/// Quick due-time picker used by the context menu's "Set due time…" entry.
/// One DatePicker (date + time) plus a Save button.
struct SetDueTimeSheet: View {
    @Bindable var task: TaskItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var picked: Date

    init(task: TaskItem) {
        self.task = task
        _picked = State(initialValue: task.dueDate ?? .now)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                VStack(spacing: Tokens.Space.lg) {
                    DatePicker(
                        "Due",
                        selection: $picked,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .tint(Tokens.Color.accent)
                    .padding(.horizontal, Tokens.Space.lg)

                    Spacer()
                }
                .padding(.top, Tokens.Space.md)
            }
            .navigationTitle("Set due time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.accent2)
                }
            }
        }
    }

    private func save() {
        Haptics.success()
        task.dueDate = picked
        task.allDay = false
        task.modifiedAt = .now
        try? modelContext.save()
        Task {
            await NotificationManager.shared.scheduleReminders(for: task)
            await SharedListMirror.shared.taskChanged(task)
        }
        dismiss()
    }
}
