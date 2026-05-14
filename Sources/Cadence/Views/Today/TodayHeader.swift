import SwiftUI

struct TodayHeader: View {
    let date: Date

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
            AvatarCluster()
        }
    }
}
