import Foundation
import SwiftData

/// Build 18: one row per day a habit task was completed. Inserted from
/// TaskRowActionContainer.toggleComplete when the task is flagged as a
/// habit (TaskItem.isHabit == true).
///
/// `completedOn` is normalized to start-of-day so duplicate completions
/// in a single day don't create duplicate rows + streak math just counts
/// days, not timestamps.
@Model
final class HabitCompletion {
    var id: UUID = UUID()
    var task: TaskItem?
    /// Normalized to `Calendar.current.startOfDay(for:)`.
    var completedOn: Date = Date.now
    /// Captured snapshot of the streak at the moment this row was created.
    /// Lets the UI render history without recomputing the whole streak walk
    /// every paint, and gives the future weekly-digest a stable number.
    var streakAtTime: Int = 0

    init(
        id: UUID = UUID(),
        task: TaskItem? = nil,
        completedOn: Date = .now,
        streakAtTime: Int = 0
    ) {
        self.id = id
        self.task = task
        self.completedOn = Calendar.current.startOfDay(for: completedOn)
        self.streakAtTime = streakAtTime
    }
}
