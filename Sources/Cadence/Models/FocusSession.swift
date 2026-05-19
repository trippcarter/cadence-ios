import Foundation
import SwiftData

/// Build 18: a single Pomodoro-style focus session anchored to a task.
/// Persisted so the You tab "focus time this week" stat + future weekly
/// digest have ground-truth data to query.
///
/// Lifecycle:
///   - Created on `startedAt` when the user taps Focus
///   - `endedAt` stamped when the session naturally completes OR the user
///     ends it early via the End-early button
///   - `wasCompleted` distinguishes "ran the full planned duration" (true)
///     from "ended early or interrupted" (false) so streak/honesty stats
///     don't reward half-sessions
@Model
final class FocusSession {
    var id: UUID = UUID()
    var task: TaskItem?
    var startedAt: Date = Date.now
    var endedAt: Date?
    /// Planned duration in seconds (e.g. 1500 for 25 min). The user can
    /// extend mid-session with +5 min — that bumps this value, not
    /// `actualDuration`.
    var plannedDuration: TimeInterval = 1500
    /// Actual elapsed seconds at the moment of `endedAt`. Computed by the
    /// FocusView's ticker; same as plannedDuration on natural completion.
    var actualDuration: TimeInterval = 0
    var wasCompleted: Bool = false

    init(
        id: UUID = UUID(),
        task: TaskItem? = nil,
        startedAt: Date = .now,
        plannedDuration: TimeInterval = 1500
    ) {
        self.id = id
        self.task = task
        self.startedAt = startedAt
        self.plannedDuration = plannedDuration
    }
}
