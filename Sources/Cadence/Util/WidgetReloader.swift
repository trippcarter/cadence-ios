import Foundation
import os.log
#if canImport(WidgetKit)
import WidgetKit
#endif

/// One-line convenience around WidgetCenter to keep call sites tidy and to
/// make the no-op behavior on platforms without WidgetKit (e.g., macOS prior
/// to widget-host support) explicit.
///
/// Build 29: every call site passes a short `reason` string that lands in
/// os_log under the "WIDGET" category so we can verify in Console.app
/// that the right mutations trigger reloads.
enum WidgetReloader {
    private static let log = OSLog(subsystem: "net.mcinnis.cadence", category: "WIDGET")

    static func reload(reason: String = "unspecified") {
        os_log("[WIDGET] reloadAllTimelines() — reason: %{public}@", log: log, type: .info, reason)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
