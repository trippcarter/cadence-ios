import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Shared chrome

/// Build 28: card+row helpers shared by every drill-in sub-screen.
/// Keeps the You-tab visual language consistent — soft surface cards,
/// 0.5pt border, the same chevron-row sizing as the existing settings.
struct SubscreenCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
            .padding(.horizontal, Tokens.Space.lg)
    }
}

struct SubscreenScaffold<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Tokens.Color.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Tokens.Space.md) {
                    content()
                    Color.clear.frame(height: 60)
                }
                .padding(.top, Tokens.Space.md)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Tokens.Color.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct SubscreenRowLabel: View {
    let icon: String
    let tint: Color
    let text: String

    init(icon: String, tint: Color = Tokens.Color.text3, text: String) {
        self.icon = icon
        self.tint = tint
        self.text = text
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(text)
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text)
        }
    }
}

// MARK: - Apple ID

struct AppleIDSubscreen: View {
    @EnvironmentObject private var authSession: AuthSession
    @EnvironmentObject private var cloudSync: CloudKitSyncManager

    @State private var showingSignOut = false
    @State private var showingSwitch = false

    private var user: AuthenticatedUser? { authSession.state.user }

    var body: some View {
        SubscreenScaffold(title: "Apple ID") {
            SubscreenCard {
                accountRow
                Divider().background(Tokens.Color.borderSoft)
                iCloudRow
                Divider().background(Tokens.Color.borderSoft)
                signOutRow
                Divider().background(Tokens.Color.borderSoft)
                switchRow
            }
        }
        .alert("Sign out of Cadence?", isPresented: $showingSignOut) {
            Button("Sign Out", role: .destructive) {
                Haptics.warning()
                authSession.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your tasks stay safely in iCloud. Sign back in any time with the same Apple ID to restore them.")
        }
        .alert("Switch to a different Apple ID?", isPresented: $showingSwitch) {
            Button("Switch", role: .destructive) {
                Haptics.warning()
                authSession.switchAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll sign out of this account and Apple will ask you which Apple ID to use next. Your existing tasks stay in iCloud and reappear when you sign back in with this account.")
        }
    }

    private var accountRow: some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Tokens.Color.indigo, Tokens.Color.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 40, height: 40)
                Image(systemName: "applelogo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(user?.displayName ?? "Not signed in")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text(emailLabel)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var emailLabel: String {
        guard let user else { return "Sign in with Apple to enable sync" }
        if user.isUsingHiddenEmail { return "Private email (\(user.email ?? ""))" }
        if let email = user.email, !email.isEmpty { return email }
        return "Signed in with Apple ID"
    }

    private var iCloudRow: some View {
        HStack(spacing: 8) {
            Image(systemName: iCloudIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iCloudColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("Backed by iCloud")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text(iCloudStatusLine)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var iCloudIcon: String {
        switch cloudSync.accountStatus {
        case .available:           return "icloud.fill"
        case .noAccount, .restricted: return "icloud.slash.fill"
        case .temporarilyUnavailable: return "icloud.fill"
        case .couldNotDetermine:   return "icloud"
        @unknown default:          return "icloud"
        }
    }

    private var iCloudColor: Color {
        switch cloudSync.accountStatus {
        case .available: return Tokens.Color.mint
        case .noAccount, .restricted: return Tokens.Color.rose
        case .temporarilyUnavailable: return Tokens.Color.amber
        default: return Tokens.Color.text3
        }
    }

    private var iCloudStatusLine: String {
        switch cloudSync.accountStatus {
        case .available:
            if let email = cloudSync.userEmail, !email.isEmpty { return email }
            return "iCloud signed in"
        case .noAccount: return "No iCloud signed in — tasks won't sync"
        case .restricted: return "iCloud access restricted on this device"
        case .temporarilyUnavailable: return "iCloud temporarily unavailable"
        case .couldNotDetermine: return "Checking iCloud…"
        @unknown default: return cloudSync.accountStatus.displayLabel
        }
    }

    private var signOutRow: some View {
        Button { showingSignOut = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.rose)
                    .frame(width: 18)
                Text("Sign Out")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.rose)
                Spacer()
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(user == nil)
    }

    private var switchRow: some View {
        Button { showingSwitch = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Switch Apple ID")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.accent2)
                    Text("Sign out and choose a different Apple ID.")
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
        .disabled(user == nil)
    }
}

// MARK: - Connected accounts (Google etc.)

struct ConnectedAccountsSubscreen: View {
    var body: some View {
        SubscreenScaffold(title: "Connected accounts") {
            SubscreenCard {
                ConnectedAccountsSection()
            }
        }
    }
}

// MARK: - Data & Privacy

struct DataPrivacySubscreen: View {
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.modelContext) private var modelContext

    @State private var exportURL: URL?
    @State private var exportBusy = false
    @State private var exportError: String?
    @State private var showingDeleteConfirm = false

    private var user: AuthenticatedUser? { authSession.state.user }

    var body: some View {
        SubscreenScaffold(title: "Data & Privacy") {
            SubscreenCard {
                exportRow
                Divider().background(Tokens.Color.borderSoft)
                deleteRow
            }
            SubscreenCard {
                ResetDataSection()
            }
        }
        .alert("Delete your account?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Wipes every list, task, habit, and review on this device and signs you out. Data already synced to your iCloud stays tied to your Apple ID — to remove that too, sign out of Cadence in iOS Settings → Apple ID → iCloud after this.")
        }
        .sheet(item: Binding(
            get: { exportURL.map { IdentifiableExportURL(url: $0) } },
            set: { newValue in exportURL = newValue?.url }
        )) { wrapper in
            DataPrivacyShareSheet(url: wrapper.url)
        }
        .alert("Couldn't build export", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private var exportRow: some View {
        Button {
            Haptics.tap()
            runExport()
        } label: {
            HStack(spacing: 8) {
                if exportBusy {
                    ProgressView().scaleEffect(0.8).frame(width: 18)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.Color.mint)
                        .frame(width: 18)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export my data")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    Text("Save every task, list, habit, and review as a JSON file.")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(exportBusy)
    }

    @MainActor
    private func runExport() {
        guard !exportBusy else { return }
        exportBusy = true
        Task {
            defer { exportBusy = false }
            let export = DataExporter.buildExport(context: modelContext, user: user)
            do {
                let url = try DataExporter.writeExport(export)
                exportURL = url
            } catch {
                exportError = error.localizedDescription
            }
        }
    }

    private var deleteRow: some View {
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.rose)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Delete my account")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.rose)
                    Text("Wipes local data and signs you out.")
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
        .disabled(user == nil)
    }

    @MainActor
    private func deleteAccount() {
        Haptics.warning()
        let wipes: [() -> Void] = [
            { (try? modelContext.fetch(FetchDescriptor<TaskItem>()))?.forEach { modelContext.delete($0) } },
            { (try? modelContext.fetch(FetchDescriptor<TaskList>()))?.forEach { modelContext.delete($0) } },
            { (try? modelContext.fetch(FetchDescriptor<Household>()))?.forEach { modelContext.delete($0) } },
            { (try? modelContext.fetch(FetchDescriptor<FocusSession>()))?.forEach { modelContext.delete($0) } },
            { (try? modelContext.fetch(FetchDescriptor<HabitCompletion>()))?.forEach { modelContext.delete($0) } },
            { (try? modelContext.fetch(FetchDescriptor<ReviewLog>()))?.forEach { modelContext.delete($0) } },
            { (try? modelContext.fetch(FetchDescriptor<TomorrowIntention>()))?.forEach { modelContext.delete($0) } },
            { (try? modelContext.fetch(FetchDescriptor<DailyWin>()))?.forEach { modelContext.delete($0) } }
        ]
        for wipe in wipes { wipe() }
        try? modelContext.save()
        authSession.signOut()
    }
}

private struct IdentifiableExportURL: Identifiable {
    let url: URL
    var id: String { url.path }
}

private struct DataPrivacyShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Appearance: Theme

struct ThemeSubscreen: View {
    var body: some View {
        SubscreenScaffold(title: "Theme") {
            SubscreenCard {
                AppearanceThemePicker()
            }
        }
    }
}

// MARK: - Appearance: App Icon

struct AppIconSubscreen: View {
    var body: some View {
        SubscreenScaffold(title: "App icon") {
            SubscreenCard {
                AppIconPicker()
            }
        }
    }
}

// MARK: - Notifications: Daily Brief

struct DailyBriefSubscreen: View {
    @AppStorage(PrefsKey.dailyBriefHour)   private var briefHour: Int = 7
    @AppStorage(PrefsKey.dailyBriefMinute) private var briefMinute: Int = 30
    @EnvironmentObject private var notifications: NotificationManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        SubscreenScaffold(title: "Daily brief") {
            SubscreenCard {
                HStack {
                    SubscreenRowLabel(icon: "sun.max", text: "Time of day")
                    Spacer()
                    DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(Tokens.Color.accent)
                }
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.vertical, Tokens.Space.md)
            }
            Text("A friendly nudge with the day's plan, sent at your chosen time.")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Color.text3)
                .padding(.horizontal, Tokens.Space.xl)
                .padding(.top, Tokens.Space.xs)
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: briefHour, minute: briefMinute, second: 0, of: .now) ?? .now },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                briefHour = c.hour ?? 7
                briefMinute = c.minute ?? 30
                Task { await notifications.scheduleDailyBrief(context: modelContext) }
            }
        )
    }
}

// MARK: - Notifications: Daily Review

struct DailyReviewSubscreen: View {
    @AppStorage(PrefsKey.dailyReviewEnabled) private var reviewEnabled: Bool = false
    @AppStorage(PrefsKey.dailyReviewHour)    private var reviewHour: Int = 21
    @AppStorage(PrefsKey.dailyReviewMinute)  private var reviewMinute: Int = 0
    @EnvironmentObject private var notifications: NotificationManager
    @State private var showingManual = false

    var body: some View {
        SubscreenScaffold(title: "Daily review") {
            SubscreenCard {
                HStack {
                    SubscreenRowLabel(icon: "moon.zzz.fill", text: "Evening review")
                    Spacer()
                    Toggle("", isOn: $reviewEnabled).tint(Tokens.Color.accent).labelsHidden()
                }
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.vertical, Tokens.Space.md)

                if reviewEnabled {
                    Divider().background(Tokens.Color.borderSoft)
                    HStack {
                        SubscreenRowLabel(icon: "clock", text: "Reminder time")
                        Spacer()
                        DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(Tokens.Color.accent)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                }

                Divider().background(Tokens.Color.borderSoft)
                Button {
                    showingManual = true
                } label: {
                    HStack {
                        SubscreenRowLabel(icon: "play.fill", text: "Run today's review")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Tokens.Color.text3)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: reviewEnabled) { _, _ in
            Task { await notifications.scheduleDailyReview(requestIfNeeded: true) }
        }
        .sheet(isPresented: $showingManual) {
            DailyReviewSheet()
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: reviewHour, minute: reviewMinute, second: 0, of: .now) ?? .now },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reviewHour = c.hour ?? 21
                reviewMinute = c.minute ?? 0
                Task { await notifications.scheduleDailyReview(requestIfNeeded: false) }
            }
        )
    }
}

// MARK: - Notifications: Quiet Hours

struct QuietHoursSubscreen: View {
    @AppStorage(PrefsKey.quietHoursEnabled)            private var enabled: Bool = false
    @AppStorage(PrefsKey.quietHoursStartHour)          private var startHour: Int = 22
    @AppStorage(PrefsKey.quietHoursStartMinute)        private var startMinute: Int = 0
    @AppStorage(PrefsKey.quietHoursEndHour)            private var endHour: Int = 7
    @AppStorage(PrefsKey.quietHoursEndMinute)          private var endMinute: Int = 0
    @AppStorage(PrefsKey.quietHoursAllowTimeSensitive) private var allowTimeSensitive: Bool = true

    var body: some View {
        SubscreenScaffold(title: "Quiet hours") {
            SubscreenCard {
                HStack {
                    SubscreenRowLabel(icon: "moon.fill", text: "Quiet hours")
                    Spacer()
                    Toggle("", isOn: $enabled).tint(Tokens.Color.accent).labelsHidden()
                }
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.vertical, Tokens.Space.md)

                if enabled {
                    Divider().background(Tokens.Color.borderSoft)
                    HStack {
                        SubscreenRowLabel(icon: "moon.stars.fill", text: "Start")
                        Spacer()
                        DatePicker("", selection: startBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden().tint(Tokens.Color.accent)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                    Divider().background(Tokens.Color.borderSoft)
                    HStack {
                        SubscreenRowLabel(icon: "sun.horizon.fill", text: "End")
                        Spacer()
                        DatePicker("", selection: endBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden().tint(Tokens.Color.accent)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                    Divider().background(Tokens.Color.borderSoft)
                    HStack {
                        SubscreenRowLabel(icon: "exclamationmark.bell.fill",
                                          tint: Tokens.Color.amber,
                                          text: "Allow time-sensitive")
                        Spacer()
                        Toggle("", isOn: $allowTimeSensitive).tint(Tokens.Color.accent).labelsHidden()
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                }
            }
            Text("Quiet hours silence non-urgent reminders between your chosen times. iOS-flagged \"time-sensitive\" notifications can still cut through when the toggle above is on. Suppression wiring lands in Build 29 — for now, this saves your schedule.")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Color.text3)
                .padding(.horizontal, Tokens.Space.xl)
                .padding(.top, Tokens.Space.xs)
        }
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: startHour, minute: startMinute, second: 0, of: .now) ?? .now },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                startHour = c.hour ?? 22
                startMinute = c.minute ?? 0
            }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: endHour, minute: endMinute, second: 0, of: .now) ?? .now },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                endHour = c.hour ?? 7
                endMinute = c.minute ?? 0
            }
        )
    }
}

// MARK: - Productivity: Focus

struct FocusSubscreen: View {
    @AppStorage(PrefsKey.focusDurationMinutes) private var focusDuration: Int = 25
    @AppStorage(PrefsKey.focusBreakMinutes)    private var focusBreak: Int = 5
    @AppStorage(PrefsKey.focusPlaySound)       private var focusSound: Bool = true
    @AppStorage(PrefsKey.focusPlayHaptic)      private var focusHaptic: Bool = true
    @AppStorage(PrefsKey.focusAutoStartNext)   private var focusAutoStart: Bool = false

    var body: some View {
        SubscreenScaffold(title: "Focus") {
            SubscreenCard {
                durationGroup
                Divider().background(Tokens.Color.borderSoft)
                breakGroup
                Divider().background(Tokens.Color.borderSoft)
                soundRow
                Divider().background(Tokens.Color.borderSoft)
                hapticRow
                Divider().background(Tokens.Color.borderSoft)
                autoStartRow
            }
        }
    }

    private var durationGroup: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            SubscreenRowLabel(icon: "timer", text: "Session length")
            HStack(spacing: Tokens.Space.sm) {
                ForEach([15, 25, 30, 45, 60], id: \.self) { mins in
                    chip(label: "\(mins)", selected: focusDuration == mins, tint: Tokens.Color.accent) {
                        Haptics.tap()
                        focusDuration = mins
                    }
                }
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var breakGroup: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            SubscreenRowLabel(icon: "cup.and.saucer.fill", text: "Break length")
            HStack(spacing: Tokens.Space.sm) {
                ForEach([5, 10, 15], id: \.self) { mins in
                    chip(label: "\(mins) min", selected: focusBreak == mins, tint: Tokens.Color.mint) {
                        Haptics.tap()
                        focusBreak = mins
                    }
                }
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private func chip(label: String, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Tokens.Font.bodyEmphasis)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.Space.sm)
                .background(selected ? tint.opacity(0.22) : Tokens.Color.surface2)
                .foregroundStyle(selected ? tint : Tokens.Color.text2)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                        .stroke(selected ? tint : Tokens.Color.borderSoft, lineWidth: selected ? 1 : 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var soundRow: some View {
        toggleRow(icon: "speaker.wave.2.fill", text: "Completion sound", isOn: $focusSound)
    }

    private var hapticRow: some View {
        toggleRow(icon: "iphone.radiowaves.left.and.right", text: "Completion haptic", isOn: $focusHaptic)
    }

    private var autoStartRow: some View {
        toggleRow(icon: "arrow.triangle.2.circlepath", text: "Auto-start next session", isOn: $focusAutoStart)
    }

    private func toggleRow(icon: String, text: String, isOn: Binding<Bool>) -> some View {
        HStack {
            SubscreenRowLabel(icon: icon, text: text)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Tokens.Color.accent)
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }
}

// MARK: - Productivity: Voice & Siri

struct VoiceSiriSubscreen: View {
    var body: some View {
        SubscreenScaffold(title: "Voice & Siri") {
            SubscreenCard {
                introRow
                Divider().background(Tokens.Color.borderSoft)
                phraseRow("\"Hey Siri, add to Cadence: pay rent next Friday\"",
                          icon: "plus.circle.fill", tint: Tokens.Color.accent)
                Divider().background(Tokens.Color.borderSoft)
                phraseRow("\"Hey Siri, what's on my plate today\"",
                          icon: "list.bullet.rectangle.fill", tint: Tokens.Color.teal)
                Divider().background(Tokens.Color.borderSoft)
                phraseRow("\"Hey Siri, mark <task> done in Cadence\"",
                          icon: "checkmark.circle.fill", tint: Tokens.Color.mint)
                Divider().background(Tokens.Color.borderSoft)
                phraseRow("\"Hey Siri, open Cadence\"",
                          icon: "moon.stars.fill", tint: Tokens.Color.accent2)
            }
            Text("Cadence registers its actions with Shortcuts so Siri picks them up automatically. You can also build a custom Shortcut and assign your own phrase.")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Color.text3)
                .padding(.horizontal, Tokens.Space.xl)
                .padding(.top, Tokens.Space.xs)
        }
    }

    private var introRow: some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            ZStack {
                Circle().fill(Tokens.Color.accent.opacity(0.18)).frame(width: 36, height: 36)
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Talk to Cadence")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text("Siri can add tasks, complete them, and read out your day.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private func phraseRow(_ phrase: String, icon: String, tint: Color) -> some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(phrase)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(Tokens.Color.text2)
                .italic()
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }
}

// MARK: - Productivity: Today Layout

struct TodayLayoutSubscreen: View {
    @AppStorage(PrefsKey.showComingUpSection)          private var showComingUp: Bool = true
    @AppStorage(PrefsKey.comingUpWindowDays)           private var comingUpDays: Int = 7
    @AppStorage(PrefsKey.autoCollapseCarriedThreshold) private var autoCollapseThreshold: Int = 10

    /// Sentinel for "Never auto-collapse." Picked Int.max so the
    /// `count <= threshold` check in TodayView is always true when the
    /// user picks Never.
    private static let neverCollapseTag = Int.max

    var body: some View {
        SubscreenScaffold(title: "Today layout") {
            SubscreenCard {
                HStack {
                    SubscreenRowLabel(icon: "calendar.badge.clock", text: "Show \"Coming up\"")
                    Spacer()
                    Toggle("", isOn: $showComingUp).labelsHidden().tint(Tokens.Color.accent)
                }
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.vertical, Tokens.Space.md)
                if showComingUp {
                    Divider().background(Tokens.Color.borderSoft)
                    HStack {
                        SubscreenRowLabel(icon: "calendar", text: "Coming up window")
                        Spacer()
                        Picker("", selection: $comingUpDays) {
                            Text("3 days").tag(3)
                            Text("7 days").tag(7)
                            Text("14 days").tag(14)
                        }
                        .labelsHidden()
                        .tint(Tokens.Color.accent2)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                }
                Divider().background(Tokens.Color.borderSoft)
                HStack {
                    SubscreenRowLabel(icon: "rectangle.compress.vertical", text: "Auto-collapse carried over above")
                    Spacer()
                    Picker("", selection: $autoCollapseThreshold) {
                        Text("3").tag(3)
                        Text("5").tag(5)
                        Text("10").tag(10)
                        Text("Never").tag(Self.neverCollapseTag)
                    }
                    .labelsHidden()
                    .tint(Tokens.Color.accent2)
                }
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.vertical, Tokens.Space.md)
            }

            Text("Build 30 default order: Pinned → Carried over → Today → Coming up. Carried over sits above Today and is expanded unless you have more than the threshold above. Drag-reorder of these sections is on the Build 31 roadmap.")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Color.text3)
                .padding(.horizontal, Tokens.Space.xl)
                .padding(.top, Tokens.Space.xs)

            SubscreenCard {
                Button {
                    Haptics.tap()
                    resetToDefaults()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tokens.Color.accent2)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset to defaults")
                                .font(Tokens.Font.bodyEmphasis)
                                .foregroundStyle(Tokens.Color.text)
                            Text("Show Coming up · 7-day window · auto-collapse above 10.")
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
            }
        }
    }

    private func resetToDefaults() {
        showComingUp = true
        comingUpDays = 7
        autoCollapseThreshold = 10
    }
}
