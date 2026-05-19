import Foundation
import EventKit
import SwiftData

/// Build 22: bulk-import Apple Reminders into Cadence as new TaskLists +
/// TaskItems. Uses EventKit's request-full-access-to-reminders API
/// (iOS 17+) — the iOS 17 API split read access from write access; we
/// only need read but the system surfaces it as "Full Access" in the
/// permission dialog regardless.
@MainActor
final class RemindersImportService: ObservableObject {

    static let shared = RemindersImportService()

    private let eventStore = EKEventStore()

    /// Per-list result of `fetchSourceLists()`.
    struct SourceList: Identifiable, Hashable {
        let id: String     // EKCalendar.calendarIdentifier
        let title: String
        let color: CGColor?
        let totalCount: Int
        let openCount: Int
    }

    enum AuthorizationState {
        case notDetermined
        case authorized
        case denied
        case restricted
    }

    /// Build 22 progress callback shape — drives the import progress UI.
    struct ProgressUpdate {
        let listsProcessed: Int
        let totalLists: Int
        let tasksImported: Int
        let currentListTitle: String?
    }

    // MARK: Authorization

    func authorizationState() -> AuthorizationState {
        let status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .notDetermined: return .notDetermined
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .fullAccess, .authorized, .writeOnly: return .authorized
        @unknown default:    return .notDetermined
        }
    }

    func requestAccess() async -> AuthorizationState {
        do {
            // iOS 17+ split the API. requestFullAccessToReminders is the
            // current modern name; falls back to the deprecated method on
            // older systems via the system's runtime selection.
            let granted = try await eventStore.requestFullAccessToReminders()
            return granted ? .authorized : .denied
        } catch {
            NSLog("[Cadence-Import] reminders access request failed: %@", error.localizedDescription)
            return .denied
        }
    }

    // MARK: Source list discovery

    /// Returns every Reminders list the user has visible, with their
    /// total + open counts so the UI can show "Family · 12 (3 open)".
    func fetchSourceLists() async throws -> [SourceList] {
        let calendars = eventStore.calendars(for: .reminder)
        var results: [SourceList] = []
        for calendar in calendars {
            let predicate = eventStore.predicateForReminders(in: [calendar])
            let reminders = await fetchReminders(matching: predicate)
            let openCount = reminders.filter { !$0.isCompleted }.count
            results.append(SourceList(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                color: calendar.cgColor,
                totalCount: reminders.count,
                openCount: openCount
            ))
        }
        return results.sorted { $0.title < $1.title }
    }

    private func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    // MARK: Import

    /// Bulk-import the selected lists. Per spec: each EKCalendar maps to
    /// a new TaskList; each EKReminder maps to a TaskItem with title,
    /// notes, dueDateComponents, priority, URL.
    ///
    /// `includeCompleted` controls whether we pull completed-state
    /// reminders too (default: open only).
    /// `progress` fires on each list boundary so the UI can update.
    func importLists(
        sourceListIDs: Set<String>,
        includeCompleted: Bool,
        context: ModelContext,
        progress: @escaping (ProgressUpdate) -> Void
    ) async throws -> Int {
        let allCalendars = eventStore.calendars(for: .reminder)
        let selected = allCalendars.filter { sourceListIDs.contains($0.calendarIdentifier) }

        // Compute next sortOrder so we don't trample any existing lists.
        let descriptor = FetchDescriptor<TaskList>(
            sortBy: [SortDescriptor(\TaskList.sortOrder, order: .reverse)]
        )
        var nextSort = ((try? context.fetch(descriptor).first?.sortOrder) ?? 0) + 1

        var totalImported = 0
        for (i, calendar) in selected.enumerated() {
            progress(.init(
                listsProcessed: i,
                totalLists: selected.count,
                tasksImported: totalImported,
                currentListTitle: calendar.title
            ))

            let pred = eventStore.predicateForReminders(in: [calendar])
            let reminders = await fetchReminders(matching: pred)
            let filtered = reminders.filter { includeCompleted || !$0.isCompleted }

            let newList = TaskList(
                name: calendar.title,
                colorKey: closestPaletteKey(forCGColor: calendar.cgColor),
                iconKey: "tray.fill",
                sortOrder: nextSort,
                isSeeded: false
            )
            context.insert(newList)
            nextSort += 1

            for reminder in filtered {
                let task = makeTask(from: reminder, list: newList)
                context.insert(task)
                totalImported += 1
            }
        }

        try context.save()
        progress(.init(
            listsProcessed: selected.count,
            totalLists: selected.count,
            tasksImported: totalImported,
            currentListTitle: nil
        ))
        return totalImported
    }

    // MARK: Mapping helpers

    private func makeTask(from reminder: EKReminder, list: TaskList) -> TaskItem {
        let priority = Self.mapEKPriority(reminder.priority)
        let dueDate: Date? = {
            guard let comps = reminder.dueDateComponents else { return nil }
            return Calendar.current.date(from: comps)
        }()
        let allDay = (reminder.dueDateComponents?.hour == nil)
        var notes = reminder.notes ?? ""
        if let url = reminder.url?.absoluteString, !url.isEmpty {
            if !notes.isEmpty { notes += "\n\n" }
            notes += url
        }
        let item = TaskItem(
            title: reminder.title ?? "Untitled",
            notes: notes.isEmpty ? nil : notes,
            dueDate: dueDate,
            allDay: allDay,
            priority: priority,
            status: reminder.isCompleted ? .completed : .open,
            completedAt: reminder.completionDate,
            list: list
        )
        return item
    }

    /// EKReminder.priority is 0 (none), 1 (high), 5 (medium), 9 (low) per
    /// CalDAV / iCalendar RFC 5545. Cadence uses an inverted Priority enum.
    static func mapEKPriority(_ p: Int) -> Priority {
        switch p {
        case 1...4:  return .high
        case 5:      return .medium
        case 6...9:  return .low
        default:     return .none
        }
    }

    /// Picks the closest Cadence ListPalette key to a EKCalendar's CGColor.
    /// Reminders colors are typically vivid + match Apple's stock set; we
    /// map them by hue distance to our 9 brand palette tones.
    private func closestPaletteKey(forCGColor cg: CGColor?) -> String {
        guard let cg, let components = cg.components, components.count >= 3 else {
            return "violet"
        }
        let r = Double(components[0])
        let g = Double(components[1])
        let b = Double(components[2])
        // Crude bucketing: which channel dominates?
        if r > 0.7 && g < 0.5 && b < 0.5 { return "rose" }
        if r > 0.7 && g > 0.5 && b < 0.3 { return "amber" }
        if r > 0.5 && g < 0.5 && b > 0.5 { return "violet" }
        if g > 0.7 && b > 0.5             { return "teal" }
        if g > 0.7                        { return "mint" }
        if b > 0.7                        { return "indigo" }
        if r > 0.9 && g > 0.6 && b > 0.6 { return "pink" }
        if r > 0.9 && g > 0.4             { return "orange" }
        return "neutral"
    }
}
