import SwiftUI

enum AppTab: Hashable {
    case today, week, lists, you
}

/// Custom bottom navigation bar with five slots and a raised center "+" button.
struct BottomTabBar: View {
    @Binding var selected: AppTab
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.today, system: "sun.max.fill", label: "Today")
            tabButton(.week, system: "calendar", label: "Calendar")
            addButton
            tabButton(.lists, system: "list.bullet", label: "Lists")
            tabButton(.you, system: "person.fill", label: "You")
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.top, Tokens.Space.sm)
        .padding(.bottom, Tokens.Space.sm + 2)
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                // Frosted-glass surface that runs all the way to the bottom of
                // the screen, including the home-indicator strip below the
                // safe area inset. Without `.ignoresSafeArea(edges: .bottom)`,
                // the background would stop where the icons stop and the dark
                // app bg shows through underneath — that was the "tab bar
                // floating above the bottom edge" bug Tripp reported.
                Rectangle().fill(.ultraThinMaterial)
                Tokens.Color.bg.opacity(0.55)
            }
            .overlay(alignment: .top) {
                Rectangle().fill(Tokens.Color.border).frame(height: 0.5)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(_ tab: AppTab, system: String, label: String) -> some View {
        Button {
            Haptics.tap()
            selected = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: system)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.2)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(selected == tab ? Tokens.Color.accent2 : Tokens.Color.text3)
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button(action: {
            Haptics.tap()
            onAdd()
        }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Tokens.Color.accent, Tokens.Color.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: Tokens.Color.accentGlow, radius: 12, x: 0, y: 4)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .offset(y: -10)
        .accessibilityLabel("Add task")
    }
}
