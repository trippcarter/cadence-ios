import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// One-line convenience around WidgetCenter to keep call sites tidy and to
/// make the no-op behavior on platforms without WidgetKit (e.g., macOS prior
/// to widget-host support) explicit.
enum WidgetReloader {
    static func reload() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
