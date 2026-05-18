import SwiftUI
import SwiftData

/// "Quick start" template chooser. Auto-presents once after the first
/// successful sign-in for a given Apple ID on this device (keyed per-user
/// via `UserScopedPrefs.hasSeenTemplateGallery`). Also reachable any time
/// via the Lists tab's "From template" button.
///
/// Build 11 rewrite: tap-to-toggle multi-select. Cards no longer auto-insert
/// on tap — the user picks N cards, then commits with "Create N lists" at
/// the bottom. "Skip" dismisses without creating anything. Either action
/// stamps the seen flag so we don't auto-present again.
struct TemplateGallerySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authSession: AuthSession

    @State private var selectedCategory: TemplateLibrary.Category = .personal
    @State private var selectedTemplateIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Tokens.Color.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                        headerBlock
                            .padding(.horizontal, Tokens.Space.lg)
                            .padding(.top, Tokens.Space.md)

                        categoryTabs
                            .padding(.horizontal, Tokens.Space.lg)

                        templateGrid
                            .padding(.horizontal, Tokens.Space.lg)

                        // Leave room for the docked bottom action bar.
                        Color.clear.frame(height: 100)
                    }
                }
                .scrollIndicators(.hidden)

                actionBar
            }
            .navigationTitle("Quick start")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
    }

    // MARK: Header

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pick a starting point")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Tokens.Color.text)
            Text("Tap any template to select it. Pick as many as you want — your lists fill in when you tap Create.")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text3)
        }
    }

    // MARK: Category tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.sm) {
                ForEach(TemplateLibrary.Category.allCases) { category in
                    categoryChip(category)
                }
            }
        }
    }

    private func categoryChip(_ category: TemplateLibrary.Category) -> some View {
        let isSelected = selectedCategory == category
        let tint = ListPalette.color(for: category.accentKey)
        return Button {
            Haptics.tap()
            withAnimation(.bouncy(duration: 0.3)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(category.rawValue)
                    .font(Tokens.Font.bodyEmphasis)
            }
            .foregroundStyle(isSelected ? tint : Tokens.Color.text2)
            .padding(.horizontal, Tokens.Space.md)
            .padding(.vertical, Tokens.Space.sm)
            .background(isSelected ? tint.opacity(0.18) : Tokens.Color.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? tint : Tokens.Color.borderSoft, lineWidth: isSelected ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Template grid

    private var templateGrid: some View {
        let columns = [GridItem(.flexible(), spacing: Tokens.Space.sm),
                       GridItem(.flexible(), spacing: Tokens.Space.sm)]
        let templates = TemplateLibrary.templates(in: selectedCategory)
        return LazyVGrid(columns: columns, spacing: Tokens.Space.sm) {
            ForEach(templates) { template in
                templateCard(template)
            }
        }
    }

    private func templateCard(_ template: TemplateLibrary.Template) -> some View {
        let isSelected = selectedTemplateIDs.contains(template.id)
        let tint = ListPalette.color(for: template.colorKey)
        return Button {
            toggle(template)
        } label: {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                            .fill(tint.opacity(0.22))
                            .frame(width: 36, height: 36)
                        Image(systemName: template.iconKey)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    Spacer()
                    selectionIndicator(isSelected: isSelected, tint: tint)
                }
                Text(template.name)
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                    .lineLimit(1)
                Text("\(template.starterTasks.count) starter tasks")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Space.md)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(isSelected ? Tokens.Color.accent : Tokens.Color.borderSoft,
                            lineWidth: isSelected ? 1.4 : 0.5)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.bouncy(duration: 0.35), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func selectionIndicator(isSelected: Bool, tint: Color) -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Tokens.Color.accent : Tokens.Color.borderSoft, lineWidth: isSelected ? 0 : 1)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(Tokens.Color.accent)
                    .frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.bouncy(duration: 0.3), value: isSelected)
    }

    // MARK: Bottom action bar

    private var actionBar: some View {
        HStack(spacing: Tokens.Space.md) {
            Button {
                Haptics.tap()
                finish(creating: false)
            } label: {
                Text("Skip")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text2)
                    .padding(.vertical, Tokens.Space.md)
                    .padding(.horizontal, Tokens.Space.lg)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                Haptics.success()
                finish(creating: true)
            } label: {
                HStack(spacing: 6) {
                    Text(selectedTemplateIDs.isEmpty
                         ? "Create"
                         : "Create \(selectedTemplateIDs.count) list\(selectedTemplateIDs.count == 1 ? "" : "s")")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(.white)
                }
                .padding(.vertical, Tokens.Space.md)
                .padding(.horizontal, Tokens.Space.xl)
                .background(
                    LinearGradient(
                        colors: selectedTemplateIDs.isEmpty
                            ? [Tokens.Color.text3.opacity(0.4), Tokens.Color.text3.opacity(0.4)]
                            : [Tokens.Color.accent, Tokens.Color.accentDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                .shadow(color: selectedTemplateIDs.isEmpty ? .clear : Tokens.Color.accentGlow,
                        radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(selectedTemplateIDs.isEmpty)
            .opacity(selectedTemplateIDs.isEmpty ? 0.6 : 1.0)
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
    }

    // MARK: Actions

    private func toggle(_ template: TemplateLibrary.Template) {
        Haptics.tap()
        withAnimation(.bouncy(duration: 0.35)) {
            if selectedTemplateIDs.contains(template.id) {
                selectedTemplateIDs.remove(template.id)
            } else {
                selectedTemplateIDs.insert(template.id)
            }
        }
    }

    private func finish(creating: Bool) {
        if creating {
            createSelectedLists()
        }
        if let identifier = authSession.state.user?.appleUserIdentifier {
            UserScopedPrefs.setHasSeenTemplateGallery(true, for: identifier)
        } else {
            // No-auth case (e.g. simulator with no sign-in) — fall back to
            // the legacy device-wide flag so we don't keep re-prompting.
            UserDefaults.standard.set(true, forKey: PrefsKey.hasSeenTemplateGallery)
        }
        dismiss()
    }

    private func createSelectedLists() {
        let descriptor = FetchDescriptor<TaskList>(
            sortBy: [SortDescriptor(\TaskList.sortOrder, order: .reverse)]
        )
        var highestSort = (try? modelContext.fetch(descriptor).first?.sortOrder) ?? 0

        // Materialize selected templates in user-tap order via the cached
        // category sweep so user-perceived ordering is intuitive.
        let allTemplates = TemplateLibrary.Category.allCases.flatMap { TemplateLibrary.templates(in: $0) }
        let templatesToCreate = allTemplates.filter { selectedTemplateIDs.contains($0.id) }

        for template in templatesToCreate {
            highestSort += 1
            let newList = TaskList(
                name: template.name,
                colorKey: template.colorKey,
                iconKey: template.iconKey,
                sortOrder: highestSort,
                isSeeded: false
            )
            modelContext.insert(newList)
            for title in template.starterTasks {
                let task = TaskItem(title: title, list: newList)
                modelContext.insert(task)
            }
        }

        try? modelContext.save()
        WidgetReloader.reload()
    }
}
