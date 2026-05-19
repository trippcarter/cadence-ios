import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Build 28: full You-tab restructure. The previous mega-section list
/// (15+ groups stacked vertically) collapses into 8 well-named
/// sections with chevron drill-ins for anything that needs more than
/// a single toggle. Profile card + insights strip live above the
/// sections; preferences live below the existing settings.
///
/// All current @AppStorage keys are preserved — only their UI homes
/// moved. Deeper propagation of the new preferences (time format
/// affecting every formatter, first day of week reshaping Calendar,
/// quiet hours suppressing notifications, Insights drill-in with
/// charts) ships in Build 29.
struct SettingsView: View {
    // Existing settings — still wired here either as inline rows or
    // bindings the sub-screens reference.
    @AppStorage(PrefsKey.themeChoice)          private var themeRaw: String = ThemeChoice.system.rawValue
    @AppStorage(PrefsKey.notificationsEnabled) private var notifsEnabled: Bool = true
    @AppStorage(PrefsKey.rolloverPolicy)       private var rolloverRaw: String = RolloverPolicy.on.rawValue

    // Build 28 — new preferences (UI saves values; deeper wiring in 29).
    @AppStorage(PrefsKey.firstDayOfWeek)        private var firstDayOfWeek: Int = 1
    @AppStorage(PrefsKey.timeFormat24Hour)      private var timeFormat24: Bool = false
    @AppStorage(PrefsKey.defaultListSort)       private var defaultSortRaw: String = ListSortPreference.manual.rawValue
    @AppStorage(PrefsKey.defaultReminderOffset) private var defaultReminderOffset: Double = ReminderOffsetPreset.none.rawValue
    @AppStorage(PrefsKey.defaultNewTaskList)    private var defaultNewTaskList: String = "inbox"
    @AppStorage(PrefsKey.showCompletedInToday)  private var showCompletedInToday: Bool = true
    @AppStorage(PrefsKey.showCalendarEvents)    private var showCalendarEvents: Bool = true

    // Local state
    @State private var testFeedback: String?
    @State private var showingRemindersImport = false
    @State private var showingCSVImport = false
    @State private var showingHelpFAQ = false
    @State private var showingCrashLogs = false
    @State private var showingEditProfile = false
    @State private var showingMail = false
    @State private var crashLogCount: Int = 0

    @EnvironmentObject private var notifications: NotificationManager
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @Query private var allTasks: [TaskItem]
    @Query private var allLists: [TaskList]

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        profileCard
                        insightsStrip

                        accountSection
                        appearanceSection
                        notificationsSection
                        productivitySection
                        preferencesSection
                        helpSection
                        aboutSection

                        footer
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.top, Tokens.Space.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarHidden(true)
            .onAppear {
                Task { await notifications.refreshAuthorizationStatus() }
                hydrateFirstDayOfWeekIfNeeded()
                hydrateTimeFormatIfNeeded()
                crashLogCount = MetricKitObserver.listLogs().count
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
            .sheet(isPresented: $showingEditProfile) { EditProfileSheet() }
            .sheet(isPresented: $showingRemindersImport) { RemindersImportSheet() }
            .sheet(isPresented: $showingCSVImport) { CSVImportSheet() }
            .sheet(isPresented: $showingHelpFAQ) { HelpFAQSheet() }
            .sheet(isPresented: $showingCrashLogs) { CrashLogsView() }
        }
    }

    // MARK: - Profile card

    private var profileCard: some View {
        Button {
            Haptics.tap()
            showingEditProfile = true
        } label: {
            HStack(spacing: Tokens.Space.md) {
                avatarBadge
                VStack(alignment: .leading, spacing: 4) {
                    Text(authSession.state.user?.displayName ?? "Cadence")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Color.text)
                        .lineLimit(1)
                    emailLine
                    if let memberSince = authSession.state.user?.memberSinceLabel {
                        Text(memberSince.uppercased())
                            .font(Tokens.Font.label)
                            .kerning(1.0)
                            .foregroundStyle(Tokens.Color.text3)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(profileAccessibilityLabel)
    }

    private var avatarBadge: some View {
        let gradient = currentAvatarGradient
        return ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: gradient.colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 64, height: 64)
                .shadow(color: gradient.colors.first!.opacity(0.45), radius: 10, x: 0, y: 4)
            Text(authSession.state.user?.avatarInitials ?? "C")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var currentAvatarGradient: AvatarGradient {
        guard let id = authSession.state.user?.appleUserIdentifier else { return .violet }
        return AvatarGradient.resolve(UserScopedPrefs.avatarColorKey(for: id))
    }

    @ViewBuilder
    private var emailLine: some View {
        let user = authSession.state.user
        if user == nil {
            Text("Not signed in")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text3)
        } else if let user, user.isUsingHiddenEmail {
            Text("Private email")
                .font(.system(size: 13).italic())
                .foregroundStyle(Tokens.Color.text2)
        } else if let email = user?.email, !email.isEmpty {
            Text(email)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text2)
                .lineLimit(1)
        } else {
            Text("Signed in with Apple ID")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text2)
        }
    }

    private var profileAccessibilityLabel: String {
        guard let user = authSession.state.user else { return "Profile. Not signed in." }
        var parts: [String] = ["Profile", user.displayName]
        if user.isUsingHiddenEmail { parts.append("Private email") }
        else if let email = user.email, !email.isEmpty { parts.append(email) }
        if let memberSince = user.memberSinceLabel { parts.append(memberSince) }
        parts.append("Tap to edit.")
        return parts.joined(separator: ". ")
    }

    // MARK: - Insights strip

    private var insightsStrip: some View {
        HStack(spacing: Tokens.Space.sm) {
            statCard(value: completedToday, label: "today", accent: Tokens.Color.accent)
            statCard(value: completedThisWeek, label: "this week", accent: Tokens.Color.teal)
            statCard(value: longestStreak, label: longestStreak == 1 ? "day streak" : "day streak", accent: Tokens.Color.amber, icon: "flame.fill")
        }
    }

    private func statCard(value: Int, label: String, accent: Color, icon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.Color.text)
                    .monospacedDigit()
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
            Text(label.uppercased())
                .font(Tokens.Font.label)
                .kerning(1.1)
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private var completedToday: Int {
        let cal = Calendar.current
        return allTasks.filter { $0.status == .completed && $0.parent == nil
            && ($0.completedAt.map(cal.isDateInToday) ?? false) }.count
    }

    private var completedThisWeek: Int {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -7, to: .now) ?? .now
        return allTasks.filter { $0.status == .completed && $0.parent == nil
            && ($0.completedAt.map { $0 >= cutoff } ?? false) }.count
    }

    /// Build 28: crude longest-current-streak across all habit tasks.
    /// Counts consecutive past days each habit-flagged recurring task
    /// has been completed, then returns the max. Insights drill-in
    /// (Build 29) will replace this with per-habit history.
    private var longestStreak: Int {
        let habits = allTasks.filter { $0.isHabit && $0.parent == nil }
        guard !habits.isEmpty else { return 0 }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var best = 0
        for habit in habits {
            let completedDays = Set((habit.habitCompletions ?? []).map { cal.startOfDay(for: $0.completedOn) })
            var streak = 0
            var cursor = today
            while completedDays.contains(cursor) {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            }
            best = max(best, streak)
        }
        return best
    }

    // MARK: - Section: Account

    private var accountSection: some View {
        section(title: "Account") {
            chevronRow(icon: "applelogo", iconTint: Tokens.Color.text2,
                       title: "Apple ID",
                       subtitle: appleIDSubtitle,
                       destination: AnyView(AppleIDSubscreen()))
            Divider().background(Tokens.Color.borderSoft)
            chevronRow(icon: "calendar.badge.plus", iconTint: Tokens.Color.teal,
                       title: "Connected accounts",
                       subtitle: "Google Calendar and other services.",
                       destination: AnyView(ConnectedAccountsSubscreen()))
            Divider().background(Tokens.Color.borderSoft)
            chevronRow(icon: "lock.shield.fill", iconTint: Tokens.Color.mint,
                       title: "Data & privacy",
                       subtitle: "Export your data or delete your account.",
                       destination: AnyView(DataPrivacySubscreen()))
        }
    }

    private var appleIDSubtitle: String {
        guard let user = authSession.state.user else { return "Sign in with Apple to enable sync." }
        if user.isUsingHiddenEmail { return "Private relay" }
        return user.email ?? "Signed in"
    }

    // MARK: - Section: Appearance

    private var appearanceSection: some View {
        section(title: "Appearance") {
            chevronRow(icon: "paintpalette.fill", iconTint: Tokens.Color.accent,
                       title: "Theme",
                       subtitle: "Accent colors for the whole app.",
                       destination: AnyView(ThemeSubscreen()))
            Divider().background(Tokens.Color.borderSoft)
            chevronRow(icon: "app.badge.fill", iconTint: Tokens.Color.indigo,
                       title: "App icon",
                       subtitle: "8 home-screen icons to choose from.",
                       destination: AnyView(AppIconSubscreen()))
            Divider().background(Tokens.Color.borderSoft)
            lightDarkRow
        }
    }

    private var lightDarkRow: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            SubscreenRowLabel(icon: "moon.circle", text: "Light · Dark · System")
            HStack(spacing: Tokens.Space.sm) {
                ForEach(ThemeChoice.allCases) { choice in
                    themeChip(choice)
                }
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
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

    // MARK: - Section: Notifications

    private var notificationsSection: some View {
        section(title: "Notifications") {
            HStack {
                SubscreenRowLabel(icon: "bell.fill", text: "Reminders enabled")
                Spacer()
                Toggle("", isOn: $notifsEnabled).labelsHidden().tint(Tokens.Color.accent)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            Divider().background(Tokens.Color.borderSoft)
            chevronRow(icon: "sun.max", iconTint: Tokens.Color.amber,
                       title: "Daily morning brief",
                       subtitle: "A friendly nudge with your day's plan.",
                       destination: AnyView(DailyBriefSubscreen()))
            Divider().background(Tokens.Color.borderSoft)
            chevronRow(icon: "moon.zzz.fill", iconTint: Tokens.Color.indigo,
                       title: "Daily review",
                       subtitle: "Look back at what you finished.",
                       destination: AnyView(DailyReviewSubscreen()))
            Divider().background(Tokens.Color.borderSoft)
            chevronRow(icon: "moon.fill", iconTint: Tokens.Color.accent2,
                       title: "Quiet hours",
                       subtitle: "Silence non-urgent reminders at night.",
                       destination: AnyView(QuietHoursSubscreen()))
        }
    }

    // MARK: - Section: Productivity

    private var productivitySection: some View {
        section(title: "Productivity") {
            chevronRow(icon: "timer", iconTint: Tokens.Color.accent,
                       title: "Focus settings",
                       subtitle: "Session length, break, sound, haptic.",
                       destination: AnyView(FocusSubscreen()))
            Divider().background(Tokens.Color.borderSoft)
            chevronRow(icon: "mic.fill", iconTint: Tokens.Color.accent2,
                       title: "Voice & Siri",
                       subtitle: "Sample phrases and Shortcut actions.",
                       destination: AnyView(VoiceSiriSubscreen()))
            Divider().background(Tokens.Color.borderSoft)
            chevronRow(icon: "calendar.day.timeline.left", iconTint: Tokens.Color.teal,
                       title: "Today layout",
                       subtitle: "Coming up window, carried-over collapse.",
                       destination: AnyView(TodayLayoutSubscreen()))
            Divider().background(Tokens.Color.borderSoft)
            chevronRow(icon: "tray.and.arrow.down.fill", iconTint: Tokens.Color.amber,
                       title: "Import data",
                       subtitle: "Apple Reminders or CSV files.",
                       destination: AnyView(ImportSubscreen(
                           onApple: { showingRemindersImport = true },
                           onCSV: { showingCSVImport = true }
                       )))
        }
    }

    // MARK: - Section: Preferences (NEW)

    private var preferencesSection: some View {
        section(title: "Preferences") {
            // First day of week
            HStack {
                SubscreenRowLabel(icon: "calendar", text: "First day of week")
                Spacer()
                Picker("", selection: $firstDayOfWeek) {
                    Text("Sunday").tag(1)
                    Text("Monday").tag(2)
                }
                .labelsHidden()
                .tint(Tokens.Color.accent2)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            Divider().background(Tokens.Color.borderSoft)

            // Time format
            HStack {
                SubscreenRowLabel(icon: "clock", text: "Time format")
                Spacer()
                Picker("", selection: $timeFormat24) {
                    Text("12-hour").tag(false)
                    Text("24-hour").tag(true)
                }
                .labelsHidden()
                .tint(Tokens.Color.accent2)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            Divider().background(Tokens.Color.borderSoft)

            // Default list sort
            HStack {
                SubscreenRowLabel(icon: "arrow.up.arrow.down.circle", text: "Default sort for lists")
                Spacer()
                Picker("", selection: $defaultSortRaw) {
                    ForEach(ListSortPreference.allCases) { opt in
                        Text(opt.displayName).tag(opt.rawValue)
                    }
                }
                .labelsHidden()
                .tint(Tokens.Color.accent2)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            Divider().background(Tokens.Color.borderSoft)

            // Default reminder offset
            HStack {
                SubscreenRowLabel(icon: "bell.badge", text: "Default reminder offset")
                Spacer()
                Picker("", selection: $defaultReminderOffset) {
                    ForEach(ReminderOffsetPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset.rawValue)
                    }
                }
                .labelsHidden()
                .tint(Tokens.Color.accent2)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            Divider().background(Tokens.Color.borderSoft)

            // Default new-task list
            HStack {
                SubscreenRowLabel(icon: "tray.fill", text: "Default new-task list")
                Spacer()
                Picker("", selection: $defaultNewTaskList) {
                    Text("Inbox").tag("inbox")
                    Text("Last used").tag("last-used")
                    ForEach(userLists, id: \.id) { list in
                        Text(list.name).tag(list.id.uuidString)
                    }
                }
                .labelsHidden()
                .tint(Tokens.Color.accent2)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            Divider().background(Tokens.Color.borderSoft)

            // Show completed in Today
            HStack {
                SubscreenRowLabel(icon: "checkmark.seal", text: "Show completed in Today")
                Spacer()
                Toggle("", isOn: $showCompletedInToday).labelsHidden().tint(Tokens.Color.accent)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            Divider().background(Tokens.Color.borderSoft)

            // Show calendar events
            HStack {
                SubscreenRowLabel(icon: "calendar.badge.exclamationmark", text: "Show calendar events")
                Spacer()
                Toggle("", isOn: $showCalendarEvents).labelsHidden().tint(Tokens.Color.accent)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
        }
    }

    private var userLists: [TaskList] {
        allLists.filter { !$0.isHidden && !$0.isSharedAsParticipant }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Section: Help & Support

    private var helpSection: some View {
        section(title: "Help & support") {
            Button {
                Haptics.tap()
                showingHelpFAQ = true
            } label: {
                rowContent(icon: "questionmark.circle.fill",
                           iconTint: Tokens.Color.accent2,
                           title: "Help & FAQ",
                           subtitle: "Searchable answers to common questions.",
                           trailing: { Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Tokens.Color.text3) })
            }
            .buttonStyle(.plain)
            Divider().background(Tokens.Color.borderSoft)
            Button {
                Haptics.tap()
                openSupport()
            } label: {
                rowContent(icon: "envelope.fill",
                           iconTint: Tokens.Color.mint,
                           title: "Contact support",
                           subtitle: "Email support@cadence.app — real human, real reply.",
                           trailing: { Image(systemName: "arrow.up.right.square").font(.system(size: 12, weight: .semibold)).foregroundStyle(Tokens.Color.text3) })
            }
            .buttonStyle(.plain)
            Divider().background(Tokens.Color.borderSoft)
            chevronRow(icon: "sparkles", iconTint: Tokens.Color.amber,
                       title: "What's new",
                       subtitle: "Per-build release notes.",
                       destination: AnyView(WhatsNewSubscreen()))
        }
    }

    private func openSupport() {
        let subject = "Cadence Support: \(authSession.state.user?.displayName ?? "user")"
        let body = "\n\n--- please write above this line ---\nCadence v\(appVersion) (build \(buildNumber))"
        let subj = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let b = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:support@cadence.app?subject=\(subj)&body=\(b)") {
            openURL(url)
        }
    }

    // MARK: - Section: About

    private var aboutSection: some View {
        section(title: "About") {
            HStack {
                SubscreenRowLabel(icon: "app.badge", text: "Cadence")
                Spacer()
                Text("v\(appVersion) · build \(buildNumber)")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text2)
                    .monospacedDigit()
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            Divider().background(Tokens.Color.borderSoft)
            externalLinkRow(icon: "hand.raised.fill", tint: Tokens.Color.accent,
                            title: "Privacy Policy",
                            url: "https://trippcarter.github.io/cadence-ios/privacy")
            Divider().background(Tokens.Color.borderSoft)
            externalLinkRow(icon: "doc.text.fill", tint: Tokens.Color.teal,
                            title: "Terms of Service",
                            url: "https://trippcarter.github.io/cadence-ios/terms")
            Divider().background(Tokens.Color.borderSoft)
            chevronRow(icon: "heart.text.square.fill", iconTint: Tokens.Color.rose,
                       title: "Acknowledgments",
                       subtitle: "Open-source libraries Cadence uses.",
                       destination: AnyView(AcknowledgmentsSubscreen()))
            if crashLogCount > 0 {
                Divider().background(Tokens.Color.borderSoft)
                Button {
                    Haptics.tap()
                    showingCrashLogs = true
                } label: {
                    rowContent(icon: "exclamationmark.octagon",
                               iconTint: Tokens.Color.rose,
                               title: "Crash & diagnostic logs",
                               subtitle: nil,
                               trailing: {
                                   HStack(spacing: 6) {
                                       Text("\(crashLogCount)")
                                           .font(Tokens.Font.caption)
                                           .foregroundStyle(Tokens.Color.text3)
                                           .monospacedDigit()
                                       Image(systemName: "chevron.right")
                                           .font(.system(size: 12, weight: .semibold))
                                           .foregroundStyle(Tokens.Color.text3)
                                   }
                               })
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Generic chrome

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(title.uppercased())
                .font(Tokens.Font.label)
                .kerning(1.0)
                .foregroundStyle(Tokens.Color.text3)
                .padding(.leading, Tokens.Space.sm)
            VStack(spacing: 0) { content() }
                .background(Tokens.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                        .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
                )
        }
    }

    private func chevronRow(icon: String, iconTint: Color, title: String, subtitle: String?, destination: AnyView) -> some View {
        NavigationLink {
            destination
        } label: {
            rowContent(icon: icon, iconTint: iconTint, title: title, subtitle: subtitle,
                       trailing: {
                           Image(systemName: "chevron.right")
                               .font(.system(size: 12, weight: .semibold))
                               .foregroundStyle(Tokens.Color.text3)
                       })
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
    }

    private func rowContent<Trailing: View>(icon: String,
                                             iconTint: Color,
                                             title: String,
                                             subtitle: String?,
                                             @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                        .lineLimit(2)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
        .contentShape(Rectangle())
    }

    private func externalLinkRow(icon: String, tint: Color, title: String, url: String) -> some View {
        Button {
            Haptics.tap()
            if let u = URL(string: url) { openURL(u) }
        } label: {
            rowContent(icon: icon, iconTint: tint, title: title, subtitle: nil,
                       trailing: {
                           Image(systemName: "arrow.up.right.square")
                               .font(.system(size: 12, weight: .semibold))
                               .foregroundStyle(Tokens.Color.text3)
                       })
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        Text("Made with care")
            .font(Tokens.Font.caption)
            .foregroundStyle(Tokens.Color.text3)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, Tokens.Space.lg)
            .padding(.bottom, 120)
    }

    // MARK: - Hydration helpers

    private func hydrateFirstDayOfWeekIfNeeded() {
        if UserDefaults.standard.object(forKey: PrefsKey.firstDayOfWeek) == nil {
            // Calendar.current.firstWeekday: 1 = Sunday, 2 = Monday
            firstDayOfWeek = Calendar.current.firstWeekday
        }
    }

    private func hydrateTimeFormatIfNeeded() {
        if UserDefaults.standard.object(forKey: PrefsKey.timeFormat24Hour) == nil {
            // Inspect the user's locale: a format containing "a" means
            // it uses AM/PM (12h); absence means 24h.
            if let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current) {
                timeFormat24 = !format.contains("a")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}

// MARK: - Import Subscreen (small drill-in for Reminders + CSV)

struct ImportSubscreen: View {
    let onApple: () -> Void
    let onCSV: () -> Void

    var body: some View {
        SubscreenScaffold(title: "Import data") {
            SubscreenCard {
                Button {
                    Haptics.tap()
                    onApple()
                } label: {
                    importRow(icon: "list.bullet.rectangle.portrait.fill",
                              tint: Tokens.Color.accent2,
                              title: "Apple Reminders",
                              subtitle: "Bring in your existing Reminders lists.")
                }
                .buttonStyle(.plain)
                Divider().background(Tokens.Color.borderSoft)
                Button {
                    Haptics.tap()
                    onCSV()
                } label: {
                    importRow(icon: "doc.text.fill",
                              tint: Tokens.Color.indigo,
                              title: "CSV file",
                              subtitle: "Things 3, TickTick, Todoist, or any tool with CSV export.")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func importRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Tokens.Font.bodyEmphasis).foregroundStyle(Tokens.Color.text)
                Text(subtitle).font(Tokens.Font.caption).foregroundStyle(Tokens.Color.text3)
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
}
