import SwiftUI
import SwiftData

/// Grouped, searchable list picker (Build 17). Replaces the flat
/// horizontal list strip previously used in AddTaskSheet — gives the
/// user a clear visual grouping of personal lists vs each household's
/// lists, and a search field for jumping to a specific name.
///
/// Sections:
///   1. **Personal** — every TaskList where `household == nil`
///   2. One section per `Household` — that household's lists, with the
///      household's icon + color dot in the header
///
/// UX:
///   - `.searchable` filters list names across every section
///   - Selected list shows a violet outer ring + checkmark on the right
///   - Tap a list → calls `onSelect` with the picked list's
///     `PersistentIdentifier` and dismisses
struct HierarchicalListPickerSheet: View {
    @Binding var selectedListID: PersistentIdentifier?
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\TaskList.sortOrder, order: .forward)])
    private var allLists: [TaskList]

    @Query(sort: [SortDescriptor(\Household.createdAt, order: .forward)])
    private var households: [Household]

    @State private var searchText: String = ""

    private var personalLists: [TaskList] {
        filtered(allLists.filter { $0.household == nil && !$0.isHidden })
    }

    private func lists(in household: Household) -> [TaskList] {
        filtered(allLists.filter { $0.household?.id == household.id && !$0.isHidden })
    }

    private func filtered(_ source: [TaskList]) -> [TaskList] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return source }
        return source.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                List {
                    if !personalLists.isEmpty {
                        Section {
                            ForEach(personalLists) { list in
                                listRow(list)
                            }
                        } header: {
                            sectionHeader(title: "Personal",
                                          icon: "person.fill",
                                          tint: Tokens.Color.text2)
                        }
                    }

                    ForEach(households) { household in
                        let householdLists = lists(in: household)
                        if !householdLists.isEmpty {
                            Section {
                                ForEach(householdLists) { list in
                                    listRow(list, householdName: household.name)
                                }
                            } header: {
                                sectionHeader(
                                    title: household.name,
                                    icon: household.iconKey,
                                    tint: ListPalette.color(for: household.colorKey),
                                    showsDot: true
                                )
                            }
                        }
                    }

                    if personalLists.isEmpty && households.allSatisfy({ lists(in: $0).isEmpty }) {
                        emptyResults
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Search lists")
            }
            .navigationTitle("Goes in…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Tokens.Color.accent2)
                }
            }
        }
    }

    // MARK: Rows

    private func listRow(_ list: TaskList, householdName: String? = nil) -> some View {
        let isSelected = list.persistentModelID == selectedListID
        let tint = ListPalette.color(for: list.colorKey)
        return Button {
            Haptics.tap()
            selectedListID = list.persistentModelID
            dismiss()
        } label: {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                        .fill(tint.opacity(0.22))
                        .frame(width: 32, height: 32)
                    Image(systemName: list.iconKey)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name)
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    if let householdName {
                        Text(householdName)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Color.text3)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Tokens.Color.accent2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            isSelected
                ? Tokens.Color.accent.opacity(0.12)
                : Tokens.Color.surface
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle()
                    .fill(Tokens.Color.accent)
                    .frame(width: 3)
                    .padding(.vertical, 6)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.2), value: isSelected)
    }

    // MARK: Section headers

    private func sectionHeader(title: String, icon: String, tint: Color, showsDot: Bool = false) -> some View {
        HStack(spacing: 6) {
            if showsDot {
                Circle().fill(tint).frame(width: 8, height: 8)
            }
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(Tokens.Font.label)
                .kerning(0.6)
                .foregroundStyle(Tokens.Color.text2)
            Spacer()
        }
        .textCase(nil)
    }

    private var emptyResults: some View {
        Text("No lists match \"\(searchText)\".")
            .font(Tokens.Font.body)
            .foregroundStyle(Tokens.Color.text3)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, Tokens.Space.lg)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
