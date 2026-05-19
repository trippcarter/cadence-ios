import SwiftUI

struct TodayHeader: View {
    let date: Date
    var onTapAvatar: () -> Void = {}
    /// Build 25: tap the search glyph on Today header → opens the cross-
    /// entity search sheet (same one ⌘F triggers from a hardware keyboard).
    var onTapSearch: () -> Void = {}
    @EnvironmentObject private var cloudSync: CloudKitSyncManager

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(date, format: .dateTime.weekday(.wide))
                    .font(.system(size: 13, weight: .medium))
                    .kerning(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Color.text3)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(date, format: .dateTime.day(.defaultDigits))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Tokens.Color.text)
                        .kerning(-0.5)
                    Text(date, format: .dateTime.month(.wide))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Tokens.Color.text2)
                }
            }
            Spacer()
            if cloudSync.isSyncing {
                syncIndicator
                    .padding(.trailing, 4)
            }
            Button {
                Haptics.tap()
                onTapSearch()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text2)
                    .frame(width: 30, height: 30)
                    .background(Tokens.Color.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Tokens.Color.borderSoft, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
            .accessibilityLabel("Search")
            AvatarCluster(onTap: onTapAvatar)
        }
    }

    /// Hairline-subtle pulsing teal dot while iCloud sync is in flight.
    private var syncIndicator: some View {
        Circle()
            .fill(Tokens.Color.teal)
            .frame(width: 7, height: 7)
            .opacity(0.85)
            .symbolEffect(.pulse, options: .repeating, isActive: true)
            .accessibilityLabel("Syncing")
    }
}
