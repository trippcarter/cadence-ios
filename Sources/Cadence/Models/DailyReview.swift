import Foundation
import SwiftData

/// Build 18: one row per day a user submits the evening Daily Review.
/// Drives the "Review streak" stat on the You tab.
@Model
final class ReviewLog {
    var id: UUID = UUID()
    /// Normalized to `Calendar.current.startOfDay(for:)` so streak math
    /// counts unique days.
    var date: Date = Date.now
    var completedAt: Date = Date.now
    var hasIntention: Bool = false
    var hasWin: Bool = false

    init(
        id: UUID = UUID(),
        date: Date = .now,
        completedAt: Date = .now,
        hasIntention: Bool = false,
        hasWin: Bool = false
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.completedAt = completedAt
        self.hasIntention = hasIntention
        self.hasWin = hasWin
    }
}

/// User-captured one-liner intention for tomorrow. Surfaced in the next
/// morning's Today screen (deferred for build 18 to keep scope) and rolled
/// up into the future weekly digest.
@Model
final class TomorrowIntention {
    var id: UUID = UUID()
    /// The day this intention is FOR (start-of-day of tomorrow, i.e. the
    /// day after the review was filled out).
    var date: Date = Date.now
    var text: String = ""
    /// Apple Sign-In identifier of who wrote it (kept for multi-user
    /// households in a future build; today this is always self).
    var userIdentifier: String = ""

    init(
        id: UUID = UUID(),
        date: Date = .now,
        text: String,
        userIdentifier: String = ""
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.text = text
        self.userIdentifier = userIdentifier
    }
}

/// User-captured "win" of the day. Used today for the daily review's
/// "Save & close" affordance and the future weekly recap.
@Model
final class DailyWin {
    var id: UUID = UUID()
    /// Start-of-day for the day the win happened.
    var date: Date = Date.now
    var text: String = ""
    var userIdentifier: String = ""

    init(
        id: UUID = UUID(),
        date: Date = .now,
        text: String,
        userIdentifier: String = ""
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.text = text
        self.userIdentifier = userIdentifier
    }
}
