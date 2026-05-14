import SwiftUI

/// Two overlapping circular avatars used in the Today header. Placeholder gradients
/// for now — real CKShare participant photos come in Phase 4.
struct AvatarCluster: View {
    var body: some View {
        ZStack {
            avatar(
                initials: "TC",
                gradient: [Tokens.Color.indigo, Tokens.Color.accent]
            )
            .offset(x: -10)
            avatar(
                initials: "BC",
                gradient: [Tokens.Color.amber, Tokens.Color.rose]
            )
            .offset(x: 10)
        }
        .frame(width: 56, height: 30)
    }

    private func avatar(initials: String, gradient: [Color]) -> some View {
        Text(initials)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
            .overlay(Circle().stroke(Tokens.Color.bg, lineWidth: 1.5))
    }
}
