import SwiftUI
import UserNotifications

/// Build 31: developer screen that surfaces the full state of the
/// notification subsystem — authorization, per-channel settings,
/// pending requests, recently delivered notifications — plus a
/// 30-second test button. Reached from Settings → Developer.
struct NotificationDiagnosticsView: View {
    @EnvironmentObject private var notifications: NotificationManager

    @State private var report: NotificationDiagnosticsReport?
    @State private var loading = true
    @State private var testFeedback: String?

    @AppStorage(PrefsKey.quietHoursEnabled)     private var quietHoursEnabled: Bool = false
    @AppStorage(PrefsKey.quietHoursStartHour)   private var quietStartHour: Int = 22
    @AppStorage(PrefsKey.quietHoursStartMinute) private var quietStartMinute: Int = 0
    @AppStorage(PrefsKey.quietHoursEndHour)     private var quietEndHour: Int = 7
    @AppStorage(PrefsKey.quietHoursEndMinute)   private var quietEndMinute: Int = 0

    var body: some View {
        SubscreenScaffold(title: "Notification Diagnostics") {
            if loading {
                ProgressView()
                    .padding(.top, Tokens.Space.xxl)
            } else if let report {
                authCard(report)
                settingsCard(report)
                quietHoursCard
                testCard
                pendingCard(report)
                deliveredCard(report)
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        loading = true
        report = await notifications.diagnosticsSnapshot()
        loading = false
    }

    // MARK: Cards

    private func authCard(_ r: NotificationDiagnosticsReport) -> some View {
        SubscreenCard {
            VStack(alignment: .leading, spacing: 6) {
                diagRow("Authorization", authText(r.authorizationStatus),
                        ok: r.authorizationStatus == .authorized || r.authorizationStatus == .provisional)
            }
            .padding(Tokens.Space.lg)
        }
    }

    private func settingsCard(_ r: NotificationDiagnosticsReport) -> some View {
        SubscreenCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("CHANNELS")
                    .font(Tokens.Font.label).kerning(0.8)
                    .foregroundStyle(Tokens.Color.text3)
                diagRow("Alerts", settingText(r.alertSetting), ok: r.alertSetting == .enabled)
                diagRow("Sound", settingText(r.soundSetting), ok: r.soundSetting == .enabled)
                diagRow("Badge", settingText(r.badgeSetting), ok: r.badgeSetting == .enabled)
                diagRow("Lock Screen", settingText(r.lockScreenSetting), ok: r.lockScreenSetting == .enabled)
                diagRow("Notification Center", settingText(r.notificationCenterSetting), ok: r.notificationCenterSetting == .enabled)
            }
            .padding(Tokens.Space.lg)
        }
    }

    private var quietHoursCard: some View {
        SubscreenCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("QUIET HOURS")
                    .font(Tokens.Font.label).kerning(0.8)
                    .foregroundStyle(Tokens.Color.text3)
                diagRow("Enabled", quietHoursEnabled ? "Yes" : "No", ok: true)
                if quietHoursEnabled {
                    diagRow("Window",
                            String(format: "%02d:%02d – %02d:%02d", quietStartHour, quietStartMinute, quietEndHour, quietEndMinute),
                            ok: true)
                    diagRow("Now inside window?", nowInQuietWindow ? "YES — recap may be held" : "No", ok: !nowInQuietWindow)
                }
                Text("Note: as of Build 31 Quiet Hours is a stored preference only — it does not suppress notifications. Task reminders and recaps fire regardless.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
                    .padding(.top, 2)
            }
            .padding(Tokens.Space.lg)
        }
    }

    private var testCard: some View {
        SubscreenCard {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    Haptics.tap()
                    Task {
                        let ok = await notifications.sendTest(afterSeconds: 30)
                        testFeedback = ok
                            ? "Test scheduled — lock your phone, it fires in 30 seconds."
                            : "Couldn't schedule — authorization is off."
                        await reload()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tokens.Color.accent2)
                        Text("Fire test notification in 30 sec")
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(Tokens.Color.text)
                        Spacer()
                    }
                    .padding(Tokens.Space.lg)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if let testFeedback {
                    Text(testFeedback)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                        .padding(.horizontal, Tokens.Space.lg)
                        .padding(.bottom, Tokens.Space.md)
                }
            }
        }
    }

    private func pendingCard(_ r: NotificationDiagnosticsReport) -> some View {
        SubscreenCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("PENDING (\(r.pending.count))")
                    .font(Tokens.Font.label).kerning(0.8)
                    .foregroundStyle(Tokens.Color.text3)
                if r.pending.isEmpty {
                    Text("No scheduled notifications. If you expected reminders or a recap here, that's the bug.")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.rose)
                } else {
                    ForEach(r.pending) { p in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.body.isEmpty ? p.identifier : p.body)
                                .font(Tokens.Font.body)
                                .foregroundStyle(Tokens.Color.text)
                                .lineLimit(1)
                            Text("\(p.triggerKind) · \(p.nextFireDate.map { Self.dateFormatter.string(from: $0) } ?? "no fire date")")
                                .font(Tokens.Font.caption)
                                .foregroundStyle(Tokens.Color.text3)
                        }
                    }
                }
            }
            .padding(Tokens.Space.lg)
        }
    }

    private func deliveredCard(_ r: NotificationDiagnosticsReport) -> some View {
        SubscreenCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("DELIVERED — still in Notification Center (\(r.delivered.count))")
                    .font(Tokens.Font.label).kerning(0.8)
                    .foregroundStyle(Tokens.Color.text3)
                if r.delivered.isEmpty {
                    Text("Nothing delivered recently.")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                } else {
                    ForEach(r.delivered) { d in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.body.isEmpty ? d.identifier : d.body)
                                .font(Tokens.Font.body)
                                .foregroundStyle(Tokens.Color.text)
                                .lineLimit(1)
                            Text(Self.dateFormatter.string(from: d.deliveredAt))
                                .font(Tokens.Font.caption)
                                .foregroundStyle(Tokens.Color.text3)
                        }
                    }
                }
            }
            .padding(Tokens.Space.lg)
        }
    }

    // MARK: Helpers

    private func diagRow(_ label: String, _ value: String, ok: Bool) -> some View {
        HStack {
            Text(label)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text2)
            Spacer()
            Text(value)
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(ok ? Tokens.Color.text : Tokens.Color.rose)
        }
    }

    private var nowInQuietWindow: Bool {
        let cal = Calendar.current
        let now = cal.dateComponents([.hour, .minute], from: .now)
        let nowMin = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        let startMin = quietStartHour * 60 + quietStartMinute
        let endMin = quietEndHour * 60 + quietEndMinute
        if startMin <= endMin {
            return nowMin >= startMin && nowMin < endMin
        } else {
            // Window crosses midnight.
            return nowMin >= startMin || nowMin < endMin
        }
    }

    private func authText(_ s: UNAuthorizationStatus) -> String {
        switch s {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        case .notDetermined: return "Not determined"
        @unknown default: return "Unknown"
        }
    }

    private func settingText(_ s: UNNotificationSetting) -> String {
        switch s {
        case .enabled: return "Enabled"
        case .disabled: return "Disabled"
        case .notSupported: return "N/A"
        @unknown default: return "Unknown"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d, h:mm a"
        return f
    }()
}
