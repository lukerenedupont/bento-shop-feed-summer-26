import QuartzCore

/// A temporary depth cue layered over the dock's existing position/size morph.
/// The model transform never changes, so layout and the final hit targets stay put.
@MainActor
enum ShopDockSwapDepthAnimation {
    static let animationKey = "ShopDockSwap.depth"
    static let minimumScale = 0.90
    static let subtleMinimumScale = 0.96
    static let maximumScale = 1.12

    static func animate(
        on layer: CALayer,
        recedes: Bool,
        bumps: Bool = false,
        recedingScale: CGFloat = minimumScale,
        duration: TimeInterval,
        animated: Bool
    ) {
        let wasAnimating = layer.animation(forKey: animationKey) != nil
        // Retarget from the visible scale when the user reverses a swap mid-flight.
        let currentScale = (layer.presentation()?.value(forKeyPath: "transform.scale") as? NSNumber)?.doubleValue ?? 1
        layer.removeAnimation(forKey: animationKey)
        guard animated, duration > 0, recedes || bumps || wasAnimating else { return }

        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        let hasMidpoint = recedes || bumps
        let midpointScale = bumps ? maximumScale : recedingScale
        animation.values = hasMidpoint ? [currentScale, midpointScale, 1] : [currentScale, 1]
        animation.keyTimes = hasMidpoint ? [0, 0.5, 1] : [0, 1]
        animation.timingFunctions = Array(
            repeating: CAMediaTimingFunction(name: .easeInEaseOut),
            count: hasMidpoint ? 2 : 1
        )
        animation.duration = duration
        layer.add(animation, forKey: animationKey)
    }

    static func reset(on layer: CALayer) {
        layer.removeAnimation(forKey: animationKey)
    }
}
