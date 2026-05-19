import AppIntents

/// Build 20: declares the spoken phrases Siri listens for and maps them to
/// the App Intents shipped above. iOS scans this provider on first launch
/// (and on app updates) to register the phrases with Siri / Spotlight.
///
/// Phrase syntax uses `\(.applicationName)` so users can say "Cadence" OR
/// any of the app's localized names. Parameter slots use `\(\.$paramName)`
/// — the user fills them in via dictation OR Siri prompts if missing.
///
/// `AddTaskToListIntent` is intentionally NOT a separate intent: the
/// AddTaskIntent's `list` parameter is Optional, so "Add X to Cadence" and
/// "Add X to my Family list" both route to the same intent — Siri prompts
/// for the list slot only when the phrase includes it.
@available(iOS 17.0, *)
struct CadenceShortcutsProvider: AppShortcutsProvider {

    /// Tinted phrase color in Shortcuts.app — uses the brand violet.
    static var shortcutTileColor: ShortcutTileColor = .purple

    static var appShortcuts: [AppShortcut] {
        // Apple constraints (learned the hard way): AppShortcut phrases can
        // ONLY reference AppEntity/AppEnum parameters, NOT plain Strings,
        // and a single phrase can include at most one parameter slot.
        // For AddTask the title is a String, so the phrase can't capture
        // it as a slot — Siri prompts the user for it via the @Parameter's
        // dialog UI after they invoke the shortcut.
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task to \(.applicationName)",
                "Add task to \(.applicationName)",
                "New task in \(.applicationName)"
            ],
            shortTitle: "Add task",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: WhatsOnMyPlateIntent(),
            phrases: [
                "What's on my plate today in \(.applicationName)",
                "What's on my plate in \(.applicationName)",
                "What's on my \(.applicationName) plate"
            ],
            shortTitle: "What's on my plate",
            systemImageName: "list.bullet.rectangle.fill"
        )
        AppShortcut(
            intent: CompleteTaskIntent(),
            phrases: [
                "Mark \(\.$task) done in \(.applicationName)",
                "Complete \(\.$task) in \(.applicationName)"
            ],
            shortTitle: "Complete task",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: OpenCadenceIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Launch \(.applicationName)"
            ],
            shortTitle: "Open Cadence",
            systemImageName: "moon.stars.fill"
        )
    }
}
