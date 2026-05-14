import SwiftUI
import SwiftData

/// Small action sheet presented after the user swipes left → Snooze.
struct SnoozeSheet: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var customDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var showingCustomPicker: Bool = false

    var body: some View {
        ZStack {
            Tokens.Color.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                header
                VStack(spacing: Tokens.Space.sm) {
                    snoozeChip("Tonight", subtitle: "8 PM", date: tonight())
                    snoozeChip("Tomorrow", subtitle: "9 AM", date: tomorrow())
                    snoozeChip("This Weekend", subtitle: weekendLabel(), date: thisWeekend())
                    snoozeChip("Next Week", subtitle: "Mon 9 AM", date: nextMonday())
                    pickerChip
                }
                if showingCustomPicker {
                    customPicker
                }
                Spacer(minLength: 0)
            }
            .padding(Tokens.Space.lg)
        }
        .presentationDetents(showingCustomPicker ? [.large] : [.medium])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SNOOZE")
                .font(Tokens.Font.label)
                .kerning(1.2)
                .foregroundStyle(Tokens.Color.text3)
            Text(task.title)
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Color.text)
                .lineLimit(2)
        }
        .padding(.top, Tokens.Space.sm)
    }

    private func snoozeChip(_ title: String, subtitle: String, date: Date) -> some View {
        Button {
            apply(date: date)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    Text(subtitle)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
            }
            .padding(Tokens.Space.lg)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var pickerChip: some View {
        Button {
            withAnimation(Tokens.Motion.snappy) {
                showingCustomPicker.toggle()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pick a date")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    Text(customDate, format: .dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
                Image(systemName: showingCustomPicker ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
            }
            .padding(Tokens.Space.lg)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var customPicker: some View {
        VStack(spacing: Tokens.Space.md) {
            DatePicker("Snooze until", selection: $customDate)
                .datePickerStyle(.graphical)
                .tint(Tokens.Color.accent)
                .padding(.horizontal, Tokens.Space.sm)
            Button {
                apply(date: customDate)
            } label: {
                Text("Snooze")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Tokens.Space.md)
                    .background(
                        LinearGradient(
                            colors: [Tokens.Color.accent, Tokens.Color.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(Tokens.Space.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
        )
    }

    // MARK: Apply

    private func apply(date: Date) {
        Haptics.tap()
        withAnimation(Tokens.Motion.spring) {
            task.snoozeUntil = date
            task.status = .snoozed
        }
        try? modelContext.save()
        Task { await NotificationManager.shared.cancelReminders(forTaskID: task.id) }
        WidgetReloader.reload()
        dismiss()
    }

    // MARK: Quick-snooze date helpers

    private func tonight() -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 20, minute: 0, second: 0, of: .now) ?? .now
    }

    private func tomorrow() -> Date {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: 1, to: .now) ?? .now
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
    }

    /// Next Saturday at 9 AM. If today is Saturday, advances a week.
    private func thisWeekend() -> Date {
        let cal = Calendar.current
        var components = DateComponents()
        components.weekday = 7  // Saturday
        components.hour = 9
        components.minute = 0
        let next = cal.nextDate(after: .now, matching: components, matchingPolicy: .nextTime) ?? .now
        return next
    }

    private func weekendLabel() -> String {
        let date = thisWeekend()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE 'at' h a"
        return formatter.string(from: date)
    }

    private func nextMonday() -> Date {
        let cal = Calendar.current
        var components = DateComponents()
        components.weekday = 2  // Monday
        components.hour = 9
        components.minute = 0
        return cal.nextDate(after: .now, matching: components, matchingPolicy: .nextTime) ?? .now
    }
}
