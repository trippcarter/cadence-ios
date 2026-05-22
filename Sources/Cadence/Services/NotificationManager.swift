import Foundation
import SwiftUI
import SwiftData
import UserNotifications
import os.log

/// Build 31: shared logger for the notification subsystem. Filter
/// Console.app by subsystem `net.mcinnis.cadence` category `NOTIF` —
/// every line is also tagged `[Build 31]` in the message text.
let notifLog = OSLog(subsystem: "net.mcinnis.cadence", category: "NOTIF")

/// Single owner of all local-notification scheduling.
///
/// Identifier scheme:
///   - Per-task offset reminder: `task.<UUID>.offset.<offsetSeconds>`
///   - Daily morning brief:      `daily-brief`
///   - Send-test (debug):        `test.<UUID>`
///
/// The class is `@MainActor` because it interacts with SwiftData on the main
/// context and publishes state to SwiftUI. Internal awaiting on the system
/// notification center happens off-main but writes are funneled back.
@MainActor
final class NotificationManager: NSObject, ObservableObject {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    /// Most recent authorization status. Refreshed on `refreshAuthorizationStatus()`
    /// and after each `requestAuthorization()` call.
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Set when the user taps a task reminder; RootView observes and presents
    /// the Task Detail sheet, then clears this value.
    @Published var deepLinkTaskID: UUID?
    /// Build 18: flipped to true when the user taps the evening review
    /// notification. RootView observes this and presents DailyReviewSheet,
    /// then resets the flag.
    @Published var deepLinkOpenReview: Bool = false

    /// Set when the user taps the morning brief; RootView routes to the Today tab.
    @Published var deepLinkRequestedTab: AppTab?

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: Permission

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Requests permission if not yet determined. Returns true when notifications
    /// can be scheduled (authorized or provisional).
    @discardableResult
    func ensureAuthorization() async -> Bool {
        await refreshAuthorizationStatus()
        switch authorizationStatus {
        case .notDetermined:
            do {
                os_log("[Build 31] requesting notification authorization (status was notDetermined)",
                       log: notifLog, type: .info)
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                await refreshAuthorizationStatus()
                os_log("[Build 31] authorization request returned granted=%{public}@ → status=%{public}@",
                       log: notifLog, type: .info,
                       granted ? "true" : "false", String(describing: authorizationStatus.rawValue))
                return granted
            } catch {
                os_log("[Build 31] authorization request threw: %{public}@",
                       log: notifLog, type: .error, error.localizedDescription)
                return false
            }
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            os_log("[Build 31] authorization unavailable — status=%{public}d (denied?)",
                   log: notifLog, type: .error, authorizationStatus.rawValue)
            return false
        }
    }

    /// Build 31: called once on every app launch from CadenceApp. If the
    /// user has never been asked (fresh install / new device), this fires
    /// the system permission prompt — previously that only happened when
    /// the user happened to open Settings or add a reminder manually,
    /// which is why a fresh-installed phone got zero notifications.
    func requestAuthorizationOnLaunch() async {
        await refreshAuthorizationStatus()
        os_log("[Build 31] launch auth check — status=%{public}d",
               log: notifLog, type: .info, authorizationStatus.rawValue)
        if authorizationStatus == .notDetermined {
            await ensureAuthorization()
        }
    }

    // MARK: Master toggle

    private var masterEnabled: Bool {
        // Default true on first run.
        if UserDefaults.standard.object(forKey: PrefsKey.notificationsEnabled) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: PrefsKey.notificationsEnabled)
    }

    /// Cancel every pending Cadence-owned notification. Called when the master
    /// toggle goes off.
    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
    }

    /// Re-schedules every applicable task plus the daily brief. Use after the
    /// master toggle flips back on, or on app foreground to keep brief content
    /// fresh.
    ///
    /// `requestIfNeeded` is false by default so background callers (scene-phase
    /// activations) never trigger a permission dialog — that flow is only
    /// driven by explicit user actions in Settings or Task Detail.
    func rescheduleEverything(context: ModelContext, requestIfNeeded: Bool = false) async {
        guard masterEnabled else { return }
        let authorized: Bool
        if requestIfNeeded {
            authorized = await ensureAuthorization()
        } else {
            await refreshAuthorizationStatus()
            authorized = isAuthorized
        }
        guard authorized else { return }

        let descriptor = FetchDescriptor<TaskItem>()
        let tasks = (try? context.fetch(descriptor)) ?? []
        for task in tasks where task.status == .open && !task.reminderOffsets.isEmpty && task.parent == nil {
            await schedule(task: task, requestIfNeeded: false)
        }

        await schedule(briefWithContext: context, requestIfNeeded: false)
        await scheduleDailyReview(requestIfNeeded: false)
    }

    private var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    // MARK: Per-task reminders

    /// Default entry point used by task-edit code paths. Requests permission
    /// if the user is interacting (e.g., adding a reminder offset).
    func scheduleReminders(for task: TaskItem) async {
        await schedule(task: task, requestIfNeeded: true)
    }

    private func schedule(task: TaskItem, requestIfNeeded: Bool) async {
        await cancelReminders(forTaskID: task.id)
        guard masterEnabled else { return }
        guard task.status == .open else { return }
        guard let due = task.dueDate, !task.reminderOffsets.isEmpty else { return }
        let authorized: Bool
        if requestIfNeeded {
            authorized = await ensureAuthorization()
        } else {
            authorized = isAuthorized
        }
        guard authorized else { return }

        let cal = Calendar.current
        let listName = task.list?.name
        let titleSuffix = listName.map { " — \($0)" } ?? ""

        for offset in task.reminderOffsets {
            let fireDate = due.addingTimeInterval(offset)
            // Skip times that already passed (e.g., user adds reminder after due time).
            guard fireDate > .now else { continue }

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let content = UNMutableNotificationContent()
            content.title = task.title
            content.body = friendlyOffsetDescription(offset: offset) + titleSuffix
            content.sound = .default
            content.userInfo = ["kind": "task", "taskID": task.id.uuidString]
            // Time-sensitive for at-due reminders if user grants the entitlement.
            // Silently degrades to .active when the entitlement isn't present.
            if offset >= -900 {
                if #available(iOS 15.0, *) {
                    content.interruptionLevel = .timeSensitive
                }
            }

            let id = identifier(forTaskID: task.id, offset: offset)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            do {
                try await center.add(request)
                os_log("[Build 31] scheduled task reminder '%{public}@' for %{public}@ (offset %{public}ds)",
                       log: notifLog, type: .info,
                       task.title, fireDate.description, Int(offset))
            } catch {
                os_log("[Build 31] FAILED to add task reminder '%{public}@': %{public}@",
                       log: notifLog, type: .error, task.title, error.localizedDescription)
            }
        }
    }

    func cancelReminders(forTaskID taskID: UUID) async {
        let pending = await center.pendingNotificationRequests()
        let toCancel = pending
            .map { $0.identifier }
            .filter { $0.hasPrefix("task.\(taskID.uuidString).") }
        center.removePendingNotificationRequests(withIdentifiers: toCancel)
    }

    private func identifier(forTaskID id: UUID, offset: TimeInterval) -> String {
        "task.\(id.uuidString).offset.\(Int(offset))"
    }

    private func friendlyOffsetDescription(offset: TimeInterval) -> String {
        if offset == 0 { return "Due now" }
        let absMinutes = Int(abs(offset) / 60)
        if absMinutes < 60 {
            return "Due in \(absMinutes) min"
        }
        let hours = absMinutes / 60
        if hours < 24 { return "Due in \(hours) hr" }
        let days = hours / 24
        return "Due in \(days) day\(days == 1 ? "" : "s")"
    }

    // MARK: Daily morning brief

    func scheduleDailyBrief(context: ModelContext) async {
        await schedule(briefWithContext: context, requestIfNeeded: true)
    }

    /// Build 18: schedule (or cancel + reschedule) the daily-review evening
    /// notification. Called from Settings when the toggle / time picker
    /// changes, plus on app launch via `rescheduleEverything`.
    func scheduleDailyReview(requestIfNeeded: Bool = false) async {
        center.removePendingNotificationRequests(withIdentifiers: ["daily-review"])
        guard masterEnabled else { return }
        let enabled = UserDefaults.standard.bool(forKey: PrefsKey.dailyReviewEnabled)
        guard enabled else { return }
        let authorized: Bool
        if requestIfNeeded {
            authorized = await ensureAuthorization()
        } else {
            authorized = isAuthorized
        }
        guard authorized else { return }

        let hour = UserDefaults.standard.object(forKey: PrefsKey.dailyReviewHour) as? Int ?? 21
        let minute = UserDefaults.standard.object(forKey: PrefsKey.dailyReviewMinute) as? Int ?? 0

        let content = UNMutableNotificationContent()
        content.title = "How did today go?"
        content.body = "Quick reflection — under a minute."
        content.sound = .default
        content.userInfo = ["kind": "dailyReview"]

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(identifier: "daily-review", content: content, trigger: trigger)
        do {
            try await center.add(request)
            os_log("[Build 31] scheduled daily review (repeating) at %{public}02d:%{public}02d",
                   log: notifLog, type: .info, hour, minute)
        } catch {
            os_log("[Build 31] FAILED to add daily review: %{public}@",
                   log: notifLog, type: .error, error.localizedDescription)
        }
    }

    private func schedule(briefWithContext context: ModelContext, requestIfNeeded: Bool) async {
        center.removePendingNotificationRequests(withIdentifiers: ["daily-brief"])
        guard masterEnabled else { return }
        let authorized: Bool
        if requestIfNeeded {
            authorized = await ensureAuthorization()
        } else {
            authorized = isAuthorized
        }
        guard authorized else { return }

        let hour = UserDefaults.standard.object(forKey: PrefsKey.dailyBriefHour) as? Int ?? 7
        let minute = UserDefaults.standard.object(forKey: PrefsKey.dailyBriefMinute) as? Int ?? 30

        let content = UNMutableNotificationContent()
        content.title = "Good morning"
        content.body = computeBriefBody(context: context)
        content.sound = .default
        content.userInfo = ["kind": "dailyBrief"]

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(identifier: "daily-brief", content: content, trigger: trigger)
        do {
            try await center.add(request)
            os_log("[Build 31] scheduled daily brief (repeating) at %{public}02d:%{public}02d",
                   log: notifLog, type: .info, hour, minute)
        } catch {
            os_log("[Build 31] FAILED to add daily brief: %{public}@",
                   log: notifLog, type: .error, error.localizedDescription)
        }
    }

    private func computeBriefBody(context: ModelContext) -> String {
        let descriptor = FetchDescriptor<TaskItem>()
        let tasks = (try? context.fetch(descriptor)) ?? []
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)

        let todayOpen = tasks.filter { task in
            guard task.status == .open, task.parent == nil, let due = task.dueDate else { return false }
            return cal.isDate(due, inSameDayAs: .now) || cal.startOfDay(for: due) < todayStart
        }.count

        let taskWord = todayOpen == 1 ? "task" : "tasks"
        // Events arrive in Phase 3 (Google Calendar); for now this stays 0.
        return "You have \(todayOpen) \(taskWord) today and 0 events."
    }

    // MARK: Build 31 — calendar event reminders

    /// Re-syncs local notifications for every cached Google Calendar
    /// event. Called after each `GoogleCalendarService.fetchAllEvents()`.
    ///
    /// Strategy: cancel all `event.*` reminders, then re-schedule for
    /// every upcoming timed event using the user's default reminder
    /// offset. Re-syncing the whole set each fetch means events that
    /// were deleted or fell out of the window automatically lose their
    /// reminders — no per-event bookkeeping needed.
    func syncEventReminders(context: ModelContext) async {
        // Always clear stale event reminders first.
        let pending = await center.pendingNotificationRequests()
        let staleEventIDs = pending.map(\.identifier).filter { $0.hasPrefix("event.") }
        center.removePendingNotificationRequests(withIdentifiers: staleEventIDs)

        guard masterEnabled else { return }

        // The toggle defaults ON when never set.
        let remindersOn: Bool = {
            if UserDefaults.standard.object(forKey: PrefsKey.calendarEventRemindersEnabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: PrefsKey.calendarEventRemindersEnabled)
        }()
        guard remindersOn else {
            os_log("[Build 31] event reminders disabled by preference", log: notifLog, type: .info)
            return
        }

        await refreshAuthorizationStatus()
        guard isAuthorized else {
            os_log("[Build 31] event reminders skipped — not authorized", log: notifLog, type: .info)
            return
        }

        // Default offset (negative seconds before start). -1 sentinel = none.
        let rawOffset = UserDefaults.standard.object(forKey: PrefsKey.defaultReminderOffset) as? Double
            ?? ReminderOffsetPreset.tenMin.rawValue
        guard rawOffset != ReminderOffsetPreset.none.rawValue else {
            os_log("[Build 31] event reminders skipped — default offset is None", log: notifLog, type: .info)
            return
        }

        let events = (try? context.fetch(FetchDescriptor<CachedEvent>())) ?? []
        var scheduled = 0
        for event in events where !event.isAllDay {
            let fireDate = event.start.addingTimeInterval(rawOffset)
            guard fireDate > .now else { continue }

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let content = UNMutableNotificationContent()
            content.title = event.title
            let mins = Int(abs(rawOffset) / 60)
            content.body = mins == 0 ? "Starting now" : "Starting in \(mins) min"
            content.sound = .default
            content.userInfo = ["kind": "event", "eventID": event.id]
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
            }

            let request = UNNotificationRequest(
                identifier: "event.\(event.id).reminder.default",
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
                scheduled += 1
            } catch {
                os_log("[Build 31] FAILED to add event reminder '%{public}@': %{public}@",
                       log: notifLog, type: .error, event.title, error.localizedDescription)
            }
        }
        os_log("[Build 31] event reminders synced — %{public}d scheduled (offset %{public}ds)",
               log: notifLog, type: .info, scheduled, Int(rawOffset))
    }

    // MARK: Diagnostics

    /// Schedule a notification 5 seconds out — used by the "Send test" button
    /// in Settings to verify the pipeline works end-to-end.
    func sendTestInFiveSeconds() async -> Bool {
        await sendTest(afterSeconds: 5)
    }

    /// Build 31: parameterized test notification. The Notification
    /// Diagnostics screen uses the 30-second variant so the user has
    /// time to lock the phone and confirm it fires on the Lock Screen.
    @discardableResult
    func sendTest(afterSeconds seconds: TimeInterval) async -> Bool {
        guard await ensureAuthorization() else {
            os_log("[Build 31] test notification blocked — not authorized", log: notifLog, type: .error)
            return false
        }
        let content = UNMutableNotificationContent()
        content.title = "Cadence test"
        content.body = "If you can see this, notifications work. (\(Int(seconds))s test)"
        content.sound = .default
        content.userInfo = ["kind": "dailyBrief"]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "test.\(UUID().uuidString)", content: content, trigger: trigger)
        do {
            try await center.add(request)
            os_log("[Build 31] test notification scheduled — fires in %{public}ds", log: notifLog, type: .info, Int(seconds))
            return true
        } catch {
            os_log("[Build 31] test notification add() failed: %{public}@", log: notifLog, type: .error, error.localizedDescription)
            return false
        }
    }

    // MARK: Build 31 — full diagnostics snapshot

    /// Gathers a complete picture of the notification subsystem for the
    /// Settings → Developer → Notification Diagnostics screen, and dumps
    /// it to os_log so it's also visible in Console.app.
    func diagnosticsSnapshot() async -> NotificationDiagnosticsReport {
        let settings = await center.notificationSettings()
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()

        os_log("[Build 31] DIAG auth=%{public}d alert=%{public}d sound=%{public}d badge=%{public}d lockScreen=%{public}d notifCenter=%{public}d",
               log: notifLog, type: .info,
               settings.authorizationStatus.rawValue,
               settings.alertSetting.rawValue,
               settings.soundSetting.rawValue,
               settings.badgeSetting.rawValue,
               settings.lockScreenSetting.rawValue,
               settings.notificationCenterSetting.rawValue)
        os_log("[Build 31] DIAG pending=%{public}d delivered=%{public}d",
               log: notifLog, type: .info, pending.count, delivered.count)
        for req in pending {
            os_log("[Build 31] DIAG pending id=%{public}@ next=%{public}@",
                   log: notifLog, type: .info, req.identifier, Self.nextFireDate(req)?.description ?? "n/a")
        }

        return NotificationDiagnosticsReport(
            authorizationStatus: settings.authorizationStatus,
            alertSetting: settings.alertSetting,
            soundSetting: settings.soundSetting,
            badgeSetting: settings.badgeSetting,
            lockScreenSetting: settings.lockScreenSetting,
            notificationCenterSetting: settings.notificationCenterSetting,
            pending: pending.map { req in
                PendingNotificationInfo(
                    identifier: req.identifier,
                    body: req.content.body,
                    triggerKind: Self.triggerDescription(req.trigger),
                    nextFireDate: Self.nextFireDate(req)
                )
            },
            delivered: delivered.map { note in
                DeliveredNotificationInfo(
                    identifier: note.request.identifier,
                    body: note.request.content.body,
                    deliveredAt: note.date
                )
            }
        )
    }

    private static func triggerDescription(_ trigger: UNNotificationTrigger?) -> String {
        switch trigger {
        case let t as UNCalendarNotificationTrigger:
            return t.repeats ? "Calendar (repeating)" : "Calendar (one-shot)"
        case let t as UNTimeIntervalNotificationTrigger:
            return t.repeats ? "Interval (repeating)" : "Interval (one-shot)"
        case is UNPushNotificationTrigger:
            return "Push"
        default:
            return "Unknown"
        }
    }

    private static func nextFireDate(_ request: UNNotificationRequest) -> Date? {
        switch request.trigger {
        case let t as UNCalendarNotificationTrigger:
            return t.nextTriggerDate()
        case let t as UNTimeIntervalNotificationTrigger:
            return t.nextTriggerDate()
        default:
            return nil
        }
    }
}

// MARK: - Build 31 diagnostics value types

struct NotificationDiagnosticsReport {
    let authorizationStatus: UNAuthorizationStatus
    let alertSetting: UNNotificationSetting
    let soundSetting: UNNotificationSetting
    let badgeSetting: UNNotificationSetting
    let lockScreenSetting: UNNotificationSetting
    let notificationCenterSetting: UNNotificationSetting
    let pending: [PendingNotificationInfo]
    let delivered: [DeliveredNotificationInfo]
}

struct PendingNotificationInfo: Identifiable {
    let identifier: String
    let body: String
    let triggerKind: String
    let nextFireDate: Date?
    var id: String { identifier }
}

struct DeliveredNotificationInfo: Identifiable {
    let identifier: String
    let body: String
    let deliveredAt: Date
    var id: String { identifier }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// Show banner + sound when a notification arrives while the app is in the
    /// foreground. Default iOS behavior is to suppress entirely.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .list]
    }

    /// User tapped the notification. Route via the published deep-link state.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let kind = info["kind"] as? String
        if kind == "task", let idStr = info["taskID"] as? String, let id = UUID(uuidString: idStr) {
            await MainActor.run { self.deepLinkTaskID = id }
        } else if kind == "dailyBrief" {
            await MainActor.run { self.deepLinkRequestedTab = .today }
        } else if kind == "dailyReview" {
            await MainActor.run { self.deepLinkOpenReview = true }
        } else if kind == "event" {
            // Build 31: a calendar-event reminder tap opens the Calendar tab.
            await MainActor.run { self.deepLinkRequestedTab = .week }
        }
    }
}
