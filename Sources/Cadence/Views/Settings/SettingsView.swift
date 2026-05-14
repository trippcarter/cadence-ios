import SwiftUI

struct SettingsView: View {
    @AppStorage(PrefsKey.dailyBriefHour)   private var briefHour: Int = 7
    @AppStorage(PrefsKey.dailyBriefMinute) private var briefMinute: Int = 30
    @AppStorage(PrefsKey.rolloverPolicy)   private var rolloverRaw: String = RolloverPolicy.on.rawValue
    @AppStorage(PrefsKey.themeChoice)      private var themeRaw: String = ThemeChoice.dark.rawValue

    @State private var briefTime: Date = .now

    var body: some View {
        ZStack {
            Tokens.Color.bg.ignoresSafeArea()

            List {
                Section {
                    profileCard
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Tokens.Space.lg, leading: Tokens.Space.lg, bottom: Tokens.Space.sm, trailing: Tokens.Space.lg))
                }

                section(title: "About") {
                    rowKeyValue("Version", value: appVersion)
                    Divider().background(Tokens.Color.borderSoft)
                    rowKeyValue("Build", value: buildNumber)
                }

                section(title: "Daily brief") {
                    HStack {
                        rowLabel(icon: "sun.max", text: "Time of day")
                        Spacer()
                        DatePicker("", selection: $briefTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(Tokens.Color.accent)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                }

                section(title: "Default rollover policy") {
                    ForEach(RolloverPolicy.allCases, id: \.self) { policy in
                        Button {
                            Haptics.tap()
                            rolloverRaw = policy.rawValue
                        } label: {
                            HStack(alignment: .top, spacing: Tokens.Space.md) {
                                Image(systemName: rolloverRaw == policy.rawValue ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(rolloverRaw == policy.rawValue ? Tokens.Color.accent : Tokens.Color.text3)
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(policy.displayName)
                                        .font(Tokens.Font.bodyEmphasis)
                                        .foregroundStyle(Tokens.Color.text)
                                    Text(policy.subtitle)
                                        .font(Tokens.Font.caption)
                                        .foregroundStyle(Tokens.Color.text3)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, Tokens.Space.lg)
                            .padding(.vertical, Tokens.Space.md)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if policy != RolloverPolicy.allCases.last {
                            Divider().background(Tokens.Color.borderSoft)
                        }
                    }
                }

                section(title: "Theme") {
                    HStack(spacing: Tokens.Space.sm) {
                        ForEach(ThemeChoice.allCases) { choice in
                            themeChip(choice)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                }

                Section {
                    Text("Made with care · Cadence v\(appVersion)")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Tokens.Space.xl)
                        .padding(.bottom, 120)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
        }
        .onAppear {
            briefTime = Calendar.current.date(bySettingHour: briefHour, minute: briefMinute, second: 0, of: .now) ?? .now
        }
        .onChange(of: briefTime) { _, newValue in
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            briefHour = comps.hour ?? 7
            briefMinute = comps.minute ?? 30
        }
    }

    // MARK: Components

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Tokens.Color.indigo, Tokens.Color.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    Text("TC")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tripp Carter")
                        .font(Tokens.Font.title)
                        .foregroundStyle(Tokens.Color.text)
                    Text("tripp@mcinnis.net")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
            }
        }
    }

    private func themeChip(_ choice: ThemeChoice) -> some View {
        let isSelected = themeRaw == choice.rawValue
        return Button {
            Haptics.tap()
            themeRaw = choice.rawValue
        } label: {
            Text(choice.displayName)
                .font(Tokens.Font.bodyEmphasis)
                .padding(.vertical, Tokens.Space.sm)
                .frame(maxWidth: .infinity)
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

    // MARK: Section helper

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        Section {
            VStack(spacing: 0) {
                content()
            }
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: Tokens.Space.lg, bottom: Tokens.Space.sm, trailing: Tokens.Space.lg))
        } header: {
            GroupHeader(title: title, count: 0, accent: Tokens.Color.text3, trailingLabel: "")
                .textCase(nil)
        }
        .listSectionSeparator(.hidden)
    }

    private func rowLabel(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.Color.text3)
                .frame(width: 18)
            Text(text)
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text)
        }
    }

    private func rowKeyValue(_ key: String, value: String) -> some View {
        HStack {
            rowLabel(icon: "info.circle", text: key)
            Spacer()
            Text(value)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text2)
                .monospacedDigit()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    // MARK: App info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}
