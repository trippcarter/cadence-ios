import SwiftUI
import SwiftData

/// "Create household" form. Captures name + color + icon, then on save
/// inserts a Household, a creator-as-owner HouseholdMembership using the
/// current AuthSession user, AND a default starter list inside the
/// household so the user has somewhere to add their first task.
///
/// Build 15: the household is local-only initially (no CKShare yet). Cross-
/// device sharing happens per-list via the existing Phase 4 share flow.
/// A future build will collapse those into a single household-level CKShare.
struct CreateHouseholdSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authSession: AuthSession

    @State private var name: String = ""
    @State private var colorKey: String = "violet"
    @State private var iconKey: String = "house.fill"

    private static let iconChoices: [String] = [
        "house.fill",
        "person.2.fill",
        "person.3.fill",
        "figure.2.and.child.holdinghands",
        "briefcase.fill",
        "building.2.fill",
        "sailboat.fill",
        "tent.fill",
        "leaf.fill",
        "sparkles",
        "heart.fill",
        "graduationcap.fill",
        "hammer.fill",
        "fork.knife",
        "airplane",
        "lightbulb.fill",
        "soccerball",
        "guitars.fill",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                        previewCard
                        section(title: "Name") { nameField }
                        section(title: "Color") { colorPicker }
                        section(title: "Icon") { iconPicker }
                        Color.clear.frame(height: 60)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.top, Tokens.Space.lg)
                }
            }
            .navigationTitle("New household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Tokens.Color.text2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") { commit() }
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(canCommit ? Tokens.Color.accent2 : Tokens.Color.text3)
                        .disabled(!canCommit)
                }
            }
        }
    }

    // MARK: Subviews

    private var previewCard: some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ListPalette.color(for: colorKey), ListPalette.color(for: colorKey).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: iconKey)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Your new household" : name)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Color.text)
                Text("Shared with members you invite.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
        }
        .padding(Tokens.Space.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(title.uppercased())
                .font(Tokens.Font.label)
                .kerning(1.2)
                .foregroundStyle(Tokens.Color.text3)
            content()
        }
    }

    private var nameField: some View {
        TextField("e.g. Carter Family, Honey Brake Team", text: $name)
            .font(Tokens.Font.body)
            .foregroundStyle(Tokens.Color.text)
            .padding(.horizontal, Tokens.Space.md)
            .padding(.vertical, Tokens.Space.md)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
            .submitLabel(.done)
            .onSubmit { if canCommit { commit() } }
    }

    private var colorPicker: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.sm), count: 5)
        return LazyVGrid(columns: columns, spacing: Tokens.Space.sm) {
            ForEach(ListPalette.allKeys, id: \.self) { key in
                Button {
                    Haptics.tap()
                    colorKey = key
                } label: {
                    ZStack {
                        Circle()
                            .fill(ListPalette.color(for: key))
                            .frame(width: 38, height: 38)
                        if colorKey == key {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var iconPicker: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.sm), count: 6)
        return LazyVGrid(columns: columns, spacing: Tokens.Space.sm) {
            ForEach(Self.iconChoices, id: \.self) { symbol in
                Button {
                    Haptics.tap()
                    iconKey = symbol
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                            .fill(iconKey == symbol
                                  ? ListPalette.color(for: colorKey).opacity(0.25)
                                  : Tokens.Color.surface2)
                            .frame(height: 44)
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(iconKey == symbol
                                             ? ListPalette.color(for: colorKey)
                                             : Tokens.Color.text2)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                            .stroke(iconKey == symbol
                                    ? ListPalette.color(for: colorKey)
                                    : Tokens.Color.borderSoft,
                                    lineWidth: iconKey == symbol ? 1.4 : 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Commit

    private var canCommit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Haptics.success()

        let creatorIdentifier = authSession.state.user?.appleUserIdentifier ?? ""
        let creatorName = authSession.state.user?.displayName ?? "You"
        let creatorEmail = authSession.state.user?.email

        let household = Household(
            name: trimmed,
            iconKey: iconKey,
            colorKey: colorKey,
            createdBy: creatorIdentifier
        )
        modelContext.insert(household)

        // The creator becomes the founding owner. Membership is local — a
        // future build will sync members via household-level CKShare.
        let ownerMembership = HouseholdMembership(
            household: household,
            userIdentifier: creatorIdentifier,
            displayName: creatorName,
            email: creatorEmail,
            avatarColorKey: colorKey,
            role: .owner
        )
        modelContext.insert(ownerMembership)

        // Auto-seed a starter list so the household isn't empty.
        let descriptor = FetchDescriptor<TaskList>(
            sortBy: [SortDescriptor(\TaskList.sortOrder, order: .reverse)]
        )
        let highestSort = (try? modelContext.fetch(descriptor).first?.sortOrder) ?? 0
        let starter = TaskList(
            name: trimmed.lowercased().contains("team") ? "Team Tasks" : "Shared Tasks",
            colorKey: colorKey,
            iconKey: "checklist",
            sortOrder: highestSort + 1,
            isSeeded: false
        )
        starter.household = household
        modelContext.insert(starter)

        try? modelContext.save()
        WidgetReloader.reload()
        dismiss()
    }
}
