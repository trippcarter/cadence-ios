import SwiftUI
import SwiftData

/// Build 25: cross-entity search sheet. Live fuzzy-substring search
/// across Tasks, Lists, Spaces (Households). Grouped results, filter
/// chips, recent searches.
///
/// Entry points (Build 25):
///   - You tab toolbar: small search icon
///   - ⌘F hardware keyboard shortcut (added to RootView's
///     keyboardShortcutShelf)
///
/// Deferred to a follow-up build: saved smart filters, edit-distance
/// fuzzy match, search Events.
struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var allTasks: [TaskItem]
    @Query private var allLists: [TaskList]
    @Query private var allHouseholds: [Household]

    @State private var query: String = ""
    @State private var filter: Filter = .all
    @FocusState private var searchFocused: Bool
    @AppStorage("recentSearches") private var recentSearchesRaw: String = ""

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case open = "Open"
        case completed = "Completed"
        case tasks = "Tasks"
        case lists = "Lists"

        var id: String { rawValue }
    }

    @State private var detailTask: TaskItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    filterStrip
                        .padding(.horizontal, Tokens.Space.lg)
                        .padding(.bottom, Tokens.Space.sm)
                    resultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Tasks, lists, spaces…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Tokens.Color.accent2)
                }
            }
        }
        .sheet(item: $detailTask) { task in
            TaskDetailSheet(task: task)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                searchFocused = true
            }
        }
    }

    // MARK: Filter strip

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.sm) {
                ForEach(Filter.allCases) { f in
                    let isSelected = filter == f
                    Button {
                        Haptics.tap()
                        withAnimation(.smooth(duration: 0.2)) {
                            filter = f
                        }
                    } label: {
                        Text(f.rawValue)
                            .font(Tokens.Font.chip)
                            .padding(.horizontal, Tokens.Space.md)
                            .padding(.vertical, 6)
                            .background(isSelected ? Tokens.Color.accent.opacity(0.22) : Tokens.Color.surface)
                            .foregroundStyle(isSelected ? Tokens.Color.accent2 : Tokens.Color.text2)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(isSelected ? Tokens.Color.accent : Tokens.Color.borderSoft,
                                                 lineWidth: isSelected ? 1 : 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Results

    @ViewBuilder
    private var resultsList: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            recentSearchesView
        } else if hasAnyResults {
            List {
                if filter == .all || filter == .tasks || filter == .open || filter == .completed {
                    if !matchedTasks.isEmpty {
                        Section {
                            ForEach(matchedTasks) { task in
                                taskRow(task)
                            }
                        } header: {
                            sectionHeader("Tasks", count: matchedTasks.count)
                        }
                    }
                }
                if filter == .all || filter == .lists {
                    if !matchedLists.isEmpty {
                        Section {
                            ForEach(matchedLists) { list in
                                listRow(list)
                            }
                        } header: {
                            sectionHeader("Lists", count: matchedLists.count)
                        }
                    }
                }
                if filter == .all {
                    if !matchedSpaces.isEmpty {
                        Section {
                            ForEach(matchedSpaces) { space in
                                spaceRow(space)
                            }
                        } header: {
                            sectionHeader("Spaces", count: matchedSpaces.count)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        } else {
            VStack(spacing: Tokens.Space.md) {
                Spacer()
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Tokens.Color.text3)
                Text("No matches for \"\(query)\"")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text("Try a shorter or different keyword.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
                Spacer()
            }
        }
    }

    private var hasAnyResults: Bool {
        !matchedTasks.isEmpty || !matchedLists.isEmpty || !matchedSpaces.isEmpty
    }

    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            if recentSearches.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(Tokens.Color.text3)
                    Text("Search across your tasks, lists, and spaces.")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Color.text3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Tokens.Space.xxl)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                Text("Recent")
                    .font(Tokens.Font.label)
                    .kerning(0.6)
                    .foregroundStyle(Tokens.Color.text3)
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.top, Tokens.Space.md)
                ForEach(recentSearches, id: \.self) { recent in
                    Button {
                        query = recent
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 13))
                                .foregroundStyle(Tokens.Color.text3)
                            Text(recent)
                                .font(Tokens.Font.body)
                                .foregroundStyle(Tokens.Color.text2)
                            Spacer()
                        }
                        .padding(.horizontal, Tokens.Space.lg)
                        .padding(.vertical, Tokens.Space.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }

    // MARK: Row views

    private func taskRow(_ task: TaskItem) -> some View {
        Button {
            recordRecentSearch()
            detailTask = task
        } label: {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(task.status == .completed ? Tokens.Color.mint : Tokens.Color.text3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                        .lineLimit(1)
                    if let context = task.contextString {
                        Text(context)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Color.text3)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let list = task.list {
                    Circle()
                        .fill(ListPalette.color(for: list.colorKey))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func listRow(_ list: TaskList) -> some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(ListPalette.color(for: list.colorKey).opacity(0.22))
                    .frame(width: 28, height: 28)
                Image(systemName: list.iconKey)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ListPalette.color(for: list.colorKey))
            }
            Text(list.name)
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text)
            if let household = list.household {
                Text(household.name)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
            Text("\(openCount(in: list))")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Color.text3)
                .monospacedDigit()
        }
    }

    private func spaceRow(_ household: Household) -> some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(ListPalette.color(for: household.colorKey).opacity(0.22))
                    .frame(width: 28, height: 28)
                Image(systemName: household.iconKey)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ListPalette.color(for: household.colorKey))
            }
            Text(household.name)
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text)
            Spacer()
            Text("\(household.listsArray.count) list\(household.listsArray.count == 1 ? "" : "s")")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Color.text3)
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title.uppercased())
                .font(Tokens.Font.label)
                .kerning(0.6)
                .foregroundStyle(Tokens.Color.text2)
            Spacer()
            Text("\(count)")
                .font(Tokens.Font.label)
                .foregroundStyle(Tokens.Color.text3)
        }
    }

    // MARK: Matching logic

    private var needle: String {
        query.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var matchedTasks: [TaskItem] {
        guard !needle.isEmpty else { return [] }
        let base = allTasks.filter { task in
            guard task.parent == nil else { return false }
            switch filter {
            case .open:      if task.status != .open { return false }
            case .completed: if task.status != .completed { return false }
            default: break
            }
            return task.title.lowercased().contains(needle)
                || (task.notes?.lowercased().contains(needle) ?? false)
        }
        // Open first, then sort by due date.
        return base.sorted { a, b in
            if (a.status == .open) != (b.status == .open) {
                return a.status == .open
            }
            return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
        }
    }

    private var matchedLists: [TaskList] {
        guard !needle.isEmpty else { return [] }
        return allLists
            .filter { !$0.isHidden && $0.name.lowercased().contains(needle) }
            .sorted { $0.name < $1.name }
    }

    private var matchedSpaces: [Household] {
        guard !needle.isEmpty else { return [] }
        return allHouseholds
            .filter { $0.name.lowercased().contains(needle) }
            .sorted { $0.name < $1.name }
    }

    private func openCount(in list: TaskList) -> Int {
        list.taskList.filter { $0.status == .open && $0.parent == nil }.count
    }

    // MARK: Recent searches (newline-separated string in @AppStorage)

    private var recentSearches: [String] {
        recentSearchesRaw
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func recordRecentSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var list = recentSearches
        list.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        list.insert(trimmed, at: 0)
        list = Array(list.prefix(8))
        recentSearchesRaw = list.joined(separator: "\n")
    }
}

private extension TaskItem {
    /// Short context line for a search result row. E.g. "Honey Brake / Marketing"
    /// or "Personal".
    var contextString: String? {
        var parts: [String] = []
        if let household = list?.household?.name { parts.append(household) }
        if let listName = list?.name { parts.append(listName) }
        return parts.isEmpty ? nil : parts.joined(separator: " / ")
    }
}
