import SwiftUI

/// User-tunable preferences. All values persist via @AppStorage so they
/// survive launches and (eventually) sync via NSUbiquitousKeyValueStore in
/// Phase 2.
enum PrefsKey {
    static let hasOnboarded             = "hasOnboarded"
    static let dailyBriefHour           = "dailyBriefHour"
    static let dailyBriefMinute         = "dailyBriefMinute"
    static let rolloverPolicy           = "defaultRolloverPolicy"   // RolloverPolicy.rawValue
    static let themeChoice              = "themeChoice"             // ThemeChoice.rawValue
    static let notificationsEnabled     = "notificationsEnabled"    // master switch

    // Two-way Google Calendar sync (Phase 7a)
    /// Google calendar ID the user picked as the default destination when
    /// time-blocking new tasks. nil = ask each time / use account primary.
    static let defaultMirrorCalendarID  = "defaultMirrorCalendarID"
    /// When true, new tasks with a specific time auto-toggle isTimeBlocked=true
    /// on save. Default false — opt-in.
    static let autoMirrorTimeBlocked    = "autoMirrorTimeBlocked"

    /// Set to true the first time the user dismisses (or completes) the
    /// post-sign-in template gallery, so we don't auto-present it again.
    /// Users can still open it manually via the Lists tab "From template"
    /// button at any time.
    ///
    /// NOTE: Build 11 onward — this is keyed per Apple-Sign-In identifier
    /// via `UserScopedPrefs.hasSeenTemplateGallery(for:)`. The bare key
    /// here is the legacy device-wide flag, still used as a migration
    /// fallback for users upgrading from Build 10.
    static let hasSeenTemplateGallery   = "hasSeenTemplateGallery"

    // Focus mode (Build 18)
    /// Planned focus-session length in minutes. Default 25 (classic Pomodoro).
    static let focusDurationMinutes     = "focusDurationMinutes"
    /// Break-suggestion length in minutes shown after a completed session.
    static let focusBreakMinutes        = "focusBreakMinutes"
    /// Play the gentle completion bell when a session naturally ends.
    static let focusPlaySound           = "focusPlaySound"
    /// Fire a success notification haptic when a session naturally ends.
    static let focusPlayHaptic          = "focusPlayHaptic"
    /// Auto-start the next focus session as soon as the break ends.
    static let focusAutoStartNext       = "focusAutoStartNext"

    // Daily review (Build 18)
    /// Enable the evening review notification + sheet entry point.
    static let dailyReviewEnabled       = "dailyReviewEnabled"
    /// Hour-of-day (0-23) for the review notification fire.
    static let dailyReviewHour          = "dailyReviewHour"
    /// Minute-of-hour for the review notification fire.
    static let dailyReviewMinute        = "dailyReviewMinute"

    // Theme + icon personalization (Build 24)
    /// AppTheme.rawValue. Drives Tokens.Color.accent / accent2 / accentDeep
    /// / accentGlow at render time via ThemeManager.shared.
    static let themeKey                 = "themeKey"
    /// Currently-selected alternate app icon name. nil = default.
    static let alternateIconName        = "alternateIconName"

    // Today reorg (Build 25)
    /// Toggle for whether Today shows the "Coming up" section (tasks
    /// due in the next N days). Default ON.
    static let showComingUpSection      = "showComingUpSection"
    /// How far ahead the "Coming up" section looks. Default 7 days.
    static let comingUpWindowDays       = "comingUpWindowDays"
    /// Threshold above which the "Carried over" section auto-collapses
    /// on first render. Default 3 — keeps Today clean when there's a
    /// lot of backlog without hiding it entirely.
    static let autoCollapseCarriedThreshold = "autoCollapseCarriedThreshold"

    // You-tab restructure (Build 28) — new preferences. UI saves the
    // values; deeper propagation through date formatters / calendar
    // start day / NotificationManager quiet-hour suppression ships in
    // Build 29.

    /// 1 = Sunday, 2 = Monday. Default reads Calendar.current.firstWeekday
    /// on first launch.
    static let firstDayOfWeek           = "firstDayOfWeek"
    /// false = 12-hour (3:30 PM), true = 24-hour (15:30). Default reads
    /// Locale.current.uses24HourTime on first launch.
    static let timeFormat24Hour         = "timeFormat24Hour"
    /// Default sort applied to newly-opened lists. ListSortPreference.rawValue.
    static let defaultListSort          = "defaultListSort"
    /// Pre-selected reminder offset in seconds when the user opens "Add
    /// task" with no list-default override. Encoded as a Double; -1 = none,
    /// 0 = at due time, negative numbers = N seconds before.
    static let defaultReminderOffset    = "defaultReminderOffset"
    /// Destination list for new tasks created via the global "+" button.
    /// "inbox" = always Inbox; "last-used" = whichever list the user
    /// last added to; otherwise a TaskList.id.uuidString.
    static let defaultNewTaskList       = "defaultNewTaskList"
    /// Whether the Today view shows already-completed tasks below the
    /// open ones. Default ON.
    static let showCompletedInToday     = "showCompletedInToday"
    /// Master toggle for displaying Google Calendar events on Today /
    /// Calendar / Week / Day views. Connection state lives elsewhere;
    /// this just hides the events without disconnecting.
    static let showCalendarEvents       = "showCalendarEvents"

    // Quiet hours (Build 28)
    /// Whether quiet hours suppress non-time-sensitive reminders.
    static let quietHoursEnabled        = "quietHoursEnabled"
    /// Hour-of-day (0-23) when quiet hours start. Default 22 (10 PM).
    static let quietHoursStartHour      = "quietHoursStartHour"
    static let quietHoursStartMinute    = "quietHoursStartMinute"
    /// Hour-of-day (0-23) when quiet hours end. Default 7 (7 AM).
    static let quietHoursEndHour        = "quietHoursEndHour"
    static let quietHoursEndMinute      = "quietHoursEndMinute"
    /// When true, reminders flagged time-sensitive (the iOS interruption
    /// level) still fire during quiet hours.
    static let quietHoursAllowTimeSensitive = "quietHoursAllowTimeSensitive"

    // Calendar event reminders (Build 31)
    /// When ON, every Google Calendar event synced into Cadence gets a
    /// local notification at the default reminder offset. Default ON.
    static let calendarEventRemindersEnabled = "calendarEventRemindersEnabled"

    // One-shot migration flags (Build 30 / 31)
    /// Build 31: bumps the default reminder offset from "None" to
    /// "10 min before" for users who never changed it. Runs once.
    static let migratedReminderDefaultBuild31 = "migratedReminderDefaultBuild31"
    /// Marks that the Build 30 carried-over threshold rebalance has been
    /// applied to this device. Users on the previous 3/5 default get
    /// bumped to 10 once so the new expanded-by-default behavior takes
    /// effect without them having to re-enter Settings.
    static let migratedCarriedThresholdBuild30 = "migratedCarriedThresholdBuild30"

    // Profile avatar color (Build 28)
    /// Picked gradient identifier for the user's avatar circle. Per-user
    /// (keyed via UserScopedPrefs). Falls back to violet→indigo default
    /// when unset.
    static let avatarColorKey           = "avatarColorKey"
}

/// Built-in sort options offered by the per-list sort menu and the
/// new "Default sort for lists" preference. Build 28.
enum ListSortPreference: String, CaseIterable, Identifiable {
    case manual
    case dueDate
    case priority
    case alphabetical

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual:       return "Manual"
        case .dueDate:      return "Due date"
        case .priority:     return "Priority"
        case .alphabetical: return "Alphabetical"
        }
    }
}

/// User-pickable reminder offsets for the "Default reminder time"
/// preference. Encoded as seconds; -1 sentinel = no default. Build 28,
/// extended Build 31 with 10- and 15-minute options.
enum ReminderOffsetPreset: TimeInterval, CaseIterable, Identifiable {
    case none      = -1
    case atDue     = 0
    case fiveMin   = -300
    case tenMin    = -600
    case fifteenMin = -900
    case thirtyMin = -1800
    case oneHour   = -3600
    case oneDay    = -86400

    var id: TimeInterval { rawValue }

    var displayName: String {
        switch self {
        case .none:       return "None"
        case .atDue:      return "At time"
        case .fiveMin:    return "5 min before"
        case .tenMin:     return "10 min before"
        case .fifteenMin: return "15 min before"
        case .thirtyMin:  return "30 min before"
        case .oneHour:    return "1 hr before"
        case .oneDay:     return "1 day before"
        }
    }

    /// Short label for the inline reminder chip in AddTaskSheet.
    var chipLabel: String {
        switch self {
        case .none:       return "No reminder"
        case .atDue:      return "At time"
        case .fiveMin:    return "5 min before"
        case .tenMin:     return "10 min before"
        case .fifteenMin: return "15 min before"
        case .thirtyMin:  return "30 min before"
        case .oneHour:    return "1 hr before"
        case .oneDay:     return "1 day before"
        }
    }

    static func resolve(_ rawValue: Double) -> ReminderOffsetPreset {
        ReminderOffsetPreset(rawValue: rawValue) ?? .tenMin
    }
}

/// Per-Apple-Sign-In-identifier preferences. Different users on the same
/// device each get their own template-gallery-seen flag and editable
/// display name. Keys are composed as `<prefKey>_<identifier>`.
///
/// Added in Build 11 to fix:
///   - Bug 1: template gallery re-appearing for a second user on the same
///     device because the seen flag was device-wide.
///   - Bug 3: user-set display name that survives across signOut/signIn
///     and is per-account (so two users on one device don't share a name).
enum UserScopedPrefs {

    // MARK: Template gallery

    static func hasSeenTemplateGallery(for identifier: String) -> Bool {
        UserDefaults.standard.bool(forKey: "hasSeenTemplateGallery_\(identifier)")
    }

    static func setHasSeenTemplateGallery(_ value: Bool, for identifier: String) {
        UserDefaults.standard.set(value, forKey: "hasSeenTemplateGallery_\(identifier)")
    }

    // MARK: User-set display name

    /// The name the user explicitly chose (or accepted) in Settings →
    /// Display Name OR in the first-run name prompt. Highest priority in
    /// the displayName resolution chain — overrides Apple's fullName even
    /// if Apple supplied one.
    static func userDisplayName(for identifier: String) -> String? {
        let raw = UserDefaults.standard.string(forKey: "userDisplayName_\(identifier)")
        guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return raw
    }

    static func setUserDisplayName(_ value: String?, for identifier: String) {
        let trimmed = value?.trimmingCharacters(in: .whitespaces)
        if let trimmed, !trimmed.isEmpty {
            UserDefaults.standard.set(trimmed, forKey: "userDisplayName_\(identifier)")
        } else {
            UserDefaults.standard.removeObject(forKey: "userDisplayName_\(identifier)")
        }
    }

    // MARK: User avatar color (Build 28)

    /// The avatar gradient the user picked in the new EditProfileSheet.
    /// One of AvatarGradient.allCases.rawValue. Falls back to .violet
    /// when nil.
    static func avatarColorKey(for identifier: String) -> String? {
        let raw = UserDefaults.standard.string(forKey: "avatarColorKey_\(identifier)")
        guard let raw, !raw.isEmpty else { return nil }
        return raw
    }

    static func setAvatarColorKey(_ value: String?, for identifier: String) {
        if let value, !value.isEmpty {
            UserDefaults.standard.set(value, forKey: "avatarColorKey_\(identifier)")
        } else {
            UserDefaults.standard.removeObject(forKey: "avatarColorKey_\(identifier)")
        }
    }
}

/// Build 28: pickable avatar gradient palette in EditProfileSheet.
/// Each case maps to a (start, end) color pair used by LinearGradient.
enum AvatarGradient: String, CaseIterable, Identifiable {
    case violet
    case indigo
    case ocean
    case mint
    case forest
    case amber
    case rose
    case mono

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .violet: return "Violet"
        case .indigo: return "Indigo"
        case .ocean:  return "Ocean"
        case .mint:   return "Mint"
        case .forest: return "Forest"
        case .amber:  return "Amber"
        case .rose:   return "Rose"
        case .mono:   return "Mono"
        }
    }

    var colors: [Color] {
        switch self {
        case .violet: return [Color(hex: 0x7C5CFF), Color(hex: 0x5B3CFA)]
        case .indigo: return [Color(hex: 0x6366F1), Color(hex: 0x4338CA)]
        case .ocean:  return [Color(hex: 0x06B6D4), Color(hex: 0x0E7490)]
        case .mint:   return [Color(hex: 0x34D399), Color(hex: 0x059669)]
        case .forest: return [Color(hex: 0x16A34A), Color(hex: 0x065F46)]
        case .amber:  return [Color(hex: 0xF59E0B), Color(hex: 0xB45309)]
        case .rose:   return [Color(hex: 0xFB7185), Color(hex: 0xBE123C)]
        case .mono:   return [Color(hex: 0x4B5563), Color(hex: 0x111827)]
        }
    }

    static func resolve(_ rawValue: String?) -> AvatarGradient {
        guard let rawValue, let g = AvatarGradient(rawValue: rawValue) else { return .violet }
        return g
    }
}

/// Three-way theme picker. Applied at the app root via .preferredColorScheme.
enum ThemeChoice: String, CaseIterable, Identifiable {
    case dark
    case light
    case system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark:   return "Dark"
        case .light:  return "Light"
        case .system: return "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark:   return .dark
        case .light:  return .light
        case .system: return nil
        }
    }
}

extension RolloverPolicy {
    var displayName: String {
        switch self {
        case .on:  return "On"
        case .ask: return "Ask each morning"
        case .off: return "Off"
        }
    }

    var subtitle: String {
        switch self {
        case .on:  return "Carry incomplete tasks to today"
        case .ask: return "Prompt me first thing each day"
        case .off: return "Show as overdue, don't move"
        }
    }
}
