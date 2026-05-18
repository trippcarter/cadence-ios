import SwiftUI
import SwiftData

/// Bottom toolbar that slides up when at least one task is selected in
/// multi-select mode. Standard iOS pattern (Mail, Reminders).
///
/// Exposes Complete / Move / Priority / More (Duplicate, Delete) plus a
/// Cancel exit. Owner provides the list of all tasks in scope so the
/// batch actions can resolve selectedIDs → TaskItem.
struct BatchActionBar: View {
    @ObservedObject var selection: TaskSelectionState
    let allTasks: [TaskItem]
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\TaskList.sortOrder, order: .forward)])
    private var allLists: [TaskList]

    @State private var showingMoveSheet = false
    @State private var showingPrioritySheet = false
    @State private var showingMoreSheet = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        HStack(spacing: Tokens.Space.lg) {
            actionButton(icon: "checkmark.circle.fill",
                         label: "Complete",
                         tint: Tokens.Color.mint) {
                selection.completeAll(in: modelContext, allTasks: allTasks)
            }
            actionButton(icon: "tray.and.arrow.up",
                         label: "Move",
                         tint: Tokens.Color.accent2) {
                showingMoveSheet = true
            }
            actionButton(icon: "flag.fill",
                         label: "Priority",
                         tint: Tokens.Color.amber) {
                showingPrioritySheet = true
            }
            actionButton(icon: "ellipsis.circle.fill",
                         label: "More",
                         tint: Tokens.Color.text2) {
                showingMoreSheet = true
            }
            Spacer()
            cancelButton
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.top, Tokens.Space.md)
        .padding(.bottom, Tokens.Space.md)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Tokens.Color.bg.opacity(0.55)
            }
            .overlay(alignment: .top) {
                Rectangle().fill(Tokens.Color.border).frame(height: 0.5)
            }
            .ignoresSafeArea(edges: .bottom)
        )
        .confirmationDialog("Move \(selection.selectedCount) task\(selection.selectedCount == 1 ? "" : "s") to…",
                            isPresented: $showingMoveSheet,
                            titleVisibility: .visible) {
            ForEach(allLists.filter { !$0.isHidden }) { list in
                Button(list.name) {
                    selection.moveAll(to: list, in: modelContext, allTasks: allTasks)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Set priority for \(selection.selectedCount) task\(selection.selectedCount == 1 ? "" : "s")",
                            isPresented: $showingPrioritySheet,
                            titleVisibility: .visible) {
            Button("High") { selection.setPriorityAll(.high, in: modelContext, allTasks: allTasks) }
            Button("Medium") { selection.setPriorityAll(.medium, in: modelContext, allTasks: allTasks) }
            Button("Low") { selection.setPriorityAll(.low, in: modelContext, allTasks: allTasks) }
            Button("None") { selection.setPriorityAll(.none, in: modelContext, allTasks: allTasks) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("More actions",
                            isPresented: $showingMoreSheet,
                            titleVisibility: .visible) {
            Button("Duplicate") {
                selection.duplicateAll(in: modelContext, allTasks: allTasks)
            }
            Button("Delete", role: .destructive) {
                showingDeleteConfirm = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete \(selection.selectedCount) task\(selection.selectedCount == 1 ? "" : "s")?",
               isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                selection.deleteAll(in: modelContext, allTasks: allTasks)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }

    private func actionButton(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.2)
                    .foregroundStyle(Tokens.Color.text2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) \(selection.selectedCount) task\(selection.selectedCount == 1 ? "" : "s")")
    }

    private var cancelButton: some View {
        Button {
            selection.cancel()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Tokens.Color.rose)
                Text("Cancel")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.2)
                    .foregroundStyle(Tokens.Color.text2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Exit select mode")
    }
}
