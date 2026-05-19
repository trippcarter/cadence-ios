import SwiftUI
import WidgetKit

// MARK: Circular — gauge-style task count

struct CircularLockView: View {
    let entry: CadenceWidgetEntry

    private var count: Int { entry.openTaskCount }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Text("\(count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(count == 1 ? "task" : "tasks")
                    .font(.system(size: 9, weight: .semibold))
                    .opacity(0.7)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetAccentable()
    }
}

// MARK: Rectangular — next-task or next-event summary

struct RectangularLockView: View {
    let entry: CadenceWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("CADENCE · NEXT")
                .font(.system(size: 9, weight: .semibold))
                .kerning(0.6)
                .opacity(0.7)
            if let next = entry.nextItem {
                if let time = nextTime(next) {
                    Text(time)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .widgetAccentable()
                }
                Text(nextTitle(next))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
            } else {
                Text("Nothing on your plate")
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }

    private func nextTime(_ item: WidgetItem) -> String? {
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

// MARK: Inline — one-line summary

struct InlineLockView: View {
    let entry: CadenceWidgetEntry

    var body: some View {
        if let next = entry.nextItem {
            let label = title(next)
            if let time = time(next) {
                Text("⏵ \(entry.openTaskCount) tasks · next \(time) \(label)")
            } else {
                Text("⏵ \(entry.openTaskCount) tasks · next: \(label)")
            }
        } else if entry.openTaskCount > 0 {
            Text("⏵ \(entry.openTaskCount) tasks today")
        } else {
            Text("⏵ Nothing on your plate today")
        }
    }

    private func time(_ item: WidgetItem) -> String? {
        switch item {
        case .task(let t):  return t.timeText
        case .event(let e): return e.timeText
        }
    }

    private func title(_ item: WidgetItem) -> String {
        switch item {
        case .task(let t):  return t.title
        case .event(let e): return e.title
        }
    }
}
