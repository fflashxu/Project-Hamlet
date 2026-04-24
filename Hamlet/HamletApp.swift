import SwiftUI
import SwiftData
import Combine

@main
struct HamletApp: App {
    @StateObject private var themeEngine = ThemeEngine.shared
    @StateObject private var aiManager = AIProviderManager.shared
    @StateObject private var languageManager = LanguageManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Entry.self, DimensionState.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeEngine)
                .environmentObject(aiManager)
                .environmentObject(languageManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
