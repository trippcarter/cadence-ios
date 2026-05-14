import Foundation
import SwiftData

/// A Google Calendar event cached locally. NOT synced to CloudKit (per
/// architecture doc §3.3) — events are derived data we can always refetch.
///
/// Identifier note: `id` is Google's event ID (a string like
/// "abc123_20260514T100000Z"), not a generated UUID. Reusing Google's ID
/// lets us upsert in one fetch query when their API returns updated events.
@Model
final class CachedEvent {
    @Attribute(.unique) var id: String      // Google event ID
    var calendarID: String                   // Google calendar ID
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var location: String?
    var notes: String?
    var attendees: [String]                  // display emails
    var meetingURL: URL?                     // e.g., hangoutLink
    var htmlLink: URL?                       // "Open in Google Calendar"
    var lastFetched: Date

    init(
        id: String,
        calendarID: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        location: String? = nil,
        notes: String? = nil,
        attendees: [String] = [],
        meetingURL: URL? = nil,
        htmlLink: URL? = nil,
        lastFetched: Date = .now
    ) {
        self.id = id
        self.calendarID = calendarID
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.attendees = attendees
        self.meetingURL = meetingURL
        self.htmlLink = htmlLink
        self.lastFetched = lastFetched
    }
}
