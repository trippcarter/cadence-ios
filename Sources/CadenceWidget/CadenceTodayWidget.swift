import SwiftUI
import WidgetKit

/// One widget definition covering all six families (Home + Lock Screen).
/// `CadenceWidgetView` routes based on `@Environment(\.widgetFamily)`.
struct CadenceTodayWidget: Widget {
    let kind: String = "CadenceTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskTimelineProvider()) { entry in
            CadenceWidgetView(entry: entry)
        }
        .configurationDisplayName("Cadence — Today")
        .description("Tasks and the next thing on your day at a glance.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
        .contentMarginsDisabled()
    }
}

private struct CadenceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CadenceWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryCircular:
            CircularLockView(entry: entry)
        case .accessoryRectangular:
            RectangularLockView(entry: entry)
        case .accessoryInline:
            InlineLockView(entry: entry)
        default:
            EmptyView()
        }
    }
}
