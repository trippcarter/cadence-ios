import SwiftUI
import SwiftData

struct ListDetailView: View {
    let source: ListSource

    @Query(sort: [SortDescriptor(\TaskItem.dueDate, order: .forward)])
    private var allTasks: [TaskItem]

    @State private var detailTask: TaskItem?
    @State private var showingAddTask = false

    var body: some View {
        ZStack {
            Tokens.Color.bg.ignoresSafeArea()

            if filteredTasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .navigationTitle(source.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Tokens.Color.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if case .list = source {
                    Button {
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Tokens.Color.accent2)
                    }
                }
            }
        }
        .sheet(item: $detailTask) { task in
            TaskDetailSheet(task: task)
        }
        .sheet(isPresented: $showingAddTask) {
            if case .list(let list) = source {
                AddTaskSheet(defaultList: list)
            }
        }
    }

    // MARK: Task list

    private var taskList: some View {
        List {
            ForEach(groupedTasks, id: \.0) { bucket, tasks in
                Section {
                    ForEach(tasks) { task in
                        TaskRowActionContainer(task: task) {
                            TaskRow(
                                task: task,
                                showsCarriedOverChip: bucket == .overdue,
                                onTitleTap: { detailTask = task }
                            )
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: Tokens.Space.lg, bottom: 4, trailing: Tokens.Space.lg))
                    }
                } header: {
                    GroupHeader(
                        title: bucket.displayTitle,
                        count: tasks.count,
                        accent: accent(for: bucket)
                    )
                    .textCase(nil)
                }
                .listSectionSeparator(.hidden)
            }

            Color.clear
                .frame(height: 120)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: source.iconKey)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(ListPalette.color(for: source.colorKey).opacity(0.85))
            Text("Nothing here yet")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Color.text)
            Text("Tap + to add a task to \(source.displayName).")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.xxl)
        }
        .padding(.bottom, 100)
    }

    // MARK: Bucket → accent

    private func accent(for bucket: TaskBucket) -> Color {
        switch bucket {
        case .overdue:   return Tokens.Color.rose
        case .today:     return Tokens.Color.accent
        case .tomorrow:  return Tokens.Color.amber
        case .thisWeek:  return Tokens.Color.teal
        case .later:     return Tokens.Color.indigo
        case .noDate:    return Tokens.Color.text3
        case .completed: return Tokens.Color.mint
        }
    }

    // MARK: Filtering + grouping

    private var filteredTasks: [TaskItem] {
        // Exclude subtasks from top-level list view — they appear under their parent.
        let tasksForSource: [TaskItem]
        switch source {
        case .list(let list):
            tasksForSource = allTasks.filter { $0.list?.id == list.id && $0.parent == nil }
        case .smart(.noDueDate):
            tasksForSource = allTasks.filter { $0.status == .open && $0.dueDate == nil && $0.parent == nil }
        case .smart(.overdue):
            tasksForSource = allTasks.filter { $0.isCarriedOver && $0.parent == nil }
        }
        return tasksForSource
    }

    private var groupedTasks: [(TaskBucket, [TaskItem])] {
        TaskGrouping.bucket(filteredTasks)
    }
}
