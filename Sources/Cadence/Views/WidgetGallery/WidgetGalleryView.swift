import SwiftUI
import SwiftData
import WidgetKit

/// Hidden screen the screenshot pipeline mounts when launched with
/// `--widget-preview=...`. Renders the actual widget SwiftUI views at their
/// stock WidgetKit point sizes against a dark, faux-home-screen backdrop —
/// so the resulting PNG matches what a real iOS Home Screen would show.
struct WidgetGalleryView: View {
    let preview: String
    @Query private var allTasks: [TaskItem]

    var body: some View {
        ZStack {
            // Subtle radial gradient roughly matching iOS Home Screen wallpaper.
            RadialGradient(
                colors: [Color(hex: 0x1B1338), Color(hex: 0x05060B)],
                center: .top,
                startRadius: 40,
                endRadius: 700
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 30)
                switch preview {
                case "small":
                    widgetFrame(size: CGSize(width: 158, height: 158)) {
                        SmallWidgetView(entry: liveEntry)
                    }
                case "medium":
                    widgetFrame(size: CGSize(width: 338, height: 158)) {
                        MediumWidgetView(entry: liveEntry)
                    }
                case "large":
                    widgetFrame(size: CGSize(width: 338, height: 354)) {
                        LargeWidgetView(entry: liveEntry)
                    }
                case "lockall":
                    lockGroup
                default:
                    Text("Unknown --widget-preview value: \(preview)")
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 30)
                caption
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: Lock-screen group

    private var lockGroup: some View {
        VStack(spacing: 22) {
            // Mimic the lock-screen white tint for legibility.
            VStack(spacing: 4) {
                Text("Lock Screen")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .kerning(0.8)
                Text("3:14")
                    .font(.system(size: 76, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)
            }

            HStack(spacing: 14) {
                widgetFrame(size: CGSize(width: 76, height: 76), accessory: true) {
                    CircularLockView(entry: liveEntry)
                }
                widgetFrame(size: CGSize(width: 168, height: 76), accessory: true) {
                    RectangularLockView(entry: liveEntry)
                }
            }
            .foregroundStyle(.white)

            // Inline rendered approximately how iOS places it (above the clock area).
            HStack {
                InlineLockView(entry: liveEntry)
                    .foregroundStyle(.white.opacity(0.9))
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.top, 6)
        }
    }

    private func widgetFrame<Content: View>(size: CGSize, accessory: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: size.width, height: size.height)
            // containerBackground only paints in a real WidgetKit context, so
            // apply Cadence's dark surface explicitly here for the gallery.
            .background(accessory ? Color.white.opacity(0.18) : Tokens.Color.bg)
            .clipShape(RoundedRectangle(cornerRadius: accessory ? 24 : 22, style: .continuous))
    }

    private var caption: some View {
        Text(captionText)
            .font(.system(size: 11, weight: .semibold))
            .kerning(1.0)
            .foregroundStyle(.white.opacity(0.5))
    }

    private var captionText: String {
        switch preview {
        case "small": return "SMALL · 158 × 158"
        case "medium": return "MEDIUM · 338 × 158"
        case "large": return "LARGE · 338 × 354"
        case "lockall": return "LOCK SCREEN ACCESSORIES"
        default: return preview.uppercased()
        }
    }

    // MARK: Live data → WidgetEntry

    /// Builds a CadenceWidgetEntry from the actual SwiftData store, so the
    /// preview reflects current seed/test data 1:1 with what the real widget
    /// would show.
    private var liveEntry: CadenceWidgetEntry {
        let cal = Calendar.current
        let todays = allTasks.filter { task in
            guard task.parent == nil, let due = task.dueDate else { return false }
            return cal.isDate(due, inSameDayAs: .now)
        }
        let carried = allTasks.filter { task in
            task.parent == nil && task.status == .open && {
                guard let due = task.dueDate else { return false }
                return cal.startOfDay(for: due) < cal.startOfDay(for: .now)
            }()
        }
        let sorted = todays.sorted { lhs, rhs in
            if lhs.status == .completed && rhs.status != .completed { return false }
            if lhs.status != .completed && rhs.status == .completed { return true }
            if lhs.allDay != rhs.allDay { return !lhs.allDay }
            return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
        }
        let startOfToday = cal.startOfDay(for: .now)
        let projected: [WidgetItem] = sorted.map { t in
            .task(WidgetTaskInfo(
                id: t.id,
                title: t.title,
                dueDate: t.dueDate,
                allDay: t.allDay,
                colorKey: t.list?.colorKey ?? "violet",
                listName: t.list?.name ?? "Inbox",
                isCompleted: t.status == .completed,
                isCarriedOver: (t.dueDate.map { $0 < startOfToday }) ?? false
            ))
        }
        return CadenceWidgetEntry(
            date: .now,
            items: projected,
            openTaskCount: sorted.filter { $0.status != .completed }.count,
            carriedCount: carried.count,
            eventsCount: 0,
            nextItem: projected.first
        )
    }
}

