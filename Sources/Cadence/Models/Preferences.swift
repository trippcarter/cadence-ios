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
