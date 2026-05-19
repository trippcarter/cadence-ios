import SwiftUI

/// Compact avatar bubble for a HouseholdMembership. Reused on task rows
/// (small "who owns this" chip), in the assignment picker (medium with
/// name), and in the household section header (cluster of 3+).
struct AssigneeAvatar: View {
    let initial: String
    let colorKey: String
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [ListPalette.color(for: colorKey), ListPalette.color(for: colorKey).opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            Text(initial)
                .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .overlay(Circle().stroke(Tokens.Color.bg, lineWidth: 1))
    }
}
