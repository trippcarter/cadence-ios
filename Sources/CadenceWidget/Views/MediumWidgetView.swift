import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: CadenceWidgetEntry

    private var displayItems: [WidgetItem] {
        Array(entry.items.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)
            Divider()
                .background(Tokens.Color.borderSoft)
                .padding(.horizontal, 12)
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text("CADENCE · TODAY")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(Tokens.Color.text3)
                Text(entry.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Tokens.Color.text)
            }
            Spacer()
            // Count badge — tasks + events combined.
            HStack(spacing: 4) {
                Text("\(entry.openTaskCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.Color.accent2)
                if entry.eventsCount > 0 {
                    Text("·")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.Color.text3)
                    Text("\(entry.eventsCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Tokens.Color.teal)
                }
            }
        }
    }
}
