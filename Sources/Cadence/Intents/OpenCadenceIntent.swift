import AppIntents

/// Build 20: "Hey Siri, open Cadence."
///
/// Useful for Shortcuts automations (e.g., morning routine: "Every weekday
/// at 7am, open Cadence"). Apple opens the app to its last state.
@available(iOS 17.0, *)
struct OpenCadenceIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Cadence"
    static var description = IntentDescription("Open the Cadence app.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
