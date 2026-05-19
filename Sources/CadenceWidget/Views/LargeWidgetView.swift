import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: CadenceWidgetEntry

    private var displayItems: [WidgetItem] {
        Array(entry.items.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            statStrip
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

            Divider().background(Tokens.Color.borderSoft).padding(.horizontal, 12)

            VStack(spacing: 1) {
                ForEach(displayItems) { item in
                    WidgetItemRow(item: item)
                    if item.id != displayItems.last?.id {
                        Divider().background(Tokens.Color.borderSoft).padding(.leading, 38)
                    }
                }
                if displayItems.isEmpty {
                    Spacer(minLength: 0)
                    Text("Nothing on your plate today")
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.Color.text3)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
            }
            .padding(.top, 4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            Tokens.Color.bg
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("CADENCE · TODAY")
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(Tokens.Color.text3)
            Text(entry.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Tokens.Color.text)
        }
    }

    private var statStrip: some View {
        HStack(spacing: 8) {
            statCard("TASKS", value: "\(entry.openTaskCount)", color: Tokens.Color.text)
            statCard("EVENTS", value: "\(entry.eventsCount)",
                     color: entry.eventsCount > 0 ? Tokens.Color.teal : Tokens.Color.text2)
            statCard("CARRIED", value: "\(entry.carriedCount)",
                     color: entry.carriedCount > 0 ? Tokens.Color.amber : Tokens.Color.text2)
        }
    }

    private func statCard(_ label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(Tokens.Color.text3)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
        )
    }
}
