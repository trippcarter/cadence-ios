import SwiftUI

// MARK: - What's New

/// Build 28: walk-the-history release notes view reached from
/// Settings → Help & support → What's new. The list reads top-down,
/// newest build first, with each card showing a few bullet wins.
struct WhatsNewSubscreen: View {
    var body: some View {
        SubscreenScaffold(title: "What's new") {
            ForEach(WhatsNewEntry.all) { entry in
                buildCard(entry)
            }
        }
    }

    private func buildCard(_ entry: WhatsNewEntry) -> some View {
        SubscreenCard {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.sm) {
                    Text("Build \(entry.build)")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Color.text)
                    if entry.build == WhatsNewEntry.all.first?.build {
                        Text("LATEST")
                            .font(Tokens.Font.label)
                            .kerning(0.8)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Tokens.Color.accent.opacity(0.22))
                            .foregroundStyle(Tokens.Color.accent2)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text(entry.dateLabel)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Text(entry.headline)
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text2)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(Tokens.Color.text3)
                                .padding(.top, 6)
                            Text(bullet)
                                .font(Tokens.Font.body)
                                .foregroundStyle(Tokens.Color.text2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(Tokens.Space.lg)
        }
    }
}

struct WhatsNewEntry: Identifiable, Hashable {
    let build: Int
    let dateLabel: String
    let headline: String
    let bullets: [String]

    var id: Int { build }

    static let all: [WhatsNewEntry] = [
        WhatsNewEntry(
            build: 28,
            dateLabel: "May 2026",
            headline: "Settings rebuilt around what you actually do.",
            bullets: [
                "You tab reorganized into 8 clean sections.",
                "New Edit profile sheet with avatar color picker.",
                "Quiet hours, time format, first day of week, default sort, default reminder — all new preferences.",
                "Drill-in sub-screens for Account, Theme, Focus, Voice & Siri, Today layout, and more.",
                "What's new (this screen) and Acknowledgments added under About."
            ]
        ),
        WhatsNewEntry(
            build: 27,
            dateLabel: "May 2026",
            headline: "Distinct icons + genericized policy + Watch shipping.",
            bullets: [
                "Fixed the alternate-icon bug — every variant on the home screen now matches the picker.",
                "Privacy Policy and Terms genericized; no more personal info.",
                "Apple Watch app is shipping with every iPhone install."
            ]
        ),
        WhatsNewEntry(
            build: 26,
            dateLabel: "May 2026",
            headline: "Real-world readiness.",
            bullets: [
                "Privacy Policy + Terms of Service in Settings → About.",
                "Help & FAQ with searchable Q&A.",
                "Data export to JSON; delete-my-account flow.",
                "Recovery banners for iCloud and Google Calendar issues.",
                "MetricKit crash logs viewable on-device."
            ]
        ),
        WhatsNewEntry(
            build: 25,
            dateLabel: "May 2026",
            headline: "Spaces, search, completed history.",
            bullets: [
                "Households renamed to Spaces.",
                "Today view reordered: Pinned → Today → Coming up → Carried over.",
                "Magnifying-glass search across tasks, lists, and spaces.",
                "Completed history view with week/month/year picker."
            ]
        ),
        WhatsNewEntry(
            build: 24,
            dateLabel: "Earlier",
            headline: "Themes, alternate icons, keyboard shortcuts.",
            bullets: [
                "7 picker-driven theme accents.",
                "8 alternate app icons (and now they actually work — see Build 27).",
                "⌘N / ⌘F / ⌘1-4 for power-user navigation."
            ]
        ),
        WhatsNewEntry(
            build: 23,
            dateLabel: "Earlier",
            headline: "Apple Watch app shipped.",
            bullets: [
                "Native watchOS app with Today view + complete circles.",
                "Voice add via Siri-style speech recognition.",
                "Complications for corner, circular, and rectangular faces."
            ]
        )
    ]
}

// MARK: - Acknowledgments

struct AcknowledgmentsSubscreen: View {
    var body: some View {
        SubscreenScaffold(title: "Acknowledgments") {
            introCard
            ForEach(Library.all) { lib in
                libraryCard(lib)
            }
        }
    }

    private var introCard: some View {
        SubscreenCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Thanks to the open-source community")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text("Cadence wouldn't ship without the work below. Each library keeps its own license; tap a card to read it.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Space.lg)
        }
    }

    private func libraryCard(_ lib: Library) -> some View {
        SubscreenCard {
            Link(destination: URL(string: lib.url)!) {
                HStack(spacing: Tokens.Space.md) {
                    Image(systemName: lib.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.Color.accent2)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lib.name)
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(Tokens.Color.text)
                        Text(lib.purpose)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Color.text3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Text(lib.license)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Tokens.Color.text3)
                }
                .padding(Tokens.Space.lg)
                .contentShape(Rectangle())
            }
        }
    }
}

struct Library: Identifiable, Hashable {
    let name: String
    let purpose: String
    let url: String
    let license: String
    let icon: String

    var id: String { name }

    static let all: [Library] = [
        Library(
            name: "AppAuth-iOS",
            purpose: "OAuth/OpenID Connect client for Google Calendar sign-in.",
            url: "https://github.com/openid/AppAuth-iOS",
            license: "Apache 2.0",
            icon: "key.fill"
        ),
        Library(
            name: "Apple SwiftUI + SwiftData",
            purpose: "The UI and persistence framework Cadence is built on.",
            url: "https://developer.apple.com/swiftui/",
            license: "Apple SDK",
            icon: "applelogo"
        ),
        Library(
            name: "Apple CloudKit",
            purpose: "Private cross-device sync of your tasks and lists.",
            url: "https://developer.apple.com/icloud/cloudkit/",
            license: "Apple SDK",
            icon: "icloud.fill"
        ),
        Library(
            name: "Apple MetricKit",
            purpose: "On-device crash and hang reporting (Settings → About → Crash logs).",
            url: "https://developer.apple.com/documentation/metrickit",
            license: "Apple SDK",
            icon: "exclamationmark.octagon"
        )
    ]
}
