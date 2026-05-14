import Foundation
import SwiftData
import WidgetKit

/// Fetches the latest snapshot of tasks from the App Group's shared SwiftData
/// container and hands a timeline to WidgetKit. Refreshes every 15 minutes;
/// the main app also calls `WidgetCenter.shared.reloadAllTimelines()` on
/// task lifecycle events, so the next entry usually arrives within seconds.
struct TaskTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> CadenceWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (CadenceWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CadenceWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    // MARK: Snapshot

    private func makeEntry() -> CadenceWidgetEntry {
        let snapshot = TaskSnapshot.load()
        return CadenceWidgetEntry(
            date: .now,
            todaysTasks: snapshot.tasks,
            carriedCount: snapshot.carriedCount,
            eventsCount: 0
        )
    }
}

/// Helper that opens the shared container and produces a stable, struct-only
/// view of today's tasks. We intentionally project SwiftData models into
/// value types so the rest of the widget never holds onto live model
/// instances across timeline boundaries.
enum TaskSnapshot {
    struct Result {
        let tasks: [WidgetTaskInfo]
        let carriedCount: Int
    }

    static func load() -> Result {
        do {
            let container = try CadenceContainer.makeContainer()
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<TaskItem>(
                sortBy: [SortDescriptor(\TaskItem.dueDate, order: .forward)]
            )
            let all = try context.fetch(descriptor)
            let cal = Calendar.current

            let todays = all.filter { task in
                guard task.parent == nil, let due = task.dueDate else { return false }
                return cal.isDate(due, inSameDayAs: .now)
            }
            let carried = all.filter { task in
                task.parent == nil && task.status == .open && {
                    guard let due = task.dueDate else { return false }
                    return cal.startOfDay(for: due) < cal.startOfDay(for: .now)
                }()
            }

            // Sort: timed (by time) → all-day (by createdAt). Completed last.
            let sorted = todays.sorted { lhs, rhs in
                if lhs.status == .completed && rhs.status != .completed { return false }
                if lhs.status != .completed && rhs.status == .completed { return true }
                if lhs.allDay != rhs.allDay { return !lhs.allDay }
                return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
            }

            let projected = sorted.map { t in
                WidgetTaskInfo(
                    id: t.id,
                    title: t.title,
                    dueDate: t.dueDate,
                    allDay: t.allDay,
                    colorKey: t.list?.colorKey ?? "violet",
                    listName: t.list?.name ?? "Inbox",
                    isCompleted: t.status == .completed
                )
            }
            return Result(tasks: projected, carriedCount: carried.count)
        } catch {
            // If the container can't open (e.g., entitlement missing on a real
            // device with a free Apple Dev account), fall back to placeholder.
            return Result(tasks: CadenceWidgetEntry.placeholder.todaysTasks, carriedCount: 2)
        }
    }
}
