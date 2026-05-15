import Foundation
import SwiftUI
import AuthenticationServices

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

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        if let email, !email.isEmpty { return email }
        // Fall back to a truncated identifier so the user sees *something*.
        return "Signed in (\(appleUserIdentifier.prefix(8))…)"
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

    /// Keychain account name we store the AuthenticatedUser JSON blob under.
    /// Re-uses the existing KeychainStore from Phase 3 (with its file
    /// fallback for unsigned simulator builds).
    private static let keychainAccount = "AppleSignInUser"

    @Published private(set) var state: State = .signedOut

    /// True briefly after a fresh sign-in so RootView can present the
    /// "Welcome, <name>" splash. Auto-clears after ~1.5s.
    @Published var showWelcomeSplash: Bool = false

    private init() {
        if let user = loadFromKeychain() {
            self.state = .signedIn(user)
        }
    }

    // MARK: Sign in

    /// Called from the SignInWithAppleButton's onCompletion handler when
    /// Apple returns a successful credential.
    func handleAppleAuthorization(_ credential: ASAuthorizationAppleIDCredential) {
        let identifier = credential.user
        let firstName = credential.fullName?.givenName
        let lastName = credential.fullName?.familyName
        let email = credential.email

        // If we have a stored user, merge in new info. Apple only sends
        // fullName + email on the FIRST sign-in; later signs only return
        // the identifier. Don't clobber stored display info with nils.
        var user = state.user ?? AuthenticatedUser(
            appleUserIdentifier: identifier,
            firstName: nil,
            lastName: nil,
            email: nil
        )
        user = AuthenticatedUser(
            appleUserIdentifier: identifier,
            firstName: firstName ?? user.firstName,
            lastName: lastName ?? user.lastName,
            email: email ?? user.email
        )

        persist(user)
        // Animate the state change so RootView's content transition runs.
        withAnimation(.smooth(duration: 0.45)) {
            state = .signedIn(user)
        }
        // Trigger the welcome splash overlay (RootView clears it on its own timer).
        showWelcomeSplash = true
    }

    // MARK: Sign out

    func signOut() {
        KeychainStore.delete(account: AuthSession.keychainAccount)
        withAnimation(.smooth(duration: 0.45)) {
            state = .signedOut
        }
    }

    // MARK: Credential refresh
    //
    // Apple lets the user revoke an app's access from Settings → Apple ID
    // → Sign-In with Apple. When that happens, getCredentialState reports
    // .revoked and we should sign the user out locally.
    //
    // Network is required; on offline launches we trust the Keychain blob.

    func refreshCredentialState() async {
        guard case .signedIn(let user) = state else { return }
        let provider = ASAuthorizationAppleIDProvider()
        do {
            let credentialState = try await provider.credentialState(forUserID: user.appleUserIdentifier)
            switch credentialState {
            case .authorized:
                // All good — nothing to do.
                return
            case .revoked, .notFound, .transferred:
                NSLog("[Cadence-Auth] credential state=%d, signing out", credentialState.rawValue)
                signOut()
            @unknown default:
                return
            }
        } catch {
            // Network failure / Apple servers down — keep the user signed in.
            // The next refresh after network returns will catch revocation.
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
}
