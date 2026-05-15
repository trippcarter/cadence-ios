import SwiftUI
import SwiftData

struct AddTaskSheet: View {
    /// When provided, the list picker pre-selects this list on appear.
    let defaultList: TaskList?
    /// When non-nil, pre-fills the title field on appear (also triggers
    /// the live NL parse so the AS PARSED panel populates immediately).
    let prefill: String?

    init(defaultList: TaskList? = nil, prefill: String? = nil) {
        self.defaultList = defaultList
        self.prefill = prefill
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\TaskList.sortOrder, order: .forward)])
    private var lists: [TaskList]

    @State private var titleInput: String = ""
    @State private var parsedTitle: String = ""
    @State private var parsedResult: NaturalLanguageTaskParser.Result = .empty
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
                        TextField("Email Sam tomorrow at 3pm #personal !high", text: $titleInput, axis: .vertical)
                            .font(Tokens.Font.headline)
                            .foregroundStyle(Tokens.Color.text)
                            .padding(Tokens.Space.lg)
                            .background(Tokens.Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
                            )

                        if hasParsedSomething {
                            asParsedPanel
                        }

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
            if let prefill, titleInput.isEmpty {
                titleInput = prefill
                applyParse(prefill)
            }
        }
        .onChange(of: titleInput) { _, newValue in
            applyParse(newValue)
        }
    }

    private var hasParsedSomething: Bool {
        parsedResult.dueDate != nil
            || parsedResult.listToken != nil
            || parsedResult.priority != nil
            || !parsedResult.tags.isEmpty
    }

    private var canSave: Bool {
        let effectiveTitle = parsedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return !effectiveTitle.isEmpty && selectedListID != nil
    }

    // MARK: AS PARSED preview panel

    private var asParsedPanel: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
                Text("AS PARSED")
                    .font(Tokens.Font.label)
                    .kerning(0.8)
                    .foregroundStyle(Tokens.Color.text3)
            }

            // Inline colorized rendering of the original input.
            Text(buildAttributedInput())
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Structured field summary.
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                parsedRow(label: "TASK", value: parsedTitle.isEmpty ? "—" : parsedTitle, tint: Tokens.Color.text)
                if let due = parsedResult.dueDate {
                    let label = parsedResult.allDay
                        ? due.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
                        : due.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())
                    parsedRow(label: "DUE", value: label, tint: Tokens.Color.amber)
                }
                if let token = parsedResult.listToken {
                    let matched = NaturalLanguageTaskParser.fuzzyMatch(token: token, against: lists.map { $0.name })
                    parsedRow(label: "LIST", value: matched ?? "#\(token) (no match)", tint: matched != nil ? Tokens.Color.accent2 : Tokens.Color.text3)
                }
                if let p = parsedResult.priority {
                    parsedRow(label: "PRIORITY", value: priorityLabel(p), tint: Tokens.Color.mint)
                }
                if !parsedResult.tags.isEmpty {
                    parsedRow(label: "TAGS", value: parsedResult.tags.map { "@" + $0 }.joined(separator: " "), tint: Tokens.Color.pink)
                }
            }
        }
        .padding(Tokens.Space.lg)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Color.accent.opacity(0.25), lineWidth: 0.5)
        )
    }

    private func parsedRow(label: String, value: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.md) {
            Text(label)
                .font(Tokens.Font.label)
                .kerning(0.6)
                .foregroundStyle(Tokens.Color.text3)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(tint)
            Spacer()
        }
    }

    /// Builds an AttributedString of the original input where each recognized
    /// token gets a token-kind color.
    private func buildAttributedInput() -> AttributedString {
        var attr = AttributedString(parsedResult.originalText)
        let nsInput = parsedResult.originalText as NSString
        for hl in parsedResult.highlights {
            guard NSMaxRange(hl.range) <= nsInput.length else { continue }
            let swiftRange = Range(hl.range, in: parsedResult.originalText)!
            if let attrRange = Range(swiftRange, in: attr) {
                let color: Color
                switch hl.kind {
                case .date:     color = Tokens.Color.amber
                case .list:     color = Tokens.Color.accent2
                case .priority: color = Tokens.Color.mint
                case .tag:      color = Tokens.Color.pink
                }
                attr[attrRange].foregroundColor = color
                attr[attrRange].font = Tokens.Font.bodyEmphasis
            }
        }
        return attr
    }

    private func priorityLabel(_ p: Priority) -> String {
        switch p {
        case .high:   return "High"
        case .medium: return "Medium"
        case .low:    return "Low"
        case .none:   return "None"
        }
    }

    // MARK: Parse + apply

    private func applyParse(_ input: String) {
        let result = NaturalLanguageTaskParser.parse(input)
        parsedResult = result
        parsedTitle = result.title

        if let parsedDate = result.dueDate {
            hasDueDate = true
            dueDate = parsedDate
            hasTime = !result.allDay
        }
        if let token = result.listToken,
           let matched = NaturalLanguageTaskParser.fuzzyMatch(token: token, against: lists.map { $0.name }),
           let match = lists.first(where: { $0.name == matched }) {
            selectedListID = match.persistentModelID
        }
        if let p = result.priority {
            priority = p
        }
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

        let finalTitle = parsedTitle.isEmpty
            ? titleInput.trimmingCharacters(in: .whitespacesAndNewlines)
            : parsedTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        let task = TaskItem(
            title: finalTitle,
            dueDate: hasDueDate ? dueDate : nil,
            allDay: hasDueDate ? !hasTime : false,
            priority: priority,
            tags: parsedResult.tags,
            list: list,
            isTimeBlocked: shouldMirror,
            mirrorCalendarId: shouldMirror ? defaultCalID : nil
        )
        modelContext.insert(task)
        try? modelContext.save()
        ActivityLogger.record(.created, for: task, in: modelContext)
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
