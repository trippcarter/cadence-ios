import Foundation

/// Parses process arguments for navigation hints. Used by the screenshot
/// pipeline to deterministically land the app on Lists / List Detail / Task
/// Detail without driving the Simulator UI.
///
/// Supported flags:
///   --initial-tab=lists
///   --open-list=Personal
///   --open-task=Sam            (substring match on title, case-insensitive)
enum AppLaunchArgs {

    static var initialTab: AppTab {
        if value(for: "--initial-tab") == "lists" { return .lists }
        if value(for: "--initial-tab") == "week" { return .week }
        if value(for: "--initial-tab") == "you" { return .you }
        return .today
    }

    static var openListName: String? {
        value(for: "--open-list")?.replacingOccurrences(of: "+", with: " ")
    }

    static var openTaskMatching: String? { value(for: "--open-task") }

    /// When present, force `hasOnboarded = true` at app start. Used by the
    /// screenshot pipeline so the onboarding pager doesn't block other screens.
    static var skipOnboarding: Bool {
        CommandLine.arguments.contains("--skip-onboarding")
    }

    /// `--widget-preview=small|medium|large|circular|rectangular|inline|lockall`
    /// short-circuits RootView and renders the WidgetGallery at real WidgetKit
    /// dimensions for clean screenshots.
    static var widgetPreview: String? { value(for: "--widget-preview") }

    /// `--calendar-mode=day|week|month|year` — preselects the Calendar tab's
    /// mode picker. Used by the screenshot pipeline.
    static var calendarMode: String? { value(for: "--calendar-mode") }

    /// `--add-task-prefill=<text>` opens AddTaskSheet at launch with the
    /// given text pre-typed. Useful for screenshotting the NL parser flow.
    /// Spaces should be percent-encoded or use + as space.
    static var addTaskPrefill: String? {
        value(for: "--add-task-prefill")?.replacingOccurrences(of: "+", with: " ")
    }

    private static func value(for key: String) -> String? {
        for arg in CommandLine.arguments {
            if arg.hasPrefix("\(key)=") {
                return String(arg.dropFirst(key.count + 1))
            }
        }
        return nil
    }
}
