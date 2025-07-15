import Foundation
import AudioToolbox

@Observable
@MainActor
public final class SoundManager {
    public enum CompletionSound: String, CaseIterable {
        case tink = "Tink"
        case bell = "Bell" 
        case chime = "Chime"
        case pop = "Pop"
        case ping = "Ping"
        
        public var systemSoundID: SystemSoundID {
            switch self {
            case .tink: return 1057  // Tink
            case .bell: return 1005  // New Mail
            case .chime: return 1013 // Glass
            case .pop: return 1306   // Begin Video Record
            case .ping: return 1103  // SMS Alert Tone
            }
        }
        
        public var description: String {
            switch self {
            case .tink: return "Tink (Default)"
            case .bell: return "Bell"
            case .chime: return "Chime"
            case .pop: return "Pop"
            case .ping: return "Ping"
            }
        }
        
        public var icon: String {
            switch self {
            case .tink: return "bell"
            case .bell: return "bell.fill"
            case .chime: return "bell.and.waves.left.and.right"
            case .pop: return "burst"
            case .ping: return "dot.radiowaves.left.and.right"
            }
        }
    }
    
    public var selectedSound: CompletionSound = .tink {
        didSet {
            UserDefaults.standard.set(selectedSound.rawValue, forKey: "CompletionSound")
        }
    }
    
    public init() {
        if let saved = UserDefaults.standard.string(forKey: "CompletionSound"),
           let sound = CompletionSound(rawValue: saved) {
            selectedSound = sound
        }
    }
    
    public func playCompletionSound() {
        print("🔊 Playing completion sound: \(selectedSound.rawValue)")
        AudioServicesPlaySystemSound(selectedSound.systemSoundID)
    }
    
    public func previewSound(_ sound: CompletionSound) {
        print("🔊 Previewing sound: \(sound.rawValue)")
        AudioServicesPlaySystemSound(sound.systemSoundID)
    }
}