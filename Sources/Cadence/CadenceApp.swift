import SwiftUI
import SwiftData

@main
struct CadenceApp: App {

    let container: ModelContainer

    init() {
        do {
            let schema = Schema([TaskItem.self, TaskList.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        SeedData.bootstrapIfNeeded(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
