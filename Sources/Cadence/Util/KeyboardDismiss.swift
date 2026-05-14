import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension View {
    /// Adds a transparent tap-anywhere gesture that resigns the keyboard.
    /// Place this near the top of a form so it doesn't fight your buttons —
    /// the gesture only activates on background hits.
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTap())
    }
}

private struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        #if canImport(UIKit)
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                        #endif
                    }
            )
    }
}
