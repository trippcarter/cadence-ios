import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Settings section showing Google Calendar connection state, calendar
/// list with per-calendar enable toggles, and connect/refresh/disconnect
/// actions. Embedded in SettingsView between Notifications and Daily brief.
struct ConnectedAccountsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ConnectedAccount.connectedAt, order: .forward)])
    private var accounts: [ConnectedAccount]
    @ObservedObject private var service = GoogleCalendarService.shared

    @State private var feedback: String?
    @AppStorage(PrefsKey.defaultMirrorCalendarID) private var defaultMirrorCalendarID: String = ""
    @AppStorage(PrefsKey.autoMirrorTimeBlocked) private var autoMirror: Bool = false

    private var googleAccounts: [ConnectedAccount] {
        accounts.filter { $0.provider == "google" }
    }

    var body: some View {
        VStack(spacing: 0) {
            if googleAccounts.isEmpty {
                disconnectedRow
            } else {
                ForEach(Array(googleAccounts.enumerated()), id: \.element.id) { index, account in
                    if index > 0 {
                        Divider().background(Tokens.Color.borderSoft)
                            .padding(.vertical, Tokens.Space.xs)
                    }
                    accountCard(account: account, isOnly: googleAccounts.count == 1)
                }
                Divider().background(Tokens.Color.borderSoft)
                syncPrefsBlock
                Divider().background(Tokens.Color.borderSoft)
                addAccountRow
            }
            if let feedback {
                Divider().background(Tokens.Color.borderSoft)
                Text(feedback)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onChange(of: googleAccounts.count) { _, _ in
            // Clear stale messages when account state actually changes so
            // the UI doesn't leave a misleading line at the bottom.
            feedback = nil
        }
    }

    @ViewBuilder
    private func accountCard(account: ConnectedAccount, isOnly: Bool) -> some View {
        if service.needsReconnect(for: account) {
            reconnectBanner(account: account)
            Divider().background(Tokens.Color.borderSoft)
        }
        connectedHeader(account: account)
        Divider().background(Tokens.Color.borderSoft)
        calendarsRow(account: account)
        Divider().background(Tokens.Color.borderSoft)
        actionsRow(account: account)
    }

    // MARK: Connected state

    private func connectedHeader(account: ConnectedAccount) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Color.teal.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.teal)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Google Calendar")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text(account.email)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
                if let last = account.lastSyncedAt {
                    Text("Last refresh \(last, format: .relative(presentation: .named))")
                        .font(Tokens.Font.chip)
                        .foregroundStyle(Tokens.Color.text3)
                }
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Tokens.Color.mint)
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private func calendarsRow(account: ConnectedAccount) -> some View {
        let sortedCalendars = account.calendarList.sorted { $0.name < $1.name }
        return VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
                    .frame(width: 18)
                Text("Calendars")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Spacer()
                let enabled = sortedCalendars.filter { $0.isEnabled }.count
                Text("\(enabled) of \(sortedCalendars.count) shown")
                    .font(Tokens.Font.chip)
                    .foregroundStyle(Tokens.Color.text3)
            }
            if sortedCalendars.isEmpty {
                Text("No calendars yet — tap refresh.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            } else {
                VStack(spacing: 4) {
                    ForEach(sortedCalendars) { cal in
                        CalendarToggleRow(calendar: cal) {
                            try? modelContext.save()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private func actionsRow(account: ConnectedAccount) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            Button {
                refresh(account: account)
            } label: {
                Label("Refresh now", systemImage: "arrow.clockwise")
                    .font(Tokens.Font.chip)
                    .padding(.horizontal, Tokens.Space.md)
                    .padding(.vertical, 7)
                    .background(Tokens.Color.accent.opacity(0.18))
                    .foregroundStyle(Tokens.Color.accent2)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(service.isFetching)
            Spacer()
            Button {
                disconnect(account: account)
            } label: {
                Label("Disconnect", systemImage: "minus.circle")
                    .font(Tokens.Font.chip)
                    .padding(.horizontal, Tokens.Space.md)
                    .padding(.vertical, 7)
                    .background(Tokens.Color.rose.opacity(0.18))
                    .foregroundStyle(Tokens.Color.rose)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    // MARK: Reconnect banner (scope upgrade)

    private func reconnectBanner(account: ConnectedAccount) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Color.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reconnect for two-way sync")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    Text("Cadence now writes time-blocked tasks back to Google Calendar. Reconnect to grant write access.")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
            }
            Button {
                reconnect(account: account)
            } label: {
                Text("Reconnect now")
                    .font(Tokens.Font.chip)
                    .padding(.horizontal, Tokens.Space.md)
                    .padding(.vertical, 7)
                    .background(Tokens.Color.amber.opacity(0.20))
                    .foregroundStyle(Tokens.Color.amber)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
        .background(Tokens.Color.amber.opacity(0.06))
    }

    // MARK: + Add another Google account

    private var addAccountRow: some View {
        Button {
            connect()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14, weight: .semibold))
                Text(service.isSigningIn ? "Connecting…" : "Add Google account")
                    .font(Tokens.Font.bodyEmphasis)
                Spacer()
            }
            .foregroundStyle(Tokens.Color.accent2)
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(service.isSigningIn)
    }

    // MARK: Sync prefs (default calendar + auto-mirror)

    private var syncPrefsBlock: some View {
        // Aggregate calendars across all connected Google accounts.
        let enabledCalendars = googleAccounts
            .flatMap { $0.calendarList }
            .filter { $0.isEnabled }
            .sorted { $0.name < $1.name }
        return VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
                    .frame(width: 18)
                Text("Two-way sync")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Spacer()
            }
            HStack {
                Text("Default destination calendar")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
                Spacer()
                Menu {
                    Button {
                        defaultMirrorCalendarID = ""
                    } label: {
                        Label("None — ask each time", systemImage: defaultMirrorCalendarID.isEmpty ? "checkmark" : "circle")
                    }
                    Divider()
                    ForEach(enabledCalendars) { cal in
                        Button {
                            defaultMirrorCalendarID = cal.googleCalendarID
                        } label: {
                            Label(cal.name, systemImage: cal.googleCalendarID == defaultMirrorCalendarID ? "checkmark" : "calendar")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(defaultCalendarLabel(among: enabledCalendars))
                            .font(Tokens.Font.chip)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .padding(.horizontal, Tokens.Space.md)
                    .padding(.vertical, 6)
                    .background(Tokens.Color.teal.opacity(0.18))
                    .foregroundStyle(Tokens.Color.teal)
                    .clipShape(Capsule())
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-block new timed tasks")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Color.text)
                    Text("Mirror new tasks with specific times automatically.")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
                Toggle("", isOn: $autoMirror)
                    .tint(Tokens.Color.teal)
                    .labelsHidden()
                    .disabled(defaultMirrorCalendarID.isEmpty)
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private func defaultCalendarLabel(among options: [CalendarConfig]) -> String {
        if defaultMirrorCalendarID.isEmpty { return "Ask each time" }
        return options.first(where: { $0.googleCalendarID == defaultMirrorCalendarID })?.name ?? "Pick…"
    }

    private func reconnect(account: ConnectedAccount) {
        Task {
            await service.signOut(account: account)
            // Surface a tiny prompt to re-tap Connect — clean separation
            // from sign-out makes the flow predictable.
            feedback = "Disconnected. Tap Connect Google Calendar to re-link with write access."
        }
    }

    // MARK: Disconnected state

    private var disconnectedRow: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(Tokens.Color.teal.opacity(0.10))
                        .frame(width: 36, height: 36)
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.Color.teal.opacity(0.7))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Google Calendar")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    Text("See your events alongside today's tasks.")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
            }
            Button {
                connect()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 12, weight: .semibold))
                    Text(service.isSigningIn ? "Connecting…" : "Connect Google Calendar")
                        .font(Tokens.Font.bodyEmphasis)
                }
                .padding(.vertical, Tokens.Space.sm + 2)
                .padding(.horizontal, Tokens.Space.lg)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Tokens.Color.accent, Tokens.Color.accentDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(service.isSigningIn)
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    // MARK: Actions

    private func connect() {
        guard let presenter = topViewController() else {
            feedback = "Couldn't find a view controller to present sign-in."
            return
        }
        feedback = nil
        Task {
            do {
                try await service.signIn(presentingFrom: presenter)
                Haptics.success()
                feedback = "Connected. Refreshing events…"
                await service.fetchAllEvents()
                feedback = nil
            } catch let GoogleCalendarError.oauth(error) {
                feedback = "Sign-in cancelled or failed: \(error.localizedDescription)"
            } catch {
                feedback = error.localizedDescription
            }
        }
    }

    private func disconnect(account: ConnectedAccount) {
        Task {
            await service.signOut(account: account)
            Haptics.warning()
            feedback = "Disconnected from Google Calendar."
        }
    }

    private func refresh(account: ConnectedAccount) {
        Task {
            do {
                try await service.fetchCalendars(for: account)
                await service.fetchAllEvents()
                feedback = "Refreshed."
            } catch {
                feedback = error.localizedDescription
            }
        }
    }

    // MARK: Top view controller helper

    private func topViewController() -> PlatformViewController? {
        #if canImport(UIKit)
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var current = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = current?.presentedViewController {
            current = presented
        }
        return current
        #else
        return nil
        #endif
    }
}

// MARK: - Per-calendar toggle row

private struct CalendarToggleRow: View {
    @Bindable var calendar: CalendarConfig
    var onChange: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            Circle()
                .fill(swatchColor)
                .frame(width: 12, height: 12)
            Text(calendar.name)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text)
                .lineLimit(1)
            Spacer()
            Toggle("", isOn: $calendar.isEnabled)
                .labelsHidden()
                .tint(Tokens.Color.accent)
                .onChange(of: calendar.isEnabled) { _, _ in onChange() }
        }
        .padding(.vertical, 4)
    }

    private var swatchColor: Color {
        if let override = calendar.colorOverride {
            return ListPalette.color(for: override)
        }
        if let hex = calendar.defaultColorHex, let value = UInt32(hex.replacingOccurrences(of: "#", with: ""), radix: 16) {
            return Color(hex: value)
        }
        return Tokens.Color.teal
    }
}
