import SwiftUI

/// Extracts the exact animation curve and duration from a keyboard notification.
/// iOS uses a private curve (rawValue 7) that maps closely to a cubic bezier.
enum KeyboardAnimation {
    /// Create a SwiftUI Animation matching the keyboard's show/hide curve.
    static func animation(from notification: Notification) -> Animation {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7

        // Curve 7 is the keyboard's private ease-in-out — best matched by this spring
        if curveRaw == 7 {
            return .interpolatingSpring(mass: 3, stiffness: 1000, damping: 500, initialVelocity: 0)
        }

        // Fallback for standard curves
        let curve = UIView.AnimationCurve(rawValue: Int(curveRaw)) ?? .easeInOut
        switch curve {
        case .easeIn: return .easeIn(duration: duration)
        case .easeOut: return .easeOut(duration: duration)
        case .linear: return .linear(duration: duration)
        default: return .easeInOut(duration: duration)
        }
    }

    /// Extract the end frame height from a keyboard notification.
    static func endHeight(from notification: Notification) -> CGFloat {
        (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
    }
}
