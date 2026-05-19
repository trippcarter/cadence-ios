import SwiftUI
import SwiftData

/// Build 21: native watchOS companion app entry point. Shares the
/// CadenceContainer + CloudKit private DB with the iPhone, so the user's
/// tasks appear identically on both devices within seconds.
///
/// Container init follows the same Build 19 safe-failure pattern as the
/// iPhone app: any ModelContainer error surfaces a recoverable message
/// instead of crashing the launch.
@main
struct CadenceWatchApp: App {
    @State private var container: ModelContainer?
    @State private var initError: String?

    init() {
        do {
            _container = State(initialValue: try CadenceContainer.makeContainer())
        } catch {
            NSLog("[CadenceWatch-Boot] container init failed: %@", String(describing: error))
            _initError = State(initialValue: String(describing: error))
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                WatchTodayView()
                    .modelContainer(container)
            } else {
                WatchErrorView(message: initError ?? "Unknown error")
            }
        }
    }
}

/// Minimal Watch-sized error screen — surfaced if the SwiftData container
/// fails to build on the Watch (typically a CloudKit / App Group entitlement
/// mismatch). Better than a crash for diagnosis.
struct WatchErrorView: View {
    let message: String
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                    .padding(.top, 8)
                Text("Sync issue")
                    .font(.system(size: 16, weight: .semibold))
                Text("Open Cadence on your iPhone to retry.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 8)
        }
    }
}
