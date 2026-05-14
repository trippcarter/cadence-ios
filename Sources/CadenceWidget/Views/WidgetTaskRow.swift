import SwiftUI
import AppIntents

struct WidgetTaskRow: View {
    let task: WidgetTaskInfo

    var body: some View {
        HStack(spacing: 8) {
            // Interactive complete circle (iOS 17+). The button label IS the
            // circle; tapping it invokes the AppIntent without opening the app.
            Button(intent: CompleteTaskFromWidgetIntent(taskID: task.id.uuidString)) {
                ZStack {
                    Circle()
                        .strokeBorder(ListPalette.color(for: task.colorKey), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    if task.isCompleted {
                        Circle()
                            .fill(ListPalette.color(for: task.colorKey))
                            .frame(width: 16, height: 16)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(task.isCompleted ? Tokens.Color.text3 : Tokens.Color.text)
                .strikethrough(task.isCompleted, color: Tokens.Color.text3)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let time = task.timeText {
                Text(time)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
                    .monospacedDigit()
            } else if task.allDay {
                Text("all day")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
            }

            Circle()
                .fill(ListPalette.color(for: task.colorKey))
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
