import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppAuth)
import AppAuth
#endif

/// Talks to Google Calendar v3 API.
///
/// Lifecycle:
/// 1. `signIn(presentingFrom:)` — opens Google's OAuth browser via AppAuth,
///    runs PKCE code exchange, persists OIDAuthState in Keychain, fetches
///    profile email, creates ConnectedAccount + CalendarConfig rows.
/// 2. `fetchCalendars(for:)` — lists every calendar in the user's account.
/// 3. `fetchEvents(for:in:)` — sliding window of events for enabled calendars,
///    upserts to CachedEvent. Honors If-None-Match via per-calendar ETag.
/// 4. `signOut(account:)` — revokes the token at Google, drops keychain,
///    deletes ConnectedAccount + CachedEvent rows.
///
/// All public methods are @MainActor so SwiftData writes happen on the main
/// context. Network calls await off-main.
@MainActor
final class GoogleCalendarService: ObservableObject {

    static let shared = GoogleCalendarService()

    /// The ModelContext this service reads/writes. Set once at app launch via
    /// `bindContext(_:)` so it matches the @Query-bound mainContext in the UI.
    /// Until bound, we fall back to a fresh container — fine for unit tests
    /// or pre-launch, but means writes won't show up in @Query views.
    private var context: ModelContext

    /// Tracks the most recent error so the UI can surface a banner.
    @Published var lastError: GoogleCalendarError?

    /// Set during sign-in flow so SwiftUI can disable the Connect button.
    @Published var isSigningIn: Bool = false

    /// Set while fetching events for any account.
    @Published var isFetching: Bool = false

    /// AppAuth must hang onto the in-flight authorization flow during the
    /// browser hop or it gets garbage collected and the callback never fires.
    #if canImport(AppAuth)
    private var pendingAuthFlow: OIDExternalUserAgentSession?
    #endif

    private init(context: ModelContext? = nil) {
        if let context {
            self.context = context
        } else {
            // Late-bound — bindContext() is called from CadenceApp on launch
            // so this default is rarely used in practice.
            self.context = ModelContext(try! CadenceContainer.makeContainer())
        }
    }

    /// Attach the service to the App's main ModelContext so writes are
    /// visible to all SwiftUI @Query views. Call exactly once on app start.
    func bindContext(_ newContext: ModelContext) {
        self.context = newContext
    }

    /// True if the account's persisted auth state lacks the new
    /// `calendar.events` scope — meaning the user signed in before Phase 7a
    /// and needs to reconnect for write access. Reads the granted scope from
    /// the most recent token response stored in Keychain.
    func needsReconnect(for account: ConnectedAccount) -> Bool {
        #if canImport(AppAuth)
        guard let state = KeychainStore.loadAuthState(account: account.keychainID) else {
            return false
        }
        // `lastTokenResponse?.scope` is the space-separated string of scopes
        // that Google actually granted. The OAuth request scopes can differ
        // from granted, so we must inspect the response.
        let granted = state.lastTokenResponse?.scope ?? state.lastAuthorizationResponse.scope ?? ""
        // Need both scopes for full Phase 7a functionality: .events for the
        // two-way write sync, .readonly for the calendarList endpoint.
        return !granted.contains("calendar.events") || !granted.contains("calendar.readonly")
        #else
        return false
        #endif
    }

    /// Forward redirects from `.onOpenURL` to AppAuth's in-flight session.
    /// Returns true when the URL belonged to a pending Cadence OAuth flow.
    @discardableResult
    func resumeAuthFlow(with url: URL) -> Bool {
        #if canImport(AppAuth)
        NSLog("[Cadence-OAuth] resumeAuthFlow called with URL: %@", url.absoluteString)
        guard let session = pendingAuthFlow else {
            NSLog("[Cadence-OAuth] no pending auth flow — dropping URL")
            return false
        }
        let handled = session.resumeExternalUserAgentFlow(with: url)
        NSLog("[Cadence-OAuth] resumeExternalUserAgentFlow returned %@", handled ? "true" : "false")
        // Keep pendingAuthFlow alive until the callback fires (in case the
        // token exchange is still in flight) — clearing here can deallocate
        // AppAuth's URLSession task.
        return handled
        #else
        return false
        #endif
    }

    // MARK: Public API

    func signIn(presentingFrom controller: PlatformViewController) async throws {
        #if canImport(AppAuth)
        guard GoogleOAuthConfig.isConfigured else {
            throw GoogleCalendarError.notConfigured
        }
        isSigningIn = true
        defer { isSigningIn = false }

        // Discover Google's OAuth endpoints from the issuer URL.
        let config = try await discoverConfiguration()

        let request = OIDAuthorizationRequest(
            configuration: config,
            clientId: GoogleOAuthConfig.clientID,
            clientSecret: nil,
            scopes: GoogleOAuthConfig.scopes + ["openid", "email", "profile"],
            redirectURL: GoogleOAuthConfig.redirectURI,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
        )

        NSLog("[Cadence-OAuth] signIn starting, redirect URI = %@", GoogleOAuthConfig.redirectURI.absoluteString)

        // Present the browser and await the OIDAuthState.
        // We hold pendingAuthFlow until the next sign-in attempt overwrites it
        // — this guarantees AppAuth's URLSession task for the code→token
        // exchange isn't deallocated mid-flight.
        let authState: OIDAuthState = try await withCheckedThrowingContinuation { cont in
            let session = OIDAuthState.authState(
                byPresenting: request,
                presenting: controller
            ) { state, error in
                NSLog("[Cadence-OAuth] callback fired: state=%@ error=%@",
                      state == nil ? "nil" : "<state>",
                      error == nil ? "nil" : (error as NSError?)?.localizedDescription ?? "<err>")
                if let error {
                    cont.resume(throwing: GoogleCalendarError.oauth(error))
                } else if let state {
                    cont.resume(returning: state)
                } else {
                    cont.resume(throwing: GoogleCalendarError.oauthMissingState)
                }
            }
            self.pendingAuthFlow = session
            NSLog("[Cadence-OAuth] auth session created and retained")
        }
        NSLog("[Cadence-OAuth] authState received, email lookup next")

        // Pull email from the ID token (no extra API call needed).
        let email = extractEmail(from: authState) ?? "unknown@google"
        NSLog("[Cadence-OAuth] email resolved: %@", email)

        let keychainID = UUID().uuidString
        NSLog("[Cadence-OAuth] saving auth state to keychain id=%@", keychainID)
        guard KeychainStore.saveAuthState(authState, for: keychainID) else {
            NSLog("[Cadence-OAuth] KEYCHAIN SAVE FAILED")
            throw GoogleCalendarError.keychainSaveFailed
        }
        NSLog("[Cadence-OAuth] keychain saved OK")

        // If an account for this email already exists (re-link case), update
        // it instead of inserting a duplicate.
        let existing = try? context.fetch(FetchDescriptor<ConnectedAccount>())
            .first(where: { $0.provider == "google" && $0.email == email })

        let account: ConnectedAccount
        if let existing {
            NSLog("[Cadence-OAuth] reusing existing account row")
            existing.keychainID = keychainID
            existing.connectedAt = .now
            account = existing
        } else {
            NSLog("[Cadence-OAuth] creating new account row")
            account = ConnectedAccount(
                provider: "google",
                email: email,
                keychainID: keychainID
            )
            context.insert(account)
        }

        do {
            try context.save()
            NSLog("[Cadence-OAuth] SwiftData context saved")
        } catch {
            NSLog("[Cadence-OAuth] SwiftData SAVE FAILED: %@", (error as NSError).localizedDescription)
            throw error
        }

        // Eagerly fetch the calendar list so the UI can populate immediately.
        NSLog("[Cadence-OAuth] fetching calendar list…")
        _ = try await fetchCalendars(for: account)
        NSLog("[Cadence-OAuth] calendar list fetched, signIn COMPLETE")
        #else
        throw GoogleCalendarError.notConfigured
        #endif
    }

    func signOut(account: ConnectedAccount) async {
        #if canImport(AppAuth)
        // Best-effort token revocation; ignore errors (e.g., network offline).
        if let state = KeychainStore.loadAuthState(account: account.keychainID),
           let accessToken = state.lastTokenResponse?.accessToken,
           let url = URL(string: "https://oauth2.googleapis.com/revoke?token=\(accessToken)") {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            _ = try? await URLSession.shared.data(for: req)
        }
        KeychainStore.delete(account: account.keychainID)
        #endif

        // Cascade-delete CachedEvent rows for every calendar on this account.
        let calendarIDs = Set(account.calendarList.map { $0.googleCalendarID })
        let events = (try? context.fetch(FetchDescriptor<CachedEvent>())) ?? []
        for event in events where calendarIDs.contains(event.calendarID) {
            context.delete(event)
        }
        context.delete(account)
        try? context.save()
    }

    @discardableResult
    func fetchCalendars(for account: ConnectedAccount) async throws -> [CalendarConfig] {
        #if canImport(AppAuth)
        let token = try await freshAccessToken(for: account)
        let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!
        let payload: CalendarListResponse = try await get(url, token: token)

        // Upsert by googleCalendarID.
        let existing = account.calendarList
        var keptIDs = Set<String>()
        for item in payload.items {
            keptIDs.insert(item.id)
            if let row = existing.first(where: { $0.googleCalendarID == item.id }) {
                row.name = item.summary
                row.defaultColorHex = item.backgroundColor
            } else {
                let new = CalendarConfig(
                    googleCalendarID: item.id,
                    name: item.summary,
                    defaultColorHex: item.backgroundColor,
                    isEnabled: item.primary == true
                )
                new.account = account
                context.insert(new)
                // Append-or-init the optional relationship array.
                account.calendars = (account.calendars ?? []) + [new]
            }
        }
        // Remove calendars the user deleted on Google's side.
        for row in existing where !keptIDs.contains(row.googleCalendarID) {
            context.delete(row)
        }
        try context.save()
        return account.calendarList
        #else
        throw GoogleCalendarError.notConfigured
        #endif
    }

    /// Fetch events for every enabled calendar on every connected Google account.
    /// Window: today − 7 days .. today + 30 days.
    func fetchAllEvents() async {
        let accounts = (try? context.fetch(FetchDescriptor<ConnectedAccount>())) ?? []
        guard !accounts.isEmpty else { return }
        isFetching = true
        defer { isFetching = false }
        for account in accounts where account.provider == "google" {
            do {
                try await fetchEvents(for: account)
                account.lastSyncedAt = .now
            } catch let GoogleCalendarError.tokenExpired(message) {
                lastError = .tokenExpired(message)
            } catch {
                lastError = .underlying(error)
            }
        }
        try? context.save()
        // Build 29: events feed the widget too — refresh timelines so a
        // newly-synced meeting shows up on the home screen / lock screen
        // without waiting for the next 15-minute cadence.
        WidgetReloader.reload(reason: "google events refreshed")
    }

    func fetchEvents(for account: ConnectedAccount) async throws {
        #if canImport(AppAuth)
        let token = try await freshAccessToken(for: account)

        let cal = Calendar.current
        let now = cal.startOfDay(for: .now)
        let from = cal.date(byAdding: .day, value: -7, to: now)!
        let to = cal.date(byAdding: .day, value: 30, to: now)!

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let timeMin = isoFormatter.string(from: from)
        let timeMax = isoFormatter.string(from: to)

        for calendarConfig in account.calendarList where calendarConfig.isEnabled {
            var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(percentEncoded(calendarConfig.googleCalendarID))/events")!
            components.queryItems = [
                .init(name: "timeMin", value: timeMin),
                .init(name: "timeMax", value: timeMax),
                .init(name: "singleEvents", value: "true"),
                .init(name: "orderBy", value: "startTime"),
                .init(name: "maxResults", value: "250")
            ]
            guard let url = components.url else { continue }

            var headers: [String: String] = [:]
            if let etag = calendarConfig.lastETag {
                headers["If-None-Match"] = etag
            }

            do {
                let (payload, etag): (EventsListResponse, String?) = try await getWithETag(
                    url,
                    token: token,
                    extraHeaders: headers
                )
                if let etag {
                    calendarConfig.lastETag = etag
                }
                upsertEvents(payload.items ?? [], calendarID: calendarConfig.googleCalendarID)
            } catch GoogleCalendarError.notModified {
                // 304 — nothing changed. Skip.
                continue
            }
        }

        try context.save()
        #else
        throw GoogleCalendarError.notConfigured
        #endif
    }

    // MARK: Two-way sync (Phase 7a)

    /// Reconciles a task's mirror state with Google Calendar in one call.
    /// Decides whether to POST (new mirror), PATCH (update), or DELETE based
    /// on the task's current state vs. what's stored.
    ///
    /// Call after every persist on a task. Safe to call when no mirror state
    /// exists — short-circuits cleanly.
    func syncTaskToCalendar(_ task: TaskItem) async {
        #if canImport(AppAuth)
        // Find the Google account that owns this calendar.
        let accounts = (try? context.fetch(FetchDescriptor<ConnectedAccount>())) ?? []
        let googleAccount = accounts.first(where: { $0.provider == "google" })
        guard let account = googleAccount else { return }

        // Three cases:
        // 1. Mirror exists but should be deleted (toggled off, time removed, no time-block).
        // 2. Mirror exists and should be updated.
        // 3. No mirror exists but should be created.
        let shouldHaveMirror = task.isTimeBlocked
            && task.dueDate != nil
            && !task.allDay
            && task.mirrorCalendarId != nil

        do {
            if let eventID = task.mirroredEventId, let calID = task.mirrorCalendarId {
                if !shouldHaveMirror {
                    try await deleteMirroredEvent(eventID: eventID, calendarID: calID, account: account)
                    task.mirroredEventId = nil
                    task.lastSyncedStart = nil
                    try context.save()
                } else {
                    try await updateMirroredEvent(task: task, account: account)
                    task.lastSyncedStart = task.dueDate
                    try context.save()
                }
            } else if shouldHaveMirror, let calID = task.mirrorCalendarId, let due = task.dueDate {
                let newEventID = try await createMirroredEvent(task: task, calendarID: calID, account: account)
                task.mirroredEventId = newEventID
                task.lastSyncedStart = due
                try context.save()
            }
        } catch {
            // Surface but don't crash — sync failures shouldn't block local task edits.
            lastError = .underlying(error)
        }
        #endif
    }

    /// Called when a task is deleted from Cadence — drops its mirrored event.
    func deleteMirrorIfNeeded(taskID: UUID, eventID: String?, calendarID: String?) async {
        guard let eventID, let calendarID else { return }
        let accounts = (try? context.fetch(FetchDescriptor<ConnectedAccount>())) ?? []
        guard let account = accounts.first(where: { $0.provider == "google" }) else { return }
        try? await deleteMirroredEvent(eventID: eventID, calendarID: calendarID, account: account)
    }

    private func createMirroredEvent(task: TaskItem, calendarID: String, account: ConnectedAccount) async throws -> String {
        let token = try await freshAccessToken(for: account)
        guard let due = task.dueDate else { throw GoogleCalendarError.invalidResponse }
        let end = due.addingTimeInterval(task.mirrorDurationSeconds)

        let body = eventBody(task: task, start: due, end: end)

        let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/\(percentEncoded(calendarID))/events")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw GoogleCalendarError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            if http.statusCode == 401 { throw GoogleCalendarError.tokenExpired("Google rejected the token.") }
            throw GoogleCalendarError.http(http.statusCode)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let id = json?["id"] as? String else { throw GoogleCalendarError.invalidResponse }
        return id
    }

    private func updateMirroredEvent(task: TaskItem, account: ConnectedAccount) async throws {
        guard let calendarID = task.mirrorCalendarId,
              let eventID = task.mirroredEventId,
              let due = task.dueDate
        else { return }
        let token = try await freshAccessToken(for: account)
        let end = due.addingTimeInterval(task.mirrorDurationSeconds)
        let body = eventBody(task: task, start: due, end: end)

        let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/\(percentEncoded(calendarID))/events/\(percentEncoded(eventID))")!
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw GoogleCalendarError.invalidResponse }
        // 404 is acceptable here — event was deleted externally. We clear our
        // mirror ID at the call site if needed.
        guard 200..<300 ~= http.statusCode || http.statusCode == 404 else {
            if http.statusCode == 401 { throw GoogleCalendarError.tokenExpired("Google rejected the token.") }
            throw GoogleCalendarError.http(http.statusCode)
        }
    }

    private func deleteMirroredEvent(eventID: String, calendarID: String, account: ConnectedAccount) async throws {
        let token = try await freshAccessToken(for: account)
        let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/\(percentEncoded(calendarID))/events/\(percentEncoded(eventID))")!
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { return }
        // 200/204 success; 404 = already gone; 410 = gone. All fine.
        if http.statusCode == 401 {
            throw GoogleCalendarError.tokenExpired("Google rejected the token.")
        }
    }

    /// Build the JSON body Google expects for events.insert/patch.
    private func eventBody(task: TaskItem, start: Date, end: Date) -> [String: Any] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let completed = task.status == .completed

        // Marker so we (or anyone) can identify Cadence-origin events.
        var description = ""
        if let notes = task.notes, !notes.isEmpty {
            description = notes + "\n\n"
        }
        if completed, let completedAt = task.completedAt {
            description += "Completed in Cadence: \(completedAt.formatted(.dateTime.month().day().hour().minute()))\n"
        }
        description += "—\nCreated by Cadence · taskId: \(task.id.uuidString)"

        var body: [String: Any] = [
            "summary": completed ? "✓ \(task.title)" : task.title,
            "description": description,
            "start": ["dateTime": iso.string(from: start)],
            "end":   ["dateTime": iso.string(from: end)],
            "source": [
                "title": "Cadence",
                "url": "https://github.com/trippcarter/cadence-ios"
            ]
        ]
        // Send the RRULE so Google renders a single recurring event covering
        // every future occurrence (instead of one event per Cadence instance).
        if let rrule = task.rruleString, !rrule.isEmpty {
            body["recurrence"] = ["RRULE:\(rrule)"]
        }
        return body
    }

    // MARK: Token plumbing

    #if canImport(AppAuth)
    private func freshAccessToken(for account: ConnectedAccount) async throws -> String {
        guard let state = KeychainStore.loadAuthState(account: account.keychainID) else {
            throw GoogleCalendarError.tokenExpired("Sign in to Google Calendar again.")
        }
        return try await withCheckedThrowingContinuation { cont in
            state.performAction { accessToken, _, error in
                if let error {
                    cont.resume(throwing: GoogleCalendarError.tokenExpired(error.localizedDescription))
                } else if let accessToken {
                    // Persist any token refresh that just happened.
                    KeychainStore.saveAuthState(state, for: account.keychainID)
                    cont.resume(returning: accessToken)
                } else {
                    cont.resume(throwing: GoogleCalendarError.tokenExpired("Missing access token."))
                }
            }
        }
    }

    private func discoverConfiguration() async throws -> OIDServiceConfiguration {
        try await withCheckedThrowingContinuation { cont in
            OIDAuthorizationService.discoverConfiguration(
                forIssuer: GoogleOAuthConfig.issuer
            ) { config, error in
                if let config { cont.resume(returning: config) }
                else { cont.resume(throwing: GoogleCalendarError.oauth(error ?? GoogleCalendarError.discoveryFailed)) }
            }
        }
    }

    private func extractEmail(from state: OIDAuthState) -> String? {
        // Google returns email in the ID token payload.
        guard let idToken = state.lastTokenResponse?.idToken else { return nil }
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64.append("=") }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json["email"] as? String
    }
    #endif

    // MARK: HTTP helpers

    private func get<T: Decodable>(_ url: URL, token: String) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw GoogleCalendarError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            if http.statusCode == 401 {
                throw GoogleCalendarError.tokenExpired("Google rejected the token.")
            }
            throw GoogleCalendarError.http(http.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func getWithETag<T: Decodable>(_ url: URL, token: String, extraHeaders: [String: String]) async throws -> (T, String?) {
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        for (k, v) in extraHeaders { req.setValue(v, forHTTPHeaderField: k) }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw GoogleCalendarError.invalidResponse }
        if http.statusCode == 304 { throw GoogleCalendarError.notModified }
        guard 200..<300 ~= http.statusCode else {
            if http.statusCode == 401 {
                throw GoogleCalendarError.tokenExpired("Google rejected the token.")
            }
            throw GoogleCalendarError.http(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(T.self, from: data)
        let etag = http.value(forHTTPHeaderField: "ETag")
        return (decoded, etag)
    }

    private func percentEncoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    // MARK: Upsert

    private func upsertEvents(_ items: [GoogleEvent], calendarID: String) {
        let existing = (try? context.fetch(FetchDescriptor<CachedEvent>())) ?? []
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for item in items {
            // Cancelled events arrive with status == "cancelled" — delete locally.
            if item.status == "cancelled" {
                if let existingEvent = byID[item.id] {
                    context.delete(existingEvent)
                }
                continue
            }

            let (start, end, allDay) = parseInterval(item)
            guard let start, let end else { continue }

            let attendees = (item.attendees ?? []).map { $0.email ?? $0.displayName ?? "" }.filter { !$0.isEmpty }
            let meetingURL = item.hangoutLink.flatMap(URL.init(string:))
            let htmlLink = item.htmlLink.flatMap(URL.init(string:))

            if let existingEvent = byID[item.id] {
                existingEvent.title = item.summary ?? "(no title)"
                existingEvent.start = start
                existingEvent.end = end
                existingEvent.isAllDay = allDay
                existingEvent.location = item.location
                existingEvent.notes = item.description
                existingEvent.attendees = attendees
                existingEvent.meetingURL = meetingURL
                existingEvent.htmlLink = htmlLink
                existingEvent.lastFetched = .now
            } else {
                let new = CachedEvent(
                    id: item.id,
                    calendarID: calendarID,
                    title: item.summary ?? "(no title)",
                    start: start,
                    end: end,
                    isAllDay: allDay,
                    location: item.location,
                    notes: item.description,
                    attendees: attendees,
                    meetingURL: meetingURL,
                    htmlLink: htmlLink
                )
                context.insert(new)
            }
        }
    }

    private func parseInterval(_ item: GoogleEvent) -> (Date?, Date?, Bool) {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.timeZone = TimeZone(identifier: "UTC")

        func decode(_ d: GoogleEvent.DateTime?) -> (Date?, Bool) {
            guard let d else { return (nil, false) }
            if let dateTime = d.dateTime, let parsed = isoFormatter.date(from: dateTime) {
                return (parsed, false)
            }
            if let dayString = d.date, let parsed = dayFormatter.date(from: dayString) {
                return (parsed, true)
            }
            return (nil, false)
        }

        let (start, startAllDay) = decode(item.start)
        let (end, endAllDay) = decode(item.end)
        return (start, end, startAllDay || endAllDay)
    }
}

// MARK: - Errors

enum GoogleCalendarError: Error, LocalizedError {
    case notConfigured
    case oauth(Error)
    case oauthMissingState
    case discoveryFailed
    case keychainSaveFailed
    case invalidResponse
    case http(Int)
    case notModified
    case tokenExpired(String)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Google Calendar isn't configured yet."
        case .oauth(let e): return "Sign-in failed: \(e.localizedDescription)"
        case .oauthMissingState: return "Sign-in didn't return credentials."
        case .discoveryFailed: return "Couldn't reach Google's auth servers."
        case .keychainSaveFailed: return "Couldn't save credentials to Keychain."
        case .invalidResponse: return "Bad response from Google."
        case .http(let code): return "Google returned HTTP \(code)."
        case .notModified: return "Not modified."
        case .tokenExpired(let msg): return msg
        case .underlying(let e): return e.localizedDescription
        }
    }
}

// MARK: - Decoded Google response shapes

private struct CalendarListResponse: Decodable {
    let items: [Item]
    struct Item: Decodable {
        let id: String
        let summary: String
        let primary: Bool?
        let backgroundColor: String?
    }
}

private struct EventsListResponse: Decodable {
    let items: [GoogleEvent]?
}

private struct GoogleEvent: Decodable {
    let id: String
    let status: String?
    let summary: String?
    let description: String?
    let location: String?
    let htmlLink: String?
    let hangoutLink: String?
    let start: DateTime?
    let end: DateTime?
    let attendees: [Attendee]?

    struct DateTime: Decodable {
        let dateTime: String?      // RFC3339 timestamp
        let date: String?          // "YYYY-MM-DD" for all-day
        let timeZone: String?
    }
    struct Attendee: Decodable {
        let email: String?
        let displayName: String?
    }
}

// MARK: - Platform shim

#if canImport(UIKit)
typealias PlatformViewController = UIViewController
#else
typealias PlatformViewController = NSObject
#endif
