import SwiftUI
import SwiftData

/// Modal task editor. Mirrors mockup phone 6 — auto-saves every edit via
/// SwiftData @Bindable; no explicit Save button.
struct TaskDetailSheet: View {
    @Bindable var task: TaskItem

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\TaskList.sortOrder, order: .forward)])
    private var allLists: [TaskList]

    @State private var hasDueDate: Bool = false
    @State private var hasTime: Bool = false
    @State private var newSubtaskTitle: String = ""
    @FocusState private var titleFocused: Bool
    @FocusState private var subtaskFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                        titleBlock
                        chipsRow
                        notesBlock
                        propertiesGroup
                        subtasksBlock
                        Color.clear.frame(height: Tokens.Space.xl)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.top, Tokens.Space.md)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: dismissAndSave) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(Tokens.Color.accent2)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("TASK")
                        .font(Tokens.Font.label)
                        .kerning(1.2)
                        .foregroundStyle(Tokens.Color.text3)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            deleteTask()
                        } label: {
                            Label("Delete task", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Tokens.Color.text2)
                    }
                }
            }
            .toolbarBackground(Tokens.Color.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            hasDueDate = task.dueDate != nil
            hasTime = !task.allDay
        }
        .onChange(of: hasDueDate) { _, newValue in
            if !newValue {
                task.dueDate = nil
                task.allDay = false
            } else if task.dueDate == nil {
                task.dueDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)
                task.allDay = !hasTime
            }
            persist()
        }
        .onChange(of: hasTime) { _, newValue in
            task.allDay = !newValue
            persist()
        }
        .interactiveDismissDisabled(false)
    }

    // MARK: Title

    private var titleBlock: some View {
        TextField("", text: $task.title, axis: .vertical)
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(Tokens.Color.text)
            .focused($titleFocused)
            .lineLimit(3)
            .onSubmit { titleFocused = false; persist() }
            .onChange(of: task.title) { _, _ in persist() }
    }

    // MARK: Chips row

    private var chipsRow: some View {
        HStack(spacing: Tokens.Space.sm) {
            if task.isCarriedOver, let due = task.dueDate {
                let dayName = due.formatted(.dateTime.weekday(.abbreviated))
                Text("was \(dayName)")
                    .font(Tokens.Font.chip)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Tokens.Color.rose.opacity(0.12))
                    .foregroundStyle(Tokens.Color.rose)
                    .clipShape(Capsule())
            }
            if let list = task.list {
                HStack(spacing: 4) {
                    Image(systemName: list.iconKey)
                        .font(.system(size: 10, weight: .semibold))
                    Text(list.name)
                        .font(Tokens.Font.chip)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(ListPalette.chipFill(for: list.colorKey))
                .foregroundStyle(ListPalette.color(for: list.colorKey))
                .clipShape(Capsule())
            }
            Spacer()
        }
    }

    // MARK: Notes

    private var notesBlock: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            sectionLabel("Notes")
            ZStack(alignment: .topLeading) {
                if (task.notes ?? "").isEmpty {
                    Text("Add notes…")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Color.text3)
                        .padding(.top, 12)
                        .padding(.leading, 12)
                }
                TextEditor(text: Binding(
                    get: { task.notes ?? "" },
                    set: { task.notes = $0.isEmpty ? nil : $0; persist() }
                ))
                .scrollContentBackground(.hidden)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text)
                .padding(.horizontal, 7)
                .padding(.vertical, 6)
                .frame(minHeight: 90)
            }
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
        }
    }

    // MARK: Properties

    private var propertiesGroup: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            sectionLabel("Details")
            VStack(spacing: 0) {
                dueRow
                Divider().background(Tokens.Color.borderSoft)
                priorityRow
                Divider().background(Tokens.Color.borderSoft)
                remindersRow
                Divider().background(Tokens.Color.borderSoft)
                listRow
                Divider().background(Tokens.Color.borderSoft)
                createdByRow
            }
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private var dueRow: some View {
        VStack(spacing: Tokens.Space.sm) {
            HStack {
                detailLabel(icon: "calendar", text: "Due")
                Spacer()
                Toggle("", isOn: $hasDueDate)
                    .tint(Tokens.Color.accent)
                    .labelsHidden()
            }
            if hasDueDate {
                HStack {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { task.dueDate ?? .now },
                            set: { task.dueDate = $0; persist() }
                        ),
                        displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date]
                    )
                    .labelsHidden()
                    .tint(Tokens.Color.accent)
                    Spacer()
                    Toggle("Time", isOn: $hasTime)
                        .toggleStyle(.button)
                        .tint(Tokens.Color.accent)
                        .font(Tokens.Font.chip)
                }
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var priorityRow: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            detailLabel(icon: "flag", text: "Priority")
            HStack(spacing: 6) {
                priorityChip(.none, label: "None", tint: Tokens.Color.text3)
                priorityChip(.low, label: "Low", tint: Tokens.Color.text2)
                priorityChip(.medium, label: "Medium", tint: Tokens.Color.amber)
                priorityChip(.high, label: "High", tint: Tokens.Color.rose)
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private func priorityChip(_ p: Priority, label: String, tint: Color) -> some View {
        let isSelected = task.priority == p
        return Button {
            Haptics.tap()
            task.priority = p
            persist()
        } label: {
            Text(label)
                .font(Tokens.Font.chip)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? tint.opacity(0.18) : Tokens.Color.surface2)
                .foregroundStyle(isSelected ? tint : Tokens.Color.text2)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? tint : Tokens.Color.borderSoft, lineWidth: isSelected ? 1 : 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var remindersRow: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            detailLabel(icon: "bell", text: "Reminders")
            HStack(spacing: 6) {
                reminderChip("At due", offset: 0)
                reminderChip("5m", offset: -300)
                reminderChip("30m", offset: -1800)
                reminderChip("1h", offset: -3600)
                reminderChip("1d", offset: -86400)
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private func reminderChip(_ label: String, offset: TimeInterval) -> some View {
        let isSelected = task.reminderOffsets.contains(offset)
        return Button {
            Haptics.tap()
            if isSelected {
                task.reminderOffsets.removeAll { $0 == offset }
            } else {
                task.reminderOffsets.append(offset)
            }
            persist()
        } label: {
            Text(label)
                .font(Tokens.Font.chip)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Tokens.Color.accent.opacity(0.18) : Tokens.Color.surface2)
                .foregroundStyle(isSelected ? Tokens.Color.accent2 : Tokens.Color.text2)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        isSelected ? Tokens.Color.accent : Tokens.Color.borderSoft,
                        lineWidth: isSelected ? 1 : 0.5
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private var listRow: some View {
        HStack {
            detailLabel(icon: "list.bullet", text: "List")
            Spacer()
            Menu {
                ForEach(allLists) { list in
                    Button {
                        task.list = list
                        persist()
                    } label: {
                        Label(list.name, systemImage: list.iconKey)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: task.list?.iconKey ?? "tray")
                        .font(.system(size: 11, weight: .semibold))
                    Text(task.list?.name ?? "Inbox")
                        .font(Tokens.Font.bodyEmphasis)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, Tokens.Space.md)
                .padding(.vertical, 6)
                .background(ListPalette.chipFill(for: task.list?.colorKey ?? "neutral"))
                .foregroundStyle(ListPalette.color(for: task.list?.colorKey ?? "neutral"))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var createdByRow: some View {
        HStack {
            detailLabel(icon: "person.crop.circle", text: "Created by")
            Spacer()
            Text(task.createdBy.isEmpty ? "You" : task.createdBy)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text2)
            Text(task.createdAt, format: .dateTime.month(.abbreviated).day())
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Color.text3)
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private func detailLabel(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.Color.text3)
                .frame(width: 18)
            Text(text)
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text)
        }
    }

    // MARK: Subtasks

    private var subtasksBlock: some View {
        let done = task.subtasks.filter { $0.status == .completed }.count
        let total = task.subtasks.count
        return VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                sectionLabel("Subtasks")
                Spacer()
                if total > 0 {
                    Text("\(done) of \(total)")
                        .font(Tokens.Font.label)
                        .foregroundStyle(Tokens.Color.text3)
                        .kerning(0.6)
                }
            }
            VStack(spacing: 0) {
                ForEach(task.subtasks.sorted(by: { $0.createdAt < $1.createdAt })) { sub in
                    SubtaskRow(subtask: sub) {
                        persist()
                    }
                    if sub !== task.subtasks.last {
                        Divider().background(Tokens.Color.borderSoft)
                    }
                }
                if !task.subtasks.isEmpty {
                    Divider().background(Tokens.Color.borderSoft)
                }
                HStack(spacing: Tokens.Space.md) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Tokens.Color.accent2)
                    TextField("Add a subtask", text: $newSubtaskTitle)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Color.text)
                        .focused($subtaskFocused)
                        .onSubmit { addSubtask() }
                    if !newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button("Add") { addSubtask() }
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(Tokens.Color.accent2)
                    }
                }
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.vertical, Tokens.Space.md)
            }
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
        }
    }

    // MARK: Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Tokens.Font.label)
            .foregroundStyle(Tokens.Color.text3)
            .kerning(0.8)
    }

    private func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let sub = TaskItem(
            title: trimmed,
            priority: .none,
            list: task.list,
            parent: task
        )
        modelContext.insert(sub)
        newSubtaskTitle = ""
        persist()
        Haptics.tap()
    }

    private func deleteTask() {
        Haptics.warning()
        modelContext.delete(task)
        try? modelContext.save()
        dismiss()
    }

    private func persist() {
        try? modelContext.save()
    }

    private func dismissAndSave() {
        persist()
        dismiss()
    }
}

// MARK: - SubtaskRow

private struct SubtaskRow: View {
    @Bindable var subtask: TaskItem
    var onChange: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            Button(action: toggle) {
                ZStack {
                    Circle()
                        .strokeBorder(Tokens.Color.text3, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if subtask.status == .completed {
                        Circle()
                            .fill(Tokens.Color.accent)
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            TextField("", text: $subtask.title)
                .font(Tokens.Font.body)
                .foregroundStyle(subtask.status == .completed ? Tokens.Color.text3 : Tokens.Color.text)
                .strikethrough(subtask.status == .completed, color: Tokens.Color.text3)
                .focused($focused)
                .onChange(of: subtask.title) { _, _ in onChange() }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private func toggle() {
        withAnimation(Tokens.Motion.spring) {
            if subtask.status == .completed {
                subtask.status = .open
                subtask.completedAt = nil
            } else {
                subtask.status = .completed
                subtask.completedAt = .now
                Haptics.success()
            }
        }
        onChange()
    }
}
