import Foundation
import SwiftData

/// One row per Google calendar the user has visible in their account.
/// Persisted so we remember which calendars to fetch and which color the
/// user picked locally — overriding Google's calendar color is a common
/// preference.
@Model
final class CalendarConfig {
    @Attribute(.unique) var googleCalendarID: String
    var name: String
    /// Hex color string ("#7C5CFF") as Google sends it. May be overridden by
    /// `colorOverride` which references our palette keys (see ListPalette).
    var defaultColorHex: String?
    /// Optional palette key from ListPalette; nil = use defaultColorHex.
    var colorOverride: String?
    var isEnabled: Bool

    /// ETag from Google's last events.list response — supports If-None-Match
    /// for incremental polls.
    var lastETag: String?

    /// Inverse relationship lives on ConnectedAccount.
    var account: ConnectedAccount?

    init(
        googleCalendarID: String,
        name: String,
        defaultColorHex: String? = nil,
        colorOverride: String? = nil,
        isEnabled: Bool = true,
        lastETag: String? = nil
    ) {
        self.googleCalendarID = googleCalendarID
        self.name = name
        self.defaultColorHex = defaultColorHex
        self.colorOverride = colorOverride
        self.isEnabled = isEnabled
        self.lastETag = lastETag
    }
}
