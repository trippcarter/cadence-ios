import Foundation

/// OAuth client configuration for the Google Cloud project this app uses.
///
/// SAFETY: Google OAuth Client IDs for installed apps (iOS) are public — they
/// are deliberately embedded in the app binary and are not secrets. Security
/// comes from PKCE, which AppAuth-iOS handles automatically. See
/// https://developers.google.com/identity/protocols/oauth2#installed
///
/// To fill in: in Google Cloud Console → APIs & Services → Credentials,
/// create an OAuth Client ID of type "iOS" matching bundle ID
/// `net.mcinnis.cadence`. Copy the Client ID and the reversed URL scheme
/// into the constants below, and add the URL scheme to project.yml's
/// `Cadence-iOS` `info.properties.CFBundleURLTypes`.
enum GoogleOAuthConfig {

    /// Format: `<digits>-<random>.apps.googleusercontent.com`
    static let clientID = "936849433688-9fa47d098o9ik1cq7ku2lre7su7v9091.apps.googleusercontent.com"

    /// Reversed client ID used as the OAuth redirect URI scheme.
    /// Format: `com.googleusercontent.apps.<digits>-<random>`
    static let reversedClientID = "com.googleusercontent.apps.936849433688-9fa47d098o9ik1cq7ku2lre7su7v9091"

    /// Full redirect URI passed to OIDAuthorizationRequest. Combines the
    /// reversed client ID with a path so AppAuth can route the callback.
    static var redirectURI: URL {
        URL(string: "\(reversedClientID):/oauthredirect")!
    }

    /// Read + write events scope (Phase 7a — two-way sync). This single scope
    /// covers both calendarList listing AND event CRUD per Google's API docs.
    static let scope = "https://www.googleapis.com/auth/calendar.events"

    /// The legacy read-only scope previous builds requested. Used at runtime
    /// to detect when an existing account is on the old scope and needs to
    /// reconnect for write access.
    static let legacyReadOnlyScope = "https://www.googleapis.com/auth/calendar.readonly"

    /// Google's discovery doc holds all OAuth endpoints — preferred over
    /// hard-coding token / auth URLs.
    static let issuer = URL(string: "https://accounts.google.com")!

    /// Quick check used by UI: are real credentials in place yet?
    static var isConfigured: Bool {
        !clientID.contains("PASTE_") && !reversedClientID.contains("PASTE_")
    }
}
