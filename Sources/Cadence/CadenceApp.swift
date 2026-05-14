import SwiftUI
import SwiftData

@main
struct CadenceApp: App {

    let container: ModelContainer
    @AppStorage(PrefsKey.themeChoice) private var themeRaw: String = ThemeChoice.dark.rawValue

    init() {
        do {
            let schema = Schema([TaskItem.self, TaskList.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        SeedData.bootstrapIfNeeded(container.mainContext)

        if AppLaunchArgs.skipOnboarding {
            UserDefaults.standard.set(true, forKey: PrefsKey.hasOnboarded)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(ThemeChoice(rawValue: themeRaw)?.colorScheme ?? .dark)
        }
        .modelContainer(container)
    }
}
