import Foundation
import SwiftUI
import CloudKit
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Layer above SwiftData's automatic CloudKit sync — exposes what the UI
/// needs to render account/sync status that SwiftData doesn't surface
/// directly:
///   - Current CKAccountStatus (signed-in / no account / restricted)
///   - The account's iCloud user identity (the Apple ID's recordName + email)
///   - Most-recent successful sync timestamp (best-effort, updated on
///     remote-change notifications)
///   - Manual "refresh now" trigger
///
/// SwiftData drives the actual record CRUD; this manager doesn't read or
/// write CKRecords itself.
@MainActor
final class CloudKitSyncManager: ObservableObject {

    static let shared = CloudKitSyncManager()

    /// Set to the same identifier as SharedContainer.cloudContainerID.
    private let container: CKContainer

    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published private(set) var userEmail: String?
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastError: SyncError?

    private var hasRegisteredSubscription = false

    private init() {
        self.container = CKContainer(identifier: CadenceContainer.cloudContainerID)
        observeAccountChangeNotifications()
    }

    // MARK: Public

    /// Call once at app launch. Idempotent — repeat calls are cheap.
    func bootstrap() async {
        await refreshAccountStatus()
        await registerSubscriptionsIfNeeded()
        if accountStatus == .available {
            // SwiftData will fetch and merge on its own once the container
            // opens; record the timestamp so the UI can render "Up to date".
            lastSyncedAt = .now
        }
    }

    func refreshAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            self.accountStatus = status
            if status == .available {
                await fetchUserEmail()
            } else {
                userEmail = nil
            }
        } catch {
            lastError = .accountStatus(error)
        }
    }

    /// User-driven manual refresh. SwiftData has no "force push/pull" API
    /// (CoreData/CloudKit replication is internal), but we can: (a) ping
    /// the container, (b) bounce the timestamp so the UI updates, and
    /// (c) reload widgets on the chance that recent remote changes
    /// arrived since the last timeline.
    func refreshNow() async {
        guard accountStatus == .available else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            _ = try await container.userRecordID()
            lastSyncedAt = .now
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            lastError = .refresh(error)
        }
    }

    // MARK: Subscriptions

    /// Register a single subscription on the private database that fires a
    /// silent push whenever any record in our zone changes. SwiftData
    /// handles the actual merge — we just want the wake-up so widget
    /// timelines and the in-app sync indicator stay fresh.
    private func registerSubscriptionsIfNeeded() async {
        guard !hasRegisteredSubscription, accountStatus == .available else { return }
        let subscriptionID = "cadence.private.changes"
        let db = container.privateCloudDatabase

        // Look for an existing subscription so we don't duplicate on every launch.
        do {
            let existing = try await db.allSubscriptions()
            if existing.contains(where: { $0.subscriptionID == subscriptionID }) {
                hasRegisteredSubscription = true
                return
            }
        } catch {
            // Non-fatal — we'll try to add anyway below.
        }

        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true // silent push
        subscription.notificationInfo = info

        do {
            _ = try await db.modifySubscriptions(saving: [subscription], deleting: [])
            hasRegisteredSubscription = true
        } catch {
            lastError = .subscription(error)
        }
    }

    /// Call from APNs delegate handlers when a CKNotification arrives.
    /// SwiftData merges automatically — we mark the timestamp + reload widgets.
    func handleRemoteChange() async {
        lastSyncedAt = .now
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: User email

    private func fetchUserEmail() async {
        // CKUserIdentity gives us the Apple-ID-associated email when the
        // user has discovery enabled. Best-effort — failures degrade to nil.
        do {
            let id = try await container.userRecordID()
            let userIdentity = try await container.userIdentity(forUserRecordID: id)
            if let components = userIdentity?.nameComponents {
                let formatter = PersonNameComponentsFormatter()
                userEmail = formatter.string(from: components)
            } else if let lookupInfo = userIdentity?.lookupInfo {
                userEmail = lookupInfo.emailAddress
            }
        } catch {
            // Best-effort; the user might not have enabled the contact-discovery
            // CloudKit option. Falling back to nil is fine.
        }
    }

    // MARK: Account-change observer

    private func observeAccountChangeNotifications() {
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.refreshAccountStatus() }
        }
    }

    // MARK: Errors

    enum SyncError: Error {
        case accountStatus(Error)
        case subscription(Error)
        case refresh(Error)

        var displayMessage: String {
            switch self {
            case .accountStatus(let e): return "Couldn't check iCloud account: \(e.localizedDescription)"
            case .subscription(let e):  return "Couldn't register sync subscription: \(e.localizedDescription)"
            case .refresh(let e):       return "Refresh failed: \(e.localizedDescription)"
            }
        }
    }
}

// MARK: - CKAccountStatus display helpers

extension CKAccountStatus {
    var displayLabel: String {
        switch self {
        case .available:           return "Signed in to iCloud"
        case .noAccount:           return "Not signed in to iCloud"
        case .restricted:          return "iCloud restricted on this device"
        case .couldNotDetermine:   return "Checking iCloud…"
        case .temporarilyUnavailable: return "iCloud temporarily unavailable"
        @unknown default:          return "Unknown iCloud status"
        }
    }
}
