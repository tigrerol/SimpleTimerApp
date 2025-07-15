import Foundation
import SwiftData

@Model
public final class WorkoutSession {
    public var date: Date
    public var duration: TimeInterval
    public var exercises: [ExerciseLog]
    
    public init(date: Date = Date()) {
        self.date = date
        self.duration = 0
        self.exercises = []
    }
    
    public func addExercise(_ exercise: ExerciseLog) {
        exercises.append(exercise)
    }
    
    public func endSession() {
        duration = Date().timeIntervalSince(date)
    }
}

@Model
public final class ExerciseLog {
    public var name: String
    public var sets: [SetLog]
    public var timestamp: Date
    
    public init(name: String) {
        self.name = name
        self.sets = []
        self.timestamp = Date()
    }
    
    public func addSet(_ set: SetLog) {
        sets.append(set)
    }
}

@Model
public final class SetLog {
    public var setNumber: Int
    public var reps: Int?
    public var weightResistance: String
    public var notes: String
    public var timestamp: Date
    
    public init(
        setNumber: Int,
        reps: Int? = nil,
        weightResistance: String = "",
        notes: String = ""
    ) {
        self.setNumber = setNumber
        self.reps = reps
        self.weightResistance = weightResistance
        self.notes = notes
        self.timestamp = Date()
    }
}

// Exercise defaults for quick entry
@Observable
public final class ExerciseDefaults {
    public var lastValues: [String: LastSetData] = [:]
    
    public init() {}
    
    public func getLastValues(for exercise: String) -> LastSetData {
        return lastValues[exercise] ?? LastSetData()
    }
    
    public func updateLastValues(for exercise: String, reps: Int?, weightResistance: String) {
        lastValues[exercise] = LastSetData(reps: reps, weightResistance: weightResistance)
    }
}

public struct LastSetData {
    public var reps: Int?
    public var weightResistance: String
    
    public init(reps: Int? = nil, weightResistance: String = "") {
        self.reps = reps
        self.weightResistance = weightResistance
    }
}

// Workout configuration
@Observable
public final class WorkoutConfig: Equatable {
    public var exerciseName: String = ""
    public var totalSets: Int = 3
    public var restDuration: TimeInterval = 60
    
    public init() {}
    
    public var isValid: Bool {
        !exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        totalSets > 0 && 
        restDuration > 0
    }
    
    public static func == (lhs: WorkoutConfig, rhs: WorkoutConfig) -> Bool {
        lhs.exerciseName == rhs.exerciseName &&
        lhs.totalSets == rhs.totalSets &&
        lhs.restDuration == rhs.restDuration
    }
}

// Timer state management
@Observable
public final class TimerState {
    public enum Phase: Equatable {
        case configuring
        case ready(config: WorkoutConfig)
        case working(currentSet: Int, totalSets: Int)
        case resting(timeRemaining: TimeInterval, nextSet: Int, totalSets: Int)
        case paused(nextSet: Int, totalSets: Int)
        case completed
    }
    
    public var phase: Phase = .configuring
    public var currentConfig: WorkoutConfig?
    public var currentWorkoutSession: WorkoutSession?
    public var currentExerciseLog: ExerciseLog?
    public var isScreenLocked: Bool = false
    
    public init() {}
    
    public func configureWorkout(_ config: WorkoutConfig) {
        currentConfig = config
        
        // Create workout session and exercise log immediately when configuring
        currentWorkoutSession = WorkoutSession()
        currentExerciseLog = ExerciseLog(name: config.exerciseName)
        
        phase = .ready(config: config)
    }
    
    public func startWorkout() {
        guard let config = currentConfig else { return }
        
        // Session and exercise log are already created in configureWorkout
        phase = .working(currentSet: 1, totalSets: config.totalSets)
    }
    
    public func startSet(_ setNumber: Int) {
        guard let config = currentConfig else { return }
        phase = .working(currentSet: setNumber, totalSets: config.totalSets)
    }
    
    public func endSet() {
        guard let config = currentConfig else { return }
        
        switch phase {
        case .working(let currentSet, let totalSets):
            if currentSet >= totalSets {
                phase = .completed
            } else {
                let nextSet = currentSet + 1
                phase = .resting(
                    timeRemaining: config.restDuration,
                    nextSet: nextSet,
                    totalSets: totalSets
                )
            }
        default:
            break
        }
    }
    
    public func startResting(nextSet: Int, totalSets: Int, duration: TimeInterval) {
        phase = .resting(timeRemaining: duration, nextSet: nextSet, totalSets: totalSets)
    }
    
    public func pause() {
        switch phase {
        case .resting(_, let nextSet, let totalSets):
            phase = .paused(nextSet: nextSet, totalSets: totalSets)
        default:
            break
        }
    }
    
    public func resume() {
        guard let config = currentConfig else { return }
        
        switch phase {
        case .paused(let nextSet, let totalSets):
            phase = .resting(
                timeRemaining: config.restDuration,
                nextSet: nextSet,
                totalSets: totalSets
            )
        default:
            break
        }
    }
    
    public func reset() {
        phase = .configuring
        currentConfig = nil
        currentWorkoutSession = nil
        currentExerciseLog = nil
    }
    
    public func completeWorkout() -> WorkoutSession? {
        guard let session = currentWorkoutSession,
              let exerciseLog = currentExerciseLog else { return nil }
        
        session.endSession()
        session.addExercise(exerciseLog)
        
        let completedSession = session
        reset()
        return completedSession
    }
    
    public func addSetLog(_ setLog: SetLog) {
        currentExerciseLog?.addSet(setLog)
    }
}