import SwiftData
import SwiftUI

@main
struct AurelineApp: App {
    @State private var appEnvironment = AppEnvironment()
    private let modelContainer: ModelContainer

    init() {
        let usesInMemoryStore = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        modelContainer = ModelContainerProvider.makeDefaultContainer(inMemory: usesInMemoryStore)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appEnvironment)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
