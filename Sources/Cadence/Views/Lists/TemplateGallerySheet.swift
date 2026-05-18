import SwiftUI
import SwiftData

/// "Quick start" template chooser. Auto-presents once after first sign-in
/// (controlled by `PrefsKey.hasSeenTemplateGallery`); also reachable any
/// time via the Lists tab's "From template" button.
///
/// User can tap multiple template cards in a single session — each one
/// inserts a TaskList + its starter TaskItems immediately, so the user
/// can see their workspace fill out as they pick. "Done" dismisses the
/// sheet and stamps the seen flag.
struct TemplateGallerySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PrefsKey.hasSeenTemplateGallery) private var hasSeen: Bool = false

    @State private var selectedCategory: TemplateLibrary.Category = .personal
    @State private var addedTemplateIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
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

                        if !addedTemplateIDs.isEmpty {
                            addedRecap
                                .padding(.horizontal, Tokens.Space.lg)
                        }

                        Color.clear.frame(height: 80)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Quick start")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Start fresh") {
                        finish()
                    }
                    .foregroundStyle(Tokens.Color.text2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(addedTemplateIDs.isEmpty ? "Skip" : "Done") {
                        finish()
                    }
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.accent2)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: Header

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pick a starting point")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Tokens.Color.text)
            Text("Tap any template to add it to your lists. Tap several if you want — you can edit or delete them later.")
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

    // MARK: Templates grid

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
        let added = addedTemplateIDs.contains(template.id)
        let tint = ListPalette.color(for: template.colorKey)
        return Button {
            addTemplate(template)
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
                    if added {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Tokens.Color.mint)
                            .transition(.scale.combined(with: .opacity))
                    }
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
                    .stroke(added ? Tokens.Color.mint : Tokens.Color.borderSoft, lineWidth: added ? 1 : 0.5)
            )
            .scaleEffect(added ? 0.96 : 1.0)
            .animation(.bouncy(duration: 0.35), value: added)
        }
        .buttonStyle(.plain)
        .disabled(added)
    }

    private var addedRecap: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Tokens.Color.mint)
            Text("\(addedTemplateIDs.count) list\(addedTemplateIDs.count == 1 ? "" : "s") added")
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text)
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.md)
        .background(Tokens.Color.mint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Color.mint.opacity(0.4), lineWidth: 0.5)
        )
    }

    // MARK: Actions

    private func addTemplate(_ template: TemplateLibrary.Template) {
        guard !addedTemplateIDs.contains(template.id) else { return }
        Haptics.success()

        let descriptor = FetchDescriptor<TaskList>(
            sortBy: [SortDescriptor(\TaskList.sortOrder, order: .reverse)]
        )
        let highestSort = (try? modelContext.fetch(descriptor).first?.sortOrder) ?? 0

        let newList = TaskList(
            name: template.name,
            colorKey: template.colorKey,
            iconKey: template.iconKey,
            sortOrder: highestSort + 1,
            isSeeded: false
        )
        modelContext.insert(newList)

        for title in template.starterTasks {
            let task = TaskItem(title: title, list: newList)
            modelContext.insert(task)
        }

        try? modelContext.save()
        WidgetReloader.reload()

        withAnimation(.bouncy(duration: 0.35)) {
            addedTemplateIDs.insert(template.id)
        }
    }

    private func finish() {
        hasSeen = true
        dismiss()
    }
}
