import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @AppStorage(PrefsKey.dailyBriefHour)       private var briefHour: Int = 7
    @AppStorage(PrefsKey.dailyBriefMinute)     private var briefMinute: Int = 30
    @AppStorage(PrefsKey.rolloverPolicy)       private var rolloverRaw: String = RolloverPolicy.on.rawValue
    @AppStorage(PrefsKey.themeChoice)          private var themeRaw: String = ThemeChoice.dark.rawValue
    @AppStorage(PrefsKey.notificationsEnabled) private var notifsEnabled: Bool = true

    @State private var testFeedback: String?

    @EnvironmentObject private var notifications: NotificationManager
    @Environment(\.modelContext) private var modelContext

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

                section(title: "Connected accounts") {
                    ConnectedAccountsSection()
                }

                section(title: "Notifications") {
                    notificationsToggleRow
                    Divider().background(Tokens.Color.borderSoft)
                    notificationsStatusRow
                    Divider().background(Tokens.Color.borderSoft)
                    sendTestRow
                }

                section(title: "Daily brief") {
                    HStack {
                        rowLabel(icon: "sun.max", text: "Time of day")
                        Spacer()
                        DatePicker(
                            "",
                            selection: briefTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
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
            Task { await notifications.refreshAuthorizationStatus() }
        }
        .onChange(of: notifsEnabled) { _, newValue in
            Task {
                if newValue {
                    await notifications.rescheduleEverything(context: modelContext, requestIfNeeded: true)
                } else {
                    await notifications.cancelAll()
                }
            }
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

    // MARK: Daily brief binding

    /// DatePicker bound directly to the two @AppStorage components so its setter
    /// only fires on real user interaction — never on initial render.
    private var briefTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: briefHour, minute: briefMinute, second: 0, of: .now) ?? .now
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                briefHour = comps.hour ?? 7
                briefMinute = comps.minute ?? 30
                Task { await notifications.scheduleDailyBrief(context: modelContext) }
            }
        )
    }

    // MARK: Notifications rows

    private var notificationsToggleRow: some View {
        HStack {
            rowLabel(icon: "bell.fill", text: "Reminders enabled")
            Spacer()
            Toggle("", isOn: $notifsEnabled)
                .tint(Tokens.Color.accent)
                .labelsHidden()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var notificationsStatusRow: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    Text(statusSubtitle)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
            }
            if notifications.authorizationStatus == .denied {
                Button {
                    openAppSettings()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Open System Settings")
                            .font(Tokens.Font.chip)
                    }
                    .padding(.horizontal, Tokens.Space.md)
                    .padding(.vertical, 7)
                    .background(Tokens.Color.accent.opacity(0.18))
                    .foregroundStyle(Tokens.Color.accent2)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var sendTestRow: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                rowLabel(icon: "paperplane.fill", text: "Send a test")
                Spacer()
                Button {
                    Haptics.tap()
                    Task {
                        let ok = await notifications.sendTestInFiveSeconds()
                        testFeedback = ok ? "Test scheduled · arrives in 5 seconds" : "Couldn't schedule — check permission."
                    }
                } label: {
                    Text("Send")
                        .font(Tokens.Font.chip)
                        .padding(.horizontal, Tokens.Space.md)
                        .padding(.vertical, 7)
                        .background(Tokens.Color.accent.opacity(0.20))
                        .foregroundStyle(Tokens.Color.accent2)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!notifsEnabled)
            }
            if let testFeedback {
                Text(testFeedback)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var statusIcon: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "checkmark.seal.fill"
        case .denied: return "xmark.seal.fill"
        case .notDetermined: return "questionmark.circle"
        @unknown default: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return Tokens.Color.mint
        case .denied: return Tokens.Color.rose
        case .notDetermined: return Tokens.Color.text3
        @unknown default: return Tokens.Color.text3
        }
    }

    private var statusTitle: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "Notifications enabled"
        case .denied: return "Notifications blocked"
        case .notDetermined: return "Permission not granted yet"
        @unknown default: return "Unknown status"
        }
    }

    private var statusSubtitle: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Reminders, daily brief, and shared-list pings."
        case .denied:
            return "Enable in System Settings → Cadence."
        case .notDetermined:
            return "iOS will ask the first time a reminder is set."
        @unknown default:
            return ""
        }
    }

    #if canImport(UIKit)
    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    #else
    private func openAppSettings() {}
    #endif

    // MARK: App info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}
