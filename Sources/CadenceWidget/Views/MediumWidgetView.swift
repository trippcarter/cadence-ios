import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: CadenceWidgetEntry

    private var openTasks: [WidgetTaskInfo] {
        entry.todaysTasks.filter { !$0.isCompleted }
    }
    private var displayTasks: [WidgetTaskInfo] {
        Array(openTasks.prefix(4))
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
                ForEach(displayTasks) { task in
                    WidgetTaskRow(task: task)
                    if task.id != displayTasks.last?.id {
                        Divider().background(Tokens.Color.borderSoft).padding(.leading, 38)
                    }
                }
                if displayTasks.isEmpty {
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
            Text("\(openTasks.count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Tokens.Color.accent2)
        }
    }
}
