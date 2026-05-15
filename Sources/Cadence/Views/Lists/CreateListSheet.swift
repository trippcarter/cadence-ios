import SwiftUI
import SwiftData

/// Modal sheet for creating a new list or renaming/editing an existing one.
///
/// Two modes:
///   - `.create` — inserts a new TaskList at the end of the user's pinned
///     section on save. Default lists (`isSeeded = true`) are unaffected.
///   - `.edit(list)` — renames + recolors + re-icons the existing list.
///     Works for both seeded and user-created lists. Deletion lives in the
///     ListsView context menu, not here.
struct CreateListSheet: View {

    enum Mode {
        case create
        case edit(TaskList)
    }

    let mode: Mode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var colorKey: String
    @State private var iconKey: String

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _colorKey = State(initialValue: "violet")
            _iconKey = State(initialValue: "list.bullet")
        case .edit(let list):
            _name = State(initialValue: list.name)
            _colorKey = State(initialValue: list.colorKey)
            _iconKey = State(initialValue: list.iconKey)
        }
    }

    private static let iconChoices: [String] = [
        "list.bullet",
        "briefcase.fill",
        "house.fill",
        "person.2.fill",
        "dollarsign.circle.fill",
        "heart.fill",
        "book.fill",
        "figure.run",
        "suitcase.fill",
        "cart.fill",
        "gearshape.fill",
        "leaf.fill",
        "star.fill",
        "tray.fill",
        "person.fill",
        "graduationcap.fill",
        "fork.knife",
        "airplane",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                        previewCard
                        section(title: "Name") {
                            nameField
                        }
                        section(title: "Color") {
                            colorPicker
                        }
                        section(title: "Icon") {
                            iconPicker
                        }
                        Color.clear.frame(height: 60)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.top, Tokens.Space.lg)
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Tokens.Color.text2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(saveTitle) { save() }
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(canSave ? Tokens.Color.accent2 : Tokens.Color.text3)
                        .disabled(!canSave)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: Sub-views

    private var previewCard: some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                    .fill(ListPalette.color(for: colorKey).opacity(0.22))
                    .frame(width: 42, height: 42)
                Image(systemName: iconKey)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ListPalette.color(for: colorKey))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Your new list" : name)
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Color.text)
                Text("Tap the share icon later to invite people.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
        }
        .padding(Tokens.Space.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(title.uppercased())
                .font(Tokens.Font.label)
                .kerning(1.2)
                .foregroundStyle(Tokens.Color.text3)
            content()
        }
    }

    private var nameField: some View {
        TextField("e.g. Movie Night", text: $name)
            .font(Tokens.Font.body)
            .foregroundStyle(Tokens.Color.text)
            .padding(.horizontal, Tokens.Space.md)
            .padding(.vertical, Tokens.Space.md)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
            .submitLabel(.done)
            .onSubmit { if canSave { save() } }
    }

    private var colorPicker: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.sm), count: 5)
        return LazyVGrid(columns: columns, spacing: Tokens.Space.sm) {
            ForEach(ListPalette.allKeys, id: \.self) { key in
                Button {
                    Haptics.tap()
                    colorKey = key
                } label: {
                    ZStack {
                        Circle()
                            .fill(ListPalette.color(for: key))
                            .frame(width: 38, height: 38)
                        if colorKey == key {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var iconPicker: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.sm), count: 6)
        return LazyVGrid(columns: columns, spacing: Tokens.Space.sm) {
            ForEach(Self.iconChoices, id: \.self) { symbol in
                Button {
                    Haptics.tap()
                    iconKey = symbol
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                            .fill(iconKey == symbol
                                  ? ListPalette.color(for: colorKey).opacity(0.25)
                                  : Tokens.Color.surface2)
                            .frame(height: 44)
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(iconKey == symbol
                                             ? ListPalette.color(for: colorKey)
                                             : Tokens.Color.text2)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                            .stroke(iconKey == symbol
                                    ? ListPalette.color(for: colorKey)
                                    : Tokens.Color.borderSoft,
                                    lineWidth: iconKey == symbol ? 1.4 : 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Save

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var navTitle: String {
        switch mode {
        case .create: return "New list"
        case .edit:   return "Edit list"
        }
    }

    private var saveTitle: String {
        switch mode {
        case .create: return "Create"
        case .edit:   return "Save"
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Haptics.success()

        switch mode {
        case .create:
            let descriptor = FetchDescriptor<TaskList>(
                sortBy: [SortDescriptor(\TaskList.sortOrder, order: .reverse)]
            )
            let highest = (try? modelContext.fetch(descriptor).first?.sortOrder) ?? 0
            let newList = TaskList(
                name: trimmed,
                colorKey: colorKey,
                iconKey: iconKey,
                sortOrder: highest + 1,
                isSeeded: false
            )
            modelContext.insert(newList)
        case .edit(let list):
            list.name = trimmed
            list.colorKey = colorKey
            list.iconKey = iconKey
            list.modifiedAt = .now
            // If this list is shared, push metadata change so the recipient
            // sees the new name/color/icon.
            if list.isShared {
                Task { await SharedListMirror.shared.listMetadataChanged(list) }
            }
        }

        try? modelContext.save()
        WidgetReloader.reload()
        dismiss()
    }
}
