import SwiftUI

/// Build 28: replaces the old DisplayNameEditSheet's edit mode. Shows
/// the user's avatar (driven by the picked gradient), an editable
/// display name, an 8-color gradient picker, and a read-only email
/// row. Tap "Save" to commit display name + avatar color to
/// UserScopedPrefs (per Apple identifier).
///
/// First-run mode of the previous sheet still uses DisplayNameEditSheet.
struct EditProfileSheet: View {
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var gradient: AvatarGradient = .violet
    @FocusState private var nameFieldFocused: Bool

    private var user: AuthenticatedUser? { authSession.state.user }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.xl) {
                        avatarPreview
                            .padding(.top, Tokens.Space.xl)
                        nameField
                        gradientPicker
                        emailRow
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Tokens.Color.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Tokens.Color.text2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(canSave ? Tokens.Color.accent2 : Tokens.Color.text3)
                        .disabled(!canSave)
                }
            }
            .onAppear { hydrate() }
        }
    }

    private var avatarPreview: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradient.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)
                .shadow(color: gradient.colors.first!.opacity(0.45), radius: 14, x: 0, y: 6)
            Text(initials)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("DISPLAY NAME")
                .font(Tokens.Font.label)
                .kerning(0.8)
                .foregroundStyle(Tokens.Color.text3)
            TextField("Your name", text: $name)
                .focused($nameFieldFocused)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit { if canSave { save() } }
                .padding(.horizontal, Tokens.Space.md)
                .padding(.vertical, Tokens.Space.md)
                .background(Tokens.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                        .stroke(nameFieldFocused ? Tokens.Color.accent : Tokens.Color.borderSoft, lineWidth: nameFieldFocused ? 1 : 0.5)
                )
        }
    }

    private var gradientPicker: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("AVATAR COLOR")
                .font(Tokens.Font.label)
                .kerning(0.8)
                .foregroundStyle(Tokens.Color.text3)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: Tokens.Space.sm),
                GridItem(.flexible(), spacing: Tokens.Space.sm),
                GridItem(.flexible(), spacing: Tokens.Space.sm),
                GridItem(.flexible(), spacing: Tokens.Space.sm)
            ], spacing: Tokens.Space.sm) {
                ForEach(AvatarGradient.allCases) { option in
                    gradientSwatch(option)
                }
            }
        }
    }

    private func gradientSwatch(_ option: AvatarGradient) -> some View {
        let isSelected = gradient == option
        return Button {
            Haptics.tap()
            withAnimation(.bouncy(duration: 0.32)) {
                gradient = option
            }
        } label: {
            Circle()
                .fill(
                    LinearGradient(
                        colors: option.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)
                .overlay(
                    Circle()
                        .stroke(isSelected ? .white : Color.clear, lineWidth: 3)
                )
                .overlay(
                    Circle()
                        .stroke(isSelected ? Tokens.Color.accent : Color.clear, lineWidth: 1)
                        .padding(-3)
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .accessibilityLabel(option.displayName)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
        .buttonStyle(.plain)
    }

    private var emailRow: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("EMAIL")
                .font(Tokens.Font.label)
                .kerning(0.8)
                .foregroundStyle(Tokens.Color.text3)
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
                    .frame(width: 18)
                Text(emailLine)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text2)
                Spacer()
                Text("From Apple ID")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            .padding(.horizontal, Tokens.Space.md)
            .padding(.vertical, Tokens.Space.md)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
        }
    }

    private var emailLine: String {
        guard let user else { return "Not signed in" }
        if user.isUsingHiddenEmail { return "Private email" }
        if let email = user.email, !email.isEmpty { return email }
        return "Signed in with Apple ID"
    }

    private var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return user?.avatarInitials ?? "C"
        }
        let parts = trimmed.split(separator: " ", maxSplits: 1)
        let first = parts.first.flatMap { $0.first }.map(String.init)?.uppercased() ?? ""
        let last  = parts.dropFirst().first.flatMap { $0.first }.map(String.init)?.uppercased() ?? ""
        let pair = (first + last)
        return pair.isEmpty ? "C" : pair
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func hydrate() {
        name = user?.displayName ?? ""
        if let id = user?.appleUserIdentifier {
            gradient = AvatarGradient.resolve(UserScopedPrefs.avatarColorKey(for: id))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            nameFieldFocused = true
        }
    }

    private func save() {
        guard canSave, let id = user?.appleUserIdentifier else { return }
        Haptics.success()
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        UserScopedPrefs.setAvatarColorKey(gradient.rawValue, for: id)
        // setDisplayName persists to UserDefaults and reflects in state.
        authSession.setDisplayName(trimmed)
        dismiss()
    }
}
