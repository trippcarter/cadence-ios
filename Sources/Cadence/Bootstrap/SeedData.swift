import Foundation
import SwiftData

/// Seeds the four default lists and a handful of demo tasks on first launch.
/// Safe to call on every launch — exits if any TaskList already exists.
enum SeedData {

    static func bootstrapIfNeeded(_ context: ModelContext) {
        let descriptor = FetchDescriptor<TaskList>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let lists = makeDefaultLists()
        for list in lists { context.insert(list) }

        // Sample tasks are dev-only — real users get clean empty lists
        // and the friendly "Nothing on your plate today" empty state from
        // Phase 1.8. The four default lists above (Inbox/Personal/Business/
        // Joint Business) are still created so the app is immediately usable.
        #if DEBUG
        seedSampleTasks(in: lists, context: context)
        #endif

        do {
            try context.save()
        } catch {
            // First-launch seed shouldn't fail; if it does the user sees an empty app.
            print("SeedData save error: \(error)")
        }
    }

    // MARK: Default lists (per spec §5.2)

    private static func makeDefaultLists() -> [TaskList] {
        [
            TaskList(
                name: "Inbox",
                colorKey: "neutral",
                iconKey: "tray.fill",
                sortOrder: 0
            ),
            TaskList(
                name: "Personal",
                colorKey: "violet",
                iconKey: "person.fill",
                sortOrder: 1
            ),
            TaskList(
                name: "Business",
                colorKey: "amber",
                iconKey: "briefcase.fill",
                sortOrder: 2
            ),
            TaskList(
                name: "Joint Business",
                colorKey: "teal",
                iconKey: "person.2.fill",
                sortOrder: 3
            ),
        ]
    }

    // MARK: Sample tasks

    private static func seedSampleTasks(in lists: [TaskList], context: ModelContext) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today)!

        // Stable lookup by name for readability.
        let byName = Dictionary(uniqueKeysWithValues: lists.map { ($0.name, $0) })
        let personal = byName["Personal"]!
        let business = byName["Business"]!
        let joint = byName["Joint Business"]!

        func at(_ day: Date, hour: Int, minute: Int = 0) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        var tasks: [TaskItem] = []

        // 2 carried over
        tasks.append(TaskItem(
            title: "Reply to insurance broker",
            dueDate: at(yesterday, hour: 16),
            priority: .medium,
            list: business
        ))
        tasks.append(TaskItem(
            title: "Submit Q1 expense reports",
            dueDate: at(twoDaysAgo, hour: 17),
            priority: .high,
            list: business
        ))

        // 4 due today with times
        tasks.append(TaskItem(
            title: "Sam Quarterly Sync prep",
            dueDate: at(today, hour: 10),
            priority: .high,
            list: business
        ))
        tasks.append(TaskItem(
            title: "Review Q2 numbers",
            dueDate: at(today, hour: 14),
            priority: .medium,
            list: joint
        ))
        tasks.append(TaskItem(
            title: "Pick up dry cleaning",
            dueDate: at(today, hour: 17, minute: 30),
            priority: .low,
            list: personal
        ))
        tasks.append(TaskItem(
            title: "Email Jenny re: birthday plans",
            dueDate: at(today, hour: 18),
            priority: .none,
            list: personal
        ))

        // 3 due today, no time (allDay)
        tasks.append(TaskItem(
            title: "Order new laptop charger",
            dueDate: today,
            allDay: true,
            priority: .low,
            list: personal
        ))
        tasks.append(TaskItem(
            title: "Renew driver's license",
            dueDate: today,
            allDay: true,
            priority: .medium,
            list: personal
        ))
        tasks.append(TaskItem(
            title: "Draft contractor agreement",
            dueDate: today,
            allDay: true,
            priority: .high,
            list: joint
        ))

        // 2 completed today
        tasks.append(TaskItem(
            title: "Morning workout",
            dueDate: at(today, hour: 6, minute: 30),
            priority: .none,
            status: .completed,
            completedAt: at(today, hour: 7, minute: 15),
            list: personal
        ))
        tasks.append(TaskItem(
            title: "Call Mom",
            dueDate: at(today, hour: 9),
            priority: .none,
            status: .completed,
            completedAt: at(today, hour: 9, minute: 12),
            list: personal
        ))

        // 1 recurring task — daily 9 AM standup
        let standup = TaskItem(
            title: "Morning standup",
            dueDate: at(today, hour: 9),
            priority: .medium,
            list: joint
        )
        standup.rruleString = "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR"
        tasks.append(standup)

        // 1 parent with subtasks
        let groceries = TaskItem(
            title: "Buy groceries for dinner party",
            dueDate: at(today, hour: 16),
            priority: .medium,
            list: personal
        )
        tasks.append(groceries)

        for t in tasks { context.insert(t) }

        // Subtasks reference parent — insert after parent exists in context.
        let subtaskTitles = ["Fresh bread", "Bottle of red wine", "Aged cheddar"]
        for title in subtaskTitles {
            let sub = TaskItem(
                title: title,
                priority: .none,
                list: personal,
                parent: groceries
            )
            context.insert(sub)
        }
    }
}
