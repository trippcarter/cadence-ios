import Foundation
import SwiftData
import CloudKit
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Bridges SwiftData (local source of truth) ↔ CloudKit custom-zone records
/// (the wire format CKShare uses to ferry data between owner and recipients).
///
/// SwiftData's automatic CloudKit mirror only handles the default zone of the
/// user's Private DB, so for sharing we have to manage the custom-zone records
/// manually. This service is the single chokepoint for that bookkeeping.
///
/// Two flows:
///   - **Push** — when a TaskItem or TaskList on a shared list changes locally,
///     write a corresponding CKRecord into the share zone. Hooked at every
///     mutation site (AddTaskSheet, TaskDetailSheet, TaskRow toggle, etc.).
///   - **Pull** — when CloudKit signals remote changes (silent push from
///     `CloudKitSyncManager`'s subscriptions, or on share accept, or on
///     scenePhase becoming active), fetch the zone's `CKFetchRecordZoneChanges`
///     delta and apply to SwiftData with last-writer-wins semantics.
@MainActor
final class SharedListMirror: ObservableObject {

    static let shared = SharedListMirror()

    private weak var modelContext: ModelContext?
    private var service: CloudKitSharingService { .shared }

    private init() {}

    /// Wire up the SwiftData context. Called from `CadenceApp.init` once the
    /// container is created.
    func bind(context: ModelContext) {
        self.modelContext = context
    }

    // MARK: Push (local → cloud)

    /// Called by mutation sites after a TaskItem is added, updated, or had
    /// its status toggled. No-op when the list isn't shared.
    func taskChanged(_ task: TaskItem) async {
        guard let list = task.list, list.isShared else { return }
        guard let zoneID = service.zoneID(for: list) else { return }

        // Stamp modifiedAt for conflict resolution.
        task.modifiedAt = .now

        let db = service.database(for: list)
        let listRootID = service.makeListRecordID(listID: list.id, zoneID: zoneID)
        let recordID: CKRecord.ID = {
            if let existing = task.cloudRecordName {
                return CKRecord.ID(recordName: existing, zoneID: zoneID)
            }
            return service.makeTaskRecordID(taskID: task.id, zoneID: zoneID)
        }()

        // Fetch or create the record. Fetch-first avoids overwriting fields
        // the other side might have changed in parallel.
        let record: CKRecord
        do {
            record = try await db.record(for: recordID)
            // Last-writer-wins by modifiedAt.
            if let remoteModified = record["modifiedAt"] as? Date,
               remoteModified > task.modifiedAt {
                // Remote is newer; don't overwrite. The next pull will pull
                // their version into us.
                return
            }
        } catch {
            record = CKRecord(recordType: CloudKitSharingService.taskRecordType, recordID: recordID)
        }

        service.applyTaskFields(record, task: task, listRootID: listRootID)

        do {
            _ = try await db.modifyRecords(saving: [record], deleting: [])
            task.cloudRecordName = recordID.recordName
            try? modelContext?.save()
        } catch {
            NSLog("[Cadence-Mirror] push task failed: %@", error.localizedDescription)
        }
    }

    /// Called when a TaskItem on a shared list is about to be deleted. Reads
    /// the cloud record name + zone from the TaskItem and returns a closure
    /// the caller invokes AFTER `modelContext.delete(task)` runs — the closure
    /// runs the cloud delete using the captured-by-value identifiers, which
    /// avoids touching the deleted SwiftData object.
    func captureDeletionPayload(for task: TaskItem) -> DeletionPayload? {
        guard let list = task.list, list.isShared else { return nil }
        guard let zoneID = service.zoneID(for: list) else { return nil }
        guard let recordName = task.cloudRecordName else { return nil }
        return DeletionPayload(
            recordName: recordName,
            zoneID: zoneID,
            isParticipant: list.isSharedAsParticipant
        )
    }

    func performDeletion(_ payload: DeletionPayload) async {
        let db: CKDatabase = payload.isParticipant ? service.sharedDB : service.privateDB
        let recordID = CKRecord.ID(recordName: payload.recordName, zoneID: payload.zoneID)
        do {
            _ = try await db.modifyRecords(saving: [], deleting: [recordID])
        } catch {
            NSLog("[Cadence-Mirror] delete task failed: %@", error.localizedDescription)
        }
    }

    struct DeletionPayload {
        let recordName: String
        let zoneID: CKRecordZone.ID
        let isParticipant: Bool
    }

    /// Called when shared list *metadata* changes (rename, recolor, re-icon).
    /// Updates the root CadenceList record so the recipient sees the new name.
    func listMetadataChanged(_ list: TaskList) async {
        guard list.isShared else { return }
        guard let zoneID = service.zoneID(for: list) else { return }

        list.modifiedAt = .now
        let db = service.database(for: list)
        let recordID = service.makeListRecordID(listID: list.id, zoneID: zoneID)

        let record: CKRecord
        do {
            record = try await db.record(for: recordID)
        } catch {
            record = CKRecord(recordType: CloudKitSharingService.listRecordType, recordID: recordID)
        }
        let ownerName = list.ownerDisplayName ?? ""
        service.applyListFields(record, list: list, ownerDisplayName: ownerName)
        do {
            _ = try await db.modifyRecords(saving: [record], deleting: [])
            try? modelContext?.save()
        } catch {
            NSLog("[Cadence-Mirror] push list failed: %@", error.localizedDescription)
        }
    }

    // MARK: Pull (cloud → local)

    /// Pull all changes from every shared zone we know about. Called on:
    ///   - app foreground (`scenePhase` → .active)
    ///   - CloudKit silent-push notification (CKDatabaseSubscription)
    ///   - immediately after accepting a CKShare
    func pullAllSharedZones() async {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<TaskList>(
            predicate: #Predicate { $0.shareRecordName != nil || $0.isSharedAsParticipant == true }
        )
        let sharedLists = (try? context.fetch(descriptor)) ?? []
        for list in sharedLists {
            await pullChanges(for: list)
        }
    }

    /// Pull changes for a single list's zone, using the stored serverChangeToken
    /// for an incremental fetch. Applies inserts/updates/deletes locally.
    func pullChanges(for list: TaskList) async {
        guard let zoneID = service.zoneID(for: list) else { return }
        let db = service.database(for: list)
        let token = decodeToken(list.shareZoneChangeToken)

        do {
            let result = try await db.recordZoneChanges(inZoneWith: zoneID, since: token)

            // Apply changed records
            for (_, recordResult) in result.modificationResultsByID {
                switch recordResult {
                case .success(let modification):
                    apply(record: modification.record, in: list)
                case .failure(let err):
                    NSLog("[Cadence-Mirror] pull record failed: %@", err.localizedDescription)
                }
            }

            // Apply deletions (Apple's API returns an array of Deletion structs)
            for deletion in result.deletions {
                applyDeletion(recordID: deletion.recordID, in: list)
            }

            list.shareZoneChangeToken = encodeToken(result.changeToken)
            try? modelContext?.save()

            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif

            if result.moreComing {
                // Recurse once to drain the rest. We keep this simple — no
                // infinite recursion guard because moreComing always converges
                // in practice (CloudKit batches at <400 records).
                await pullChanges(for: list)
            }
        } catch {
            NSLog("[Cadence-Mirror] pullChanges failed for %@: %@", list.name, error.localizedDescription)
        }
    }

    /// Called by `CadenceApp.handleCloudShareAcceptance` right after the
    /// CKShare.Metadata accept returns. Materializes the root list (if not
    /// already present) and all task records into local SwiftData.
    func handleShareAccepted(_ share: CKShare, metadata: CKShare.Metadata) async {
        guard let context = modelContext else { return }

        let zoneID = metadata.share.recordID.zoneID
        let ownerName = zoneID.ownerName

        // Parse the list UUID out of the zone name ("Cadence.SharedList.<UUID>").
        guard let listUUID = parseListUUID(from: zoneID.zoneName) else {
            NSLog("[Cadence-Mirror] couldn't parse list UUID from zone %@", zoneID.zoneName)
            return
        }

        // Find or create the local TaskList shell. If found, mark it as a
        // participant. If new, create a minimal stub — the pull will fill in
        // the real fields from the root record.
        let descriptor = FetchDescriptor<TaskList>(
            predicate: #Predicate { $0.id == listUUID }
        )
        let existing = (try? context.fetch(descriptor))?.first
        let list: TaskList
        if let existing {
            list = existing
        } else {
            list = TaskList(
                id: listUUID,
                name: "Shared list",
                colorKey: "teal",
                iconKey: "person.2.fill",
                sortOrder: 9999,
                isSharedAsParticipant: true
            )
            context.insert(list)
        }
        list.isSharedAsParticipant = true
        list.shareZoneOwnerName = ownerName
        list.shareRecordName = metadata.share.recordID.recordName
        if let title = metadata.share[CKShare.SystemFieldKey.title] as? String {
            // Title is "Cadence — <listName>", strip the prefix
            if let dashIdx = title.firstIndex(of: "—") {
                let listName = title[title.index(after: dashIdx)...].trimmingCharacters(in: .whitespaces)
                if !listName.isEmpty { list.name = listName }
            }
        }

        try? context.save()

        await pullChanges(for: list)
    }

    // MARK: Apply incoming record → SwiftData

    private func apply(record: CKRecord, in list: TaskList) {
        guard let context = modelContext else { return }
        switch record.recordType {
        case CloudKitSharingService.listRecordType:
            applyListRecord(record, to: list, context: context)
        case CloudKitSharingService.taskRecordType:
            applyTaskRecord(record, in: list, context: context)
        default:
            break
        }
    }

    private func applyListRecord(_ record: CKRecord, to list: TaskList, context: ModelContext) {
        guard let remoteModified = record["modifiedAt"] as? Date else { return }
        if remoteModified <= list.modifiedAt { return }

        if let name = record["name"] as? String { list.name = name }
        if let color = record["colorKey"] as? String { list.colorKey = color }
        if let icon = record["iconKey"] as? String { list.iconKey = icon }
        if let owner = record["ownerDisplayName"] as? String { list.ownerDisplayName = owner }
        list.modifiedAt = remoteModified
    }

    private func applyTaskRecord(_ record: CKRecord, in list: TaskList, context: ModelContext) {
        guard let idString = record["id"] as? String,
              let taskID = UUID(uuidString: idString) else { return }
        guard let remoteModified = record["modifiedAt"] as? Date else { return }

        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.id == taskID }
        )
        let existing = (try? context.fetch(descriptor))?.first

        let task: TaskItem
        if let existing {
            // Last-writer-wins by modifiedAt.
            if existing.modifiedAt >= remoteModified { return }
            task = existing
        } else {
            task = TaskItem(id: taskID, title: "", list: list)
            context.insert(task)
        }

        if let title = record["title"] as? String { task.title = title }
        task.notes = record["notes"] as? String
        task.dueDate = record["dueDate"] as? Date
        if let allDay = record["allDay"] as? Bool { task.allDay = allDay }
        if let priorityRaw = record["priority"] as? Int,
           let priority = Priority(rawValue: priorityRaw) {
            task.priority = priority
        }
        if let statusRaw = record["status"] as? String,
           let status = TaskStatus(rawValue: statusRaw) {
            task.status = status
        }
        task.completedAt = record["completedAt"] as? Date
        task.rruleString = record["rruleString"] as? String
        task.list = list
        task.modifiedAt = remoteModified
        task.cloudRecordName = record.recordID.recordName

        // Reparent subtask if parentTaskID is present
        if let parentIDString = record["parentTaskID"] as? String,
           let parentID = UUID(uuidString: parentIDString) {
            let parentDescriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.id == parentID }
            )
            task.parent = (try? context.fetch(parentDescriptor))?.first
        } else {
            task.parent = nil
        }
    }

    private func applyDeletion(recordID: CKRecord.ID, in list: TaskList) {
        guard let context = modelContext else { return }
        let recordName = recordID.recordName

        // Match TaskItem by cloudRecordName
        let taskDescriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.cloudRecordName == recordName }
        )
        if let task = (try? context.fetch(taskDescriptor))?.first {
            context.delete(task)
            return
        }

        // Otherwise if it's the list root being deleted (owner stopped sharing
        // or revoked us), drop the local mirror — but keep it on owner side
        // since they might re-share later. On recipient side, delete the list.
        if recordName == "list-\(list.id.uuidString)", list.isSharedAsParticipant {
            context.delete(list)
        }
    }

    // MARK: Helpers

    private func parseListUUID(from zoneName: String) -> UUID? {
        let prefix = "Cadence.SharedList."
        guard zoneName.hasPrefix(prefix) else { return nil }
        let uuidString = String(zoneName.dropFirst(prefix.count))
        return UUID(uuidString: uuidString)
    }

    private func encodeToken(_ token: CKServerChangeToken) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    private func decodeToken(_ data: Data?) -> CKServerChangeToken? {
        guard let data else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: CKServerChangeToken.self,
            from: data
        )
    }
}
