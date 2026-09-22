import SwiftUI
import UIKit

private struct ShopKeyboardHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

public extension EnvironmentValues {
    /// Current keyboard overlap height in points for the tracking view's window (0 when hidden).
    ///
    /// Published by `tracksKeyboardHeight()` and read by `ShopCollectionList`, which folds it into
    /// its bottom content inset so the last rows scroll clear of the keyboard. This drives a scroll
    /// **content inset**, never a frame resize — pair it with `.ignoresSafeArea(.keyboard)` on
    /// screens that must not shift/jump when the keyboard appears.
    var shopKeyboardHeight: CGFloat {
        get { self[ShopKeyboardHeightKey.self] }
        set { self[ShopKeyboardHeightKey.self] = newValue }
    }
}

public extension View {
    /// Publishes the owning window's keyboard overlap into `\.shopKeyboardHeight` for descendants.
    /// Attach near a screen root; a nested `ShopCollectionList` then insets its content automatically.
    /// Recalculates on keyboard and local layout changes without moving/resizing the view itself.
    func tracksKeyboardHeight() -> some View {
        modifier(ShopKeyboardHeightTrackingModifier())
    }

    /// Publishes the keyboard overlap and reports it inside the keyboard's own animation
    /// transaction. Use the callback when non-scroll content must travel with the keyboard.
    func tracksKeyboardHeight(onChange: @escaping (CGFloat) -> Void) -> some View {
        modifier(ShopKeyboardHeightTrackingModifier(onChange: onChange))
    }

    /// Insets generic SwiftUI scroll content (`ScrollView`/`List`) by the keyboard overlap via
    /// `safeAreaPadding(.bottom)`, so content scrolls clear of the keyboard without a frame jump.
    /// For UIKit-backed `ShopCollectionList`, prefer a `tracksKeyboardHeight()` ancestor instead.
    func respectsKeyboardHeight() -> some View {
        modifier(ShopRespectsKeyboardHeightModifier())
    }
}

private struct ShopKeyboardHeightTrackingModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var keyboardHeight: CGFloat = 0
    private let onChange: ((CGFloat) -> Void)?

    init(onChange: ((CGFloat) -> Void)? = nil) {
        self.onChange = onChange
    }

    func body(content: Content) -> some View {
        content
            .environment(\.shopKeyboardHeight, keyboardHeight)
            .background {
                ShopKeyboardHeightProbe(onChange: updateKeyboardHeight)
                    .accessibilityHidden(true)
            }
    }

    private func updateKeyboardHeight(_ height: CGFloat, notification: Notification?) {
        guard keyboardHeight != height else { return }
        keyboardHeight = height
        guard let onChange else { return }

        if let notification, !accessibilityReduceMotion {
            withAnimation(ShopKeyboardOverlap.animation(from: notification)) {
                onChange(height)
            }
        } else {
            onChange(height)
        }
    }
}

private struct ShopRespectsKeyboardHeightModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.bottom, keyboardHeight)
            .background {
                ShopKeyboardHeightProbe { height, _ in
                    keyboardHeight = height
                }
                .accessibilityHidden(true)
            }
    }
}

/// Supplies window ownership without changing the SwiftUI content's layout or identity.
private struct ShopKeyboardHeightProbe: UIViewRepresentable {
    let onChange: (CGFloat, Notification?) -> Void

    func makeUIView(context: Context) -> ProbeView {
        ProbeView(onChange: onChange)
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.onChange = onChange
        view.setNeedsLayout()
    }

    final class ProbeView: UIView {
        var onChange: (CGFloat, Notification?) -> Void
        private var keyboardNotification: Notification?
        private var pendingAnimationNotification: Notification?
        private var reportedHeight: CGFloat = 0
        private var layoutReportScheduled = false

        init(onChange: @escaping (CGFloat, Notification?) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            NotificationCenter.default.addObserver(
                self, selector: #selector(keyboardChanged), name: UIResponder.keyboardWillChangeFrameNotification, object: nil
            )
            NotificationCenter.default.addObserver(
                self, selector: #selector(keyboardChanged), name: UIResponder.keyboardWillHideNotification, object: nil
            )
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        deinit { NotificationCenter.default.removeObserver(self) }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil {
                keyboardNotification = nil
                pendingAnimationNotification = nil
            }
            scheduleLayoutReport()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            scheduleLayoutReport()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            scheduleLayoutReport()
        }

        @objc private func keyboardChanged(_ notification: Notification) {
            guard let window else { return }
            if let screen = notification.object as? UIScreen, screen !== window.windowScene?.screen { return }
            keyboardNotification = notification.name == UIResponder.keyboardWillHideNotification ? nil : notification
            pendingAnimationNotification = notification
            scheduleLayoutReport()
        }

        private func scheduleLayoutReport() {
            guard !layoutReportScheduled else { return }
            layoutReportScheduled = true
            // Layout and focus changes can both originate inside a SwiftUI update. Publish on
            // the next turn, retaining keyboard timing and recomputing from the latest frame so
            // a queued layout report cannot overwrite a newer hide/frame event.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                layoutReportScheduled = false
                let animationNotification = pendingAnimationNotification
                pendingAnimationNotification = nil
                report(animationNotification: animationNotification)
            }
        }

        private func report(animationNotification: Notification?) {
            let height: CGFloat
            if let window, let keyboardNotification {
                height = ShopKeyboardOverlap.height(from: keyboardNotification, in: window)
            } else {
                height = 0
            }
            guard height != reportedHeight else { return }
            reportedHeight = height
            onChange(height, animationNotification)
        }
    }
}

public enum ShopKeyboardOverlap {
    /// Clearance from the owning window's bottom edge to the intersecting keyboard's top edge.
    /// Frames in keyboard notifications use screen coordinates, even for offset/resized windows.
    /// Pass the owner when known; the compatibility fallback uses the notification screen's key window.
    @MainActor
    public static func height(from notification: Notification, in owningWindow: UIWindow? = nil) -> CGFloat {
        guard let window = owningWindow ?? keyWindow(for: notification),
              let frame = windowFrame(from: notification, in: window) else { return 0 }
        let intersection = window.bounds.intersection(frame)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        return max(0, window.bounds.maxY - intersection.minY)
    }

    /// The keyboard overlap measured from the bottom **safe area** edge rather than the window edge,
    /// because the keyboard covers the home-indicator inset instead of adding to it. This is the
    /// inset SwiftUI installs for the keyboard, and therefore exactly how much
    /// `.ignoresSafeArea(.keyboard, edges: .bottom)` grows a view by.
    ///
    /// Zero for an undocked keyboard: SwiftUI installs no keyboard safe-area inset for one, so anything
    /// padding itself by this value must not move either.
    @MainActor
    public static func safeAreaInset(from notification: Notification, in owningWindow: UIWindow? = nil) -> CGFloat {
        guard let window = owningWindow ?? keyWindow(for: notification),
              let frame = windowFrame(from: notification, in: window),
              isDocked(frame, in: window) else { return 0 }
        return max(0, height(from: notification, in: window) - window.safeAreaInsets.bottom)
    }

    @MainActor
    private static func windowFrame(from notification: Notification, in window: UIWindow) -> CGRect? {
        guard let screen = window.windowScene?.screen,
              let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              !frame.isNull, !frame.isInfinite,
              frame.minX.isFinite, frame.minY.isFinite, frame.maxX.isFinite, frame.maxY.isFinite,
              frame.width.isFinite, frame.height.isFinite, frame.width > 0, frame.height > 0 else { return nil }
        // Since iOS 16.1 the notification object identifies the keyboard's screen. Nil remains
        // supported for synthetic/legacy notifications, using the explicit owner's screen.
        if let sourceScreen = notification.object as? UIScreen, sourceScreen !== screen { return nil }
        return screen.coordinateSpace.convert(frame, to: window)
    }

    /// The keyboard's own animation timing, so a view that follows the keyboard travels with it instead
    /// of snapping to its final position while the keyboard is still sliding.
    public static func animation(from notification: Notification) -> Animation {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        switch notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int {
        case UIView.AnimationCurve.easeIn.rawValue:
            return .easeIn(duration: duration)
        case UIView.AnimationCurve.linear.rawValue:
            return .linear(duration: duration)
        // The system keyboard reports a private curve (7) that has no SwiftUI equivalent; `easeOut` is
        // the closest public match, and sharing the reported duration is what keeps the two in step.
        default:
            return .easeOut(duration: duration)
        }
    }

    /// A floating or split iPad keyboard reports a frame that stops short of the window's bottom edge,
    /// and the system displaces no safe area for it. Only a docked keyboard — one reaching the bottom
    /// edge and spanning the full width — counts as overlapping content.
    @MainActor
    private static func isDocked(_ endFrame: CGRect, in window: UIWindow) -> Bool {
        // A hairline of tolerance: keyboard frames arrive in fractional points on some scales.
        endFrame.maxY >= window.bounds.maxY - 1
            && endFrame.minX <= window.bounds.minX + 1
            && endFrame.maxX >= window.bounds.maxX - 1
    }

    @MainActor
    private static func keyWindow(for notification: Notification) -> UIWindow? {
        let screen = notification.object as? UIScreen
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { screen == nil || $0.screen === screen }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}
