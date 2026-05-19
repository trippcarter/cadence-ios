import SwiftUI
import SwiftData

struct ListsView: View {
    @Query(sort: [SortDescriptor(\TaskList.sortOrder, order: .forward)])
    private var lists: [TaskList]
    @Query(sort: [SortDescriptor(\Household.createdAt, order: .forward)])
    private var households: [Household]
    @Query private var allTasks: [TaskItem]

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authSession: AuthSession

    @State private var showingCreateSheet = false
    @State private var showingCreateHouseholdSheet = false
    @State private var showingTemplateGallery = false
    @State private var editingList: TaskList?
    @State private var deletingList: TaskList?

    /// Personal (un-householded) lists.
    private var personalLists: [TaskList] {
        lists.filter { $0.household == nil }
    }

    private var hasAnyHabit: Bool {
        allTasks.contains { $0.isHabit && $0.parent == nil }
    }

    var body: some View {
        ZStack {
            Tokens.Color.bg.ignoresSafeArea()

            List {
                Section {
                    headerCard
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Tokens.Space.lg, leading: Tokens.Space.lg, bottom: Tokens.Space.sm, trailing: Tokens.Space.lg))
                }

                personalSection

                ForEach(households) { household in
                    householdSection(for: household)
                }

                createHouseholdRow

                if hasAnyHabit {
                    habitsDashboardRow
                }

                smartListsSection

                Color.clear
                    .frame(height: 120)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
        }
        .navigationDestination(for: ListSource.self) { source in
            ListDetailView(source: source)
        }
        .navigationDestination(for: ListsViewDestination.self) { dest in
            switch dest {
            case .habits: HabitsDashboardView()
            case .completedHistory: CompletedHistoryView()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingCreateSheet) {
            CreateListSheet(mode: .create)
        }
        .sheet(isPresented: $showingCreateHouseholdSheet) {
            CreateHouseholdSheet()
        }
        .sheet(isPresented: $showingTemplateGallery) {
            TemplateGallerySheet()
        }
        .sheet(item: $editingList) { list in
            CreateListSheet(mode: .edit(list))
        }
        .alert("Delete \(deletingList?.name ?? "this list")?",
               isPresented: Binding(
                   get: { deletingList != nil },
                   set: { if !$0 { deletingList = nil } }
               )) {
            Button("Delete", role: .destructive) {
                if let list = deletingList { deleteList(list) }
                deletingList = nil
            }
            Button("Cancel", role: .cancel) { deletingList = nil }
        } message: {
            let count = deletingList.map { openTaskCount(for: $0) + completedCount(for: $0) } ?? 0
            if count == 0 {
                Text("This list is empty.")
            } else {
                Text("\(count) task\(count == 1 ? "" : "s") in this list will also be deleted.")
            }
        }
    }

    // MARK: Personal section

    @ViewBuilder
    private var personalSection: some View {
        if !personalLists.isEmpty {
            Section {
                ForEach(personalLists) { list in
                    listRow(for: list)
                }
            } header: {
                GroupHeader(title: "Personal", count: personalLists.count, accent: Tokens.Color.accent)
                    .textCase(nil)
            }
            .listSectionSeparator(.hidden)
        }
    }

    // MARK: Household sections

    @ViewBuilder
    private func householdSection(for household: Household) -> some View {
        let householdLists = lists.filter { $0.household?.id == household.id }
        Section {
            if householdLists.isEmpty {
                householdEmptyRow(household: household)
            } else {
                ForEach(householdLists) { list in
                    listRow(for: list)
                }
            }
        } header: {
            householdSectionHeader(household: household, listCount: householdLists.count)
        }
        .listSectionSeparator(.hidden)
    }

    private func householdSectionHeader(household: Household, listCount: Int) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(ListPalette.color(for: household.colorKey).opacity(0.22))
                    .frame(width: 22, height: 22)
                Image(systemName: household.iconKey)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ListPalette.color(for: household.colorKey))
            }
            Text(household.name)
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text)
            if !household.membershipsArray.isEmpty {
                memberAvatars(for: household)
            }
            Spacer()
            Text("\(listCount) list\(listCount == 1 ? "" : "s")")
                .font(Tokens.Font.chip)
                .foregroundStyle(Tokens.Color.text3)
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.top, Tokens.Space.md)
        .padding(.bottom, 4)
        .textCase(nil)
    }

    private func memberAvatars(for household: Household) -> some View {
        let members = household.membershipsArray.prefix(3)
        return HStack(spacing: -6) {
            ForEach(Array(members.enumerated()), id: \.element.id) { _, member in
                ZStack {
                    Circle()
                        .fill(ListPalette.color(for: member.avatarColorKey))
                        .frame(width: 18, height: 18)
                    Text(member.avatarInitial)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .overlay(Circle().stroke(Tokens.Color.bg, lineWidth: 1.5))
            }
            if household.membershipsArray.count > 3 {
                Text("+\(household.membershipsArray.count - 3)")
                    .font(Tokens.Font.chip)
                    .foregroundStyle(Tokens.Color.text3)
                    .padding(.leading, 8)
            }
        }
    }

    private func householdEmptyRow(household: Household) -> some View {
        Text("No lists yet — tap + above to add one.")
            .font(Tokens.Font.caption)
            .foregroundStyle(Tokens.Color.text3)
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.sm)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: Tokens.Space.lg, bottom: 0, trailing: Tokens.Space.lg))
    }

    // MARK: List row

    @ViewBuilder
    private func listRow(for list: TaskList) -> some View {
        NavigationLink(value: ListSource.list(list)) {
            ListRow(
                source: .list(list),
                subtitle: subtitle(for: list),
                taskCount: openTaskCount(for: list),
                sharedAvatars: list.isShared ? 2 : 0
            )
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: Tokens.Space.lg, bottom: 4, trailing: Tokens.Space.lg))
        .contextMenu {
            Button {
                editingList = list
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            if !list.isSeeded {
                Button(role: .destructive) {
                    deletingList = list
                } label: {
                    Label("Delete list", systemImage: "trash")
                }
            }
        }
    }

    // MARK: "+ Create space" CTA

    @ViewBuilder
    private var createHouseholdRow: some View {
        Section {
            Button {
                Haptics.tap()
                showingCreateHouseholdSheet = true
            } label: {
                HStack(spacing: Tokens.Space.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                            .fill(Tokens.Color.accent.opacity(0.18))
                            .frame(width: 34, height: 34)
                        Image(systemName: "house.fill.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tokens.Color.accent2)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create space")
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(Tokens.Color.text)
                        Text("Family, team, crew, or any group you share lists with.")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Color.text3)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
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
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Tokens.Space.md, leading: Tokens.Space.lg, bottom: 4, trailing: Tokens.Space.lg))
        }
        .listSectionSeparator(.hidden)
    }

    // MARK: Habits dashboard row (Build 18)

    private var habitsDashboardRow: some View {
        Section {
            NavigationLink(value: ListsViewDestination.habits) {
                HStack(spacing: Tokens.Space.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                            .fill(Tokens.Color.amber.opacity(0.18))
                            .frame(width: 34, height: 34)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tokens.Color.amber)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Habits")
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(Tokens.Color.text)
                        Text("\(habitCount) tracked · longest streak \(longestStreak) days")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Color.text3)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
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
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Tokens.Space.md, leading: Tokens.Space.lg, bottom: 4, trailing: Tokens.Space.lg))
        }
        .listSectionSeparator(.hidden)
    }

    private var habitCount: Int {
        allTasks.filter { $0.isHabit && $0.parent == nil }.count
    }

    private var longestStreak: Int {
        allTasks
            .filter { $0.isHabit && $0.parent == nil }
            .map { HabitTracker.currentStreak(for: $0, in: modelContext) }
            .max() ?? 0
    }

    // MARK: Smart lists section

    @ViewBuilder
    private var smartListsSection: some View {
        Section {
            ForEach(SmartListKind.allCases) { kind in
                NavigationLink(value: ListSource.smart(kind)) {
                    ListRow(
                        source: .smart(kind),
                        subtitle: kind.subtitle,
                        taskCount: smartCount(kind)
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: Tokens.Space.lg, bottom: 4, trailing: Tokens.Space.lg))
            }
            // Build 25: Completed history isn't a normal "open tasks"
            // smart list — it routes to a dedicated time-windowed view.
            NavigationLink(value: ListsViewDestination.completedHistory) {
                completedHistoryRow
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: Tokens.Space.lg, bottom: 4, trailing: Tokens.Space.lg))
        } header: {
            GroupHeader(title: "Smart lists", count: SmartListKind.allCases.count + 1, accent: Tokens.Color.teal)
                .textCase(nil)
        }
        .listSectionSeparator(.hidden)
    }

    private var completedHistoryRow: some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                    .fill(Tokens.Color.mint.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.mint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Completed")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text("Your history, grouped by day")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
            Text("\(completedAllTimeCount)")
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text2)
                .monospacedDigit()
            Image(systemName: "chevron.right")
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

    private var completedAllTimeCount: Int {
        allTasks.filter { $0.status == .completed && $0.parent == nil }.count
    }

    // MARK: Header card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your lists")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Tokens.Color.text)
                Spacer()
                Button {
                    Haptics.tap()
                    showingCreateSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("New")
                            .font(Tokens.Font.bodyEmphasis)
                    }
                    .foregroundStyle(Tokens.Color.accent2)
                    .padding(.horizontal, Tokens.Space.md)
                    .padding(.vertical, 6)
                    .background(Tokens.Color.accent.opacity(0.16))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: Tokens.Space.sm) {
                Text("\(lists.count) lists · \(totalOpenTasks) tasks")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text3)
                Spacer()
                Button {
                    Haptics.tap()
                    showingTemplateGallery = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("From template")
                            .font(Tokens.Font.chip)
                    }
                    .foregroundStyle(Tokens.Color.accent2)
                    .padding(.horizontal, Tokens.Space.sm)
                    .padding(.vertical, 5)
                    .background(Tokens.Color.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Tokens.Color.borderSoft, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Derived data

    private var totalOpenTasks: Int {
        allTasks.filter { $0.status == .open && $0.parent == nil }.count
    }

    private func openTaskCount(for list: TaskList) -> Int {
        allTasks.filter { $0.list?.id == list.id && $0.status == .open && $0.parent == nil }.count
    }

    private func completedCount(for list: TaskList) -> Int {
        allTasks.filter { $0.list?.id == list.id && $0.status != .open && $0.parent == nil }.count
    }

    private func subtitle(for list: TaskList) -> String {
        if let household = list.household {
            return household.name
        }
        if list.isSharedAsParticipant {
            if let owner = list.ownerDisplayName, !owner.isEmpty {
                return "Shared by \(owner)"
            }
            return "Shared with you"
        }
        if list.isShared {
            return "Shared · tap to manage"
        }
        return "Private"
    }

    private var currentUserIdentifier: String? {
        authSession.state.user?.appleUserIdentifier
    }

    private func smartCount(_ kind: SmartListKind) -> Int {
        switch kind {
        case .assignedToMe:
            guard let me = currentUserIdentifier else { return 0 }
            return allTasks.filter {
                $0.status == .open
                    && $0.parent == nil
                    && $0.assignedTo == me
            }.count
        case .noDueDate:
            return allTasks.filter { $0.status == .open && $0.dueDate == nil && $0.parent == nil }.count
        case .overdue:
            return allTasks.filter { $0.isCarriedOver && $0.parent == nil }.count
        }
    }

    // MARK: Deletion

    private func deleteList(_ list: TaskList) {
        Haptics.warning()
        modelContext.delete(list)
        try? modelContext.save()
        WidgetReloader.reload()
    }
}

/// Side-channel navigation values for screens that aren't keyed by a TaskList
/// (e.g., the Habits dashboard, completed history view, future Stats /
/// Review history surfaces).
enum ListsViewDestination: Hashable {
    case habits
    case completedHistory
}

