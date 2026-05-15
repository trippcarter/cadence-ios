import Foundation
import SwiftUI
import CloudKit
import SwiftData

/// Owns the `CKShare` lifecycle for per-list sharing.
///
/// Architecture (per Phase 4 plan):
///   - One `CKRecordZone` per shared list, named "Cadence.SharedList.<UUID>".
///   - A root `CKRecord` for the list lives in that zone; `CKShare` references
///     the zone (so all child task records that land there are shared too).
///   - `TaskList.shareRecordName` on the SwiftData model stores the share's
///     `CKRecord.ID.recordName` so we can find the existing share later.
///
/// Phase 4 caveat (documented in code so it's not lost): SwiftData's
/// automatic CloudKit sync is bound to the *default* zone of the private
/// database. The custom-zone records this service writes aren't fed back
/// through SwiftData on the owner's side automatically. Cross-device
/// sharing works for the recipient (they accept the share, records appear
/// in their Shared DB which SwiftData picks up), but the owner side needs
/// follow-up work to keep the local TaskList + custom-zone records in
/// sync. For the initial co-owner roll-out we ship the invitation flow
/// + accept flow + activity log, and iterate on the data round-trip once
/// it's tested on two real devices.
@MainActor
final class CloudKitSharingService: ObservableObject {

    static let shared = CloudKitSharingService()

    private let container: CKContainer
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB:  CKDatabase { container.sharedCloudDatabase }

    @Published private(set) var lastError: String?

    private init() {
        self.container = CKContainer(identifier: CadenceContainer.cloudContainerID)
    }

    // MARK: Share creation / lookup

    /// Returns the existing CKShare for a list, or nil if it isn't shared yet.
    func existingShare(for list: TaskList) async -> CKShare? {
        guard let zone = list.sharedZoneID else { return nil }
        return await fetchShare(in: zone)
    }

    /// Creates (or returns) a CKShare for the given list. Persists the
    /// share-record name on the TaskList so future calls find it.
    ///
    /// Default participant role: read/write (Editor) — the most common
    /// case for a co-owner sharing situation. The caller can adjust on
    /// the system share sheet before sending.
    func makeShare(for list: TaskList, ownerName: String) async throws -> (CKShare, CKContainer) {
        // 1. Make sure the zone exists.
        let zoneID = try await ensureSharedZone(for: list)

        // 2. Look for an existing share in that zone first.
        if let existing = await fetchShare(in: zoneID) {
            return (existing, container)
        }

        // 3. Create a root record for the list in the zone if not already there.
        let rootRecordID = CKRecord.ID(recordName: "list-\(list.id.uuidString)", zoneID: zoneID)
        let rootRecord: CKRecord
        do {
            rootRecord = try await privateDB.record(for: rootRecordID)
        } catch {
            // Doesn't exist yet — create.
            let newRecord = CKRecord(recordType: "CadenceList", recordID: rootRecordID)
            newRecord["name"] = list.name as CKRecordValue
            newRecord["colorKey"] = list.colorKey as CKRecordValue
            newRecord["iconKey"] = list.iconKey as CKRecordValue
            rootRecord = newRecord
        }

        // 4. Create + save the share.
        let share = CKShare(rootRecord: rootRecord)
        share[CKShare.SystemFieldKey.title] = "Cadence — \(list.name)" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = "net.mcinnis.cadence.list" as CKRecordValue
        share.publicPermission = .none // Invite-only, no public link

        let result = try await privateDB.modifyRecords(saving: [rootRecord, share], deleting: [])
        // Verify both saved
        for (_, saveResult) in result.saveResults {
            if case .failure(let err) = saveResult { throw err }
        }

        // 5. Persist on the TaskList so subsequent shares find this share.
        list.shareRecordName = share.recordID.recordName
        return (share, container)
    }

    /// Stop sharing — deletes the share, the root record, and the entire zone.
    func stopSharing(_ list: TaskList) async throws {
        guard let zoneID = list.sharedZoneID else { return }
        try await privateDB.modifyRecordZones(saving: [], deleting: [zoneID])
        list.shareRecordName = nil
    }

    // MARK: Participants

    /// Fetch the current participants on a shared list. The owner is always
    /// the first participant returned. Use to render avatars + roles.
    func participants(for list: TaskList) async -> [CKShare.Participant] {
        guard let share = await existingShare(for: list) else { return [] }
        return share.participants
    }

    // MARK: Accept incoming share

    /// Called from the scene delegate when iOS hands us a CKShareMetadata
    /// (user tapped a share URL). The records land in the user's Shared DB;
    /// SwiftData's CloudKit mirror picks them up automatically on the next
    /// sync tick.
    func accept(shareMetadata: CKShare.Metadata) async throws -> CKShare {
        try await container.accept(shareMetadata)
    }

    // MARK: Internals

    private func ensureSharedZone(for list: TaskList) async throws -> CKRecordZone.ID {
        if let existing = list.sharedZoneID {
            return existing
        }
        let zoneName = "Cadence.SharedList.\(list.id.uuidString)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await privateDB.modifyRecordZones(saving: [zone], deleting: [])
        return zoneID
    }

    private func fetchShare(in zoneID: CKRecordZone.ID) async -> CKShare? {
        do {
            let query = CKQuery(recordType: CKRecord.SystemType.share, predicate: NSPredicate(value: true))
            let result = try await privateDB.records(
                matching: query,
                inZoneWith: zoneID,
                desiredKeys: nil,
                resultsLimit: 1
            )
            for (_, recordResult) in result.matchResults {
                if case .success(let record) = recordResult, let share = record as? CKShare {
                    return share
                }
            }
            return nil
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
}

// MARK: - TaskList helpers

extension TaskList {
    /// Derives the zone ID from the share record name we persisted on the
    /// list. nil = list isn't shared yet.
    var sharedZoneID: CKRecordZone.ID? {
        guard shareRecordName != nil else { return nil }
        let zoneName = "Cadence.SharedList.\(id.uuidString)"
        return CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    var isShared: Bool { shareRecordName != nil }
}
