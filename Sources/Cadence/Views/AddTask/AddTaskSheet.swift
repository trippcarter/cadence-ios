import SwiftUI
import SwiftData

struct AddTaskSheet: View {
    /// When provided, the list picker pre-selects this list on appear.
    let defaultList: TaskList?

    init(defaultList: TaskList? = nil) {
        self.defaultList = defaultList
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\TaskList.sortOrder, order: .forward)])
    private var lists: [TaskList]

    @State private var title: String = ""
    @State private var hasDueDate: Bool = true
    @State private var dueDate: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    @State private var hasTime: Bool = false
    @State private var selectedListID: PersistentIdentifier?
    @State private var priority: Priority = .none

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                        sectionLabel("Task")
                        TextField("What needs doing?", text: $title, axis: .vertical)
                            .font(Tokens.Font.headline)
                            .foregroundStyle(Tokens.Color.text)
                            .padding(Tokens.Space.lg)
                            .background(Tokens.Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
                            )

                        VStack(alignment: .leading, spacing: Tokens.Space.md) {
                            sectionLabel("When")
                            Toggle(isOn: $hasDueDate.animation(Tokens.Motion.snappy)) {
                                Text("Set a due date")
                                    .font(Tokens.Font.body)
                                    .foregroundStyle(Tokens.Color.text)
                            }
                            .tint(Tokens.Color.accent)
                            .padding(.horizontal, Tokens.Space.lg)
                            .padding(.vertical, Tokens.Space.md)
                            .background(Tokens.Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))

                            if hasDueDate {
                                VStack(alignment: .leading, spacing: Tokens.Space.md) {
                                    DatePicker(
                                        "Date",
                                        selection: $dueDate,
                                        displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date]
                                    )
                                    .tint(Tokens.Color.accent)
                                    .foregroundStyle(Tokens.Color.text)
                                    Toggle(isOn: $hasTime.animation(Tokens.Motion.snappy)) {
                                        Text("Include time")
                                            .font(Tokens.Font.body)
                                            .foregroundStyle(Tokens.Color.text)
                                    }
                                    .tint(Tokens.Color.accent)
                                }
                                .padding(Tokens.Space.lg)
                                .background(Tokens.Color.surface)
                                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                            }
                        }

                        VStack(alignment: .leading, spacing: Tokens.Space.md) {
                            sectionLabel("List")
                            ListPickerStrip(
                                lists: lists,
                                selectedListID: $selectedListID
                            )
                        }

                        VStack(alignment: .leading, spacing: Tokens.Space.md) {
                            sectionLabel("Priority")
                            PriorityPickerStrip(selected: $priority)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle("New task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Tokens.Color.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Tokens.Color.accent2 : Tokens.Color.text3)
                        .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if selectedListID == nil {
                if let defaultList {
                    selectedListID = defaultList.persistentModelID
                } else if let preferred = lists.first(where: { $0.name != "Inbox" }) ?? lists.first {
                    selectedListID = preferred.persistentModelID
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedListID != nil
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Tokens.Font.label)
            .foregroundStyle(Tokens.Color.text3)
            .kerning(0.8)
    }

    private func save() {
        guard canSave, let listID = selectedListID,
              let list = lists.first(where: { $0.persistentModelID == listID })
        else { return }

        // Auto-mirror: per-user opt-in for new tasks that have a specific time.
        let autoMirror = UserDefaults.standard.bool(forKey: PrefsKey.autoMirrorTimeBlocked)
        let defaultCalID = UserDefaults.standard.string(forKey: PrefsKey.defaultMirrorCalendarID)
        let shouldMirror = autoMirror
            && hasDueDate && hasTime
            && defaultCalID != nil

        let task = TaskItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: hasDueDate ? dueDate : nil,
            allDay: hasDueDate ? !hasTime : false,
            priority: priority,
            list: list,
            isTimeBlocked: shouldMirror,
            mirrorCalendarId: shouldMirror ? defaultCalID : nil
        )
        modelContext.insert(task)
        try? modelContext.save()
        Haptics.success()
        Task {
            await GoogleCalendarService.shared.syncTaskToCalendar(task)
        }
        WidgetReloader.reload()
        dismiss()
    }
}

// MARK: - List picker

private struct ListPickerStrip: View {
    let lists: [TaskList]
    @Binding var selectedListID: PersistentIdentifier?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.sm) {
                ForEach(lists) { list in
                    let isSelected = list.persistentModelID == selectedListID
                    Button {
                        Haptics.tap()
                        selectedListID = list.persistentModelID
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: list.iconKey)
                                .font(.system(size: 11, weight: .semibold))
                            Text(list.name)
                                .font(Tokens.Font.bodyEmphasis)
                        }
                        .padding(.horizontal, Tokens.Space.md)
                        .padding(.vertical, Tokens.Space.sm)
                        .background(
                            isSelected
                                ? ListPalette.color(for: list.colorKey).opacity(0.20)
                                : Tokens.Color.surface
                        )
                        .foregroundStyle(
                            isSelected
                                ? ListPalette.color(for: list.colorKey)
                                : Tokens.Color.text2
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                isSelected ? ListPalette.color(for: list.colorKey) : Tokens.Color.borderSoft,
                                lineWidth: isSelected ? 1 : 0.5
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Priority picker

private struct PriorityPickerStrip: View {
    @Binding var selected: Priority

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            chip(.none, label: "None", tint: Tokens.Color.text3)
            chip(.low, label: "Low", tint: Tokens.Color.text2)
            chip(.medium, label: "Medium", tint: Tokens.Color.amber)
            chip(.high, label: "High", tint: Tokens.Color.rose)
        }
    }

    private func chip(_ p: Priority, label: String, tint: Color) -> some View {
        let isSelected = selected == p
        return Button {
            Haptics.tap()
            selected = p
        } label: {
            Text(label)
                .font(Tokens.Font.bodyEmphasis)
                .padding(.horizontal, Tokens.Space.md)
                .padding(.vertical, Tokens.Space.sm)
                .frame(maxWidth: .infinity)
                .background(isSelected ? tint.opacity(0.20) : Tokens.Color.surface)
                .foregroundStyle(isSelected ? tint : Tokens.Color.text2)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        isSelected ? tint : Tokens.Color.borderSoft,
                        lineWidth: isSelected ? 1 : 0.5
                    )
                )
        }
        .buttonStyle(.plain)
    }
}
