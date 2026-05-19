#if canImport(MetricKit) && os(iOS)
import Foundation
import MetricKit

/// Build 26: lightweight crash + hang reporting via Apple's built-in
/// MetricKit. No third-party SDK, no analytics — diagnostic payloads
/// stay on the device, saved as JSON files into the App Group container
/// so the user can view (or share) them from Settings → About → Crash
/// logs.
///
/// MetricKit delivers payloads at most once per day. Crashes/hangs that
/// happen between launches arrive on the next launch.
final class MetricKitObserver: NSObject, MXMetricManagerSubscriber {

    static let shared = MetricKitObserver()

    /// Subdirectory inside the App Group container that holds the JSON
    /// records. Created lazily on first write.
    private static let logSubdir = "DiagnosticLogs"
    /// Maximum age of a log we'll keep around. Anything older gets pruned
    /// the next time `didReceive` fires.
    private static let retentionDays = 30

    private override init() { super.init() }

    func start() {
        MXMetricManager.shared.add(self)
    }

    // MARK: MXMetricManagerSubscriber

    func didReceive(_ payloads: [MXMetricPayload]) {
        // We don't currently persist metric payloads (battery, hang rate,
        // etc.); crash + hang are the user-actionable ones.
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            persist(payload)
        }
        pruneOldLogs()
    }

    // MARK: Persistence

    private func persist(_ payload: MXDiagnosticPayload) {
        guard let logsDir = Self.logsDirectory() else { return }
        let timestamp = Int(payload.timeStampEnd.timeIntervalSince1970)
        let crashCount = payload.crashDiagnostics?.count ?? 0
        let hangCount  = payload.hangDiagnostics?.count ?? 0
        let kind: String
        switch (crashCount, hangCount) {
        case (let c, _) where c > 0: kind = "crash"
        case (_, let h) where h > 0: kind = "hang"
        default: kind = "diagnostic"
        }
        let filename = "\(kind)-\(timestamp).json"
        let url = logsDir.appendingPathComponent(filename)
        do {
            let data = payload.jsonRepresentation()
            try data.write(to: url, options: .atomic)
            NSLog("[MetricKit] saved %@ (%d bytes)", filename, data.count)
        } catch {
            NSLog("[MetricKit] failed to save %@: %@", filename, error.localizedDescription)
        }
    }

    private func pruneOldLogs() {
        guard let logsDir = Self.logsDirectory() else { return }
        let cutoff = Date().addingTimeInterval(TimeInterval(-Self.retentionDays * 86400))
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: logsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for url in contents {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            if let modified = values?.contentModificationDate, modified < cutoff {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: Read API for Settings → About → Crash logs

    static func logsDirectory() -> URL? {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: CadenceContainer.appGroupID
        ) else { return nil }
        let dir = groupURL.appendingPathComponent(Self.logSubdir, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Returns all stored diagnostic log files, newest first.
    static func listLogs() -> [DiagnosticLogFile] {
        guard let logsDir = logsDirectory(),
              let contents = try? FileManager.default.contentsOfDirectory(
                at: logsDir,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
              ) else { return [] }
        let files: [DiagnosticLogFile] = contents.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            return DiagnosticLogFile(
                url: url,
                filename: url.lastPathComponent,
                modifiedAt: values?.contentModificationDate ?? .distantPast,
                sizeBytes: values?.fileSize ?? 0
            )
        }
        return files.sorted { $0.modifiedAt > $1.modifiedAt }
    }
}

struct DiagnosticLogFile: Identifiable, Hashable {
    let url: URL
    let filename: String
    let modifiedAt: Date
    let sizeBytes: Int

    var id: String { url.path }

    var kind: String {
        if filename.hasPrefix("crash") { return "Crash" }
        if filename.hasPrefix("hang")  { return "Hang" }
        return "Diagnostic"
    }
}

#else
import Foundation

/// Stub for non-iOS builds (Watch, Catalyst) — MetricKit isn't available
/// there. The shared instance has a no-op `start()` so callers don't need
/// platform checks.
final class MetricKitObserver {
    static let shared = MetricKitObserver()
    private init() {}
    func start() {}
    static func listLogs() -> [DiagnosticLogFile] { [] }
    static func logsDirectory() -> URL? { nil }
}

struct DiagnosticLogFile: Identifiable, Hashable {
    let url: URL
    let filename: String
    let modifiedAt: Date
    let sizeBytes: Int
    var id: String { url.path }
    var kind: String { "Diagnostic" }
}
#endif
