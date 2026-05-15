import Foundation
import SwiftUI
import AuthenticationServices
import CloudKit

/// Minimal user identity for "who's signed in to Cadence". This is
/// intentionally NOT a SwiftData @Model — it's per-device state, not
/// business data we want CloudKit to sync. The CloudKit-synced TaskItems
/// etc. are tied to the iCloud account underneath, not to this struct.
struct AuthenticatedUser: Codable, Equatable {
    /// Apple's stable per-device-per-app identifier (never the email).
    /// Treat as opaque.
    let appleUserIdentifier: String
    /// Display name. Apple only sends fullName on the FIRST sign-in
    /// (when the user consents). Subsequent signs return nil — we keep
    /// the original.
    var firstName: String?
    var lastName: String?
    /// Email or Apple's privaterelay.appleid.com address when the user
    /// chose "Hide my email". Same first-sign-in-only caveat.
    var email: String?
    /// CKContainer.userRecordID().recordName at the moment of sign-in.
    /// Used on every cold launch to detect "the iCloud account on this
    /// device no longer matches who we think is signed in" — protects
    /// against stale Keychain blobs surfacing the wrong identity to a
    /// different physical user.
    var iCloudUserRecordName: String?

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        if let email, !email.isEmpty { return email }
        // No name and no email — Apple withheld both, and our name cache had
        // no prior entry for this identifier. Use a friendly placeholder
        // instead of leaking the raw appleUserIdentifier prefix into the UI.
        return "Signed in with Apple"
    }

    var firstNameOrFallback: String {
        if let firstName, !firstName.isEmpty { return firstName }
        return "there"
    }

    /// True when the email is one of Apple's privaterelay.appleid.com addresses.
    var isUsingHiddenEmail: Bool {
        email?.lowercased().contains("@privaterelay.appleid.com") == true
    }
}

/// App-wide auth state. `state` is the source of truth; views observe it
/// and switch between sign-in and main-app surfaces. Persists across
/// launches by reading from Keychain on init.
@MainActor
final class AuthSession: ObservableObject {

    static let shared = AuthSession()

    enum State: Equatable {
        case signedOut
        case signedIn(AuthenticatedUser)

        var user: AuthenticatedUser? {
            if case .signedIn(let user) = self { return user }
            return nil
        }
        var isSignedIn: Bool {
            if case .signedIn = self { return true }
            return false
        }
    }

    /// Keychain account name for the *active* AuthenticatedUser. Wiped on
    /// signOut() so the user has to re-authenticate.
    private static let keychainAccount = "AppleSignInUser"

    /// Keychain account name for the per-identifier name cache. Survives
    /// signOut so that a re-sign-in (Apple sends nil fullName on every
    /// non-first attempt for a given identifier) can still display the
    /// real name we captured the first time. Maps appleUserIdentifier →
    /// JSON-encoded `[String: NameCacheEntry]`.
    private static let keychainNameCacheAccount = "AppleSignInNameCache"

    /// What we remember per-identifier across sign-out cycles.
    private struct NameCacheEntry: Codable {
        var firstName: String?
        var lastName: String?
        var email: String?
    }

    @Published private(set) var state: State = .signedOut

    /// True briefly after a fresh sign-in so RootView can present the
    /// "Welcome, <name>" splash. Auto-clears after ~1.5s.
    @Published var showWelcomeSplash: Bool = false

    /// Hint that RootView's SignInView should call out "Pick a different
    /// Apple ID below" — set by Switch Apple ID. Visual only; the actual
    /// chooser is Apple's native sheet that appears when the button is tapped.
    @Published var promptingSwitchAccount: Bool = false

    private let cloudContainer = CKContainer(identifier: CadenceContainer.cloudContainerID)

    private init() {
        if let user = loadFromKeychain() {
            self.state = .signedIn(user)
        }
    }

    // MARK: Sign in

    /// Called from the SignInWithAppleButton's onCompletion handler when
    /// Apple returns a successful credential.
    ///
    /// Name/email resolution priority (Apple only sends fullName + email on
    /// the very first sign-in for a given app+Apple-ID pair — every
    /// subsequent sign-in returns nil for both):
    ///   1. Whatever Apple just returned in this credential (truth on first
    ///      sign-in of this identity)
    ///   2. Per-identifier name cache from Keychain — survives signOut so
    ///      re-sign-ins of the same Apple ID recover the original name
    ///   3. The currently-active user's name/email, if it's the same identity
    ///   4. nil — `displayName` falls back to "Signed in with Apple"
    func handleAppleAuthorization(_ credential: ASAuthorizationAppleIDCredential) {
        let identifier = credential.user
        let appleFirstName = credential.fullName?.givenName
        let appleLastName = credential.fullName?.familyName
        let appleEmail = credential.email

        NSLog("[Cadence-Auth] credential captured: id=%@, hasName=%@, hasEmail=%@",
              identifier,
              appleFirstName != nil ? "yes" : "no",
              appleEmail != nil ? "yes" : "no")

        let existing = state.user
        let isSameUser = existing?.appleUserIdentifier == identifier
        let cached = loadNameCacheEntry(for: identifier)

        let resolvedFirstName = appleFirstName
            ?? cached?.firstName
            ?? (isSameUser ? existing?.firstName : nil)
        let resolvedLastName = appleLastName
            ?? cached?.lastName
            ?? (isSameUser ? existing?.lastName : nil)
        let resolvedEmail = appleEmail
            ?? cached?.email
            ?? (isSameUser ? existing?.email : nil)

        NSLog("[Cadence-Auth] resolved identity: firstName=%@, email=%@",
              resolvedFirstName ?? "<nil>",
              resolvedEmail ?? "<nil>")

        var user = AuthenticatedUser(
            appleUserIdentifier: identifier,
            firstName: resolvedFirstName,
            lastName: resolvedLastName,
            email: resolvedEmail,
            iCloudUserRecordName: nil
        )

        // Update the persistent per-identifier cache if Apple actually gave
        // us name/email this time (first-sign-in payload).
        if appleFirstName != nil || appleLastName != nil || appleEmail != nil {
            writeNameCacheEntry(
                for: identifier,
                entry: NameCacheEntry(
                    firstName: appleFirstName ?? cached?.firstName,
                    lastName: appleLastName ?? cached?.lastName,
                    email: appleEmail ?? cached?.email
                )
            )
        }

        // Capture the current iCloud user record name so future launches can
        // detect when the device's iCloud changed underneath us. Transition
        // state IMMEDIATELY off the main actor — don't gate the user's entry
        // into the app on the iCloud network call.
        persist(user)
        withAnimation(.smooth(duration: 0.45)) {
            state = .signedIn(user)
        }
        showWelcomeSplash = true
        promptingSwitchAccount = false
        NSLog("[Cadence-Auth] state → .signedIn")

        Task { @MainActor in
            let iCloudID = await fetchCurrentICloudUserRecordName()
            if let iCloudID, var current = state.user {
                current.iCloudUserRecordName = iCloudID
                persist(current)
                state = .signedIn(current)
                NSLog("[Cadence-Auth] iCloud record bound: %@", iCloudID)
            }
        }
    }

    // MARK: Sign out

    func signOut() {
        KeychainStore.delete(account: AuthSession.keychainAccount)
        withAnimation(.smooth(duration: 0.45)) {
            state = .signedOut
        }
    }

    /// Sign out AND set a hint that SignInView should explain why the
    /// user is back at the sign-in screen ("pick a different Apple ID").
    func switchAccount() {
        signOut()
        promptingSwitchAccount = true
    }

    // MARK: Credential refresh + iCloud binding check

    /// Apple lets the user revoke an app's access from Settings → Apple ID
    /// → Sign-In with Apple. When that happens, getCredentialState reports
    /// .revoked and we should sign the user out locally.
    ///
    /// This pass ALSO verifies that the iCloud account underneath the app
    /// matches the one bound at sign-in. If they diverge (different iCloud
    /// signed in, or stale Keychain blob from another user), we sign out.
    func refreshCredentialState() async {
        guard case .signedIn(let user) = state else { return }

        // 1. Apple revocation check (network — tolerant of offline).
        let provider = ASAuthorizationAppleIDProvider()
        do {
            let credentialState = try await provider.credentialState(forUserID: user.appleUserIdentifier)
            switch credentialState {
            case .authorized:
                break
            case .revoked, .notFound, .transferred:
                NSLog("[Cadence-Auth] credential state=%d, signing out", credentialState.rawValue)
                signOut()
                return
            @unknown default:
                break
            }
        } catch {
            // Network failure / Apple servers down — keep checking iCloud
            // and trust the Keychain blob.
        }

        // 2. iCloud account binding check.
        //
        // If we have a stored iCloud user record name, the current one MUST
        // match. If we have none stored (pre-existing sign-in from before
        // this binding was introduced), capture the current one as the
        // baseline rather than forcing a sign-out — backward-compatible.
        let currentICloudID = await fetchCurrentICloudUserRecordName()

        if let stored = user.iCloudUserRecordName {
            if let current = currentICloudID, stored == current {
                return  // Match — all good.
            }
            // Either iCloud signed out, or it's a different account.
            NSLog("[Cadence-Auth] iCloud mismatch (stored=%@, current=%@), signing out",
                  stored, currentICloudID ?? "<none>")
            signOut()
        } else if let current = currentICloudID {
            // Legacy sign-in without a binding — backfill it.
            var updated = user
            updated.iCloudUserRecordName = current
            persist(updated)
            state = .signedIn(updated)
        }
    }

    // MARK: iCloud user record helpers

    private func fetchCurrentICloudUserRecordName() async -> String? {
        do {
            let status = try await cloudContainer.accountStatus()
            guard status == .available else { return nil }
            let id = try await cloudContainer.userRecordID()
            return id.recordName
        } catch {
            return nil
        }
    }

    // MARK: Persistence

    private func persist(_ user: AuthenticatedUser) {
        do {
            let data = try JSONEncoder().encode(user)
            KeychainStore.save(data, for: AuthSession.keychainAccount)
        } catch {
            NSLog("[Cadence-Auth] persist failed: %@", error.localizedDescription)
        }
    }

    private func loadFromKeychain() -> AuthenticatedUser? {
        guard let data = KeychainStore.load(account: AuthSession.keychainAccount) else {
            return nil
        }
        return try? JSONDecoder().decode(AuthenticatedUser.self, from: data)
    }

    // MARK: Per-identifier name cache (survives signOut)

    private func loadNameCacheEntry(for identifier: String) -> NameCacheEntry? {
        guard let data = KeychainStore.load(account: AuthSession.keychainNameCacheAccount) else {
            return nil
        }
        let cache = (try? JSONDecoder().decode([String: NameCacheEntry].self, from: data)) ?? [:]
        return cache[identifier]
    }

    private func writeNameCacheEntry(for identifier: String, entry: NameCacheEntry) {
        var cache: [String: NameCacheEntry]
        if let data = KeychainStore.load(account: AuthSession.keychainNameCacheAccount),
           let decoded = try? JSONDecoder().decode([String: NameCacheEntry].self, from: data) {
            cache = decoded
        } else {
            cache = [:]
        }
        cache[identifier] = entry
        do {
            let data = try JSONEncoder().encode(cache)
            KeychainStore.save(data, for: AuthSession.keychainNameCacheAccount)
        } catch {
            NSLog("[Cadence-Auth] name cache write failed: %@", error.localizedDescription)
        }
    }
}
