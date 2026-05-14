import SwiftUI

/// A section heading like "TODAY · 4 tasks" with an optional accent dot.
struct GroupHeader: View {
    let title: String
    let count: Int
    var accent: Color = Tokens.Color.text3
    var trailingLabel: String? = nil

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            HStack(spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(Tokens.Font.label)
                    .foregroundStyle(Tokens.Color.text3)
                    .textCase(.uppercase)
                    .kerning(0.6)
            }
            if let trailingLabel {
                Text("· \(trailingLabel)")
                    .font(Tokens.Font.label)
                    .foregroundStyle(Tokens.Color.text3)
                    .textCase(.uppercase)
            } else {
                Text("· \(count) \(count == 1 ? "task" : "tasks")")
                    .font(Tokens.Font.label)
                    .foregroundStyle(Tokens.Color.text3)
                    .textCase(.uppercase)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.lg)
    }
}
