import SwiftUI

/// Lets the user build a custom RecurrenceRule: pick frequency, interval,
/// specific weekdays (for weekly), day-of-month (for monthly), and an end
/// condition (none / by date / by count).
struct RecurrenceCustomSheet: View {
    @Binding var rule: RecurrenceRule
    @Environment(\.dismiss) private var dismiss

    /// Local copy so we can stage edits and apply on Save without bouncing
    /// the bound state on every micro-change.
    @State private var draft: RecurrenceRule

    @State private var endMode: EndMode = .never
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
    @State private var count: Int = 10

    enum EndMode: String, CaseIterable, Identifiable {
        case never, onDate, after
        var id: String { rawValue }
        var label: String {
            switch self {
            case .never:  return "Never"
            case .onDate: return "On date"
            case .after:  return "After N times"
            }
        }
    }

    init(rule: Binding<RecurrenceRule>) {
        self._rule = rule
        self._draft = State(initialValue: rule.wrappedValue)
        if let until = rule.wrappedValue.endDate {
            self._endMode = State(initialValue: .onDate)
            self._endDate = State(initialValue: until)
        } else if let cnt = rule.wrappedValue.count {
            self._endMode = State(initialValue: .after)
            self._count = State(initialValue: cnt)
        } else {
            self._endMode = State(initialValue: .never)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                        frequencyBlock
                        if draft.frequency == .weekly { weekdayBlock }
                        if draft.frequency == .monthly { monthDayBlock }
                        endsBlock
                        previewBlock
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle("Custom repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Tokens.Color.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Tokens.Color.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        switch endMode {
                        case .never:  draft.endDate = nil; draft.count = nil
                        case .onDate: draft.endDate = endDate; draft.count = nil
                        case .after:  draft.endDate = nil; draft.count = max(count, 1)
                        }
                        rule = draft
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Tokens.Color.accent2)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Frequency

    private var frequencyBlock: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            sectionLabel("FREQUENCY")
            HStack(spacing: 6) {
                ForEach(RecurrenceRule.Frequency.allCases, id: \.self) { freq in
                    let isSelected = draft.frequency == freq
                    Button {
                        Haptics.tap()
                        draft.frequency = freq
                        if freq != .weekly { draft.byDay = [] }
                        if freq != .monthly { draft.byMonthDay = nil }
                    } label: {
                        Text(label(for: freq))
                            .font(Tokens.Font.chip)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Tokens.Space.sm)
                            .background(isSelected ? Tokens.Color.accent.opacity(0.20) : Tokens.Color.surface2)
                            .foregroundStyle(isSelected ? Tokens.Color.accent2 : Tokens.Color.text2)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                                    .stroke(isSelected ? Tokens.Color.accent : Tokens.Color.borderSoft, lineWidth: isSelected ? 1 : 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Text("Every")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text2)
                Stepper(value: $draft.interval, in: 1...30) {
                    Text("\(draft.interval) \(intervalUnit)")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                        .monospacedDigit()
                }
                .tint(Tokens.Color.accent)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        }
    }

    private func label(for freq: RecurrenceRule.Frequency) -> String {
        switch freq {
        case .daily:   return "Day"
        case .weekly:  return "Week"
        case .monthly: return "Month"
        case .yearly:  return "Year"
        }
    }

    private var intervalUnit: String {
        switch draft.frequency {
        case .daily:   return draft.interval == 1 ? "day" : "days"
        case .weekly:  return draft.interval == 1 ? "week" : "weeks"
        case .monthly: return draft.interval == 1 ? "month" : "months"
        case .yearly:  return draft.interval == 1 ? "year" : "years"
        }
    }

    // MARK: Weekday picker (weekly mode)

    private var weekdayBlock: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            sectionLabel("ON")
            HStack(spacing: 6) {
                ForEach(RecurrenceRule.Weekday.allCases, id: \.self) { day in
                    let isSelected = draft.byDay.contains(day)
                    Button {
                        Haptics.tap()
                        if isSelected {
                            draft.byDay.removeAll { $0 == day }
                        } else {
                            draft.byDay.append(day)
                        }
                    } label: {
                        Text(day.shortName.prefix(1))
                            .font(Tokens.Font.bodyEmphasis)
                            .frame(width: 36, height: 36)
                            .background(isSelected ? Tokens.Color.accent.opacity(0.20) : Tokens.Color.surface2)
                            .foregroundStyle(isSelected ? Tokens.Color.accent2 : Tokens.Color.text2)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(isSelected ? Tokens.Color.accent : Tokens.Color.borderSoft, lineWidth: isSelected ? 1 : 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Day-of-month picker (monthly mode)

    private var monthDayBlock: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            sectionLabel("DAY OF MONTH")
            HStack {
                Toggle("", isOn: Binding(
                    get: { draft.byMonthDay != nil },
                    set: { draft.byMonthDay = $0 ? 15 : nil }
                ))
                .tint(Tokens.Color.accent)
                .labelsHidden()
                Text(draft.byMonthDay == nil ? "Inherit from due date" : "Specific day")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text)
                Spacer()
                if let day = draft.byMonthDay {
                    Stepper(value: Binding(
                        get: { day },
                        set: { draft.byMonthDay = $0 }
                    ), in: 1...31) {
                        Text("\(day)")
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(Tokens.Color.text)
                            .monospacedDigit()
                    }
                    .tint(Tokens.Color.accent)
                    .labelsHidden()
                }
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        }
    }

    // MARK: Ends block

    private var endsBlock: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            sectionLabel("ENDS")
            VStack(spacing: 0) {
                ForEach(EndMode.allCases) { mode in
                    Button {
                        Haptics.tap()
                        endMode = mode
                    } label: {
                        HStack {
                            Image(systemName: endMode == mode ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(endMode == mode ? Tokens.Color.accent : Tokens.Color.text3)
                            Text(mode.label)
                                .font(Tokens.Font.body)
                                .foregroundStyle(Tokens.Color.text)
                            Spacer()
                        }
                        .padding(.horizontal, Tokens.Space.lg)
                        .padding(.vertical, Tokens.Space.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if mode != EndMode.allCases.last {
                        Divider().background(Tokens.Color.borderSoft)
                    }
                }
                if endMode == .onDate {
                    Divider().background(Tokens.Color.borderSoft)
                    HStack {
                        Text("End date")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Color.text3)
                        Spacer()
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .labelsHidden()
                            .tint(Tokens.Color.accent)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                } else if endMode == .after {
                    Divider().background(Tokens.Color.borderSoft)
                    HStack {
                        Text("Occurrences")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Color.text3)
                        Spacer()
                        Stepper(value: $count, in: 1...500) {
                            Text("\(count)")
                                .font(Tokens.Font.bodyEmphasis)
                                .foregroundStyle(Tokens.Color.text)
                                .monospacedDigit()
                        }
                        .tint(Tokens.Color.accent)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                }
            }
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        }
    }

    // MARK: Preview

    private var previewBlock: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            sectionLabel("SUMMARY")
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "repeat.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.displayLabel)
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    if let until = endsLabel {
                        Text(until)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Color.text3)
                    }
                }
                Spacer()
            }
            .padding(Tokens.Space.lg)
            .background(Tokens.Color.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.accent.opacity(0.4), lineWidth: 0.5)
            )
        }
    }

    private var endsLabel: String? {
        switch endMode {
        case .never:  return nil
        case .onDate: return "Ends \(endDate.formatted(.dateTime.month(.wide).day().year()))"
        case .after:  return "Ends after \(count) occurrences"
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Tokens.Font.label)
            .kerning(0.8)
            .foregroundStyle(Tokens.Color.text3)
    }
}
