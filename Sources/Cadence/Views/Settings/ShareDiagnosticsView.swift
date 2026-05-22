import SwiftUI
import SwiftData
import CloudKit
#if canImport(UIKit)
import UIKit
#endif

/// Build 31: developer screen to diagnose Spaces / list sharing without
/// needing a second device. "Run share test" exercises the full CKShare
/// creation path against a real (or freshly-created) list and reports
/// each step — iCloud account status, zone creation, share URL — inline
/// and to os_log. If it produces a share URL, the sharing pipeline works
/// and the bug is on the recipient/accept side; if it throws, the error
/// message says exactly what's wrong.
struct ShareDiagnosticsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authSession: AuthSession
    @Query private var allLists: [TaskList]

    @State private var running = false
    @State private var steps: [DiagStep] = []
    @State private var shareURL: URL?
    @State private var presentingShare: SharePresentation?

    struct DiagStep: Identifiable {
        let id = UUID()
        let ok: Bool
        let text: String
    }

    struct SharePresentation: Identifiable {
        let id = UUID()
        let share: CKShare
        let container: CKContainer
    }

    var body: some View {
        SubscreenScaffold(title: "Share Diagnostics") {
            SubscreenCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Exercises the CKShare creation path end-to-end. Runs against a list named \"Sharing Test\" (created if absent). Watch Console.app filtered to category SHARING for the full trace.")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Tokens.Space.lg)
            }

            SubscreenCard {
                Button {
                    Haptics.tap()
                    Task { await runTest() }
                } label: {
                    HStack(spacing: 8) {
                        if running {
                            ProgressView().scaleEffect(0.8).frame(width: 18)
                        } else {
                            Image(systemName: "person.2.badge.gearshape.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Tokens.Color.accent2)
                                .frame(width: 18)
                        }
                        Text(running ? "Running…" : "Run share test")
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(Tokens.Color.text)
                        Spacer()
                    }
                    .padding(Tokens.Space.lg)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(running)
            }

            if !steps.isEmpty {
                SubscreenCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RESULT")
                            .font(Tokens.Font.label).kerning(0.8)
                            .foregroundStyle(Tokens.Color.text3)
                        ForEach(steps) { step in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: step.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(step.ok ? Tokens.Color.mint : Tokens.Color.rose)
                                Text(step.text)
                                    .font(Tokens.Font.body)
                                    .foregroundStyle(Tokens.Color.text2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(Tokens.Space.lg)
                }
            }

            if shareURL != nil {
                SubscreenCard {
                    Button {
                        Haptics.tap()
                        openShareSheet()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Tokens.Color.accent2)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Open invite share sheet")
                                    .font(Tokens.Font.bodyEmphasis)
                                    .foregroundStyle(Tokens.Color.text)
                                Text("Send the invite to your own email to test acceptance.")
                                    .font(Tokens.Font.caption)
                                    .foregroundStyle(Tokens.Color.text3)
                            }
                            Spacer()
                        }
                        .padding(Tokens.Space.lg)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        #if canImport(UIKit)
        .sheet(item: $presentingShare) { p in
            CloudSharingControllerView(share: p.share, container: p.container)
        }
        #endif
    }

    @MainActor
    private func runTest() async {
        running = true
        steps = []
        shareURL = nil
        defer { running = false }

        // Step 1: iCloud account status.
        let container = CKContainer(identifier: CadenceContainer.cloudContainerID)
        do {
            let status = try await container.accountStatus()
            if status == .available {
                steps.append(.init(ok: true, text: "iCloud account available."))
            } else {
                steps.append(.init(ok: false, text: "iCloud account NOT available (status \(status.rawValue)). Sign into iCloud in Settings — sharing can't work without it."))
                return
            }
        } catch {
            steps.append(.init(ok: false, text: "Couldn't check iCloud account: \(error.localizedDescription)"))
            return
        }

        // Step 2: find or create the test list.
        let testList: TaskList
        if let existing = allLists.first(where: { $0.name == "Sharing Test" }) {
            testList = existing
            steps.append(.init(ok: true, text: "Reusing existing \"Sharing Test\" list."))
        } else {
            let maxOrder = allLists.map(\.sortOrder).max() ?? 0
            let created = TaskList(name: "Sharing Test", colorKey: "teal",
                                   iconKey: "person.2.fill", sortOrder: maxOrder + 1)
            modelContext.insert(created)
            try? modelContext.save()
            testList = created
            steps.append(.init(ok: true, text: "Created a \"Sharing Test\" list."))
        }

        // Step 3: create the CKShare.
        let ownerName = authSession.state.user?.displayName ?? "Owner"
        do {
            let (share, container) = try await CloudKitSharingService.shared.makeShare(
                for: testList, ownerName: ownerName
            )
            if let url = share.url {
                steps.append(.init(ok: true, text: "Share created. URL: \(url.absoluteString)"))
                shareURL = url
                presentingShare = SharePresentation(share: share, container: container)
            } else {
                steps.append(.init(ok: true, text: "Share created, but URL is still nil — CloudKit populates it after the first sync. Tap \"Open invite share sheet\" and iOS will finalize it."))
                presentingShare = SharePresentation(share: share, container: container)
                shareURL = URL(string: "pending://")  // unlock the button
            }
        } catch {
            steps.append(.init(ok: false, text: "Share creation FAILED: \(error.localizedDescription)"))
        }
    }

    private func openShareSheet() {
        if let p = presentingShare {
            // Re-trigger the sheet (item-based presentation).
            let again = p
            presentingShare = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                presentingShare = again
            }
        }
    }
}
