import SwiftUI
import SwiftData

public struct ContentView: View {
    @State private var timerEngine = TimerEngine()
    @State private var workoutConfig = WorkoutConfig()
    @State private var exerciseDefaults = ExerciseDefaults()
    @State private var selectedTab = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            // Timer Tab
            NavigationStack {
                switch timerEngine.timerState.phase {
                case .configuring:
                    WorkoutConfigurationView(
                        config: workoutConfig,
                        onStartWorkout: {
                            timerEngine.configureWorkout(workoutConfig)
                        }
                    )
                    .environment(exerciseDefaults)
                    
                case .ready, .working, .resting, .paused, .completed:
                    WorkoutTimerView(
                        timerEngine: timerEngine,
                        exerciseDefaults: exerciseDefaults
                    )
                }
            }
            .navigationTitle("Timer")
            .tabItem {
                Image(systemName: "timer")
                    .foregroundStyle(selectedTab == 0 ? Color("TimerCyan") : .secondary)
                Text("Timer")
                    .font(.system(.caption, design: .rounded, weight: .medium))
            }
            .tag(0)
            
            // History Tab
            NavigationStack {
                WorkoutHistoryView()
            }
            .navigationTitle("History")
            .tabItem {
                Image(systemName: "list.bullet")
                    .foregroundStyle(selectedTab == 1 ? Color("TimerCyan") : .secondary)
                Text("History")
                    .font(.system(.caption, design: .rounded, weight: .medium))
            }
            .tag(1)
        }
        .tint(Color("TimerCyan"))
    }
}

// MARK: - Workout Configuration View

struct WorkoutConfigurationView: View {
    @Bindable var config: WorkoutConfig
    let onStartWorkout: () -> Void
    @Environment(ExerciseDefaults.self) private var exerciseDefaults
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    
    private var recentExerciseNames: [String] {
        var uniqueExercises: [String] = []
        
        for session in workoutSessions {
            for exercise in session.exercises {
                if !uniqueExercises.contains(exercise.name) {
                    uniqueExercises.append(exercise.name)
                    if uniqueExercises.count >= 5 {
                        break
                    }
                }
            }
            if uniqueExercises.count >= 5 {
                break
            }
        }
        
        return uniqueExercises
    }
    
    var body: some View {
        VStack(spacing: 30) {
            HStack {
                Text("Configure Workout")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.linearGradient(
                        colors: [Color("TimerCyan"), Color("TimerPurple")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                
                Spacer()
                
                // Theme toggle
                Menu {
                    ForEach(ThemeManager.ColorScheme.allCases, id: \.self) { scheme in
                        Button {
                            themeManager.selectedScheme = scheme
                        } label: {
                            HStack {
                                Text(scheme.rawValue)
                                if themeManager.selectedScheme == scheme {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: themeIcon)
                        .font(.title2)
                        .foregroundStyle(Color("TimerPurple"))
                }
            }
            
            VStack(spacing: 20) {
                // Exercise Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exercise")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color("TimerPurple"))
                    
                    HStack {
                        TextField("Enter exercise name", text: $config.exerciseName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                        
                        if !recentExerciseNames.isEmpty {
                            Menu {
                                ForEach(recentExerciseNames, id: \.self) { exercise in
                                    Button(exercise) {
                                        config.exerciseName = exercise
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.down.circle")
                                    .font(.title2)
                                    .foregroundStyle(Color("TimerCyan"))
                            }
                        }
                    }
                }
                
                // Number of Sets
                VStack(alignment: .leading, spacing: 8) {
                    Text("Number of Sets")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color("TimerPurple"))
                    
                    HStack {
                        Button("-") {
                            if config.totalSets > 1 {
                                config.totalSets -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(Color("TimerPurple"))
                        .disabled(config.totalSets <= 1)
                        
                        Text("\(config.totalSets)")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(.linearGradient(
                                colors: [Color("TimerCyan"), Color("TimerPurple")],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(minWidth: 50)
                        
                        Button("+") {
                            if config.totalSets < 20 {
                                config.totalSets += 1
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(Color("TimerPurple"))
                        .disabled(config.totalSets >= 20)
                    }
                }
                
                // Rest Time
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rest Time")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color("TimerPurple"))
                    
                    Text(formatDuration(config.restDuration))
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.linearGradient(
                            colors: [Color("TimerOrange"), Color("TimerPink")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                    
                    Slider(value: Binding(
                        get: { 
                            // Ensure rest duration is always valid
                            guard config.restDuration.isFinite && config.restDuration >= 15 else {
                                return 60 // Default to 60 seconds
                            }
                            return config.restDuration
                        },
                        set: { newValue in
                            // Validate new value before setting
                            if newValue.isFinite && newValue >= 15 && newValue <= 300 {
                                config.restDuration = newValue
                            }
                        }
                    ), in: 15...300, step: 15)
                        .tint(Color("TimerCyan"))
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
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .tint(Color("TimerCyan"))
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .disabled(!config.isValid)
        }
        .padding()
    }
    
    private var themeIcon: String {
        switch themeManager.selectedScheme {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        // Validate input to prevent NaN or invalid values
        guard duration.isFinite && duration >= 0 else {
            return "0s"
        }
        
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
    let exerciseDefaults: ExerciseDefaults
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(spacing: 40) {
            // Exercise Name and Set Progress
            VStack(spacing: 10) {
                if let config = timerEngine.timerState.currentConfig {
                    Text(config.exerciseName)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(.linearGradient(
                            colors: [Color("TimerCyan"), Color("TimerPurple")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
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
            
            // Control Buttons or Set Logging
            switch timerEngine.timerState.phase {
            case .resting(_, let nextSet, _):
                // Show set logging directly during rest
                SetLoggingCard(
                    setNumber: nextSet - 1,
                    exerciseName: timerEngine.timerState.currentConfig?.exerciseName ?? "",
                    exerciseDefaults: exerciseDefaults,
                    onSave: { setLog in
                        timerEngine.timerState.addSetLog(setLog)
                        exerciseDefaults.updateLastValues(
                            for: timerEngine.timerState.currentConfig?.exerciseName ?? "",
                            reps: setLog.reps,
                            weightResistance: setLog.weightResistance
                        )
                    },
                    onPause: { timerEngine.pauseTimer() },
                    onSkip: { timerEngine.startCurrentSet() },
                    onReset: { timerEngine.resetTimer() }
                )
                
            case .paused(let nextSet, _):
                VStack(spacing: 15) {
                    // Set logging available when paused too
                    SetLoggingCard(
                        setNumber: nextSet - 1,
                        exerciseName: timerEngine.timerState.currentConfig?.exerciseName ?? "",
                        exerciseDefaults: exerciseDefaults,
                        onSave: { setLog in
                            timerEngine.timerState.addSetLog(setLog)
                            exerciseDefaults.updateLastValues(
                                for: timerEngine.timerState.currentConfig?.exerciseName ?? "",
                                reps: setLog.reps,
                                weightResistance: setLog.weightResistance
                            )
                        }
                    )
                    
                    HStack(spacing: 15) {
                        Button("Resume") {
                            timerEngine.resumeTimer()
                        }
                        .buttonStyle(.bordered)
                        .tint(Color("TimerCyan"))
                        
                        Button("Skip") {
                            timerEngine.startCurrentSet()
                        }
                        .buttonStyle(.bordered)
                        .tint(Color("TimerOrange"))
                        
                        Button("Reset") {
                            timerEngine.resetTimer()
                        }
                        .buttonStyle(.bordered)
                        .tint(Color("TimerPurple"))
                    }
                }
                
            default:
                ControlButtonsView(
                    phase: timerEngine.timerState.phase,
                    onPause: { timerEngine.pauseTimer() },
                    onResume: { timerEngine.resumeTimer() },
                    onSkip: { timerEngine.startCurrentSet() },
                    onReset: { 
                        if case .completed = timerEngine.timerState.phase {
                            // Save completed workout
                            if let session = timerEngine.timerState.completeWorkout() {
                                modelContext.insert(session)
                            }
                        }
                        timerEngine.resetTimer() 
                    }
                )
            }
            
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
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color("TimerPurple"))
            
        case .working(let currentSet, let totalSets):
            Text("Set \(currentSet) of \(totalSets)")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.linearGradient(
                    colors: [Color("TimerOrange"), Color("TimerPink")],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
            
        case .resting(_, let nextSet, let totalSets):
            Text("Set \(nextSet) of \(totalSets)")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color("TimerOrange"))
            
        case .paused(let nextSet, let totalSets):
            Text("Set \(nextSet) of \(totalSets)")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color("TimerPink"))
            
        case .completed:
            Text("Workout Complete!")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.linearGradient(
                    colors: [Color("TimerCyan"), Color("TimerPurple")],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
            
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
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .foregroundStyle(.linearGradient(
                        colors: [Color("TimerCyan"), Color("TimerPurple")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
            case .working:
                VStack {
                    Text("Working")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(.linearGradient(
                            colors: [Color("TimerOrange"), Color("TimerPink")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                    
                    Text("Tap when done")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color("TimerPurple"))
                }
                
            case .resting(let timeRemaining, _, _):
                VStack {
                    if timeRemaining > 0 {
                        Text("Rest")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color("TimerOrange"))
                        
                        Text(formatTime(timeRemaining))
                            .font(.system(size: 60, weight: .thin, design: .rounded))
                            .foregroundStyle(.linearGradient(
                                colors: [Color("TimerCyan"), Color("TimerPurple")],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    } else {
                        Text("Rest Complete")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color("TimerCyan"))
                        
                        Text("Ready for next set")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(Color("TimerPurple"))
                    }
                }
                
            case .paused:
                Text("Paused")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color("TimerPink"))
                
            case .completed:
                VStack {
                    Text("🎉")
                        .font(.system(size: 60))
                    
                    Text("Workout Complete!")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(.linearGradient(
                            colors: [Color("TimerCyan"), Color("TimerPurple"), Color("TimerOrange"), Color("TimerPink")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
                
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut, value: phase)
        .frame(maxHeight: 200)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        // Validate input to prevent NaN or invalid values
        guard timeInterval.isFinite && timeInterval >= 0 else {
            return "0:00"
        }
        
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
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 80)
        }
        .buttonStyle(.borderedProminent)
        .tint(buttonColor)
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
    
    private var buttonColor: Color {
        switch phase {
        case .ready:
            return Color("TimerCyan")
        case .working:
            return Color("TimerOrange")
        case .resting(let timeRemaining, _, _):
            return timeRemaining > 0 ? Color("TimerPurple") : Color("TimerCyan")
        case .paused:
            return Color("TimerPink")
        case .completed:
            return Color("TimerCyan")
        default:
            return Color("TimerCyan")
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
        case .working:
            Button("Reset") {
                onReset()
            }
            .buttonStyle(.bordered)
            .tint(Color("TimerPink"))
            .font(.system(size: 16, weight: .medium, design: .rounded))
            
        case .completed:
            Button("Finish") {
                onReset()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("TimerCyan"))
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            
        default:
            EmptyView()
        }
    }
}

// MARK: - Set Logging Card

struct SetLoggingCard: View {
    let setNumber: Int
    let exerciseName: String
    let exerciseDefaults: ExerciseDefaults
    let onSave: (SetLog) -> Void
    let onPause: (() -> Void)?
    let onSkip: (() -> Void)?
    let onReset: (() -> Void)?
    
    @State private var reps: String = ""
    @State private var weightResistance: String = ""
    @State private var notes: String = ""
    @State private var showingQuickReps = false
    @State private var showingQuickWeights = false
    @State private var hasAutoSaved = false
    
    private let quickRepOptions = [5, 8, 10, 12, 15, 20]
    private let quickWeightOptions = ["10kg", "15kg", "20kg", "25kg", "Level 1", "Level 2", "Level 3", "Level 4", "Level 5"]
    
    init(setNumber: Int, exerciseName: String, exerciseDefaults: ExerciseDefaults, onSave: @escaping (SetLog) -> Void, onPause: (() -> Void)? = nil, onSkip: (() -> Void)? = nil, onReset: (() -> Void)? = nil) {
        self.setNumber = setNumber
        self.exerciseName = exerciseName
        self.exerciseDefaults = exerciseDefaults
        self.onSave = onSave
        self.onPause = onPause
        self.onSkip = onSkip
        self.onReset = onReset
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Set logging card
            VStack(spacing: 15) {
                Text("Log Set \(setNumber)")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.linearGradient(
                        colors: [Color("TimerCyan"), Color("TimerPurple")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                
                VStack(spacing: 12) {
                    // Reps
                    HStack {
                        Text("Reps")
                            .frame(width: 60, alignment: .leading)
                        
                        TextField("Optional", text: $reps)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                        
                        Button("Quick") {
                            showingQuickReps = true
                        }
                        .buttonStyle(.bordered)
                        .tint(Color("TimerOrange"))
                        .controlSize(.small)
                        .frame(width: 60)
                    }
                    
                    // Weight/Resistance
                    HStack {
                        Text("Weight")
                            .frame(width: 60, alignment: .leading)
                        
                        TextField("Optional", text: $weightResistance)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                        
                        Button("Quick") {
                            showingQuickWeights = true
                        }
                        .buttonStyle(.bordered)
                        .tint(Color("TimerOrange"))
                        .controlSize(.small)
                        .frame(width: 60)
                    }
                    
                    // Notes
                    HStack {
                        Text("Notes")
                            .frame(width: 60, alignment: .leading)
                        
                        TextField("Optional notes...", text: $notes)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                            .frame(width: 60)
                    }
                }
                
                // Save button
                Button("Save Set") {
                    saveSet()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("TimerCyan"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .controlSize(.large)
                .disabled(hasAutoSaved)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Control buttons
            HStack(spacing: 15) {
                if let onPause = onPause {
                    Button("Pause") {
                        saveSetIfNeeded()
                        onPause()
                    }
                    .buttonStyle(.bordered)
                    .tint(Color("TimerPink"))
                }
                
                if let onSkip = onSkip {
                    Button("Skip") {
                        saveSetIfNeeded()
                        onSkip()
                    }
                    .buttonStyle(.bordered)
                    .tint(Color("TimerOrange"))
                }
                
                if let onReset = onReset {
                    Button("Reset") {
                        saveSetIfNeeded()
                        onReset()
                    }
                    .buttonStyle(.bordered)
                    .tint(Color("TimerPurple"))
                }
            }
        }
        .confirmationDialog("Quick Reps", isPresented: $showingQuickReps) {
            ForEach(quickRepOptions, id: \.self) { rep in
                Button("\(rep) reps") {
                    reps = "\(rep)"
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Quick Weight", isPresented: $showingQuickWeights) {
            ForEach(quickWeightOptions, id: \.self) { weight in
                Button(weight) {
                    weightResistance = weight
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            // Pre-fill with last used values
            let lastValues = exerciseDefaults.getLastValues(for: exerciseName)
            if let lastReps = lastValues.reps {
                reps = "\(lastReps)"
            }
            weightResistance = lastValues.weightResistance
            hasAutoSaved = false
        }
    }
    
    private func saveSet() {
        let setLog = SetLog(
            setNumber: setNumber,
            reps: Int(reps.trimmingCharacters(in: .whitespacesAndNewlines)),
            weightResistance: weightResistance.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        onSave(setLog)
        hasAutoSaved = true
    }
    
    private func saveSetIfNeeded() {
        // Auto-save when transitioning if there's any data and hasn't been saved yet
        if !hasAutoSaved && (!reps.isEmpty || !weightResistance.isEmpty || !notes.isEmpty) {
            saveSet()
        }
    }
}

// MARK: - Set Logging View

struct SetLoggingView: View {
    let setNumber: Int
    let exerciseName: String
    let exerciseDefaults: ExerciseDefaults
    let onSave: (SetLog) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var reps: String = ""
    @State private var weightResistance: String = ""
    @State private var notes: String = ""
    @State private var showingQuickReps = false
    @State private var showingQuickWeights = false
    
    private let quickRepOptions = [5, 8, 10, 12, 15, 20]
    private let quickWeightOptions = ["10kg", "15kg", "20kg", "25kg", "Level 1", "Level 2", "Level 3", "Level 4", "Level 5"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Set \(setNumber) - \(exerciseName)")) {
                    // Reps
                    HStack {
                        Text("Reps")
                        Spacer()
                        TextField("Optional", text: $reps)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        
                        Button("Quick") {
                            showingQuickReps = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    // Weight/Resistance
                    HStack {
                        Text("Weight/Resistance")
                        Spacer()
                        TextField("Optional", text: $weightResistance)
                            .multilineTextAlignment(.trailing)
                        
                        Button("Quick") {
                            showingQuickWeights = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    // Notes
                    VStack(alignment: .leading) {
                        Text("Notes")
                        TextField("Optional notes...", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
            }
            .navigationTitle("Log Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let setLog = SetLog(
                            setNumber: setNumber,
                            reps: Int(reps.trimmingCharacters(in: .whitespacesAndNewlines)),
                            weightResistance: weightResistance.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        onSave(setLog)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Quick Reps", isPresented: $showingQuickReps) {
                ForEach(quickRepOptions, id: \.self) { rep in
                    Button("\(rep) reps") {
                        reps = "\(rep)"
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .confirmationDialog("Quick Weight", isPresented: $showingQuickWeights) {
                ForEach(quickWeightOptions, id: \.self) { weight in
                    Button(weight) {
                        weightResistance = weight
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .onAppear {
                // Pre-fill with last used values
                let lastValues = exerciseDefaults.getLastValues(for: exerciseName)
                if let lastReps = lastValues.reps {
                    reps = "\(lastReps)"
                }
                weightResistance = lastValues.weightResistance
            }
        }
    }
}

// MARK: - Workout History View

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    @State private var selectedSession: WorkoutSession?
    @State private var showingDeleteConfirmation = false
    @State private var sessionToDelete: WorkoutSession?
    
    var body: some View {
        NavigationStack {
            Group {
                if workoutSessions.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "dumbbell",
                        description: Text("Your workout history will appear here after completing your first workout.")
                    )
                } else {
                    List {
                        ForEach(workoutSessions) { session in
                            WorkoutSessionRow(session: session)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedSession = session
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Delete", role: .destructive) {
                                        sessionToDelete = session
                                        showingDeleteConfirmation = true
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Workout History")
            .sheet(item: $selectedSession) { session in
                WorkoutDetailView(session: session)
            }
            .confirmationDialog("Delete Workout", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let session = sessionToDelete {
                        modelContext.delete(session)
                        sessionToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    sessionToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this workout? This action cannot be undone.")
            }
        }
    }
}

// MARK: - Workout Session Row

struct WorkoutSessionRow: View {
    let session: WorkoutSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatDate(session.date))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.linearGradient(
                        colors: [Color("TimerCyan"), Color("TimerPurple")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                Spacer()
                Text(formatDuration(session.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ForEach(session.exercises) { exercise in
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color("TimerPurple"))
                    
                    FlowLayout(spacing: 8) {
                        ForEach(exercise.sets) { set in
                            SetChip(set: set)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        guard duration.isFinite && duration >= 0 else {
            return "0m"
        }
        let minutes = Int(duration) / 60
        return "\(minutes)m"
    }
}

// MARK: - Set Chip

struct SetChip: View {
    let set: SetLog
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(set.setNumber):")
                .font(.caption2)
                .fontWeight(.semibold)
            
            if let reps = set.reps {
                Text("\(reps)")
                    .font(.caption2)
            }
            
            if !set.weightResistance.isEmpty {
                Text(set.weightResistance)
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary)
        .clipShape(Capsule())
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300 // Use a reasonable default instead of infinity
        var height: CGFloat = 0
        var rowHeight: CGFloat = 0
        var currentX: CGFloat = 0
        
        // Validate width is not NaN or invalid
        guard width.isFinite && width > 0 else {
            return CGSize(width: 300, height: 44) // Return safe default size
        }
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            // Validate subview size
            guard subviewSize.width.isFinite && subviewSize.height.isFinite &&
                  subviewSize.width >= 0 && subviewSize.height >= 0 else {
                continue // Skip invalid subviews
            }
            
            if currentX + subviewSize.width > width && currentX > 0 {
                height += rowHeight + spacing
                currentX = 0
                rowHeight = 0
            }
            
            currentX += subviewSize.width + spacing
            rowHeight = max(rowHeight, subviewSize.height)
        }
        
        height += rowHeight
        
        // Validate final size
        guard height.isFinite && height >= 0 else {
            return CGSize(width: width, height: 44) // Return safe default height
        }
        
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Validate bounds
        guard bounds.width.isFinite && bounds.height.isFinite &&
              bounds.minX.isFinite && bounds.minY.isFinite &&
              bounds.maxX.isFinite && bounds.maxY.isFinite else {
            return // Don't place subviews if bounds are invalid
        }
        
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            // Validate subview size
            guard subviewSize.width.isFinite && subviewSize.height.isFinite &&
                  subviewSize.width >= 0 && subviewSize.height >= 0 else {
                continue // Skip invalid subviews
            }
            
            if currentX + subviewSize.width > bounds.maxX && currentX > bounds.minX {
                currentY += rowHeight + spacing
                currentX = bounds.minX
                rowHeight = 0
            }
            
            let placement = CGPoint(x: currentX, y: currentY)
            
            // Validate placement point
            guard placement.x.isFinite && placement.y.isFinite else {
                continue // Skip if placement would be invalid
            }
            
            subview.place(at: placement, proposal: .unspecified)
            currentX += subviewSize.width + spacing
            rowHeight = max(rowHeight, subviewSize.height)
        }
    }
}

// MARK: - Workout Detail View

struct WorkoutDetailView: View {
    let session: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Workout Info")) {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(formatDate(session.date))
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formatDuration(session.duration))
                            .foregroundStyle(.secondary)
                    }
                }
                
                ForEach(session.exercises) { exercise in
                    Section(header: Text(exercise.name)) {
                        ForEach(exercise.sets) { set in
                            HStack {
                                Text("Set \(set.setNumber)")
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    if let reps = set.reps {
                                        Text("\(reps) reps")
                                            .font(.subheadline)
                                    }
                                    
                                    if !set.weightResistance.isEmpty {
                                        Text(set.weightResistance)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    if !set.notes.isEmpty {
                                        Text(set.notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        guard duration.isFinite && duration >= 0 else {
            return "0m"
        }
        
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
