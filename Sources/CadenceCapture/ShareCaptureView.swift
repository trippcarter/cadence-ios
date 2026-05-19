import SwiftUI
import SwiftData

/// Build 22: SwiftUI form mounted inside the iOS share sheet. Mirrors
/// the in-app AddTask aesthetic but stripped down — just title, list,
/// priority, optional due, save.
struct ShareCaptureView: View {
    let initialText: String
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var container: ModelContainer?
    @State private var containerError: String?
    @State private var title: String = ""
    @State private var detectedDate: Date?
    @State private var listPickerSelection: TaskList?
    @State private var priority: Priority = .none
    @State private var saving: Bool = false
    @State private var lists: [TaskList] = []

    init(initialText: String, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.initialText = initialText
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                if let containerError {
                    errorView(message: containerError)
                } else {
                    formView
                }
            }
            .navigationTitle("Save to Cadence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(Tokens.Color.text2)
                        .disabled(saving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(canSave ? Tokens.Color.accent2 : Tokens.Color.text3)
                        .disabled(!canSave || saving)
                }
            }
        }
        .task { await loadContainer() }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && container != nil
    }

    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                titleField
                if let date = detectedDate {
                    detectedDateBanner(date)
                }
                listPicker
                priorityRow
                Spacer(minLength: 40)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.top, Tokens.Space.md)
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Task".uppercased())
                .font(Tokens.Font.label)
                .kerning(0.6)
                .foregroundStyle(Tokens.Color.text3)
            TextField("What's the task?", text: $title, axis: .vertical)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text)
                .padding(Tokens.Space.lg)
                .background(Tokens.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                        .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
                )
                .onChange(of: title) { _, newValue in
                    detectedDate = Self.detectDate(in: newValue)
                }
        }
    }

    private func detectedDateBanner(_ date: Date) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.Color.amber)
            Text("Detected: \(date.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Color.text2)
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.sm)
        .background(Tokens.Color.amber.opacity(0.12))
        .clipShape(Capsule())
    }

    private var listPicker: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Goes in".uppercased())
                .font(Tokens.Font.label)
                .kerning(0.6)
                .foregroundStyle(Tokens.Color.text3)
            Menu {
                ForEach(lists) { list in
                    Button {
                        listPickerSelection = list
                    } label: {
                        Label(list.name, systemImage: list.iconKey)
                    }
                }
            } label: {
                HStack(spacing: Tokens.Space.md) {
                    if let list = listPickerSelection {
                        let tint = ListPalette.color(for: list.colorKey)
                        ZStack {
                            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                                .fill(tint.opacity(0.22))
                                .frame(width: 32, height: 32)
                            Image(systemName: list.iconKey)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(tint)
                        }
                        Text(list.name)
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(Tokens.Color.text)
                    } else {
                        Text("Choose a list")
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(Tokens.Color.text3)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Tokens.Color.text3)
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
        }
    }

    private var priorityRow: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Priority".uppercased())
                .font(Tokens.Font.label)
                .kerning(0.6)
                .foregroundStyle(Tokens.Color.text3)
            HStack(spacing: 6) {
                priorityChip(.none, label: "None", tint: Tokens.Color.text3)
                priorityChip(.low, label: "Low", tint: Tokens.Color.text2)
                priorityChip(.medium, label: "Medium", tint: Tokens.Color.amber)
                priorityChip(.high, label: "High", tint: Tokens.Color.rose)
            }
        }
    }

    private func priorityChip(_ p: Priority, label: String, tint: Color) -> some View {
        let isSelected = priority == p
        return Button {
            priority = p
        } label: {
            Text(label)
                .font(Tokens.Font.bodyEmphasis)
                .padding(.vertical, Tokens.Space.sm)
                .frame(maxWidth: .infinity)
                .background(isSelected ? tint.opacity(0.22) : Tokens.Color.surface)
                .foregroundStyle(isSelected ? tint : Tokens.Color.text2)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                        .stroke(isSelected ? tint : Tokens.Color.borderSoft, lineWidth: isSelected ? 1 : 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: "exclamationmark.icloud.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text("Couldn't reach Cadence's data")
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text)
            Text(message)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Color.text3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.xl)
        }
    }

    // MARK: Lifecycle

    @MainActor
    private func loadContainer() async {
        do {
            let c = try CadenceContainer.makeContainer()
            container = c
            let descriptor = FetchDescriptor<TaskList>(
                sortBy: [SortDescriptor(\TaskList.sortOrder, order: .forward)]
            )
            let fetchedLists = try ModelContext(c).fetch(descriptor)
            lists = fetchedLists
            // Default to "Inbox" if it exists, else first non-hidden.
            listPickerSelection = fetchedLists.first(where: { $0.name == "Inbox" })
                ?? fetchedLists.first(where: { !$0.isHidden })
        } catch {
            containerError = String(describing: error)
        }
    }

    private func save() {
        guard let container, let listSel = listPickerSelection else { return }
        saving = true
        Task { @MainActor in
            let context = ModelContext(container)
            // Re-fetch the list in this context to avoid model-graph
            // mismatches across ModelContext instances.
            let listID = listSel.id
            let listDescriptor = FetchDescriptor<TaskList>(
                predicate: #Predicate { $0.id == listID }
            )
            let resolvedList = (try? context.fetch(listDescriptor).first) ?? listSel

            let task = TaskItem(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                dueDate: detectedDate,
                allDay: detectedDate != nil,
                priority: priority,
                list: resolvedList
            )
            context.insert(task)
            try? context.save()
            onSave()
        }
    }

    // MARK: NSDataDetector helper

    /// Detects the first date phrase in the shared text (e.g. "tomorrow
    /// at 3pm") so we can pre-fill a due date without the user typing.
    static func detectDate(in text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        return matches.compactMap { $0.date }.first
    }
}
