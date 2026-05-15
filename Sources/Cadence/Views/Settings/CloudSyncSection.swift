import SwiftUI
import CloudKit
#if canImport(UIKit)
import UIKit
#endif

/// Settings → iCloud sync section. Renders the account row, sync status,
/// and a Refresh now action. Sits inside the existing Settings sections().
struct CloudSyncSection: View {
    @EnvironmentObject private var sync: CloudKitSyncManager
    @State private var feedback: String?

    var body: some View {
        VStack(spacing: 0) {
            accountRow
            Divider().background(Tokens.Color.borderSoft)
            statusRow
            Divider().background(Tokens.Color.borderSoft)
            refreshRow
            if sync.accountStatus == .noAccount {
                Divider().background(Tokens.Color.borderSoft)
                openSettingsRow
            }
            if let feedback {
                Divider().background(Tokens.Color.borderSoft)
                Text(feedback)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Rows

    private var accountRow: some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(accountColor.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: accountIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accountColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Account")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text(accountLabel)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var statusRow: some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            Image(systemName: sync.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.seal")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 18)
                .symbolEffect(.pulse, options: .repeating, isActive: sync.isSyncing)
            VStack(alignment: .leading, spacing: 2) {
                Text("Status")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text(statusLabel)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var refreshRow: some View {
        HStack {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Tokens.Color.text3)
                .frame(width: 18)
            Text("Refresh now")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text)
            Spacer()
            Button {
                Haptics.tap()
                Task {
                    await sync.refreshNow()
                    feedback = "Sync ping sent."
                }
            } label: {
                Text(sync.isSyncing ? "Syncing…" : "Refresh")
                    .font(Tokens.Font.chip)
                    .padding(.horizontal, Tokens.Space.md)
                    .padding(.vertical, 7)
                    .background(Tokens.Color.accent.opacity(0.18))
                    .foregroundStyle(Tokens.Color.accent2)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(sync.isSyncing || sync.accountStatus != .available)
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var openSettingsRow: some View {
        Button {
            openSystemSettings()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13, weight: .semibold))
                Text("Open iCloud Settings")
                    .font(Tokens.Font.bodyEmphasis)
                Spacer()
            }
            .foregroundStyle(Tokens.Color.accent2)
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private var accountLabel: String {
        switch sync.accountStatus {
        case .available:
            return sync.userEmail ?? "iCloud account connected"
        default:
            return sync.accountStatus.displayLabel
        }
    }

    private var accountColor: Color {
        sync.accountStatus == .available ? Tokens.Color.mint : Tokens.Color.amber
    }

    private var accountIcon: String {
        switch sync.accountStatus {
        case .available: return "cloud.fill"
        case .noAccount: return "cloud.slash"
        default:         return "cloud"
        }
    }

    private var statusColor: Color {
        if sync.isSyncing { return Tokens.Color.accent2 }
        return sync.accountStatus == .available ? Tokens.Color.mint : Tokens.Color.text3
    }

    private var statusLabel: String {
        if sync.accountStatus != .available {
            return sync.accountStatus.displayLabel
        }
        if sync.isSyncing { return "Syncing…" }
        if let last = sync.lastSyncedAt {
            return "Up to date · \(last.formatted(.relative(presentation: .named)))"
        }
        return "Up to date"
    }

    private func openSystemSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
