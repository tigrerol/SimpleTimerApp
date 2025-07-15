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
    public var weight: Double?
    public var reps: Int?
    public var restTime: TimeInterval
    public var notes: String
    public var timestamp: Date
    
    public init(
        name: String,
        weight: Double? = nil,
        reps: Int? = nil,
        restTime: TimeInterval = 0,
        notes: String = ""
    ) {
        self.name = name
        self.weight = weight
        self.reps = reps
        self.restTime = restTime
        self.notes = notes
        self.timestamp = Date()
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
    public var isScreenLocked: Bool = false
    
    public init() {}
    
    public func configureWorkout(_ config: WorkoutConfig) {
        currentConfig = config
        phase = .ready(config: config)
    }
    
    public func startWorkout() {
        guard let config = currentConfig else { return }
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
    }
}