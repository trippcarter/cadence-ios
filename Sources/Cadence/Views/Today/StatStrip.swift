import SwiftUI

/// Build 13 refresh: three stat cards under the greeting header — Today /
/// Events / Carried. Larger SF Rounded numbers, subtle linear gradient in
/// the card background, and a glow ring on the card with the highest count
/// (the "active" stat).
struct StatStrip: View {
    let todayCount: Int
    let eventsCount: Int
    let carriedCount: Int

    /// Which card to highlight with a subtle accent glow.
    private var activeIndex: Int? {
        let counts = [todayCount, eventsCount, carriedCount]
        let maxValue = counts.max() ?? 0
        guard maxValue > 0 else { return nil }
        return counts.firstIndex(of: maxValue)
    }

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            StatCard(
                label: "TODAY",
                value: todayCount,
                suffix: todayCount == 1 ? "task" : "tasks",
                accent: Tokens.Color.accent,
                isActive: activeIndex == 0
            )
            StatCard(
                label: "EVENTS",
                value: eventsCount,
                suffix: eventsCount == 1 ? "meeting" : "meetings",
                accent: Tokens.Color.teal,
                isActive: activeIndex == 1
            )
            StatCard(
                label: "CARRIED",
                value: carriedCount,
                suffix: "over",
                accent: Tokens.Color.amber,
                isActive: activeIndex == 2
            )
        }
    }
}

private struct StatCard: View {
    let label: String
    let value: Int
    let suffix: String
    let accent: Color
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isActive ? accent : Tokens.Color.text3)
                .kerning(1.0)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(value)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.Color.text)
                    .monospacedDigit()
                Text(suffix)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Tokens.Color.text3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Tokens.Space.md + 2)
        .padding(.vertical, Tokens.Space.md + 4)
        .background(
            LinearGradient(
                colors: [Tokens.Color.surface, Tokens.Color.surface2],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .stroke(isActive ? accent.opacity(0.45) : Tokens.Color.borderSoft,
                        lineWidth: isActive ? 1 : 0.5)
        )
        .shadow(color: isActive ? accent.opacity(0.18) : .clear, radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(suffix) \(label.lowercased())")
    }
}
