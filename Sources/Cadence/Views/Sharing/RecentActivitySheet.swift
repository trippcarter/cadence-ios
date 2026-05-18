import SwiftUI
import SwiftData

/// Pull-up sheet showing the last 20 Activity entries for a shared list.
/// Each row: avatar dot (color-derived from actor), actor name, action,
/// task title snapshot, and relative timestamp.
struct RecentActivitySheet: View {
    let list: TaskList
    @Environment(\.dismiss) private var dismiss

    @Query private var allActivities: [Activity]

    private var entries: [Activity] {
        allActivities
            .filter { $0.list?.id == list.id }
            .sorted { $0.at > $1.at }
            .prefix(20)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                if entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: Tokens.Space.sm) {
                            ForEach(entries) { entry in
                                row(entry)
                            }
                        }
                        .padding(.horizontal, Tokens.Space.lg)
                        .padding(.top, Tokens.Space.md)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Recent activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Tokens.Color.accent2)
                }
            }
            .toolbarBackground(Tokens.Color.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Row

    private func row(_ entry: Activity) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            avatar(for: entry.actor, name: entry.actorName)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.actorName ?? "Someone")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    Text(entry.kind.displayLabel)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Text(entry.taskTitleSnapshot)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text2)
                    .lineLimit(2)
                Text(entry.at, format: .relative(presentation: .named))
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer(minLength: 0)
            Image(systemName: entry.kind.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(actorColor(entry.actor))
        }
        .padding(Tokens.Space.lg)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
        )
    }

    private var emptyState: some View {
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Tokens.Color.text3)
            Text("No activity yet")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Color.text)
            Text("Once \(list.name) is shared, edits from any participant show up here.")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.xxl)
        }
        .padding()
    }

    // MARK: Avatar styling

    private func avatar(for actor: String, name: String?) -> some View {
        let initials = (name ?? actor)
            .components(separatedBy: .whitespacesAndNewlines)
            .compactMap { $0.first.map(String.init) }
            .prefix(2)
            .joined()
            .uppercased()
        return Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                LinearGradient(
                    colors: [actorColor(actor), actorColor(actor).opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
    }

    /// Stable color derived from the actor identifier.
    private func actorColor(_ actor: String) -> Color {
        let palette: [Color] = [
            Tokens.Color.accent,
            Tokens.Color.teal,
            Tokens.Color.amber,
            Tokens.Color.rose,
            Tokens.Color.mint,
            Tokens.Color.pink,
            Tokens.Color.indigo,
            Tokens.Color.orange
        ]
        let hash = abs(actor.hashValue)
        return palette[hash % palette.count]
    }
}
