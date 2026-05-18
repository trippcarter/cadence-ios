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
    /// Display name from Apple's credential. Apple only sends fullName on
    /// the FIRST sign-in (when the user consents). Subsequent signs return
    /// nil — we keep the original via the per-identifier name cache.
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
    /// Captured the first time this Apple identifier signs in. Persisted in
    /// the per-identifier Keychain cache so "Member since" stays stable
    /// across sign-out / sign-in cycles for the same Apple ID.
    var memberSince: Date?
    /// User-set display name from Settings → Display Name OR from the
    /// first-run "What should we call you?" prompt. Source of truth is
    /// UserDefaults via `UserScopedPrefs.userDisplayName(for:)`. This
    /// field is a hydrated copy refreshed at sign-in / on user edit so the
    /// in-memory view models can react via @Published.
    var userSetDisplayName: String?

    /// Display name resolution (Build 11 onward). Priority:
    ///   1. User-set name (Settings → Display Name, or first-run prompt)
    ///   2. Apple's firstName + lastName (from initial credential)
    ///   3. Email local-part with first letter capitalized
    ///      ("tripp@mcinnis.net" → "Tripp"). Skipped if the email is a
    ///      privaterelay alias (those are noise).
    ///   4. "Cadence User" — true last resort.
    var displayName: String {
        if let userSet = userSetDisplayName?.trimmingCharacters(in: .whitespaces),
           !userSet.isEmpty {
            return userSet
        }
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        if let email, !email.isEmpty, !isUsingHiddenEmail,
           let derived = emailDerivedName(from: email) {
            return derived
        }
        return "Cadence User"
    }

    /// First-word fallback used by the welcome splash. "there" when nothing
    /// resolves — used as the second word ("Welcome, there") not first.
    var firstNameOrFallback: String {
        let resolved = displayName
        if resolved == "Cadence User" { return "there" }
        return resolved.split(separator: " ").first.map(String.init) ?? "there"
    }

    /// 2-character initials derived from the resolved displayName.
    /// Rules: 2+ words → first letter of first + first letter of last;
    /// 1 word → first 2 chars. "C" when nothing resolves.
    var avatarInitials: String {
        let name = displayName
        let words = name.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if words.count >= 2 {
            let first = words[0].first.map(String.init) ?? ""
            let second = words[1].first.map(String.init) ?? ""
            return (first + second).uppercased()
        }
        if let only = words.first {
            return String(only.prefix(2)).uppercased()
        }
        return "C"
    }

    /// "Member since March 2026" — uses memberSince if available.
    var memberSinceLabel: String? {
        guard let memberSince else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return "Member since \(formatter.string(from: memberSince))"
    }

    /// True when the email is one of Apple's privaterelay.appleid.com addresses.
    var isUsingHiddenEmail: Bool {
        email?.lowercased().contains("@privaterelay.appleid.com") == true
    }

    /// True when the only thing we can derive is the "Cadence User" fallback —
    /// i.e., Apple gave us no name, the email is a private relay (or nil),
    /// and the user hasn't set a display name yet. UI uses this to decide
    /// whether to present the first-run name prompt.
    var needsDisplayNameSetup: Bool {
        if let userSet = userSetDisplayName, !userSet.isEmpty { return false }
        let hasAppleName = (firstName.map { !$0.isEmpty } ?? false)
            || (lastName.map { !$0.isEmpty } ?? false)
        if hasAppleName { return false }
        if let email, !email.isEmpty, !isUsingHiddenEmail { return false }
        return true
    }

    private func emailDerivedName(from email: String) -> String? {
        let local = email.split(separator: "@").first.map(String.init) ?? ""
        let cleaned = local
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let words = cleaned.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !words.isEmpty else { return nil }
        return words
            .map { word in
                guard let first = word.first else { return word }
                return String(first).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
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

    /// What we remember per-identifier across sign-out cycles. `firstSeenAt`
    /// is captured the first time this identifier ever signs in, so the
    /// Profile "Member since" line stays stable across signOut→signIn cycles.
    private struct NameCacheEntry: Codable {
        var firstName: String?
        var lastName: String?
        var email: String?
        var firstSeenAt: Date?
    }

    @Published private(set) var state: State = .signedOut

    /// True briefly after a fresh sign-in so RootView can present the
    /// "Welcome, <name>" splash. Auto-clears after ~1.5s.
    @Published var showWelcomeSplash: Bool = false

    /// Set on every sign-in so the welcome splash can pick between
    /// "Welcome, X" (first time) and "Welcome back, X" (returning).
    /// Inferred from whether the per-identifier cache had a firstSeenAt
    /// entry BEFORE this sign-in.
    @Published var lastSignInWasReturning: Bool = false

    /// Hint that RootView's SignInView should call out "Pick a different
    /// Apple ID below" — set by Switch Apple ID. Visual only; the actual
    /// chooser is Apple's native sheet that appears when the button is tapped.
    @Published var promptingSwitchAccount: Bool = false

    /// Signal that RootView should present the "What should we call you?"
    /// first-run name prompt. Set when sign-in completes with no name
    /// resolvable from any source (Apple withheld it, no email, no
    /// previously-set user name).
    @Published var needsNamePrompt: Bool = false

    private let cloudContainer = CKContainer(identifier: CadenceContainer.cloudContainerID)

    private init() {
        if var user = loadFromKeychain() {
            // UserDefaults is the source of truth for the user-set display
            // name; re-hydrate every cold launch in case Keychain is stale
            // (e.g. the user reinstalled and Keychain reset but UserDefaults
            // survived).
            user.userSetDisplayName = UserScopedPrefs.userDisplayName(for: user.appleUserIdentifier)
            self.state = .signedIn(user)
            NSLog("[DISPLAY-NAME] cold-launch hydrate: source=%@, name=%@",
                  user.userSetDisplayName != nil ? "user-set" : "credential/email",
                  user.displayName)
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
        // memberSince is stable per-identifier: keep the earliest known
        // first-seen date. If nothing is cached and this is a brand-new
        // identifier, stamp now.
        let resolvedMemberSince = cached?.firstSeenAt
            ?? (isSameUser ? existing?.memberSince : nil)
            ?? .now

        NSLog("[Cadence-Auth] resolved identity: firstName=%@, email=%@, memberSince=%@",
              resolvedFirstName ?? "<nil>",
              resolvedEmail ?? "<nil>",
              "\(resolvedMemberSince)")

        // User-set name (Settings) overrides everything else. Hydrated from
        // UserDefaults keyed by identifier so different users on the same
        // device each get their own name.
        let userSetName = UserScopedPrefs.userDisplayName(for: identifier)

        let user = AuthenticatedUser(
            appleUserIdentifier: identifier,
            firstName: resolvedFirstName,
            lastName: resolvedLastName,
            email: resolvedEmail,
            iCloudUserRecordName: nil,
            memberSince: resolvedMemberSince,
            userSetDisplayName: userSetName
        )

        NSLog("[DISPLAY-NAME] sign-in resolved: source=%@, name=%@, initials=%@",
              displayNameSource(user: user),
              user.displayName,
              user.avatarInitials)

        // Always update the per-identifier cache — either Apple gave us
        // new name/email (first-sign-in payload) or we're stamping
        // firstSeenAt for the first time.
        writeNameCacheEntry(
            for: identifier,
            entry: NameCacheEntry(
                firstName: appleFirstName ?? cached?.firstName,
                lastName: appleLastName ?? cached?.lastName,
                email: appleEmail ?? cached?.email,
                firstSeenAt: cached?.firstSeenAt ?? resolvedMemberSince
            )
        )

        // "Returning" vs "new" — detected by whether the per-identifier name
        // cache already had a firstSeenAt BEFORE this sign-in. Drives the
        // welcome-splash copy ("Welcome back, X" vs "Welcome, X").
        let isReturning = (cached?.firstSeenAt != nil)
        lastSignInWasReturning = isReturning
        // First-run name prompt — only fires if NOTHING resolves to a real
        // name. Email-local-part counts as a real name (good enough default).
        needsNamePrompt = user.needsDisplayNameSetup
        NSLog("[DISPLAY-NAME] needsNamePrompt=%@, isReturning=%@",
              needsNamePrompt ? "true" : "false",
              isReturning ? "true" : "false")

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

    // MARK: Display name editing

    /// Persist a user-set display name and update the live in-memory state.
    /// Source of truth is UserDefaults via `UserScopedPrefs`, keyed per
    /// Apple identifier — different users on the same device each get
    /// their own. Pass nil/empty to clear (resolution falls back through
    /// Apple's fullName → email local-part → "Cadence User").
    func setDisplayName(_ newName: String?) {
        guard case .signedIn(var user) = state else {
            NSLog("[DISPLAY-NAME] setDisplayName called while signed out — ignoring")
            return
        }
        let trimmed = newName?.trimmingCharacters(in: .whitespaces)
        UserScopedPrefs.setUserDisplayName(trimmed, for: user.appleUserIdentifier)
        user.userSetDisplayName = trimmed
        persist(user)
        state = .signedIn(user)
        NSLog("[DISPLAY-NAME] set name to %@ for identifier %@",
              trimmed ?? "<cleared>",
              user.appleUserIdentifier)
    }

    /// For diagnostic logging — which branch of the resolution chain won.
    private func displayNameSource(user: AuthenticatedUser) -> String {
        if let userSet = user.userSetDisplayName, !userSet.isEmpty { return "user-set" }
        if (user.firstName.map { !$0.isEmpty } ?? false)
            || (user.lastName.map { !$0.isEmpty } ?? false) { return "apple-credential" }
        if let email = user.email, !email.isEmpty, !user.isUsingHiddenEmail {
            return "email-local-part"
        }
        return "fallback-cadence-user"
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
