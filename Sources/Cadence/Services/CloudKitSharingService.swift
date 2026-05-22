import Foundation
import SwiftUI
import CloudKit
import SwiftData
import os.log

/// Build 31: shared logger for the sharing subsystem. Filter Console.app
/// by subsystem `net.mcinnis.cadence` category `SHARING` — every line
/// is also tagged `[Build 31][Sharing]` in the message text.
let sharingLog = OSLog(subsystem: "net.mcinnis.cadence", category: "SHARING")

/// Owns the `CKShare` lifecycle for per-list sharing.
///
/// Architecture (Phase 4 + Phase 9 expansion):
///   - One `CKRecordZone` per shared list, named "Cadence.SharedList.<UUID>".
///   - A root `CKRecord` for the list lives in that zone; `CKShare` references
///     the zone so all child task records that land there are shared too.
///   - `TaskList.shareRecordName` stores the share's `recordName`.
///   - When a list is shared, every `TaskItem` is *also* mirrored into the
///     shared zone as a `CadenceTask` CKRecord. See `SharedListMirror` for
///     the ongoing mutation-pump.
///
/// SwiftData remains the local source of truth on both sides. CloudKit
/// replicates the shared-zone records between owner Private DB and recipient
/// Shared DB; this service writes/reads those records and `SharedListMirror`
/// keeps SwiftData in lockstep.
@MainActor
final class CloudKitSharingService: ObservableObject {

    static let shared = CloudKitSharingService()

    let container: CKContainer
    var privateDB: CKDatabase { container.privateCloudDatabase }
    var sharedDB:  CKDatabase { container.sharedCloudDatabase }

    @Published private(set) var lastError: String?

    private init() {
        self.container = CKContainer(identifier: CadenceContainer.cloudContainerID)
    }

    // MARK: Record types

    static let listRecordType = "CadenceList"
    static let taskRecordType = "CadenceTask"

    // MARK: Share creation / lookup

    /// Returns the existing CKShare for a list, or nil if it isn't shared yet.
    func existingShare(for list: TaskList) async -> CKShare? {
        guard let zone = list.sharedZoneID else { return nil }
        return await fetchShare(in: zone, database: privateDB)
    }

    /// Creates (or returns) a CKShare for the given list. Persists the
    /// share-record name on the TaskList so future calls find it.
    ///
    /// On creation we also mirror every TaskItem currently in the list into
    /// the shared zone — that's what makes the shared content visible to
    /// recipients (vs. the empty-zone behavior pre-Phase-9).
    ///
    /// Default participant role: read/write (Editor) — caller can adjust on
    /// the system share sheet before sending.
    func makeShare(for list: TaskList, ownerName: String) async throws -> (CKShare, CKContainer) {
        os_log("[Build 31][Sharing] makeShare start — list=%{public}@", log: sharingLog, type: .info, list.name)

        // Build 31: verify the user is actually signed into iCloud before
        // we attempt any CloudKit write. A signed-out account is the most
        // common cause of share creation failing outright.
        let accountStatus = try await container.accountStatus()
        os_log("[Build 31][Sharing] CKAccountStatus = %{public}d", log: sharingLog, type: .info, accountStatus.rawValue)
        guard accountStatus == .available else {
            os_log("[Build 31][Sharing] aborting — iCloud account not available", log: sharingLog, type: .error)
            throw ShareError.iCloudUnavailable
        }

        let zoneID = try await ensureSharedZone(for: list)
        os_log("[Build 31][Sharing] zone ready — %{public}@", log: sharingLog, type: .info, zoneID.zoneName)

        if let existing = await fetchShare(in: zoneID, database: privateDB) {
            os_log("[Build 31][Sharing] reusing existing share — url=%{public}@",
                   log: sharingLog, type: .info, existing.url?.absoluteString ?? "<nil>")
            return (existing, container)
        }

        let rootRecordID = CKRecord.ID(recordName: "list-\(list.id.uuidString)", zoneID: zoneID)
        let rootRecord: CKRecord
        do {
            rootRecord = try await privateDB.record(for: rootRecordID)
            applyListFields(rootRecord, list: list, ownerDisplayName: ownerName)
        } catch {
            let newRecord = CKRecord(recordType: Self.listRecordType, recordID: rootRecordID)
            applyListFields(newRecord, list: list, ownerDisplayName: ownerName)
            rootRecord = newRecord
        }

        let share = CKShare(rootRecord: rootRecord)
        share[CKShare.SystemFieldKey.title] = "Cadence — \(list.name)" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = "net.mcinnis.cadence.list" as CKRecordValue
        share.publicPermission = .none

        // First commit: list root + share itself.
        let firstBatch = try await privateDB.modifyRecords(saving: [rootRecord, share], deleting: [])
        for (_, result) in firstBatch.saveResults {
            if case .failure(let err) = result {
                os_log("[Build 31][Sharing] root/share save FAILED: %{public}@",
                       log: sharingLog, type: .error, err.localizedDescription)
                throw err
            }
        }

        list.shareRecordName = share.recordID.recordName
        os_log("[Build 31][Sharing] share created — url=%{public}@ recordName=%{public}@",
               log: sharingLog, type: .info,
               share.url?.absoluteString ?? "<nil — will populate after sync>",
               share.recordID.recordName)

        // Second commit: mirror every existing TaskItem into the zone so
        // recipients see content as soon as they accept the share.
        let taskRecords = list.taskList.map { task -> CKRecord in
            let recordID = makeTaskRecordID(taskID: task.id, zoneID: zoneID)
            let record = CKRecord(recordType: Self.taskRecordType, recordID: recordID)
            applyTaskFields(record, task: task, listRootID: rootRecordID)
            task.cloudRecordName = recordID.recordName
            return record
        }
        if !taskRecords.isEmpty {
            let result = try await privateDB.modifyRecords(saving: taskRecords, deleting: [])
            for (_, saveResult) in result.saveResults {
                if case .failure(let err) = saveResult {
                    NSLog("[Cadence-Share] mirror-on-create save failed: %@", err.localizedDescription)
                }
            }
        }

        return (share, container)
    }

    /// Stop sharing — deletes the share, the root record, and the entire zone.
    /// Local TaskItems stay (the list reverts to private) but their cloud
    /// record names are wiped so a future re-share starts fresh.
    func stopSharing(_ list: TaskList) async throws {
        guard let zoneID = list.sharedZoneID else { return }
        try await privateDB.modifyRecordZones(saving: [], deleting: [zoneID])
        list.shareRecordName = nil
        list.shareZoneChangeToken = nil
        for task in list.taskList {
            task.cloudRecordName = nil
        }
    }

    // MARK: Participants

    func participants(for list: TaskList) async -> [CKShare.Participant] {
        guard let share = await existingShare(for: list) else { return [] }
        return share.participants
    }

    // MARK: Accept incoming share

    func accept(shareMetadata: CKShare.Metadata) async throws -> CKShare {
        os_log("[Build 31][Sharing] accepting share — title=%{public}@",
               log: sharingLog, type: .info,
               (shareMetadata.share[CKShare.SystemFieldKey.title] as? String) ?? "<untitled>")
        do {
            let share = try await container.accept(shareMetadata)
            os_log("[Build 31][Sharing] accept SUCCEEDED", log: sharingLog, type: .info)
            return share
        } catch {
            os_log("[Build 31][Sharing] accept FAILED: %{public}@",
                   log: sharingLog, type: .error, error.localizedDescription)
            throw error
        }
    }

    // MARK: Build 31 errors

    enum ShareError: LocalizedError {
        case iCloudUnavailable

        var errorDescription: String? {
            switch self {
            case .iCloudUnavailable:
                return "Sign into iCloud in Settings to share Spaces."
            }
        }
    }

    // MARK: Internals (zone setup + share lookup)

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

    private func fetchShare(in zoneID: CKRecordZone.ID, database: CKDatabase) async -> CKShare? {
        do {
            let query = CKQuery(recordType: CKRecord.SystemType.share, predicate: NSPredicate(value: true))
            let result = try await database.records(
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

    // MARK: Record field application

    func applyListFields(_ record: CKRecord, list: TaskList, ownerDisplayName: String) {
        record["name"] = list.name as CKRecordValue
        record["colorKey"] = list.colorKey as CKRecordValue
        record["iconKey"] = list.iconKey as CKRecordValue
        record["ownerDisplayName"] = ownerDisplayName as CKRecordValue
        record["modifiedAt"] = list.modifiedAt as CKRecordValue
    }

    func applyTaskFields(_ record: CKRecord, task: TaskItem, listRootID: CKRecord.ID) {
        record["id"] = task.id.uuidString as CKRecordValue
        record["title"] = task.title as CKRecordValue
        if let notes = task.notes {
            record["notes"] = notes as CKRecordValue
        } else {
            record["notes"] = nil
        }
        if let due = task.dueDate {
            record["dueDate"] = due as CKRecordValue
        } else {
            record["dueDate"] = nil
        }
        record["allDay"] = task.allDay as CKRecordValue
        record["priority"] = task.priority.rawValue as CKRecordValue
        record["status"] = task.status.rawValue as CKRecordValue
        if let completedAt = task.completedAt {
            record["completedAt"] = completedAt as CKRecordValue
        } else {
            record["completedAt"] = nil
        }
        if let rrule = task.rruleString {
            record["rruleString"] = rrule as CKRecordValue
        } else {
            record["rruleString"] = nil
        }
        if let parent = task.parent {
            record["parentTaskID"] = parent.id.uuidString as CKRecordValue
        } else {
            record["parentTaskID"] = nil
        }
        record["modifiedAt"] = task.modifiedAt as CKRecordValue
        record["listRef"] = CKRecord.Reference(recordID: listRootID, action: .deleteSelf)
    }

    // MARK: Record ID helpers

    func makeTaskRecordID(taskID: UUID, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "task-\(taskID.uuidString)", zoneID: zoneID)
    }

    func makeListRecordID(listID: UUID, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "list-\(listID.uuidString)", zoneID: zoneID)
    }

    // MARK: Database selection

    /// Owners read/write the Private DB; recipients use the Shared DB.
    /// The choice is per-list because each list can be one or the other.
    func database(for list: TaskList) -> CKDatabase {
        list.isSharedAsParticipant ? sharedDB : privateDB
    }

    /// Construct the zone ID for a list. Owner-side uses CKCurrentUserDefaultName;
    /// recipient-side uses the owner's user record name captured at accept time.
    func zoneID(for list: TaskList) -> CKRecordZone.ID? {
        let zoneName = "Cadence.SharedList.\(list.id.uuidString)"
        if list.isSharedAsParticipant {
            guard let ownerName = list.shareZoneOwnerName else { return nil }
            return CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        }
        guard list.shareRecordName != nil else { return nil }
        return CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }
}

// MARK: - TaskList helpers

extension TaskList {
    /// Derives the OWNER-side zone ID from the share record name we persisted
    /// on the list. nil for recipients (use `CloudKitSharingService.zoneID(for:)`
    /// instead, which handles both sides).
    var sharedZoneID: CKRecordZone.ID? {
        guard shareRecordName != nil, !isSharedAsParticipant else { return nil }
        let zoneName = "Cadence.SharedList.\(id.uuidString)"
        return CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    /// Either owner-side or recipient-side: the list participates in a share.
    var isShared: Bool {
        shareRecordName != nil || isSharedAsParticipant
    }
}
