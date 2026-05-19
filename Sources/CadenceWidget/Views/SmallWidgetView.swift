import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: CadenceWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Big number block — combined task count (today + carried).
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(entry.openTaskCount)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.Color.text)
                Text("today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
                    .kerning(0.6)
                    .padding(.bottom, 6)
            }

            HStack(spacing: 4) {
                Text(entry.openTaskCount == 1 ? "task" : "tasks")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(Tokens.Color.accent2)
                if entry.carriedCount > 0 {
                    Text("· \(entry.carriedCount) carried")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Tokens.Color.amber)
                }
                if entry.eventsCount > 0 {
                    Text("· \(entry.eventsCount) events")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Tokens.Color.teal)
                }
            }
            .padding(.top, -4)

            Spacer(minLength: 0)

            if let next = entry.nextItem {
                VStack(alignment: .leading, spacing: 1) {
                    Text("NEXT")
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(0.8)
                        .foregroundStyle(Tokens.Color.text3)
                    HStack(spacing: 4) {
                        if let time = nextTimeText(next) {
                            Text(time)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Tokens.Color.accent2)
                        }
                        Spacer(minLength: 0)
                    }
                    Text(nextTitle(next))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Tokens.Color.text2)
                        .lineLimit(2)
                }
            } else {
                Text("Nothing on your plate")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Tokens.Color.text3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Tokens.Color.bg
        }
    }

    private func nextTimeText(_ item: WidgetItem) -> String? {
        switch item {
        case .task(let t):  return t.timeText
        case .event(let e): return e.timeText
        }
    }

    private func nextTitle(_ item: WidgetItem) -> String {
        switch item {
        case .task(let t):  return t.title
        case .event(let e): return e.title
        }
    }
}
