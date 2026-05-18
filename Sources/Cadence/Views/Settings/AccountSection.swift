import SwiftUI

/// Settings → Account row. Shows the signed-in user's name + email and
/// offers a destructive Sign Out action with confirmation alert.
///
/// Per Phase 8 spec: signing out is LOCAL only. CloudKit-synced data
/// (tasks, lists, etc.) lives in the user's iCloud Private DB and stays
/// intact across sign-out / sign-in cycles. Signing back in with the
/// same Apple ID will surface the same data.
///
/// Phase 9 additions:
///   - "Backed by iCloud: <name>" diagnostic so account mismatch is obvious
///   - "Switch Apple ID" destructive action that signs out AND re-presents
///     Apple's reauth sheet for a different identity
struct AccountSection: View {
    @EnvironmentObject private var authSession: AuthSession
    @EnvironmentObject private var cloudSync: CloudKitSyncManager
    @State private var showingSignOutConfirm = false
    @State private var showingSwitchConfirm = false
    @State private var showingDisplayNameEdit = false

    private var user: AuthenticatedUser? {
        authSession.state.user
    }

    var body: some View {
        VStack(spacing: 0) {
            displayNameRow
            Divider().background(Tokens.Color.borderSoft)
            accountRow
            Divider().background(Tokens.Color.borderSoft)
            iCloudDiagnosticRow
            Divider().background(Tokens.Color.borderSoft)
            signOutRow
            Divider().background(Tokens.Color.borderSoft)
            switchAccountRow
        }
        .sheet(isPresented: $showingDisplayNameEdit) {
            DisplayNameEditSheet(mode: .edit)
        }
        .alert("Sign out of Cadence?", isPresented: $showingSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                Haptics.warning()
                authSession.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your tasks stay safely in iCloud. Sign back in any time with the same Apple ID to restore them.")
        }
        .alert("Switch to a different Apple ID?", isPresented: $showingSwitchConfirm) {
            Button("Switch", role: .destructive) {
                Haptics.warning()
                authSession.switchAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll sign out of this account and Apple will ask you which Apple ID to use next. Your existing tasks stay in iCloud and reappear when you sign back in with this account.")
        }
    }

    /// Build 11: editable display name lives at the top of the Account
    /// section. Source of truth is UserDefaults via `UserScopedPrefs`,
    /// keyed per Apple identifier (different users on this device each
    /// get their own).
    private var displayNameRow: some View {
        Button {
            showingDisplayNameEdit = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Display Name")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    Text(user?.displayName ?? "Sign in to set")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(user == nil)
    }

    private var accountRow: some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Tokens.Color.indigo, Tokens.Color.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                Image(systemName: "applelogo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(user?.displayName ?? "Not signed in")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text(emailLabel)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var emailLabel: String {
        guard let user else { return "Sign in with Apple to enable sync" }
        if user.isUsingHiddenEmail { return "Private email (\(user.email ?? ""))" }
        if let email = user.email, !email.isEmpty { return email }
        return "Signed in with Apple ID"
    }

    /// Surfaces which iCloud account is backing the SwiftData/CloudKit store.
    /// If this diverges from the Apple Sign-In user shown above, something
    /// is off and we should investigate — but AuthSession.refreshCredentialState
    /// will normally force a sign-out before the user ever sees a mismatch.
    private var iCloudDiagnosticRow: some View {
        HStack(spacing: 8) {
            Image(systemName: iCloudIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iCloudColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("Backed by iCloud")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text(iCloudStatusLine)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var iCloudIcon: String {
        switch cloudSync.accountStatus {
        case .available:           return "icloud.fill"
        case .noAccount:           return "icloud.slash.fill"
        case .restricted:          return "icloud.slash.fill"
        case .temporarilyUnavailable: return "icloud.fill"
        case .couldNotDetermine:   return "icloud"
        @unknown default:          return "icloud"
        }
    }

    private var iCloudColor: Color {
        switch cloudSync.accountStatus {
        case .available:    return Tokens.Color.mint
        case .noAccount:    return Tokens.Color.rose
        case .restricted:   return Tokens.Color.rose
        case .temporarilyUnavailable: return Tokens.Color.amber
        case .couldNotDetermine: return Tokens.Color.text3
        @unknown default:   return Tokens.Color.text3
        }
    }

    private var iCloudStatusLine: String {
        switch cloudSync.accountStatus {
        case .available:
            if let email = cloudSync.userEmail, !email.isEmpty {
                return email
            }
            return "iCloud signed in"
        case .noAccount:
            return "No iCloud signed in — tasks won't sync"
        case .restricted:
            return "iCloud access restricted on this device"
        case .temporarilyUnavailable:
            return "iCloud temporarily unavailable"
        case .couldNotDetermine:
            return "Checking iCloud…"
        @unknown default:
            return cloudSync.accountStatus.displayLabel
        }
    }

    private var signOutRow: some View {
        Button {
            showingSignOutConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.rose)
                    .frame(width: 18)
                Text("Sign Out")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.rose)
                Spacer()
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(user == nil)
    }

    private var switchAccountRow: some View {
        Button {
            showingSwitchConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Switch Apple ID")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.accent2)
                    Text("Sign out and choose a different Apple ID.")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(user == nil)
    }
}
