import Foundation
import SwiftData

/// A third-party account the user has linked. For Phase 3 this is Google
/// only; Apple Calendar (via EventKit) and others come later.
///
/// Tokens are NEVER stored here. OIDAuthState lives in Keychain, keyed by
/// `keychainID`. This model only carries display metadata + the link to
/// per-calendar config.
@Model
final class ConnectedAccount {
    @Attribute(.unique) var id: UUID
    /// Provider tag — "google" today. Apple/EventKit additions reuse this column.
    var provider: String
    var email: String
    /// Keychain identifier for the corresponding OIDAuthState blob.
    var keychainID: String
    var connectedAt: Date
    var lastSyncedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \CalendarConfig.account)
    var calendars: [CalendarConfig] = []

    init(
        id: UUID = UUID(),
        provider: String,
        email: String,
        keychainID: String,
        connectedAt: Date = .now,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.provider = provider
        self.email = email
        self.keychainID = keychainID
        self.connectedAt = connectedAt
        self.lastSyncedAt = lastSyncedAt
    }
}
