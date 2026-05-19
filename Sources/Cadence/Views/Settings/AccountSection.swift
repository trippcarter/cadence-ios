import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Settings → Account row. Shows the signed-in user's name + email and
/// offers a destructive Sign Out action with confirmation alert.
///
/// Per Phase 8 spec: signing out is LOCAL only. CloudKit-synced data
/// (tasks, lists, etc.) lives in the user's iCloud Private DB and stays
/// intact across sign-out / sign-in cycles. Signing back in with the
/// same Apple ID will surface the same data.
///
/// Phase 9 additions:
///   - "Backed by iCloud: <name>" diagnostic so account mismatch is obvious
///   - "Switch Apple ID" destructive action that signs out AND re-presents
///     Apple's reauth sheet for a different identity
struct AccountSection: View {
    @EnvironmentObject private var authSession: AuthSession
    @EnvironmentObject private var cloudSync: CloudKitSyncManager
    @Environment(\.modelContext) private var modelContext
    @State private var showingSignOutConfirm = false
    @State private var showingSwitchConfirm = false
    @State private var showingDisplayNameEdit = false
    @State private var exportURL: URL?
    @State private var exportBusy: Bool = false
    @State private var exportError: String?
    @State private var showingDeleteConfirm = false

    private var user: AuthenticatedUser? {
        authSession.state.user
    }

    var body: some View {
        VStack(spacing: 0) {
            displayNameRow
            Divider().background(Tokens.Color.borderSoft)
            accountRow
            Divider().background(Tokens.Color.borderSoft)
            iCloudDiagnosticRow
            Divider().background(Tokens.Color.borderSoft)
            exportDataRow
            Divider().background(Tokens.Color.borderSoft)
            signOutRow
            Divider().background(Tokens.Color.borderSoft)
            switchAccountRow
            Divider().background(Tokens.Color.borderSoft)
            deleteAccountRow
        }
        .sheet(isPresented: $showingDisplayNameEdit) {
            DisplayNameEditSheet(mode: .edit)
        }
        .alert("Sign out of Cadence?", isPresented: $showingSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                Haptics.warning()
                authSession.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your tasks stay safely in iCloud. Sign back in any time with the same Apple ID to restore them.")
        }
        .alert("Switch to a different Apple ID?", isPresented: $showingSwitchConfirm) {
            Button("Switch", role: .destructive) {
                Haptics.warning()
                authSession.switchAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll sign out of this account and Apple will ask you which Apple ID to use next. Your existing tasks stay in iCloud and reappear when you sign back in with this account.")
        }
        .alert("Delete your account?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Haptics.warning()
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Wipes every list, task, habit, and review on this device and signs you out. Data already synced to your iCloud stays tied to your Apple ID — to remove that too, sign out of Cadence in iOS Settings → Apple ID → iCloud after this.")
        }
        .sheet(item: Binding(
            get: { exportURL.map { IdentifiableURL(url: $0) } },
            set: { newValue in exportURL = newValue?.url }
        )) { wrapper in
            ExportShareSheet(url: wrapper.url)
        }
        .alert("Couldn't build export", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: Export

    private var exportDataRow: some View {
        Button {
            Haptics.tap()
            runExport()
        } label: {
            HStack(spacing: 8) {
                if exportBusy {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 18)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.Color.mint)
                        .frame(width: 18)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export my data")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    Text("Save every task, list, habit, and review as a JSON file.")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(exportBusy)
    }

    @MainActor
    private func runExport() {
        guard !exportBusy else { return }
        exportBusy = true
        Task {
            defer { exportBusy = false }
            let export = DataExporter.buildExport(context: modelContext, user: user)
            do {
                let url = try DataExporter.writeExport(export)
                exportURL = url
            } catch {
                exportError = error.localizedDescription
            }
        }
    }

    // MARK: Delete account

    private var deleteAccountRow: some View {
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.rose)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Delete my account")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.rose)
                    Text("Wipes local data and signs you out.")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(user == nil)
    }

    @MainActor
    private func deleteAccount() {
        // Wipe every user-authored row. Cascades handle subtasks, focus
        // sessions, habit completions, etc.
        let entityTypes: [(name: String, deleter: () -> Void)] = [
            ("TaskItem", {
                let rows = (try? modelContext.fetch(FetchDescriptor<TaskItem>())) ?? []
                rows.forEach { modelContext.delete($0) }
            }),
            ("TaskList", {
                let rows = (try? modelContext.fetch(FetchDescriptor<TaskList>())) ?? []
                rows.forEach { modelContext.delete($0) }
            }),
            ("Household", {
                let rows = (try? modelContext.fetch(FetchDescriptor<Household>())) ?? []
                rows.forEach { modelContext.delete($0) }
            }),
            ("FocusSession", {
                let rows = (try? modelContext.fetch(FetchDescriptor<FocusSession>())) ?? []
                rows.forEach { modelContext.delete($0) }
            }),
            ("HabitCompletion", {
                let rows = (try? modelContext.fetch(FetchDescriptor<HabitCompletion>())) ?? []
                rows.forEach { modelContext.delete($0) }
            }),
            ("ReviewLog", {
                let rows = (try? modelContext.fetch(FetchDescriptor<ReviewLog>())) ?? []
                rows.forEach { modelContext.delete($0) }
            }),
            ("TomorrowIntention", {
                let rows = (try? modelContext.fetch(FetchDescriptor<TomorrowIntention>())) ?? []
                rows.forEach { modelContext.delete($0) }
            }),
            ("DailyWin", {
                let rows = (try? modelContext.fetch(FetchDescriptor<DailyWin>())) ?? []
                rows.forEach { modelContext.delete($0) }
            })
        ]
        for entity in entityTypes { entity.deleter() }
        try? modelContext.save()
        authSession.signOut()
    }

    /// Build 11: editable display name lives at the top of the Account
    /// section. Source of truth is UserDefaults via `UserScopedPrefs`,
    /// keyed per Apple identifier (different users on this device each
    /// get their own).
    private var displayNameRow: some View {
        Button {
            showingDisplayNameEdit = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Display Name")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    Text(user?.displayName ?? "Sign in to set")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(user == nil)
    }

    private var accountRow: some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Tokens.Color.indigo, Tokens.Color.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                Image(systemName: "applelogo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(user?.displayName ?? "Not signed in")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text(emailLabel)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var emailLabel: String {
        guard let user else { return "Sign in with Apple to enable sync" }
        if user.isUsingHiddenEmail { return "Private email (\(user.email ?? ""))" }
        if let email = user.email, !email.isEmpty { return email }
        return "Signed in with Apple ID"
    }

    /// Surfaces which iCloud account is backing the SwiftData/CloudKit store.
    /// If this diverges from the Apple Sign-In user shown above, something
    /// is off and we should investigate — but AuthSession.refreshCredentialState
    /// will normally force a sign-out before the user ever sees a mismatch.
    private var iCloudDiagnosticRow: some View {
        HStack(spacing: 8) {
            Image(systemName: iCloudIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iCloudColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("Backed by iCloud")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text(iCloudStatusLine)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var iCloudIcon: String {
        switch cloudSync.accountStatus {
        case .available:           return "icloud.fill"
        case .noAccount:           return "icloud.slash.fill"
        case .restricted:          return "icloud.slash.fill"
        case .temporarilyUnavailable: return "icloud.fill"
        case .couldNotDetermine:   return "icloud"
        @unknown default:          return "icloud"
        }
    }

    private var iCloudColor: Color {
        switch cloudSync.accountStatus {
        case .available:    return Tokens.Color.mint
        case .noAccount:    return Tokens.Color.rose
        case .restricted:   return Tokens.Color.rose
        case .temporarilyUnavailable: return Tokens.Color.amber
        case .couldNotDetermine: return Tokens.Color.text3
        @unknown default:   return Tokens.Color.text3
        }
    }

    private var iCloudStatusLine: String {
        switch cloudSync.accountStatus {
        case .available:
            if let email = cloudSync.userEmail, !email.isEmpty {
                return email
            }
            return "iCloud signed in"
        case .noAccount:
            return "No iCloud signed in — tasks won't sync"
        case .restricted:
            return "iCloud access restricted on this device"
        case .temporarilyUnavailable:
            return "iCloud temporarily unavailable"
        case .couldNotDetermine:
            return "Checking iCloud…"
        @unknown default:
            return cloudSync.accountStatus.displayLabel
        }
    }

    private var signOutRow: some View {
        Button {
            showingSignOutConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.rose)
                    .frame(width: 18)
                Text("Sign Out")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.rose)
                Spacer()
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(user == nil)
    }

    private var switchAccountRow: some View {
        Button {
            showingSwitchConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Switch Apple ID")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.accent2)
                    Text("Sign out and choose a different Apple ID.")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(user == nil)
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.path }
}

private struct ExportShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
