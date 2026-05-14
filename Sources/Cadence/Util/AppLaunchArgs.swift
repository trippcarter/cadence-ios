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

    static var openListName: String? { value(for: "--open-list") }

    static var openTaskMatching: String? { value(for: "--open-task") }

    private static func value(for key: String) -> String? {
        for arg in CommandLine.arguments {
            if arg.hasPrefix("\(key)=") {
                return String(arg.dropFirst(key.count + 1))
            }
        }
        return nil
    }
}
