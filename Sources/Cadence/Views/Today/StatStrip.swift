import SwiftUI

/// The three small stat cards just under the date header: Today / Events / Carried.
struct StatStrip: View {
    let todayCount: Int
    let eventsCount: Int
    let carriedCount: Int

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            StatCard(label: "TODAY", value: "\(todayCount)", suffix: todayCount == 1 ? "task" : "tasks", color: Tokens.Color.text)
            StatCard(label: "EVENTS", value: "\(eventsCount)", suffix: eventsCount == 1 ? "meeting" : "meetings", color: Tokens.Color.text)
            StatCard(label: "CARRIED", value: "\(carriedCount)", suffix: "over", color: carriedCount > 0 ? Tokens.Color.amber : Tokens.Color.text2)
        }
    }
}

private struct StatCard: View {
    let label: String
    let value: String
    let suffix: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Tokens.Color.text3)
                .kerning(0.8)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(color)
                Text(suffix)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Tokens.Color.text3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.md + 2)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
        )
    }
}
