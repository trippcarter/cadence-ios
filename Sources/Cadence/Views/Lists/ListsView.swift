import SwiftUI
import SwiftData

struct ListsView: View {
    @Query(sort: [SortDescriptor(\TaskList.sortOrder, order: .forward)])
    private var lists: [TaskList]
    @Query private var allTasks: [TaskItem]

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

                Section {
                    ForEach(lists) { list in
                        NavigationLink(value: ListSource.list(list)) {
                            ListRow(
                                source: .list(list),
                                subtitle: subtitle(for: list),
                                taskCount: openTaskCount(for: list),
                                sharedAvatars: list.name == "Joint Business" ? 2 : 0
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: Tokens.Space.lg, bottom: 4, trailing: Tokens.Space.lg))
                    }
                } header: {
                    GroupHeader(title: "Pinned", count: lists.count, accent: Tokens.Color.accent)
                        .textCase(nil)
                }
                .listSectionSeparator(.hidden)

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
                } header: {
                    GroupHeader(title: "Smart lists", count: SmartListKind.allCases.count, accent: Tokens.Color.teal)
                        .textCase(nil)
                }
                .listSectionSeparator(.hidden)

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
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Header card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your lists")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Tokens.Color.text)
                Spacer()
                Text("ALL")
                    .font(Tokens.Font.label)
                    .kerning(1.2)
                    .foregroundStyle(Tokens.Color.accent2)
            }
            Text("\(lists.count) lists · \(totalOpenTasks) tasks")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text3)
        }
    }

    // MARK: Derived data

    private var totalOpenTasks: Int {
        allTasks.filter { $0.status != .completed && $0.parent == nil }.count
    }

    private func openTaskCount(for list: TaskList) -> Int {
        allTasks.filter { $0.list?.id == list.id && $0.status != .completed && $0.parent == nil }.count
    }

    private func subtitle(for list: TaskList) -> String {
        if list.name == "Joint Business" {
            return "Shared · 2 members"
        }
        return "Private"
    }

    private func smartCount(_ kind: SmartListKind) -> Int {
        switch kind {
        case .noDueDate:
            return allTasks.filter { $0.status == .open && $0.dueDate == nil && $0.parent == nil }.count
        case .overdue:
            return allTasks.filter { $0.isCarriedOver && $0.parent == nil }.count
        }
    }
}
