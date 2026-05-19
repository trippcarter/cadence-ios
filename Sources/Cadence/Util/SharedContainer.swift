import Foundation
import SwiftData

/// Single source of truth for Cadence's SwiftData container, now split into
/// two configurations:
///
///   1. **Cloud-synced** (TaskItem, TaskList, ConnectedAccount, CalendarConfig)
///      backed by the user's iCloud Private Database via CloudKit. SwiftData
///      handles per-field last-write-wins merge automatically.
///
///   2. **Local-only** (CachedEvent) — Google Calendar events are derived data
///      we can always refetch from Google, so syncing them via CloudKit would
///      waste quota for no benefit. The local config still uses the App Group
///      container path so the widget extension can read events too.
///
/// Both configurations live under the App Group's container URL so the
/// widget process (which holds its own ModelContext) can mount the same
/// underlying SQLite files.
enum CadenceContainer {

    static let appGroupID = "group.net.mcinnis.cadence"
    static let storeName  = "Cadence.sqlite"
    static let localStoreName = "CadenceLocal.sqlite"
    /// CloudKit container identifier — must match the iCloud capability in
    /// project.yml + the App ID in the Apple Developer portal.
    static let cloudContainerID = "iCloud.net.mcinnis.cadence"

    /// Build the shared ModelContainer with cloud + local configurations.
    static func makeContainer() throws -> ModelContainer {
        let unifiedSchema = Schema([
            TaskItem.self,
            TaskList.self,
            ConnectedAccount.self,
            CalendarConfig.self,
            Activity.self,
            Household.self,
            HouseholdMembership.self,
            FocusSession.self,
            HabitCompletion.self,
            ReviewLog.self,
            TomorrowIntention.self,
            DailyWin.self,
            CachedEvent.self
        ])

        let cloudConfig = makeCloudConfig()
        let localConfig = makeLocalConfig()

        return try ModelContainer(
            for: unifiedSchema,
            configurations: [cloudConfig, localConfig]
        )
    }

    // MARK: Cloud-synced configuration

    private static func makeCloudConfig() -> ModelConfiguration {
        let cloudSchema = Schema([
            TaskItem.self,
            TaskList.self,
            ConnectedAccount.self,
            CalendarConfig.self,
            Activity.self,
            Household.self,
            HouseholdMembership.self,
            FocusSession.self,
            HabitCompletion.self,
            ReviewLog.self,
            TomorrowIntention.self,
            DailyWin.self
        ])
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            return ModelConfiguration(
                "Cadence-Cloud",
                schema: cloudSchema,
                url: groupURL.appendingPathComponent(storeName),
                cloudKitDatabase: .private(cloudContainerID)
            )
        }
        // No App Group access (free-dev fallback / unsigned dev builds) — use
        // the default per-app store path. CloudKit sync still works as long
        // as the iCloud entitlement is honored.
        return ModelConfiguration(
            "Cadence-Cloud",
            schema: cloudSchema,
            cloudKitDatabase: .private(cloudContainerID)
        )
    }

    // MARK: Local-only configuration

    private static func makeLocalConfig() -> ModelConfiguration {
        let localSchema = Schema([CachedEvent.self])
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            return ModelConfiguration(
                "Cadence-Local",
                schema: localSchema,
                url: groupURL.appendingPathComponent(localStoreName),
                cloudKitDatabase: .none
            )
        }
        return ModelConfiguration(
            "Cadence-Local",
            schema: localSchema,
            cloudKitDatabase: .none
        )
    }
}
