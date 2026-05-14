import Foundation

/// Date-based buckets used by List Detail and (later) Smart Lists.
enum TaskBucket: String, CaseIterable, Identifiable {
    case overdue
    case today
    case tomorrow
    case thisWeek
    case later
    case noDate
    case completed

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .overdue:   return "Overdue"
        case .today:     return "Today"
        case .tomorrow:  return "Tomorrow"
        case .thisWeek:  return "This week"
        case .later:     return "Later"
        case .noDate:    return "No date"
        case .completed: return "Completed"
        }
    }
}

enum TaskGrouping {

    /// Groups open tasks by their due-date bucket; completed tasks go to .completed.
    /// Returns ordered buckets — empty ones are omitted.
    static func bucket(_ tasks: [TaskItem], reference: Date = .now) -> [(TaskBucket, [TaskItem])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: reference)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        let oneWeekOut = cal.date(byAdding: .day, value: 7, to: today)!

        var buckets: [TaskBucket: [TaskItem]] = [:]

        for task in tasks {
            let bucket: TaskBucket = {
                if task.status == .completed { return .completed }
                guard let due = task.dueDate else { return .noDate }
                let day = cal.startOfDay(for: due)
                if day < today { return .overdue }
                if day == today { return .today }
                if day == tomorrow { return .tomorrow }
                if day < oneWeekOut { return .thisWeek }
                return .later
            }()
            buckets[bucket, default: []].append(task)
        }

        // Within each bucket, sort by due date ascending (overdue/today/tomorrow/etc.)
        // or by completedAt descending (completed).
        for (key, value) in buckets {
            if key == .completed {
                buckets[key] = value.sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) })
            } else {
                buckets[key] = value.sorted(by: {
                    let lhs = $0.dueDate ?? .distantFuture
                    let rhs = $1.dueDate ?? .distantFuture
                    return lhs < rhs
                })
            }
        }

        return TaskBucket.allCases.compactMap { bucket in
            guard let tasks = buckets[bucket], !tasks.isEmpty else { return nil }
            return (bucket, tasks)
        }
    }
}
