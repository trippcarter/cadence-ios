import Foundation
import SwiftData

/// Build 18: pure-function helpers for habit streak math, plus the
/// completion-recording hook called from TaskRowActionContainer.toggleComplete
/// and TaskRowActions.toggleComplete whenever a habit task is marked done.
///
/// Streak definition:
///   - Consecutive days ending TODAY (or yesterday — counting the user's
///     last-completion day as the streak's tail end) where a HabitCompletion
///     exists.
///   - Multiple completions on a single day collapse to one (we look at
///     unique startOfDay dates).
///   - A missed day breaks the streak; the streak resets to 0 next
///     completion.
enum HabitTracker {

    /// Insert a HabitCompletion for today if the task is flagged isHabit
    /// AND there isn't already a row for today (idempotent — guards against
    /// double-tap completions). Returns the computed currentStreak after
    /// the insert so the caller can show a celebration if it just bumped.
    @MainActor
    @discardableResult
    static func recordCompletionIfNeeded(for task: TaskItem, in context: ModelContext) -> Int {
        guard task.isHabit else { return 0 }
        let today = Calendar.current.startOfDay(for: .now)
        let taskID = task.id

        let descriptor = FetchDescriptor<HabitCompletion>(
            predicate: #Predicate<HabitCompletion> { row in
                row.task?.id == taskID && row.completedOn == today
            }
        )
        let alreadyDone = (try? context.fetchCount(descriptor)) ?? 0
        guard alreadyDone == 0 else {
            return currentStreak(for: task, in: context)
        }

        let snapshot = currentStreakIncludingToday(for: task, in: context)
        let completion = HabitCompletion(
            task: task,
            completedOn: today,
            streakAtTime: snapshot
        )
        context.insert(completion)
        try? context.save()
        return snapshot
    }

    /// Walks back from today checking for HabitCompletion rows on each
    /// consecutive day. Stops on the first gap.
    @MainActor
    static func currentStreak(for task: TaskItem, in context: ModelContext) -> Int {
        let completionDays = fetchCompletionDays(for: task, in: context)
        guard !completionDays.isEmpty else { return 0 }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // Today's completion counts; yesterday's also counts (the user
        // hasn't completed today yet but the streak isn't broken).
        var cursor = today
        if !completionDays.contains(cursor) {
            // No completion today — try yesterday as the start.
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: today) else { return 0 }
            cursor = yesterday
            if !completionDays.contains(cursor) { return 0 }
        }
        var streak = 0
        while completionDays.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Same as currentStreak but assumes today's completion just happened
    /// (i.e. the +1 day is already counted). Used at completion-recording
    /// time to stamp `streakAtTime` accurately.
    @MainActor
    static func currentStreakIncludingToday(for task: TaskItem, in context: ModelContext) -> Int {
        let completionDays = fetchCompletionDays(for: task, in: context)
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // Walk backwards from YESTERDAY (today's row hasn't been inserted
        // yet at this point in the flow) counting consecutive days.
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today) else { return 1 }
        var streak = 1  // today's completion that's about to insert
        var cursor = yesterday
        while completionDays.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Highest streak ever for this task. Naive O(n log n) sweep over all
    /// completions — fine since habits typically have <1000 completions.
    @MainActor
    static func longestStreak(for task: TaskItem, in context: ModelContext) -> Int {
        let completionDays = fetchCompletionDays(for: task, in: context).sorted()
        guard !completionDays.isEmpty else { return 0 }
        let cal = Calendar.current
        var longest = 1
        var current = 1
        for i in 1..<completionDays.count {
            let prev = completionDays[i - 1]
            let curr = completionDays[i]
            if let expected = cal.date(byAdding: .day, value: 1, to: prev),
               cal.isDate(expected, inSameDayAs: curr) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    /// % of expected days hit in the last `windowDays` (defaults to 30).
    @MainActor
    static func completionRate(for task: TaskItem, in context: ModelContext, windowDays: Int = 30) -> Double {
        let completionDays = fetchCompletionDays(for: task, in: context)
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        guard let windowStart = cal.date(byAdding: .day, value: -(windowDays - 1), to: today) else { return 0 }
        let recentHits = completionDays.filter { $0 >= windowStart && $0 <= today }.count
        return Double(recentHits) / Double(windowDays)
    }

    /// Last `n` days (most recent first) with a bool indicating completion.
    /// Used by the Habits dashboard mini-calendar.
    @MainActor
    static func recentDays(for task: TaskItem, in context: ModelContext, count: Int = 30) -> [(date: Date, done: Bool)] {
        let completionDays = fetchCompletionDays(for: task, in: context)
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<count).compactMap { offset -> (date: Date, done: Bool)? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (day, completionDays.contains(day))
        }
    }

    // MARK: Private

    @MainActor
    private static func fetchCompletionDays(for task: TaskItem, in context: ModelContext) -> Set<Date> {
        let taskID = task.id
        let descriptor = FetchDescriptor<HabitCompletion>(
            predicate: #Predicate<HabitCompletion> { row in
                row.task?.id == taskID
            }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return Set(rows.map { $0.completedOn })
    }
}
