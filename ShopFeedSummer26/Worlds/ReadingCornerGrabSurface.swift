import SwiftUI
import UIKit

/// A card owns horizontal drags immediately and free-direction drags after a
/// brief lift. Ordinary vertical swipes remain page scrolling. Explicit failure
/// dependencies also keep a rightward card throw from invoking native Back.
struct ReadingCornerGrabSurface: UIViewRepresentable {
    var onTap: () -> Void
    var onMove: (CGSize) -> Void
    var onEnd: (CGSize, CGSize) -> Void
    var onCancel: () -> Void
    var freeDragImmediately = false

    func makeUIView(context: Context) -> Surface { Surface() }
    func updateUIView(_ view: Surface, context: Context) {
        view.onTap = onTap; view.onMove = onMove
        view.onEnd = onEnd; view.onCancel = onCancel
        view.freeDragImmediately = freeDragImmediately
    }

    final class Surface: UIView, UIGestureRecognizerDelegate {
        var onTap: () -> Void = {}
        var onMove: (CGSize) -> Void = { _ in }
        var onEnd: (CGSize, CGSize) -> Void = { _, _ in }
        var onCancel: () -> Void = {}
        var freeDragImmediately = false
        private var liftOrigin = CGPoint.zero
        private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(panned))
        private lazy var lift = UILongPressGestureRecognizer(target: self, action: #selector(lifted))
        private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(tapped))

        init() {
            super.init(frame: .zero)
            backgroundColor = .clear
            isAccessibilityElement = false
            pan.delegate = self
            lift.minimumPressDuration = 0.16
            lift.allowableMovement = 9
            addGestureRecognizer(pan); addGestureRecognizer(lift); addGestureRecognizer(tap)
            tap.require(toFail: pan); tap.require(toFail: lift)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            // Hosting ancestry is complete on the next main turn.
            DispatchQueue.main.async { [weak self] in self?.prioritizeCard() }
        }
        private func prioritizeCard() {
            var ancestor = superview
            while let view = ancestor {
                for gesture in view.gestureRecognizers ?? [] where gesture is UIPanGestureRecognizer {
                    gesture.require(toFail: pan)
                    gesture.require(toFail: lift)
                }
                ancestor = view.superview
            }
            var responder: UIResponder? = self
            while let current = responder {
                if let controller = current as? UIViewController, let nav = controller.navigationController {
                    nav.interactivePopGestureRecognizer?.require(toFail: pan)
                    nav.interactivePopGestureRecognizer?.require(toFail: lift)
                    nav.interactiveContentPopGestureRecognizer?.require(toFail: pan)
                    nav.interactiveContentPopGestureRecognizer?.require(toFail: lift)
                }
                responder = current.next
            }
        }
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === pan, !freeDragImmediately else { return true }
            let velocity = pan.velocity(in: window)
            return abs(velocity.x) > abs(velocity.y) * 0.8
        }
        @objc private func tapped() { onTap() }
        @objc private func panned() {
            let point = pan.translation(in: window)
            let translation = CGSize(width: point.x, height: point.y)
            switch pan.state {
            case .began, .changed: onMove(translation)
            case .ended:
                let velocity = pan.velocity(in: window)
                onEnd(translation, CGSize(width: velocity.x, height: velocity.y))
            case .cancelled, .failed:
                if lift.state != .began && lift.state != .changed { onCancel() }
            default: break
            }
        }
        @objc private func lifted() {
            let point = lift.location(in: window)
            if lift.state == .began { liftOrigin = point }
            let translation = CGSize(width: point.x - liftOrigin.x, height: point.y - liftOrigin.y)
            switch lift.state {
            case .began, .changed: onMove(translation)
            case .ended: onEnd(translation, .zero)
            case .cancelled, .failed:
                if pan.state != .began && pan.state != .changed { onCancel() }
            default: break
            }
        }
    }
}
