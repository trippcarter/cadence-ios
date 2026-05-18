import SwiftUI
import SwiftData

struct ListsView: View {
    @Query(sort: [SortDescriptor(\TaskList.sortOrder, order: .forward)])
    private var lists: [TaskList]
    @Query private var allTasks: [TaskItem]

    @Environment(\.modelContext) private var modelContext

    @State private var showingCreateSheet = false
    @State private var showingTemplateGallery = false
    @State private var editingList: TaskList?
    @State private var deletingList: TaskList?

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
        .sheet(isPresented: $showingCreateSheet) {
            CreateListSheet(mode: .create)
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
        if list.isSharedAsParticipant {
            if let owner = list.ownerDisplayName, !owner.isEmpty {
                return "Shared by \(owner)"
            }
            return "Shared with you"
        }
        if list.isShared {
            return "Shared · tap to manage"
        }
        if list.name == "Shared" {
            return "Private · tap to invite others"
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

    // MARK: Deletion

    private func deleteList(_ list: TaskList) {
        Haptics.warning()
        modelContext.delete(list)
        try? modelContext.save()
        WidgetReloader.reload()
    }
}
