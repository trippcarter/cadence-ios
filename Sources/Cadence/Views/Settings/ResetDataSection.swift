import SwiftUI
import SwiftData

/// Settings → "Danger zone" reset action. Deletes all locally-stored
/// tasks, lists, activity logs, and cached calendar events from the
/// SwiftData container.
///
/// What this DOES:
///   - Deletes every TaskItem (cascades to subtasks via the parent relationship)
///   - Deletes every TaskList (cascades to remaining tasks + activities)
///   - Deletes every Activity entry
///   - Deletes every CachedEvent (local Google Calendar cache)
///   - Re-runs SeedData.bootstrapIfNeeded → creates 4 empty default lists
///     (no sample tasks in Release builds; full sample seed in Debug)
///
/// What this does NOT do:
///   - Sign the user out of Apple ID (Account section handles that)
///   - Disconnect Google Calendar (Connected Accounts handles that)
///   - Clear iCloud Private DB contents on OTHER devices — the deletes
///     do replicate via CloudKit, so other devices signed into the same
///     Apple ID will also see the data disappear. That's intentional.
struct ResetDataSection: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingConfirm = false
    @State private var feedback: String?

    var body: some View {
        VStack(spacing: 0) {
            Button {
                showingConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.Color.rose)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset all data")
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(Tokens.Color.rose)
                        Text("Wipes tasks, lists, and cached events. Replaces with the four default lists.")
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
        .alert("Delete everything in Cadence?", isPresented: $showingConfirm) {
            Button("Delete All", role: .destructive) {
                Haptics.warning()
                performReset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Tasks, lists, recent activity, and cached calendar events will be removed from this device and iCloud. The default lists (Inbox, Personal, Business, Shared, Saved for later) come back fresh.")
        }
    }

    private func performReset() {
        do {
            // Delete every model type. SwiftData cascades via inverse rels.
            try modelContext.delete(model: TaskItem.self)
            try modelContext.delete(model: TaskList.self)
            try modelContext.delete(model: Activity.self)
            try modelContext.delete(model: CachedEvent.self)
            try modelContext.save()

            // Bring back the empty default lists. In Release builds this
            // produces a clean app; in Debug builds it re-seeds samples.
            SeedData.bootstrapIfNeeded(modelContext)
            try? modelContext.save()

            WidgetReloader.reload()
            feedback = "All data reset. Default lists restored."
        } catch {
            feedback = "Reset failed: \(error.localizedDescription)"
        }
    }
}
