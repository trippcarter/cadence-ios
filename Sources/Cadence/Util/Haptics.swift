import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Tiny wrapper so feature code can call `Haptics.success()` without
/// littering #if canImport(UIKit) everywhere. No-ops on macOS.
enum Haptics {

    static func success() {
        #if canImport(UIKit) && !os(watchOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }

    static func tap() {
        #if canImport(UIKit) && !os(watchOS)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    /// Soft buzz used right before a destructive action confirmation appears.
    static func warning() {
        #if canImport(UIKit) && !os(watchOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        #endif
    }
}
