import UIKit

/// Lightweight wrapper for haptic feedback triggers used throughout the app.
enum HapticFeedback {
    case light
    case medium
    case heavy
    case soft
    case selection

    func fire() {
        switch self {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
