import SwiftUI

/// The "you" avatar in the Today header. Shows the signed-in user's initials
/// in a violet-gradient circle. Tapping deep-links into the You tab.
///
/// Sizing: 30pt circle by default. If a shared-list co-owner identity
/// surfaces later (Phase 9 ongoing) we can stack a second avatar to the
/// right — the API supports it via the optional `coOwnerInitials`.
struct AvatarCluster: View {
    var size: CGFloat = 30
    var coOwnerInitials: String? = nil
    var onTap: () -> Void = {}

    @EnvironmentObject private var authSession: AuthSession

    var body: some View {
        Button {
            Haptics.tap()
            onTap()
        } label: {
            ZStack {
                primaryAvatar
                if let coOwnerInitials {
                    coOwnerAvatar(initials: coOwnerInitials)
                        .offset(x: size * 0.55)
                }
            }
            .frame(width: size + (coOwnerInitials != nil ? size * 0.55 : 0), height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens your profile")
    }

    private var primaryAvatar: some View {
        Text(initials)
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [Tokens.Color.accent, Tokens.Color.accentDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
            .overlay(Circle().stroke(Tokens.Color.bg, lineWidth: 1.5))
            .shadow(color: Tokens.Color.accentGlow, radius: 6, x: 0, y: 2)
    }

    private func coOwnerAvatar(initials: String) -> some View {
        Text(initials.uppercased().prefix(2))
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [Tokens.Color.amber, Tokens.Color.rose],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
            .overlay(Circle().stroke(Tokens.Color.bg, lineWidth: 1.5))
    }

    /// Falls back to first 1–2 chars of email if no name; "C" as final fallback.
    private var initials: String {
        if let user = authSession.state.user {
            return user.avatarInitials
        }
        return "C"
    }

    private var accessibilityLabel: String {
        if let user = authSession.state.user {
            return user.displayName
        }
        return "Not signed in"
    }
}
