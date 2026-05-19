import AppIntents
import SwiftData
import Foundation

/// Build 20: AppEntity conformances for SwiftData models so they can be
/// parameters in App Intents. Siri / Shortcuts uses these to resolve
/// "which task?" / "which list?" from spoken phrases.
///
/// Note on data access: App Intent perform() runs in the app process but
/// not in the SwiftUI environment, so we can't inject @Environment(.modelContext).
/// Instead, we open a short-lived ModelContainer pointed at the same
/// App Group store path, run the query, and let SwiftData close it.
/// This is the standard pattern Apple shows in their App Intents docs.

@available(iOS 17.0, *)
struct TaskEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: "Task")
    static var defaultQuery = TaskQuery()

    let id: UUID
    let title: String
    let listName: String?

    var displayRepresentation: DisplayRepresentation {
        if let listName {
            return DisplayRepresentation(title: "\(title)", subtitle: "\(listName)")
        }
        return DisplayRepresentation(title: "\(title)")
    }
}

@available(iOS 17.0, *)
struct TaskQuery: EntityQuery, EntityStringQuery {
    /// Resolve by UUID (used when Siri remembers a prior pick).
    func entities(for identifiers: [UUID]) async throws -> [TaskEntity] {
        try await MainActor.run {
            guard let context = try? makeContext() else { return [] }
            let ids = Set(identifiers)
            let descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { ids.contains($0.id) && $0.parent == nil }
            )
            let tasks = (try? context.fetch(descriptor)) ?? []
            return tasks.map { TaskEntity(id: $0.id, title: $0.title, listName: $0.list?.name) }
        }
    }

    /// Fuzzy match by user-spoken string. Filters to OPEN tasks since
    /// "complete it" only makes sense on something not yet done.
    func entities(matching string: String) async throws -> [TaskEntity] {
        try await MainActor.run {
            guard let context = try? makeContext() else { return [] }
            let openStatus = TaskStatus.open
            let descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.status == openStatus && $0.parent == nil }
            )
            let candidates = (try? context.fetch(descriptor)) ?? []
            let needle = string.lowercased()
            let ranked = candidates
                .compactMap { task -> (TaskItem, Int)? in
                    let title = task.title.lowercased()
                    if title == needle { return (task, 0) }
                    if title.hasPrefix(needle) { return (task, 1) }
                    if title.contains(needle) { return (task, 2) }
                    return nil
                }
                .sorted { $0.1 < $1.1 }
                .prefix(8)
            return ranked.map { (task, _) in
                TaskEntity(id: task.id, title: task.title, listName: task.list?.name)
            }
        }
    }

    /// Default Siri suggestions — today's open + carried-over tasks.
    func suggestedEntities() async throws -> [TaskEntity] {
        try await MainActor.run {
            guard let context = try? makeContext() else { return [] }
            let openStatus = TaskStatus.open
            let descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.status == openStatus && $0.parent == nil }
            )
            let all = (try? context.fetch(descriptor)) ?? []
            let cal = Calendar.current
            let todayOrEarlier = all.filter { task in
                guard let due = task.dueDate else { return false }
                return due <= .now || cal.isDateInToday(due)
            }
            return todayOrEarlier.prefix(10).map { task in
                TaskEntity(id: task.id, title: task.title, listName: task.list?.name)
            }
        }
    }
}

@available(iOS 17.0, *)
struct TaskListEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: "List")
    static var defaultQuery = TaskListQuery()

    let id: UUID
    let name: String
    let iconKey: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: iconKey))
    }
}

@available(iOS 17.0, *)
struct TaskListQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [TaskListEntity] {
        try await MainActor.run {
            guard let context = try? makeContext() else { return [] }
            let ids = Set(identifiers)
            let descriptor = FetchDescriptor<TaskList>(
                predicate: #Predicate { ids.contains($0.id) }
            )
            let lists = (try? context.fetch(descriptor)) ?? []
            return lists.map { TaskListEntity(id: $0.id, name: $0.name, iconKey: $0.iconKey) }
        }
    }

    /// Loose string match — "joint business", "honey brake", etc.
    func entities(matching string: String) async throws -> [TaskListEntity] {
        try await MainActor.run {
            guard let context = try? makeContext() else { return [] }
            let descriptor = FetchDescriptor<TaskList>(
                predicate: #Predicate { $0.isHidden == false }
            )
            let all = (try? context.fetch(descriptor)) ?? []
            let needle = string.lowercased()
            let ranked = all
                .compactMap { list -> (TaskList, Int)? in
                    let name = list.name.lowercased()
                    if name == needle { return (list, 0) }
                    if name.hasPrefix(needle) { return (list, 1) }
                    if name.contains(needle) { return (list, 2) }
                    return nil
                }
                .sorted { $0.1 < $1.1 }
            return ranked.map { (list, _) in
                TaskListEntity(id: list.id, name: list.name, iconKey: list.iconKey)
            }
        }
    }

    func suggestedEntities() async throws -> [TaskListEntity] {
        try await MainActor.run {
            guard let context = try? makeContext() else { return [] }
            let descriptor = FetchDescriptor<TaskList>(
                predicate: #Predicate { $0.isHidden == false },
                sortBy: [SortDescriptor(\.sortOrder)]
            )
            let lists = (try? context.fetch(descriptor)) ?? []
            return lists.map { TaskListEntity(id: $0.id, name: $0.name, iconKey: $0.iconKey) }
        }
    }
}

// MARK: - Shared container access

/// Build 20: shared helper for App Intent queries. Spins up a short-lived
/// ModelContext pointed at the same App Group store path the main app
/// uses. Marked @MainActor because SwiftData FetchDescriptor + ModelContext
/// require main-thread isolation in this codebase.
@available(iOS 17.0, *)
@MainActor
fileprivate func makeContext() throws -> ModelContext {
    let container = try CadenceContainer.makeContainer()
    return ModelContext(container)
}
