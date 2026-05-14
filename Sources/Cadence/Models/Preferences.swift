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
