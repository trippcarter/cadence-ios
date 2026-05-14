import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: CadenceWidgetEntry

    private var openCount: Int {
        entry.todaysTasks.filter { !$0.isCompleted }.count
    }

    private var nextTask: WidgetTaskInfo? {
        entry.todaysTasks.first(where: { !$0.isCompleted })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Big number block
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(openCount)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.Color.text)
                Text("today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
                    .kerning(0.6)
                    .padding(.bottom, 6)
            }

            Text(openCount == 1 ? "task" : "tasks")
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(Tokens.Color.accent2)
                .padding(.top, -4)

            Spacer(minLength: 0)

            if let next = nextTask {
                VStack(alignment: .leading, spacing: 1) {
                    Text("NEXT")
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(0.8)
                        .foregroundStyle(Tokens.Color.text3)
                    HStack(spacing: 4) {
                        if let time = next.timeText {
                            Text(time)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Tokens.Color.accent2)
                        }
                        Spacer(minLength: 0)
                    }
                    Text(next.title)
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
}
