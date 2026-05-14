import Foundation
import SwiftData

/// Single source of truth for Cadence's SwiftData container.
/// Both the main app (`Cadence`) and the widget extension (`CadenceWidget`)
/// compile this file via project.yml and call `makeContainer()` so they share
/// one SQLite store mounted at the App Group's container URL.
///
/// IMPORTANT: Changing `appGroupID` or `storeName` requires migrating any
/// pre-existing user data. On first launch under a NEW group identifier,
/// SwiftData sees an empty schema and re-runs SeedData → real user tasks
/// would be lost. We accepted this for the pre-1.0 dev environment where
/// only seed/demo data exists.
enum CadenceContainer {

    static let appGroupID = "group.net.mcinnis.cadence"
    static let storeName  = "Cadence.sqlite"

    /// Build the shared ModelContainer.
    ///
    /// If the App Group entitlement isn't authorized at runtime (e.g., free
    /// Apple Developer account on a real device), we fall back to a default
    /// per-app container so the app still functions — at the cost of the
    /// widget not seeing data. The Simulator bypasses signing checks, so the
    /// shared path works for screenshot/dev purposes either way.
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([TaskItem.self, TaskList.self])

        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            let storeURL = groupURL.appendingPathComponent(storeName)
            let config = ModelConfiguration(
                schema: schema,
                url: storeURL
            )
            return try ModelContainer(for: schema, configurations: [config])
        } else {
            // Fallback: per-app default container. Widget won't share state.
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [config])
        }
    }
}
