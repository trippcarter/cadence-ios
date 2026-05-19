import Foundation
import SwiftData
import WidgetKit
import os.log

/// Build 29 overhaul. Two real bugs from production:
///
/// 1) Old predicate filtered `isDate(due, inSameDayAs: now)` — that
///    excluded carried-over tasks (yesterday or earlier) from the
///    displayed list, even though `carriedCount` was tracked. Users
///    with only carried-over tasks saw "Nothing on your plate."
///
/// 2) `eventsCount` was hardcoded to 0 — the widget never queried
///    `CachedEvent` rows at all, so Google Calendar meetings never
///    surfaced.
///
/// New behavior: pull every OPEN task with `dueDate ≤ endOfToday`,
/// pull every event whose `start` is inside today, project them into
/// a mixed `[WidgetItem]` sorted by time, and emit os_log lines so we
/// can verify in Console.app if anything still looks wrong.
struct TaskTimelineProvider: TimelineProvider {

    private static let log = OSLog(subsystem: "net.mcinnis.cadence.widget", category: "WIDGET")

    func placeholder(in context: Context) -> CadenceWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (CadenceWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CadenceWidgetEntry>) -> Void) {
        let entry = makeEntry()
        // 15 min cadence is fine — mutation sites in the main app
        // call WidgetCenter.reloadAllTimelines() so meaningful
        // changes propagate within seconds.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    // MARK: Snapshot

    private func makeEntry() -> CadenceWidgetEntry {
        let snapshot = TaskSnapshot.load()
        return CadenceWidgetEntry(
            date: .now,
            items: snapshot.items,
            openTaskCount: snapshot.openTaskCount,
            carriedCount: snapshot.carriedCount,
            eventsCount: snapshot.eventsCount,
            nextItem: snapshot.nextItem
        )
    }
}

// MARK: - Snapshot loader

/// Reads from the App Group's shared SwiftData container and produces
/// the value-type projection the timeline emits.
enum TaskSnapshot {
    private static let log = OSLog(subsystem: "net.mcinnis.cadence.widget", category: "WIDGET")

    struct Result {
        let items: [WidgetItem]
        let openTaskCount: Int
        let carriedCount: Int
        let eventsCount: Int
        let nextItem: WidgetItem?
    }

    static func load() -> Result {
        let started = Date()
        do {
            let container = try CadenceContainer.makeContainer()
            os_log("[WIDGET] timeline refresh started — container opened", log: log, type: .info)
            let context = ModelContext(container)
            let cal = Calendar.current
            let startOfToday = cal.startOfDay(for: .now)
            let endOfToday = cal.date(byAdding: .day, value: 1, to: startOfToday)!

            // -- Tasks --
            let taskDescriptor = FetchDescriptor<TaskItem>(
                sortBy: [SortDescriptor(\TaskItem.dueDate, order: .forward)]
            )
            let allTasks = try context.fetch(taskDescriptor)
            // Build 29 predicate: open + has a due date + due date is in the
            // past OR today (≤ endOfToday). This includes carried-over.
            let relevantTasks = allTasks.filter { task in
                guard task.parent == nil,
                      task.status == .open,
                      let due = task.dueDate else { return false }
                return due < endOfToday
            }
            let openTaskCount = relevantTasks.count
            let carriedCount = relevantTasks.filter { task in
                guard let due = task.dueDate else { return false }
                return due < startOfToday
            }.count

            // -- Events --
            // CachedEvent lives in the *local-only* SwiftData configuration
            // (it's derived data — we never sync it via CloudKit). The unified
            // container CadenceContainer.makeContainer() includes both stores,
            // so a single fetch against this context resolves correctly.
            let eventDescriptor = FetchDescriptor<CachedEvent>(
                sortBy: [SortDescriptor(\CachedEvent.start, order: .forward)]
            )
            let allEvents = (try? context.fetch(eventDescriptor)) ?? []
            let relevantEvents = allEvents.filter { event in
                // Event starts before tomorrow AND ends after start of today —
                // covers all-day, multi-day, and timed events that touch today.
                event.start < endOfToday && event.end > startOfToday
            }

            os_log("[WIDGET] today predicate matched %{public}d tasks (%{public}d carried) + %{public}d events",
                   log: log, type: .info,
                   openTaskCount, carriedCount, relevantEvents.count)

            // -- Project --
            let taskItems: [WidgetItem] = relevantTasks.map { t in
                .task(WidgetTaskInfo(
                    id: t.id,
                    title: t.title,
                    dueDate: t.dueDate,
                    allDay: t.allDay,
                    colorKey: t.list?.colorKey ?? "violet",
                    listName: t.list?.name ?? "Inbox",
                    isCompleted: false,
                    isCarriedOver: (t.dueDate.map { $0 < startOfToday }) ?? false
                ))
            }
            let eventItems: [WidgetItem] = relevantEvents.map { e in
                .event(WidgetEventInfo(
                    id: e.id,
                    title: e.title,
                    start: e.start,
                    end: e.end,
                    isAllDay: e.isAllDay,
                    calendarColorKey: "teal"
                ))
            }

            // Merge + sort. WidgetItem.sortDate bumps carried-over to the
            // very top, then all-day, then timed by start time.
            let merged = (taskItems + eventItems).sorted { $0.sortDate < $1.sortDate }

            // Pick nextItem: prefer the soonest still-upcoming item by
            // wall-clock time (skip carried-over since "next" should
            // suggest what's ahead, not what's overdue).
            let next: WidgetItem? = {
                let now = Date.now
                let candidates = merged.filter { item in
                    switch item {
                    case .task(let t):
                        guard !t.isCarriedOver, let due = t.dueDate else { return false }
                        return due >= now
                    case .event(let e):
                        return e.start >= now
                    }
                }
                return candidates.min(by: { lhs, rhs in lhs.sortDate < rhs.sortDate })
                    ?? merged.first  // fallback to the first item even if overdue
            }()

            let elapsed = Date().timeIntervalSince(started) * 1000
            os_log("[WIDGET] snapshot built in %{public}.0fms (%{public}d items, next=%{public}@)",
                   log: log, type: .info,
                   elapsed, merged.count, next?.id ?? "none")

            return Result(
                items: merged,
                openTaskCount: openTaskCount,
                carriedCount: carriedCount,
                eventsCount: relevantEvents.count,
                nextItem: next
            )
        } catch {
            os_log("[WIDGET] container failed to open: %{public}@. Falling back to placeholder.",
                   log: log, type: .error, error.localizedDescription)
            return Result(
                items: CadenceWidgetEntry.placeholder.items,
                openTaskCount: CadenceWidgetEntry.placeholder.openTaskCount,
                carriedCount: CadenceWidgetEntry.placeholder.carriedCount,
                eventsCount: CadenceWidgetEntry.placeholder.eventsCount,
                nextItem: CadenceWidgetEntry.placeholder.nextItem
            )
        }
    }
}
