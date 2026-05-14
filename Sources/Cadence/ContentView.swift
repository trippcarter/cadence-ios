import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Tokens.Color.bg.ignoresSafeArea()

            VStack(spacing: Tokens.Space.lg) {
                Text("Cadence")
                    .font(Tokens.Font.displayLarge)
                    .foregroundStyle(Tokens.Color.text)

                Text("Daily tasks. Real life. One calm surface.")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text2)
                    .multilineTextAlignment(.center)

                Text("Phase 0 scaffolding")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
                    .padding(.top, Tokens.Space.md)
            }
            .padding(Tokens.Space.xl)
        }
    }
}

#Preview {
    ContentView()
}
