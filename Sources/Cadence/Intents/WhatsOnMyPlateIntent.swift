import AppIntents
import SwiftData
import Foundation

/// Build 20: "Hey Siri, what's on my plate today."
///
/// Reads aloud a one-paragraph summary of today's open tasks + cached
/// Google Calendar events. Returns ProvidesDialog so Siri actually
/// speaks the answer; no UI required.
@available(iOS 17.0, *)
struct WhatsOnMyPlateIntent: AppIntent {
    static var title: LocalizedStringResource = "What's on my plate today"
    static var description = IntentDescription(
        "Cadence reads aloud what's on your plate for today: tasks, meetings, top priority."
    )
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try CadenceContainer.makeContainer()
        let context = ModelContext(container)

        let cal = Calendar.current
        let allTasksDescriptor = FetchDescriptor<TaskItem>()
        let allTasks = (try? context.fetch(allTasksDescriptor)) ?? []
        let openToday = allTasks.filter { task in
            guard task.parent == nil, task.status == .open,
                  let due = task.dueDate else { return false }
            return cal.isDateInToday(due)
        }
        let carried = allTasks.filter { $0.isCarriedOver && $0.parent == nil }

        let eventsDescriptor = FetchDescriptor<CachedEvent>()
        let allEvents = (try? context.fetch(eventsDescriptor)) ?? []
        let eventsToday = allEvents.filter { cal.isDateInToday($0.start) }

        let topPriority: TaskItem? = openToday
            .sorted { lhs, rhs in
                // Highest priority first, then earliest due time.
                if lhs.priority.rawValue != rhs.priority.rawValue {
                    return lhs.priority.rawValue > rhs.priority.rawValue
                }
                return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
            }
            .first

        var lines: [String] = []
        let taskCount = openToday.count + carried.count
        switch taskCount {
        case 0:
            lines.append("Nothing on your plate today.")
        case 1:
            lines.append("You have 1 task today.")
        default:
            lines.append("You have \(taskCount) tasks today.")
        }
        if !eventsToday.isEmpty {
            lines.append("\(eventsToday.count) \(eventsToday.count == 1 ? "meeting" : "meetings").")
        }
        if !carried.isEmpty {
            lines.append("\(carried.count) carried over.")
        }
        if let topPriority {
            let priorityWord: String = {
                switch topPriority.priority {
                case .high: return "Top priority"
                case .medium: return "Next up"
                case .low, .none: return "First up"
                }
            }()
            if let due = topPriority.dueDate, !topPriority.allDay {
                let f = DateFormatter()
                f.dateStyle = .none
                f.timeStyle = .short
                lines.append("\(priorityWord): \(topPriority.title) at \(f.string(from: due)).")
            } else {
                lines.append("\(priorityWord): \(topPriority.title).")
            }
        }
        let summary = lines.joined(separator: " ")
        return .result(dialog: IntentDialog(stringLiteral: summary))
    }
}
