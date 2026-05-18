import SwiftUI

/// Two-mode display name editor.
///
///   - `.edit` (Settings entry point): TextField pre-populated with the
///     current displayName. Save commits to UserDefaults via AuthSession.
///   - `.firstRun` (auto-presented on sign-in when no name resolves): same
///     UI but framed as a welcome "What should we call you?" with a single
///     Continue button (no cancel).
struct DisplayNameEditSheet: View {

    enum Mode {
        case edit
        case firstRun
    }

    let mode: Mode

    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                VStack(spacing: Tokens.Space.lg) {
                    headerBlock
                        .padding(.horizontal, Tokens.Space.lg)
                        .padding(.top, Tokens.Space.md)

                    nameField
                        .padding(.horizontal, Tokens.Space.lg)

                    Spacer()

                    actionButton
                        .padding(.horizontal, Tokens.Space.lg)
                        .padding(.bottom, Tokens.Space.lg)
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if mode == .edit {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(Tokens.Color.text2)
                    }
                }
            }
            .interactiveDismissDisabled(mode == .firstRun)
        }
        .onAppear {
            // Pre-fill with the currently-resolved displayName so the user
            // can edit it, not start from blank. For first-run with no
            // Apple name, this'll be the email-derived guess.
            if name.isEmpty, let user = authSession.state.user {
                let resolved = user.displayName
                name = (resolved == "Cadence User") ? "" : resolved
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                nameFieldFocused = true
            }
        }
    }

    // MARK: Sub-views

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            if mode == .firstRun {
                Text("What should we call you?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Tokens.Color.text)
                Text("This is the name we'll use everywhere — welcome screen, your profile card, the avatar in the top right of Today.")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text3)
            } else {
                Text("Display name")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Tokens.Color.text)
                Text("Used on your profile, the Today avatar, and the welcome splash. Change it any time.")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nameField: some View {
        TextField("Your name", text: $name)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Tokens.Color.text)
            .tint(Tokens.Color.accent)
            .focused($nameFieldFocused)
            .submitLabel(mode == .firstRun ? .continue : .done)
            .onSubmit { commit() }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.lg)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
    }

    private var actionButton: some View {
        let canCommit = !name.trimmingCharacters(in: .whitespaces).isEmpty
        return Button {
            commit()
        } label: {
            Text(actionLabel)
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.Space.md + 2)
                .background(
                    LinearGradient(
                        colors: canCommit
                            ? [Tokens.Color.accent, Tokens.Color.accentDeep]
                            : [Tokens.Color.text3.opacity(0.4), Tokens.Color.text3.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                .shadow(color: canCommit ? Tokens.Color.accentGlow : .clear, radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!canCommit)
    }

    // MARK: Strings

    private var navTitle: String {
        switch mode {
        case .edit: return "Edit name"
        case .firstRun: return ""
        }
    }

    private var actionLabel: String {
        switch mode {
        case .edit: return "Save"
        case .firstRun: return "Continue"
        }
    }

    // MARK: Commit

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Haptics.success()
        authSession.setDisplayName(trimmed)
        authSession.needsNamePrompt = false
        dismiss()
    }
}
