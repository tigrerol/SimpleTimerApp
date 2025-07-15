import SwiftUI
import SwiftData
import SimpleTimerAppFeature

@main
struct SimpleTimerAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [WorkoutSession.self, ExerciseLog.self, SetLog.self])
    }
}
