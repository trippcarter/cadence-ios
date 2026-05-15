import SwiftUI

/// Settings → Account row. Shows the signed-in user's name + email and
/// offers a destructive Sign Out action with confirmation alert.
///
/// Per Phase 8 spec: signing out is LOCAL only. CloudKit-synced data
/// (tasks, lists, etc.) lives in the user's iCloud Private DB and stays
/// intact across sign-out / sign-in cycles. Signing back in with the
/// same Apple ID will surface the same data.
struct AccountSection: View {
    @EnvironmentObject private var authSession: AuthSession
    @State private var showingSignOutConfirm = false

    private var user: AuthenticatedUser? {
        authSession.state.user
    }

    var body: some View {
        VStack(spacing: 0) {
            accountRow
            Divider().background(Tokens.Color.borderSoft)
            signOutRow
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
}
