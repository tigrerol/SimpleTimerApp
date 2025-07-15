import SwiftUI
import SwiftData

public struct ContentView: View {
    @State private var timerEngine = TimerEngine()
    @State private var workoutConfig = WorkoutConfig()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            switch timerEngine.timerState.phase {
            case .configuring:
                WorkoutConfigurationView(
                    config: workoutConfig,
                    onStartWorkout: {
                        timerEngine.configureWorkout(workoutConfig)
                    }
                )
                
            case .ready, .working, .resting, .paused, .completed:
                WorkoutTimerView(timerEngine: timerEngine)
            }
        }
        .navigationTitle("Simple Timer")
    }
}

// MARK: - Workout Configuration View

struct WorkoutConfigurationView: View {
    @Bindable var config: WorkoutConfig
    let onStartWorkout: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Configure Workout")
                .font(.largeTitle)
                .fontWeight(.thin)
                .foregroundStyle(.primary)
            
            VStack(spacing: 20) {
                // Exercise Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exercise")
                        .font(.headline)
                    
                    TextField("Enter exercise name", text: $config.exerciseName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                }
                
                // Number of Sets
                VStack(alignment: .leading, spacing: 8) {
                    Text("Number of Sets")
                        .font(.headline)
                    
                    HStack {
                        Button("-") {
                            if config.totalSets > 1 {
                                config.totalSets -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(config.totalSets <= 1)
                        
                        Text("\(config.totalSets)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .frame(minWidth: 50)
                        
                        Button("+") {
                            if config.totalSets < 20 {
                                config.totalSets += 1
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(config.totalSets >= 20)
                    }
                }
                
                // Rest Time
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rest Time: \(formatDuration(config.restDuration))")
                        .font(.headline)
                    
                    Slider(value: $config.restDuration, in: 15...300, step: 15)
                        .accentColor(.blue)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Start Workout Button
            Button("Start Workout") {
                onStartWorkout()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.title2)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .disabled(!config.isValid)
        }
        .padding()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Workout Timer View

struct WorkoutTimerView: View {
    let timerEngine: TimerEngine
    
    var body: some View {
        VStack(spacing: 40) {
            // Exercise Name and Set Progress
            VStack(spacing: 10) {
                if let config = timerEngine.timerState.currentConfig {
                    Text(config.exerciseName)
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                }
                
                // Set Progress
                SetProgressView(phase: timerEngine.timerState.phase)
            }
            
            // Timer Display
            TimerDisplayView(phase: timerEngine.timerState.phase)
            
            // Main Action Button
            MainActionButton(
                phase: timerEngine.timerState.phase,
                onAction: {
                    switch timerEngine.timerState.phase {
                    case .ready:
                        timerEngine.startCurrentSet()
                    case .working:
                        timerEngine.endCurrentSet()
                    case .resting(let timeRemaining, _, _):
                        if timeRemaining <= 0 {
                            timerEngine.startCurrentSet()
                        }
                    default:
                        break
                    }
                }
            )
            
            // Control Buttons
            ControlButtonsView(
                phase: timerEngine.timerState.phase,
                onPause: { timerEngine.pauseTimer() },
                onResume: { timerEngine.resumeTimer() },
                onSkip: { timerEngine.startCurrentSet() },
                onReset: { timerEngine.resetTimer() }
            )
            
            Spacer()
        }
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            UIApplication.shared.isIdleTimerDisabled = timerEngine.timerState.isScreenLocked
        }
    }
}

// MARK: - Set Progress View

struct SetProgressView: View {
    let phase: TimerState.Phase
    
    var body: some View {
        switch phase {
        case .ready(let config):
            Text("Ready • \(config.totalSets) sets")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
        case .working(let currentSet, let totalSets):
            Text("Set \(currentSet) of \(totalSets)")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.green)
            
        case .resting(_, let nextSet, let totalSets):
            Text("Set \(nextSet) of \(totalSets)")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
            
        case .paused(let nextSet, let totalSets):
            Text("Set \(nextSet) of \(totalSets)")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.yellow)
            
        case .completed:
            Text("Workout Complete!")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
            
        default:
            EmptyView()
        }
    }
}

// MARK: - Timer Display View

struct TimerDisplayView: View {
    let phase: TimerState.Phase
    
    var body: some View {
        Group {
            switch phase {
            case .ready:
                Text("Ready to Start")
                    .font(.largeTitle)
                    .fontWeight(.thin)
                    .foregroundStyle(.secondary)
                
            case .working:
                VStack {
                    Text("Working")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                    
                    Text("Tap when done")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
            case .resting(let timeRemaining, _, _):
                VStack {
                    if timeRemaining > 0 {
                        Text("Rest")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                        
                        Text(formatTime(timeRemaining))
                            .font(.system(size: 60, weight: .thin, design: .monospaced))
                            .foregroundStyle(.primary)
                    } else {
                        Text("Rest Complete")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                        
                        Text("Ready for next set")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
            case .paused:
                Text("Paused")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.yellow)
                
            case .completed:
                VStack {
                    Text("🎉")
                        .font(.system(size: 60))
                    
                    Text("Workout Complete!")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
                
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut, value: phase)
        .frame(maxHeight: 200)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Main Action Button

struct MainActionButton: View {
    let phase: TimerState.Phase
    let onAction: () -> Void
    
    var body: some View {
        Button(action: onAction) {
            Text(buttonTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: 80)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(buttonDisabled)
    }
    
    private var buttonTitle: String {
        switch phase {
        case .ready:
            return "Start First Set"
        case .working:
            return "Done with Set"
        case .resting(let timeRemaining, _, _):
            return timeRemaining > 0 ? "Resting..." : "Start Next Set"
        case .paused:
            return "Paused"
        case .completed:
            return "Workout Complete"
        default:
            return "Start"
        }
    }
    
    private var buttonDisabled: Bool {
        switch phase {
        case .resting(let timeRemaining, _, _):
            return timeRemaining > 0
        case .paused, .completed:
            return true
        default:
            return false
        }
    }
}

// MARK: - Control Buttons

struct ControlButtonsView: View {
    let phase: TimerState.Phase
    let onPause: () -> Void
    let onResume: () -> Void
    let onSkip: () -> Void
    let onReset: () -> Void
    
    var body: some View {
        switch phase {
        case .resting(let timeRemaining, _, _):
            if timeRemaining > 0 {
                HStack(spacing: 15) {
                    Button("Pause") {
                        onPause()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Skip") {
                        onSkip()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Reset") {
                        onReset()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
        case .paused:
            HStack(spacing: 15) {
                Button("Resume") {
                    onResume()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Skip") {
                    onSkip()
                }
                .buttonStyle(.bordered)
                
                Button("Reset") {
                    onReset()
                }
                .buttonStyle(.bordered)
            }
            
        case .working, .completed:
            Button("Reset") {
                onReset()
            }
            .buttonStyle(.bordered)
            
        default:
            EmptyView()
        }
    }
}
