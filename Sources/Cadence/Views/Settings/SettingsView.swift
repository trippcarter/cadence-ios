import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @AppStorage(PrefsKey.dailyBriefHour)       private var briefHour: Int = 7
    @AppStorage(PrefsKey.dailyBriefMinute)     private var briefMinute: Int = 30
    @AppStorage(PrefsKey.rolloverPolicy)       private var rolloverRaw: String = RolloverPolicy.on.rawValue
    @AppStorage(PrefsKey.themeChoice)          private var themeRaw: String = ThemeChoice.dark.rawValue
    @AppStorage(PrefsKey.notificationsEnabled) private var notifsEnabled: Bool = true
    @AppStorage(PrefsKey.showComingUpSection)      private var showComingUp: Bool = true
    @AppStorage(PrefsKey.comingUpWindowDays)       private var comingUpDays: Int = 7
    @AppStorage(PrefsKey.autoCollapseCarriedThreshold) private var autoCollapseThreshold: Int = 3
    @AppStorage(PrefsKey.focusDurationMinutes) private var focusDuration: Int = 25
    @AppStorage(PrefsKey.focusBreakMinutes)    private var focusBreak: Int = 5
    @AppStorage(PrefsKey.focusPlaySound)       private var focusSound: Bool = true
    @AppStorage(PrefsKey.focusPlayHaptic)      private var focusHaptic: Bool = true
    @AppStorage(PrefsKey.focusAutoStartNext)   private var focusAutoStart: Bool = false
    @AppStorage(PrefsKey.dailyReviewEnabled)   private var reviewEnabled: Bool = false
    @AppStorage(PrefsKey.dailyReviewHour)      private var reviewHour: Int = 21
    @AppStorage(PrefsKey.dailyReviewMinute)    private var reviewMinute: Int = 0

    @State private var testFeedback: String?
    @State private var showingDailyReviewManual: Bool = false
    @State private var showingRemindersImport: Bool = false
    @State private var showingCSVImport: Bool = false
    @State private var showingHelpFAQ: Bool = false
    @State private var showingCrashLogs: Bool = false
    @State private var crashLogCount: Int = 0

    @EnvironmentObject private var notifications: NotificationManager
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @Query private var allTasks: [TaskItem]
    @Query private var allLists: [TaskList]

    var body: some View {
        ZStack {
            Tokens.Color.bg.ignoresSafeArea()

            List {
                Section {
                    heroProfileCard
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Tokens.Space.xl, leading: Tokens.Space.lg, bottom: Tokens.Space.sm, trailing: Tokens.Space.lg))
                }

                Section {
                    statsStrip
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: Tokens.Space.lg, bottom: Tokens.Space.lg, trailing: Tokens.Space.lg))
                }

                section(title: "Account") {
                    AccountSection()
                }

                section(title: "iCloud sync") {
                    CloudSyncSection()
                }

                section(title: "Connected accounts") {
                    ConnectedAccountsSection()
                }

                section(title: "Import from…") {
                    importRow(title: "Apple Reminders",
                              subtitle: "Bring in your existing Reminders lists.",
                              icon: "list.bullet.rectangle.portrait.fill",
                              tint: Tokens.Color.accent2) {
                        showingRemindersImport = true
                    }
                    Divider().background(Tokens.Color.borderSoft)
                    importRow(title: "CSV file",
                              subtitle: "Things 3, TickTick, Todoist, or any tool with CSV export.",
                              icon: "doc.text.fill",
                              tint: Tokens.Color.indigo) {
                        showingCSVImport = true
                    }
                }

                section(title: "Notifications") {
                    notificationsToggleRow
                    Divider().background(Tokens.Color.borderSoft)
                    notificationsStatusRow
                    Divider().background(Tokens.Color.borderSoft)
                    sendTestRow
                }

                section(title: "Today layout") {
                    HStack {
                        rowLabel(icon: "calendar.badge.clock", text: "Show \"Coming up\"")
                        Spacer()
                        Toggle("", isOn: $showComingUp).labelsHidden().tint(Tokens.Color.accent)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                    if showComingUp {
                        Divider().background(Tokens.Color.borderSoft)
                        HStack {
                            rowLabel(icon: "calendar", text: "Coming up window")
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
                        rowLabel(icon: "rectangle.compress.vertical", text: "Collapse carried over above")
                        Spacer()
                        Picker("", selection: $autoCollapseThreshold) {
                            Text("3").tag(3)
                            Text("5").tag(5)
                            Text("10").tag(10)
                        }
                        .labelsHidden()
                        .tint(Tokens.Color.accent2)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
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

                section(title: "Voice & Siri") {
                    voiceIntroRow
                    Divider().background(Tokens.Color.borderSoft)
                    samplePhraseRow(
                        phrase: "\"Hey Siri, add to Cadence: pay rent next Friday\"",
                        icon: "plus.circle.fill",
                        tint: Tokens.Color.accent
                    )
                    Divider().background(Tokens.Color.borderSoft)
                    samplePhraseRow(
                        phrase: "\"Hey Siri, what's on my plate today\"",
                        icon: "list.bullet.rectangle.fill",
                        tint: Tokens.Color.teal
                    )
                    Divider().background(Tokens.Color.borderSoft)
                    samplePhraseRow(
                        phrase: "\"Hey Siri, mark <task> done in Cadence\"",
                        icon: "checkmark.circle.fill",
                        tint: Tokens.Color.mint
                    )
                    Divider().background(Tokens.Color.borderSoft)
                    samplePhraseRow(
                        phrase: "\"Hey Siri, open Cadence\"",
                        icon: "moon.stars.fill",
                        tint: Tokens.Color.accent2
                    )
                }

                section(title: "Daily review") {
                    HStack {
                        rowLabel(icon: "moon.zzz.fill", text: "Evening review")
                        Spacer()
                        Toggle("", isOn: $reviewEnabled)
                            .tint(Tokens.Color.accent)
                            .labelsHidden()
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)

                    if reviewEnabled {
                        Divider().background(Tokens.Color.borderSoft)
                        HStack {
                            rowLabel(icon: "clock", text: "Reminder time")
                            Spacer()
                            DatePicker("", selection: reviewTimeBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(Tokens.Color.accent)
                        }
                        .padding(.horizontal, Tokens.Space.lg)
                        .padding(.vertical, Tokens.Space.md)
                    }

                    Divider().background(Tokens.Color.borderSoft)
                    Button {
                        showingDailyReviewManual = true
                    } label: {
                        HStack {
                            rowLabel(icon: "play.fill", text: "Run today's review")
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

                section(title: "Focus") {
                    VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                        rowLabel(icon: "timer", text: "Session length")
                        focusDurationChips
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                    Divider().background(Tokens.Color.borderSoft)
                    VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                        rowLabel(icon: "cup.and.saucer.fill", text: "Break length")
                        focusBreakChips
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                    Divider().background(Tokens.Color.borderSoft)
                    HStack {
                        rowLabel(icon: "speaker.wave.2.fill", text: "Completion sound")
                        Spacer()
                        Toggle("", isOn: $focusSound).labelsHidden().tint(Tokens.Color.accent)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                    Divider().background(Tokens.Color.borderSoft)
                    HStack {
                        rowLabel(icon: "iphone.radiowaves.left.and.right", text: "Completion haptic")
                        Spacer()
                        Toggle("", isOn: $focusHaptic).labelsHidden().tint(Tokens.Color.accent)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                    Divider().background(Tokens.Color.borderSoft)
                    HStack {
                        rowLabel(icon: "arrow.triangle.2.circlepath", text: "Auto-start next session")
                        Spacer()
                        Toggle("", isOn: $focusAutoStart).labelsHidden().tint(Tokens.Color.accent)
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

                section(title: "Light · Dark · System") {
                    HStack(spacing: Tokens.Space.sm) {
                        ForEach(ThemeChoice.allCases) { choice in
                            themeChip(choice)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.md)
                }

                section(title: "Appearance theme") {
                    AppearanceThemePicker()
                }

                section(title: "App icon") {
                    AppIconPicker()
                }

                section(title: "Help & FAQ") {
                    helpFAQRow
                }

                section(title: "Danger zone") {
                    ResetDataSection()
                }

                section(title: "About") {
                    aboutVersionRow
                    Divider().background(Tokens.Color.borderSoft)
                    aboutPrivacyRow
                    Divider().background(Tokens.Color.borderSoft)
                    aboutTermsRow
                    Divider().background(Tokens.Color.borderSoft)
                    aboutGitHubRow
                    if crashLogCount > 0 {
                        Divider().background(Tokens.Color.borderSoft)
                        aboutCrashLogsRow
                    }
                }

                Section {
                    Text("Made with care")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Tokens.Space.lg)
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
        .onChange(of: reviewEnabled) { _, _ in
            Task { await notifications.scheduleDailyReview(requestIfNeeded: true) }
        }
        .sheet(isPresented: $showingDailyReviewManual) {
            DailyReviewSheet()
        }
        .sheet(isPresented: $showingRemindersImport) {
            RemindersImportSheet()
        }
        .sheet(isPresented: $showingCSVImport) {
            CSVImportSheet()
        }
        .sheet(isPresented: $showingHelpFAQ) {
            HelpFAQSheet()
        }
        .sheet(isPresented: $showingCrashLogs) {
            CrashLogsView()
        }
        .onAppear {
            crashLogCount = MetricKitObserver.listLogs().count
        }
    }

    private var aboutCrashLogsRow: some View {
        Button {
            Haptics.tap()
            showingCrashLogs = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.octagon")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Color.rose)
                    .frame(width: 18)
                Text("Crash & diagnostic logs")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Spacer()
                Text("\(crashLogCount)")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
                    .monospacedDigit()
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

    private var helpFAQRow: some View {
        Button {
            Haptics.tap()
            showingHelpFAQ = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Questions, how-tos, troubleshooting")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    Text("12 answers and a direct line to support.")
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
    }

    /// Build 22: reusable row for the Import from… section. Same visual
    /// language as the Account / Switch Apple ID rows in AccountSection.
    private func importRow(title: String, subtitle: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 18)
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Voice & Siri rows (Build 20)

    private var voiceIntroRow: some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Color.accent.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Talk to Cadence")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text("Siri can add tasks, complete them, and read out your day. Try the phrases below or build your own in Shortcuts.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private func samplePhraseRow(phrase: String, icon: String, tint: Color) -> some View {
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

    // MARK: Focus duration chips

    private var focusDurationChips: some View {
        HStack(spacing: Tokens.Space.sm) {
            ForEach([15, 25, 30, 45, 60], id: \.self) { mins in
                Button {
                    Haptics.tap()
                    focusDuration = mins
                } label: {
                    Text("\(mins)")
                        .font(Tokens.Font.bodyEmphasis)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Space.sm)
                        .background(focusDuration == mins ? Tokens.Color.accent.opacity(0.22) : Tokens.Color.surface2)
                        .foregroundStyle(focusDuration == mins ? Tokens.Color.accent2 : Tokens.Color.text2)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                                .stroke(focusDuration == mins ? Tokens.Color.accent : Tokens.Color.borderSoft, lineWidth: focusDuration == mins ? 1 : 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var focusBreakChips: some View {
        HStack(spacing: Tokens.Space.sm) {
            ForEach([5, 10, 15], id: \.self) { mins in
                Button {
                    Haptics.tap()
                    focusBreak = mins
                } label: {
                    Text("\(mins) min")
                        .font(Tokens.Font.bodyEmphasis)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Space.sm)
                        .background(focusBreak == mins ? Tokens.Color.mint.opacity(0.22) : Tokens.Color.surface2)
                        .foregroundStyle(focusBreak == mins ? Tokens.Color.mint : Tokens.Color.text2)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                                .stroke(focusBreak == mins ? Tokens.Color.mint : Tokens.Color.borderSoft, lineWidth: focusBreak == mins ? 1 : 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var reviewTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reviewHour, minute: reviewMinute, second: 0, of: .now) ?? .now
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reviewHour = comps.hour ?? 21
                reviewMinute = comps.minute ?? 0
                Task { await notifications.scheduleDailyReview(requestIfNeeded: false) }
            }
        )
    }

    // MARK: Hero profile card

    /// The big "you" hero at the top of the You tab — 88pt gradient avatar
    /// with initials, big rounded display name, email (or "Private email"
    /// for the relay), and "Member since" eyebrow.
    private var heroProfileCard: some View {
        let user = authSession.state.user
        return VStack(spacing: Tokens.Space.md) {
            avatarBadge

            VStack(spacing: 4) {
                Text(user?.displayName ?? "Cadence")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Color.text)
                    .multilineTextAlignment(.center)

                emailLine
                    .multilineTextAlignment(.center)

                if let memberSince = user?.memberSinceLabel {
                    Text(memberSince.uppercased())
                        .font(Tokens.Font.label)
                        .kerning(1.0)
                        .foregroundStyle(Tokens.Color.text3)
                        .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(profileAccessibilityLabel)
    }

    /// 88pt gradient circle with initials, matching the spec's violet/deep
    /// violet gradient (Tokens.Color.accent → accentDeep, which are #7C5CFF
    /// and #5B3CFA respectively).
    private var avatarBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Tokens.Color.accent, Tokens.Color.accentDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .shadow(color: Tokens.Color.accentGlow, radius: 14, x: 0, y: 6)
            Text(authSession.state.user?.avatarInitials ?? "C")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    /// Email line — uses an italicized "Private email" label when Apple's
    /// private relay is in use, since the actual address is noise.
    @ViewBuilder
    private var emailLine: some View {
        let user = authSession.state.user
        if user == nil {
            Text("Not signed in")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text3)
        } else if let user, user.isUsingHiddenEmail {
            Text("Private email")
                .font(.system(size: 14, weight: .regular).italic())
                .foregroundStyle(Tokens.Color.text2)
        } else if let email = user?.email, !email.isEmpty {
            Text(email)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text2)
        } else {
            Text("Signed in with Apple ID")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text2)
        }
    }

    private var profileAccessibilityLabel: String {
        guard let user = authSession.state.user else { return "Profile. Not signed in." }
        var parts: [String] = ["Profile", user.displayName]
        if user.isUsingHiddenEmail {
            parts.append("Private email")
        } else if let email = user.email, !email.isEmpty {
            parts.append(email)
        }
        if let memberSince = user.memberSinceLabel {
            parts.append(memberSince)
        }
        return parts.joined(separator: ". ")
    }

    // MARK: Stats strip

    /// Three-card stat row matching the Today stat-card visual treatment.
    /// Pulls from SwiftData @Query so values stay live as tasks complete.
    private var statsStrip: some View {
        HStack(spacing: Tokens.Space.sm) {
            statCard(value: completedToday, label: "today", accent: Tokens.Color.accent)
            statCard(value: completedThisWeek, label: "this week", accent: Tokens.Color.teal)
            statCard(value: listsOwned, label: listsOwned == 1 ? "list" : "lists", accent: Tokens.Color.amber)
        }
    }

    private func statCard(value: Int, label: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Tokens.Color.text)
                .monospacedDigit()
            Text(label.uppercased())
                .font(Tokens.Font.label)
                .kerning(1.1)
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: Stat derivations

    private var completedToday: Int {
        let cal = Calendar.current
        return allTasks.filter { task in
            task.status == .completed
                && task.parent == nil
                && (task.completedAt.map(cal.isDateInToday) ?? false)
        }.count
    }

    private var completedThisWeek: Int {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -7, to: .now) ?? .now
        return allTasks.filter { task in
            task.status == .completed
                && task.parent == nil
                && (task.completedAt.map { $0 >= cutoff } ?? false)
        }.count
    }

    /// "Owned" = not a list someone shared TO us. Counts both private lists
    /// and lists we ourselves are sharing with others.
    private var listsOwned: Int {
        allLists.filter { !$0.isSharedAsParticipant }.count
    }

    // MARK: About rows

    private var aboutVersionRow: some View {
        HStack {
            rowLabel(icon: "app.badge", text: "Cadence")
            Spacer()
            Text("v\(appVersion) · build \(buildNumber)")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text2)
                .monospacedDigit()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var aboutPrivacyRow: some View {
        externalLinkRow(
            icon: "hand.raised.fill",
            tint: Tokens.Color.accent,
            title: "Privacy Policy",
            url: "https://trippcarter.github.io/cadence-ios/privacy"
        )
    }

    private var aboutTermsRow: some View {
        externalLinkRow(
            icon: "doc.text.fill",
            tint: Tokens.Color.teal,
            title: "Terms of Service",
            url: "https://trippcarter.github.io/cadence-ios/terms"
        )
    }

    private func externalLinkRow(icon: String, tint: Color, title: String, url: String) -> some View {
        Button {
            Haptics.tap()
            if let u = URL(string: url) { openURL(u) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(title)
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var aboutGitHubRow: some View {
        Button {
            Haptics.tap()
            if let url = URL(string: "https://github.com/trippcarter/cadence-ios") {
                openURL(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
                    .frame(width: 18)
                Text("Source on GitHub")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.accent2)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func themeChip(_ choice: ThemeChoice) -> some View {
        let isSelected = themeRaw == choice.rawValue
        return Button {
            Haptics.tap()
            themeRaw = choice.rawValue
            NSLog("[THEME] user picked %@ (rawValue=%@)", choice.displayName, choice.rawValue)
        } label: {
            HStack(spacing: 8) {
                themeSwatch(choice)
                Text(choice.displayName)
                    .font(Tokens.Font.bodyEmphasis)
            }
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

    /// Small preview swatch next to each theme name: light circle, dark
    /// circle, or a phone icon for "System".
    @ViewBuilder
    private func themeSwatch(_ choice: ThemeChoice) -> some View {
        switch choice {
        case .light:
            Circle()
                .fill(Color(hex: 0xFAF7F1))
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Tokens.Color.borderSoft, lineWidth: 0.5))
        case .dark:
            Circle()
                .fill(Color(hex: 0x07080C))
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Tokens.Color.border, lineWidth: 0.5))
        case .system:
            Image(systemName: "iphone")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Tokens.Color.text2)
        }
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
