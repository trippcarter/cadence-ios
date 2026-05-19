import SwiftUI
import CloudKit
#if canImport(UIKit)
import UIKit
#endif

/// Build 26: persistent recovery banners shown at the top of the app
/// when the system is in a state that needs the user's attention but
/// shouldn't block the entire UI. Currently surfaces:
///
/// - iCloud not signed in / restricted (sync silently broken otherwise)
/// - Google Calendar token expired (events stop fetching otherwise)
///
/// Banners stack vertically and dismiss themselves when the underlying
/// condition clears. Use as a sibling of the main content in RootView,
/// pinned to the top safe area.
struct RecoveryBanners: View {
    /// Routes the user to Settings → Connected Accounts to re-link their
    /// Google account. RootView wires this to switch to the .you tab.
    var onReconnectGoogle: () -> Void = {}

    @EnvironmentObject private var cloudSync: CloudKitSyncManager
    @ObservedObject private var googleService = GoogleCalendarService.shared

    @State private var iCloudBannerDismissed: Bool = false
    @State private var googleBannerDismissed: Bool = false

    var body: some View {
        VStack(spacing: Tokens.Space.sm) {
            if showsICloudBanner {
                iCloudBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if showsGoogleBanner {
                googleBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showsICloudBanner)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showsGoogleBanner)
        .onChange(of: cloudSync.accountStatus) { _, status in
            if status == .available { iCloudBannerDismissed = false }
        }
        .onChange(of: googleService.lastError?.localizedDescription) { _, _ in
            googleBannerDismissed = false
        }
    }

    // MARK: Conditions

    private var showsICloudBanner: Bool {
        guard !iCloudBannerDismissed else { return false }
        switch cloudSync.accountStatus {
        case .available, .couldNotDetermine: return false
        case .noAccount, .restricted, .temporarilyUnavailable: return true
        @unknown default: return false
        }
    }

    private var showsGoogleBanner: Bool {
        guard !googleBannerDismissed else { return false }
        if case .tokenExpired = googleService.lastError { return true }
        return false
    }

    // MARK: iCloud banner

    private var iCloudBanner: some View {
        BannerCard(
            icon: "icloud.slash.fill",
            iconTint: Tokens.Color.rose,
            title: iCloudBannerTitle,
            subtitle: iCloudBannerSubtitle,
            primaryAction: BannerAction(label: "Open Settings", handler: openSystemSettings),
            onDismiss: { iCloudBannerDismissed = true }
        )
    }

    private var iCloudBannerTitle: String {
        switch cloudSync.accountStatus {
        case .noAccount:               return "Sign in to iCloud for sync"
        case .restricted:              return "iCloud is restricted on this device"
        case .temporarilyUnavailable:  return "iCloud is unavailable right now"
        default:                       return "iCloud isn't available"
        }
    }

    private var iCloudBannerSubtitle: String {
        switch cloudSync.accountStatus {
        case .noAccount:
            return "Cadence works locally, but won't sync to your other devices until you sign in."
        case .restricted:
            return "A profile or parental setting is blocking iCloud. Check Screen Time and MDM."
        case .temporarilyUnavailable:
            return "Apple's iCloud servers are unreachable. We'll keep retrying."
        default:
            return "Open System Settings and check your iCloud account."
        }
    }

    // MARK: Google banner

    private var googleBanner: some View {
        BannerCard(
            icon: "exclamationmark.arrow.triangle.2.circlepath",
            iconTint: Tokens.Color.amber,
            title: "Reconnect Google Calendar",
            subtitle: "Your Google sign-in expired. Reconnect to keep events flowing in.",
            primaryAction: BannerAction(label: "Reconnect") {
                onReconnectGoogle()
            },
            onDismiss: { googleBannerDismissed = true }
        )
    }

    // MARK: Settings deep link

    private func openSystemSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - BannerCard

struct BannerAction {
    let label: String
    let handler: () -> Void
}

private struct BannerCard: View {
    let icon: String
    let iconTint: Color
    let title: String
    let subtitle: String
    let primaryAction: BannerAction
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(iconTint.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconTint)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text(subtitle)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Haptics.tap()
                    primaryAction.handler()
                } label: {
                    Text(primaryAction.label)
                        .font(Tokens.Font.chip)
                        .padding(.horizontal, Tokens.Space.md)
                        .padding(.vertical, 6)
                        .background(Tokens.Color.accent.opacity(0.18))
                        .foregroundStyle(Tokens.Color.accent2)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
            Button {
                Haptics.tap()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Tokens.Color.text3)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(Tokens.Space.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(iconTint.opacity(0.35), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
    }
}
