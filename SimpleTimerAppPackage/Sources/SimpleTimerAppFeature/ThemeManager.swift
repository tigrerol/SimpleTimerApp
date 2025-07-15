import SwiftUI

@Observable
@MainActor
public final class ThemeManager {
    public let soundManager = SoundManager()
    public enum ColorScheme: String, CaseIterable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        
        public var colorScheme: SwiftUI.ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }
    
    public var selectedScheme: ColorScheme = .system {
        didSet {
            UserDefaults.standard.set(selectedScheme.rawValue, forKey: "ColorScheme")
        }
    }
    
    public init() {
        if let saved = UserDefaults.standard.string(forKey: "ColorScheme"),
           let scheme = ColorScheme(rawValue: saved) {
            selectedScheme = scheme
        }
    }
}