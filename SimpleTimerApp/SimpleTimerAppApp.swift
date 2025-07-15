import SwiftUI
import SwiftData
import SimpleTimerAppFeature

@main
struct SimpleTimerAppApp: App {
    @State private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .preferredColorScheme(themeManager.selectedScheme.colorScheme)
        }
        .modelContainer(for: [WorkoutSession.self, ExerciseLog.self, SetLog.self])
    }
}
