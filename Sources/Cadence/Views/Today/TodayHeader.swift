import SwiftUI

struct TodayHeader: View {
    let date: Date
    var onTapAvatar: () -> Void = {}
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
