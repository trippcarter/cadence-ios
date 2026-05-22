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
    /// Build 31: reminder offset for this task. Seeded from the user's
    /// "Default reminder time" preference; the chip below the time
    /// picker lets the user override it per-task.
    @State private var reminderPreset: ReminderOffsetPreset = .resolve(
        UserDefaults.standard.object(forKey: PrefsKey.defaultReminderOffset) as? Double
            ?? ReminderOffsetPreset.tenMin.rawValue
    )
    @State private var selectedListID: PersistentIdentifier?
    @State private var priority: Priority = .none
    /// Inline assignment (Build 16). nil = "Unassigned". Only meaningful
    /// when the currently-picked list is parented by a Household. Reset to
    /// nil if the user pivots to a personal list mid-creation.
    @State private var assignedToIdentifier: String? = nil
    @State private var showingListPicker: Bool = false

    @EnvironmentObject private var authSession: AuthSession

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

                                    // Build 31: reminder chip — only meaningful
                                    // when the task has a specific time. Tap
                                    // to change; seeded from the default pref.
                                    if hasTime {
                                        Divider().background(Tokens.Color.borderSoft)
                                        Menu {
                                            ForEach(ReminderOffsetPreset.allCases) { preset in
                                                Button {
                                                    reminderPreset = preset
                                                } label: {
                                                    Label(preset.displayName,
                                                          systemImage: reminderPreset == preset ? "checkmark" : "")
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "bell.fill")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(Tokens.Color.accent2)
                                                Text(reminderPreset.chipLabel)
                                                    .font(Tokens.Font.bodyEmphasis)
                                                    .foregroundStyle(Tokens.Color.text)
                                                Spacer()
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundStyle(Tokens.Color.text3)
                                            }
                                            .contentShape(Rectangle())
                                        }
                                    }
                                }
                                .padding(Tokens.Space.lg)
                                .background(Tokens.Color.surface)
                                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                            }
                        }

                        VStack(alignment: .leading, spacing: Tokens.Space.md) {
                            sectionLabel("Goes in")
                            goesInRow
                        }

                        // Build 16: inline household-member assignment. Only
                        // surfaced when the picked list belongs to a household.
                        if let household = pickedListHousehold,
                           !household.membershipsArray.isEmpty {
                            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                                HStack(spacing: 6) {
                                    sectionLabel("Assign to")
                                    Spacer()
                                    Text(household.name)
                                        .font(Tokens.Font.chip)
                                        .foregroundStyle(Tokens.Color.text3)
                                }
                                AssigneePickerStrip(
                                    members: household.membershipsArray,
                                    selectedIdentifier: $assignedToIdentifier
                                )
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
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
        .onChange(of: selectedListID) { _, _ in
            // When the user pivots to a personal list mid-flow, smoothly
            // clear the picked assignee so the inline picker doesn't leave
            // stale state hidden behind the section's transition.
            if pickedListHousehold == nil, assignedToIdentifier != nil {
                withAnimation(.smooth(duration: 0.25)) {
                    assignedToIdentifier = nil
                }
            }
        }
        .animation(.smooth(duration: 0.25), value: pickedListHousehold?.id)
    }

    /// Household of the currently-selected list, or nil for personal lists.
    /// Drives whether the inline "Assign to" picker renders.
    private var pickedListHousehold: Household? {
        guard let listID = selectedListID,
              let list = lists.first(where: { $0.persistentModelID == listID })
        else { return nil }
        return list.household
    }

    /// Currently-selected TaskList. nil before defaultList kicks in or if
    /// the selection somehow falls out of sync with the @Query.
    private var pickedList: TaskList? {
        guard let listID = selectedListID else { return nil }
        return lists.first(where: { $0.persistentModelID == listID })
    }

    /// Build 17: replaces the flat horizontal `ListPickerStrip` with a
    /// tappable "destination" card that surfaces the picked list's color +
    /// icon + name, plus a household chip when household-scoped. Tap opens
    /// `HierarchicalListPickerSheet` for a grouped, searchable picker.
    @ViewBuilder
    private var goesInRow: some View {
        Button {
            Haptics.tap()
            showingListPicker = true
        } label: {
            HStack(spacing: Tokens.Space.md) {
                if let list = pickedList {
                    let tint = ListPalette.color(for: list.colorKey)
                    ZStack {
                        RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                            .fill(tint.opacity(0.22))
                            .frame(width: 36, height: 36)
                        Image(systemName: list.iconKey)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(list.name)
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(Tokens.Color.text)
                            .lineLimit(1)
                        if let household = list.household {
                            HStack(spacing: 4) {
                                Image(systemName: household.iconKey)
                                    .font(.system(size: 9, weight: .semibold))
                                Text(household.name)
                                    .font(Tokens.Font.chip)
                            }
                            .foregroundStyle(ListPalette.color(for: household.colorKey))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ListPalette.color(for: household.colorKey).opacity(0.14))
                            .clipShape(Capsule())
                        } else {
                            Text("Personal")
                                .font(Tokens.Font.chip)
                                .foregroundStyle(Tokens.Color.text3)
                        }
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                            .fill(Tokens.Color.surface2)
                            .frame(width: 36, height: 36)
                        Image(systemName: "tray")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Tokens.Color.text3)
                    }
                    Text("Pick a list")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
                    .rotationEffect(.degrees(showingListPicker ? 90 : 0))
                    .animation(.bouncy(duration: 0.3), value: showingListPicker)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingListPicker) {
            HierarchicalListPickerSheet(selectedListID: $selectedListID)
                .presentationDetents([.large])
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

        // Build 31: a timed task gets the chosen reminder offset baked in.
        // Untimed tasks (date only, or no date) get no reminder — there's
        // no precise moment to fire against.
        let reminderOffsets: [TimeInterval]
        if hasDueDate, hasTime, reminderPreset != .none {
            reminderOffsets = [reminderPreset.rawValue]
        } else {
            reminderOffsets = []
        }

        let task = TaskItem(
            title: finalTitle,
            dueDate: hasDueDate ? dueDate : nil,
            allDay: hasDueDate ? !hasTime : false,
            priority: priority,
            tags: parsedResult.tags,
            reminderOffsets: reminderOffsets,
            list: list,
            isTimeBlocked: shouldMirror,
            mirrorCalendarId: shouldMirror ? defaultCalID : nil
        )
        // Inline household assignment (Build 16). Only stamp when the
        // chosen list belongs to a household — guards against orphan
        // assignedTo strings on personal-list tasks.
        if list.household != nil, let assignee = assignedToIdentifier {
            task.assignedTo = assignee
            task.assignedBy = authSession.state.user?.appleUserIdentifier
            task.assignedAt = .now
        }
        modelContext.insert(task)
        try? modelContext.save()
        ActivityLogger.record(.created, for: task, in: modelContext)
        try? modelContext.save()
        Haptics.success()
        // Build 31: schedule the local reminder for the new task. No-op
        // when reminderOffsets is empty (untimed task / "None" picked).
        if !task.reminderOffsets.isEmpty {
            Task { await NotificationManager.shared.scheduleReminders(for: task) }
        }
        Task {
            await GoogleCalendarService.shared.syncTaskToCalendar(task)
        }
        Task { await SharedListMirror.shared.taskChanged(task) }
        WidgetReloader.reload()
        dismiss()
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

// MARK: - Assignee picker (Build 16)

/// Horizontal scroll of avatar chips: "Unassigned" followed by one chip per
/// household member. Tapping selects (single-select); the selected chip
/// gets a violet outer ring and slight scale bump.
private struct AssigneePickerStrip: View {
    let members: [HouseholdMembership]
    @Binding var selectedIdentifier: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.md) {
                unassignedChip
                ForEach(members, id: \.id) { member in
                    chip(for: member)
                }
            }
            .padding(.horizontal, 2) // breathing room so the ring isn't clipped
        }
    }

    private var unassignedChip: some View {
        let isSelected = selectedIdentifier == nil
        return Button {
            Haptics.tap()
            withAnimation(.bouncy(duration: 0.3)) {
                selectedIdentifier = nil
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Tokens.Color.accent : Tokens.Color.borderSoft,
                                lineWidth: isSelected ? 2 : 1)
                        .frame(width: 38, height: 38)
                    Circle()
                        .fill(Tokens.Color.surface2)
                        .frame(width: 30, height: 30)
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? Tokens.Color.accent2 : Tokens.Color.text3)
                }
                Text("None")
                    .font(Tokens.Font.chip)
                    .foregroundStyle(isSelected ? Tokens.Color.accent2 : Tokens.Color.text3)
            }
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Unassigned")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func chip(for member: HouseholdMembership) -> some View {
        let isSelected = selectedIdentifier == member.userIdentifier
        return Button {
            Haptics.tap()
            withAnimation(.bouncy(duration: 0.3)) {
                selectedIdentifier = member.userIdentifier
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Tokens.Color.accent : Tokens.Color.borderSoft,
                                lineWidth: isSelected ? 2 : 1)
                        .frame(width: 38, height: 38)
                    AssigneeAvatar(initial: member.avatarInitial,
                                   colorKey: member.avatarColorKey,
                                   size: 30)
                }
                Text(member.displayName.split(separator: " ").first.map(String.init) ?? member.displayName)
                    .font(Tokens.Font.chip)
                    .foregroundStyle(isSelected ? Tokens.Color.accent2 : Tokens.Color.text2)
                    .lineLimit(1)
            }
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Assign to \(member.displayName)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
