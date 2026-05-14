import SwiftUI

/// Displays a Google Calendar event in the Today timeline. Visually distinct
/// from TaskRow: teal rail on the left, calendar icon, no complete circle.
struct EventRow: View {
    let event: CachedEvent
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                Rectangle()
                    .fill(Tokens.Color.teal)
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(Tokens.Font.taskTitle)
                        .foregroundStyle(Tokens.Color.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    meta
                }
                Spacer(minLength: 0)
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Color.teal.opacity(0.7))
            }
            .padding(.vertical, Tokens.Space.md)
            .padding(.horizontal, Tokens.Space.lg)
            .background(
                LinearGradient(
                    colors: [Tokens.Color.teal.opacity(0.08), Tokens.Color.surface],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.teal.opacity(0.18), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double-tap to view event details")
    }

    @ViewBuilder
    private var meta: some View {
        HStack(spacing: 6) {
            if event.isAllDay {
                Text("ALL DAY")
                    .font(Tokens.Font.chip)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Tokens.Color.teal.opacity(0.14))
                    .foregroundStyle(Tokens.Color.teal)
                    .clipShape(Capsule())
            } else {
                Text(timeRange)
                    .font(Tokens.Font.chip)
                    .foregroundStyle(Tokens.Color.teal)
            }
            if let location = event.location, !location.isEmpty {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
                Text(location)
                    .font(Tokens.Font.chip)
                    .foregroundStyle(Tokens.Color.text3)
                    .lineLimit(1)
            }
        }
    }

    private var timeRange: String {
        let start = event.start.formatted(.dateTime.hour().minute())
        let end = event.end.formatted(.dateTime.hour().minute())
        return "\(start) – \(end)"
    }

    private var accessibilityLabel: String {
        var parts: [String] = ["Event: \(event.title)"]
        if event.isAllDay {
            parts.append("all day")
        } else {
            parts.append("from \(event.start.formatted(.dateTime.hour().minute())) to \(event.end.formatted(.dateTime.hour().minute()))")
        }
        if let location = event.location, !location.isEmpty {
            parts.append("at \(location)")
        }
        return parts.joined(separator: ", ")
    }
}
