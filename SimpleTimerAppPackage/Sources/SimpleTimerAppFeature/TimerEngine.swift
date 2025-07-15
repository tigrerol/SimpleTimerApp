import Foundation
import AVFoundation
import CoreHaptics
import UIKit

@MainActor
@Observable
public final class TimerEngine {
    public private(set) var timerState = TimerState()
    public private(set) var isRunning = false
    
    private var timerTask: Task<Void, Never>?
    private var targetEndDate: Date?
    private let audioManager = AudioManager()
    private let hapticManager = HapticManager()
    
    public init() {
        setupAudioSession()
        setupHaptics()
    }
    
    // MARK: - Public Interface
    
    public func configureWorkout(_ config: WorkoutConfig) {
        timerState.configureWorkout(config)
    }
    
    public func startWorkout() {
        timerState.startWorkout()
        enableScreenLock(false)
    }
    
    public func startCurrentSet() {
        switch timerState.phase {
        case .ready:
            timerState.startWorkout()
        case .resting(_, let nextSet, let totalSets):
            timerState.startSet(nextSet)
        default:
            break
        }
        enableScreenLock(false)
    }
    
    public func endCurrentSet() {
        switch timerState.phase {
        case .working:
            timerState.endSet()
            
            // Check if we need to start rest timer or if workout is complete
            switch timerState.phase {
            case .resting(let timeRemaining, _, _):
                startRestTimer(duration: timeRemaining)
            case .completed:
                enableScreenLock(true)
            default:
                break
            }
        default:
            break
        }
    }
    
    public func pauseTimer() {
        timerState.pause()
        stopTimer()
    }
    
    public func resumeTimer() {
        switch timerState.phase {
        case .paused:
            timerState.resume()
            if case .resting(let timeRemaining, _, _) = timerState.phase {
                startRestTimer(duration: timeRemaining)
            }
        default:
            break
        }
    }
    
    public func resetTimer() {
        stopTimer()
        timerState.reset()
        enableScreenLock(true)
    }
    
    // MARK: - Private Timer Logic
    
    private func startRestTimer(duration: TimeInterval) {
        stopTimer()
        
        let endDate = Date().addingTimeInterval(duration)
        targetEndDate = endDate
        isRunning = true
        
        timerTask = Task {
            while !Task.isCancelled && Date() < endDate {
                let remaining = endDate.timeIntervalSinceNow
                
                if remaining <= 0 {
                    await restTimerCompleted()
                    return
                }
                
                // Update the rest timer with current values
                switch timerState.phase {
                case .resting(_, let nextSet, let totalSets):
                    timerState.phase = .resting(timeRemaining: remaining, nextSet: nextSet, totalSets: totalSets)
                default:
                    break
                }
                
                // Update every 0.1 seconds for smooth UI
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
    
    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        isRunning = false
        targetEndDate = nil
    }
    
    private func restTimerCompleted() {
        stopTimer()
        
        // Keep the timer in resting state but with 0 time remaining
        // The UI will show "Start" button for next set
        switch timerState.phase {
        case .resting(_, let nextSet, let totalSets):
            timerState.phase = .resting(timeRemaining: 0, nextSet: nextSet, totalSets: totalSets)
        default:
            break
        }
        
        // Play sound and haptic feedback
        Task {
            await audioManager.playCompletionSound()
            await hapticManager.triggerCompletion()
        }
    }
    
    // MARK: - System Integration
    
    private func enableScreenLock(_ enabled: Bool) {
        timerState.isScreenLocked = !enabled
        // Note: UIApplication.shared.isIdleTimerDisabled will be set in the view
    }
    
    private func setupAudioSession() {
        Task {
            await audioManager.configureAudioSession()
        }
    }
    
    private func setupHaptics() {
        Task {
            await hapticManager.prepareHaptics()
        }
    }
}

// MARK: - Audio Manager

@MainActor
final class AudioManager {
    private var audioSession: AVAudioSession {
        AVAudioSession.sharedInstance()
    }
    
    func configureAudioSession() async {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    func playCompletionSound() async {
        // Simple system sound for completion
        AudioServicesPlaySystemSound(1057) // Tink sound
    }
}

// MARK: - Haptic Manager

@MainActor
final class HapticManager {
    private var hapticEngine: CHHapticEngine?
    
    func prepareHaptics() async {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("Device doesn't support haptics")
            return
        }
        
        do {
            let engine = try CHHapticEngine()
            try await engine.start()
            hapticEngine = engine
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }
    
    func triggerCompletion() async {
        guard let engine = hapticEngine else {
            // Fallback to simple haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            return
        }
        
        do {
            // Create a strong tap pattern for rest completion
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [sharpness, intensity],
                relativeTime: 0
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try await player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
            // Fallback to simple haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
    }
}