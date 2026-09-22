import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum ShopSpinnerSize: CGFloat, CaseIterable, Sendable {
    case small = 18
    case medium = 24
    case large = 34
    case xLarge = 42

    public var points: CGFloat { rawValue }
}

public struct ShopSpinnerLogo: View {
    private let color: Color

    public init(color: Color = GravityColor.textBrand) {
        self.color = color
    }

    public var body: some View {
        ShopSpinnerLogoShape()
            .fill(color)
    }
}

public enum ShopSpinnerLogoPath {
    public static func cgPath(in rect: CGRect) -> CGPath {
        ShopSpinnerPathFactory.logoPath(in: rect)
    }
}

public struct ShopSpinner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pointSize: CGFloat
    private let color: Color
    private let accessibilityLabel: String?

    public init(
        size: ShopSpinnerSize = .medium,
        color: Color = GravityColor.textBrand,
        accessibilityLabel: String? = "Loading"
    ) {
        self.init(pointSize: size.points, color: color, accessibilityLabel: accessibilityLabel)
    }

    public init(
        pointSize: CGFloat,
        color: Color = GravityColor.textBrand,
        accessibilityLabel: String? = "Loading"
    ) {
        self.pointSize = pointSize
        self.color = color
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        spinnerContent
            .frame(width: pointSize, height: pointSize)
            .modifier(ShopSpinnerAccessibilityModifier(accessibilityLabel: accessibilityLabel))
    }

    @ViewBuilder
    private var spinnerContent: some View {
        if reduceMotion {
            ShopSpinnerLogo(color: color)
                .frame(width: pointSize, height: pointSize)
        } else {
            #if canImport(UIKit)
            ShopCoreAnimationSpinner(pointSize: pointSize, color: color)
                .frame(width: pointSize, height: pointSize)
            #else
            timelineSpinner
            #endif
        }
    }

    private var timelineSpinner: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            ShopSpinnerLogoReveal(
                revealWindow: .looping(phase: Self.animationPhase(at: context.date)),
                color: color,
                reduceMotion: false,
                pointSize: pointSize
            )
            .frame(width: pointSize, height: pointSize)
        }
    }

    public static func animationPhase(at date: Date = Date()) -> CGFloat {
        CGFloat(
            date.timeIntervalSinceReferenceDate.truncatingRemainder(
                dividingBy: ShopSpinnerMetrics.loopDuration
            ) / ShopSpinnerMetrics.loopDuration
        )
    }

    public static func remainingAnimationDuration(at date: Date = Date()) -> TimeInterval {
        let phase = animationPhase(at: date)
        guard phase > 0 else { return 0 }
        return TimeInterval(1 - phase) * ShopSpinnerMetrics.loopDuration
    }
}

enum ShopSpinnerMaskStrokeStyle {
    // Lottie `lc: 1` and `lj: 1` map to butt caps and miter joins.
    // Keep every native recreation of shop-spinner.json on this shared style.
    static let lineCap: CGLineCap = .butt
    static let lineJoin: CGLineJoin = .miter
    static let shapeLayerLineCap: CAShapeLayerLineCap = .butt
    static let shapeLayerLineJoin: CAShapeLayerLineJoin = .miter
}

enum ShopSpinnerMetrics {
    // Legacy parity source:
    // packages/mobile/src/assets/lottie/shop-spinner.json
    static let lottieCanvasSize: CGFloat = 34
    static let loopDuration: TimeInterval = 1.12
    static let lottieInFrame: CGFloat = 7
    static let lottieOutFrame: CGFloat = 74

    // Final transformed matte stroke width from packages/mobile/src/assets/lottie/shop-spinner.json,
    // scaled from the original 34pt Lottie canvas to the rendered 24pt indicator.
    static let defaultSize: CGFloat = 24
    static let defaultSwoopStrokeWidth: CGFloat = 6.1

    static func swoopStrokeWidth(for pointSize: CGFloat) -> CGFloat {
        defaultSwoopStrokeWidth * (pointSize / defaultSize)
    }

    static func frame(forLottieProgress progress: CGFloat) -> CGFloat {
        lottieInFrame + (min(max(progress, 0), 1) * (lottieOutFrame - lottieInFrame))
    }
}

#if canImport(UIKit)
private struct ShopCoreAnimationSpinner: UIViewRepresentable {
    let pointSize: CGFloat
    let color: Color

    func makeUIView(context: Context) -> ShopCoreAnimationSpinnerView {
        let view = ShopCoreAnimationSpinnerView()
        view.update(pointSize: pointSize, color: UIColor(color))
        return view
    }

    func updateUIView(_ uiView: ShopCoreAnimationSpinnerView, context: Context) {
        uiView.update(pointSize: pointSize, color: UIColor(color))
    }
}

final class ShopCoreAnimationSpinnerView: UIView {
    private enum AnimationKey {
        static let strokeStart = "shopSpinner.strokeStart"
        static let strokeEnd = "shopSpinner.strokeEnd"
    }

    private enum Presentation {
        case animating
        case reveal(ShopSpinnerRevealWindow)
    }

    private static let keyframeCount = 90

    private let logoLayer = CAShapeLayer()
    private let revealMaskLayer = CAShapeLayer()

    private var pointSize: CGFloat = ShopSpinnerSize.medium.points
    private var color: UIColor = UIColor(GravityColor.textBrand)
    private var presentation: Presentation = .animating

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func update(pointSize: CGFloat, color: UIColor) {
        self.pointSize = pointSize
        self.color = color
        updateLogoColor()
        setNeedsLayout()
        applyPresentation()
    }

    func startAnimating() {
        presentation = .animating
        applyPresentation()
    }

    func setRevealWindow(_ revealWindow: ShopSpinnerRevealWindow) {
        presentation = .reveal(revealWindow)
        applyPresentation()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let contentBounds = CGRect(origin: .zero, size: bounds.size)
        let renderedPointSize = min(bounds.width, bounds.height)

        logoLayer.frame = contentBounds
        logoLayer.path = ShopSpinnerPathFactory.logoPath(in: contentBounds)

        revealMaskLayer.frame = contentBounds
        revealMaskLayer.path = ShopSpinnerPathFactory.swoopPath(in: contentBounds)
        revealMaskLayer.lineWidth = ShopSpinnerMetrics.swoopStrokeWidth(for: renderedPointSize > 0 ? renderedPointSize : pointSize)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            removeAnimations()
        } else {
            applyPresentation()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateLogoColor()
    }

    private func commonInit() {
        isOpaque = false
        backgroundColor = .clear

        logoLayer.fillColor = color.resolvedColor(with: traitCollection).cgColor
        logoLayer.contentsScale = UIScreen.main.scale

        revealMaskLayer.fillColor = nil
        revealMaskLayer.strokeColor = UIColor.black.cgColor
        revealMaskLayer.lineCap = ShopSpinnerMaskStrokeStyle.shapeLayerLineCap
        revealMaskLayer.lineJoin = ShopSpinnerMaskStrokeStyle.shapeLayerLineJoin
        revealMaskLayer.contentsScale = UIScreen.main.scale

        logoLayer.mask = revealMaskLayer
        layer.addSublayer(logoLayer)
    }

    private func updateLogoColor() {
        logoLayer.fillColor = color.resolvedColor(with: traitCollection).cgColor
    }

    private func applyPresentation() {
        switch presentation {
        case .animating:
            startAnimatingIfNeeded()
        case let .reveal(revealWindow):
            applyRevealWindow(revealWindow)
        }
    }

    private func applyRevealWindow(_ revealWindow: ShopSpinnerRevealWindow) {
        removeAnimations()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        revealMaskLayer.strokeStart = revealWindow.trimStart
        revealMaskLayer.strokeEnd = revealWindow.trimEnd
        CATransaction.commit()
    }

    private func startAnimatingIfNeeded() {
        guard window != nil else { return }
        guard revealMaskLayer.animation(forKey: AnimationKey.strokeStart) == nil else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        revealMaskLayer.strokeStart = ShopSpinnerRevealWindow.full.trimStart
        revealMaskLayer.strokeEnd = ShopSpinnerRevealWindow.full.trimEnd
        CATransaction.commit()

        let phaseOffset = TimeInterval(ShopSpinner.animationPhase()) * ShopSpinnerMetrics.loopDuration
        let beginTime = revealMaskLayer.convertTime(CACurrentMediaTime(), from: nil) - phaseOffset

        let animations = Self.strokeAnimations(beginTime: beginTime)
        revealMaskLayer.add(animations.start, forKey: AnimationKey.strokeStart)
        revealMaskLayer.add(animations.end, forKey: AnimationKey.strokeEnd)
    }

    private func removeAnimations() {
        revealMaskLayer.removeAnimation(forKey: AnimationKey.strokeStart)
        revealMaskLayer.removeAnimation(forKey: AnimationKey.strokeEnd)
    }

    private static func strokeAnimations(beginTime: CFTimeInterval) -> (start: CAKeyframeAnimation, end: CAKeyframeAnimation) {
        var keyTimes: [NSNumber] = []
        var startValues: [NSNumber] = []
        var endValues: [NSNumber] = []

        for index in 0...keyframeCount {
            let phase = CGFloat(index) / CGFloat(keyframeCount)
            let revealWindow = ShopSpinnerRevealWindow.looping(phase: phase)

            keyTimes.append(NSNumber(value: Double(phase)))
            startValues.append(NSNumber(value: Double(revealWindow.trimStart)))
            endValues.append(NSNumber(value: Double(revealWindow.trimEnd)))
        }

        return (
            animation(keyPath: "strokeStart", values: startValues, keyTimes: keyTimes, beginTime: beginTime),
            animation(keyPath: "strokeEnd", values: endValues, keyTimes: keyTimes, beginTime: beginTime)
        )
    }

    private static func animation(
        keyPath: String,
        values: [NSNumber],
        keyTimes: [NSNumber],
        beginTime: CFTimeInterval
    ) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = values
        animation.keyTimes = keyTimes
        animation.duration = ShopSpinnerMetrics.loopDuration
        animation.beginTime = beginTime
        animation.repeatCount = .infinity
        animation.calculationMode = .linear
        animation.isRemovedOnCompletion = false
        return animation
    }
}
#endif

private struct ShopSpinnerAccessibilityModifier: ViewModifier {
    let accessibilityLabel: String?

    func body(content: Content) -> some View {
        if let accessibilityLabel {
            content
                .accessibilityRepresentation {
                    ProgressView()
                        .accessibilityLabel(SwiftUI.Text(accessibilityLabel))
                }
        } else {
            content
                .accessibilityHidden(true)
        }
    }
}

struct ShopSpinnerLogoReveal: View {
    let revealWindow: ShopSpinnerRevealWindow
    let color: Color
    let reduceMotion: Bool
    let pointSize: CGFloat

    var body: some View {
        ShopSpinnerLogo(color: color)
            .mask {
                if reduceMotion {
                    Rectangle()
                } else {
                    ShopSpinnerSwoopShape()
                        .trim(from: revealWindow.trimStart, to: revealWindow.trimEnd)
                        .stroke(
                            style: StrokeStyle(
                                lineWidth: ShopSpinnerMetrics.swoopStrokeWidth(for: pointSize),
                                lineCap: ShopSpinnerMaskStrokeStyle.lineCap,
                                lineJoin: ShopSpinnerMaskStrokeStyle.lineJoin
                            )
                        )
                }
            }
    }
}

struct ShopSpinnerRevealWindow {
    let trimStart: CGFloat
    let trimEnd: CGFloat

    static let full = ShopSpinnerRevealWindow(trimStart: 0, trimEnd: 1)

    static func pull(pullDistance: CGFloat) -> ShopSpinnerRevealWindow {
        window(forFrame: ShopRefreshIndicatorMetrics.frame(
            forLottieProgress: ShopRefreshIndicatorMetrics.lottieProgress(forPullDistance: pullDistance)
        ))
    }

    static func looping(phase: CGFloat) -> ShopSpinnerRevealWindow {
        window(forFrame: ShopSpinnerMetrics.frame(forLottieProgress: phase))
    }

    static func window(forFrame frame: CGFloat) -> ShopSpinnerRevealWindow {
        let trimEnd = trimValue(
            at: frame,
            fromFrame: 0,
            toFrame: 63,
            controlPoint1: CGPoint(x: 0.263, y: 0),
            controlPoint2: CGPoint(x: 0.472, y: 1)
        )
        let trimStart = trimValue(
            at: frame,
            fromFrame: 23.076,
            toFrame: 75,
            controlPoint1: CGPoint(x: 0.718, y: 0),
            controlPoint2: CGPoint(x: 0.843, y: 1)
        )

        return ShopSpinnerRevealWindow(
            trimStart: min(trimStart, trimEnd),
            trimEnd: max(trimStart, trimEnd)
        )
    }

    private static func trimValue(
        at frame: CGFloat,
        fromFrame: CGFloat,
        toFrame: CGFloat,
        controlPoint1: CGPoint,
        controlPoint2: CGPoint
    ) -> CGFloat {
        guard frame > fromFrame else {
            return 0
        }

        guard frame < toFrame else {
            return 1
        }

        let linearProgress = (frame - fromFrame) / (toFrame - fromFrame)
        return cubicBezierY(
            forX: linearProgress,
            controlPoint1: controlPoint1,
            controlPoint2: controlPoint2
        )
    }

    private static func cubicBezierY(
        forX x: CGFloat,
        controlPoint1: CGPoint,
        controlPoint2: CGPoint
    ) -> CGFloat {
        let clampedX = min(max(x, 0), 1)
        var low: CGFloat = 0
        var high: CGFloat = 1
        var t = clampedX

        for _ in 0..<12 {
            t = (low + high) / 2
            let sampleX = cubicBezierCoordinate(
                t: t,
                control1: controlPoint1.x,
                control2: controlPoint2.x
            )

            if sampleX < clampedX {
                low = t
            } else {
                high = t
            }
        }

        return cubicBezierCoordinate(
            t: t,
            control1: controlPoint1.y,
            control2: controlPoint2.y
        )
    }

    private static func cubicBezierCoordinate(t: CGFloat, control1: CGFloat, control2: CGFloat) -> CGFloat {
        let inverseT = 1 - t
        return (3 * inverseT * inverseT * t * control1)
            + (3 * inverseT * t * t * control2)
            + (t * t * t)
    }
}

private struct ShopSpinnerLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ShopSpinnerPathFactory.logoPath(in: rect))
    }
}

private struct ShopSpinnerSwoopShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ShopSpinnerPathFactory.swoopPath(in: rect))
    }
}

private enum ShopSpinnerPathFactory {
    static func logoPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()

        path.move(to: point(13.429, 0.930, in: rect))
        path.addCurve(
            to: point(3.251, 3.962, in: rect),
            control1: point(9.500, 0.930, in: rect),
            control2: point(5.811, 2.177, in: rect)
        )
        path.addCurve(
            to: point(6.709, 9.859, in: rect),
            control1: point(3.251, 3.962, in: rect),
            control2: point(6.709, 9.859, in: rect)
        )
        path.addCurve(
            to: point(13.434, 7.895, in: rect),
            control1: point(8.710, 8.560, in: rect),
            control2: point(11.048, 7.876, in: rect)
        )
        path.addCurve(
            to: point(23.968, 17.833, in: rect),
            control1: point(19.505, 7.895, in: rect),
            control2: point(23.968, 12.179, in: rect)
        )
        path.addCurve(
            to: point(15.873, 26.226, in: rect),
            control1: point(23.968, 22.654, in: rect),
            control2: point(20.397, 26.226, in: rect)
        )
        path.addCurve(
            to: point(9.624, 21.047, in: rect),
            control1: point(12.184, 26.226, in: rect),
            control2: point(9.624, 24.079, in: rect)
        )
        path.addCurve(
            to: point(12.656, 16.703, in: rect),
            control1: point(9.624, 19.202, in: rect),
            control2: point(10.455, 17.713, in: rect)
        )
        path.addCurve(
            to: point(9.383, 11.168, in: rect),
            control1: point(12.656, 16.703, in: rect),
            control2: point(9.383, 11.168, in: rect)
        )
        path.addCurve(
            to: point(2.477, 20.809, in: rect),
            control1: point(5.341, 12.536, in: rect),
            control2: point(2.477, 16.047, in: rect)
        )
        path.addCurve(
            to: point(15.868, 33.070, in: rect),
            control1: point(2.477, 27.833, in: rect),
            control2: point(8.071, 33.070, in: rect)
        )
        path.addCurve(
            to: point(31.523, 17.715, in: rect),
            control1: point(24.976, 33.070, in: rect),
            control2: point(31.523, 26.760, in: rect)
        )
        path.addCurve(
            to: point(13.429, 0.930, in: rect),
            control1: point(31.523, 8.013, in: rect),
            control2: point(23.904, 0.930, in: rect)
        )
        path.closeSubpath()

        return path
    }

    static func swoopPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()

        path.move(to: point(3.466, 7.747, in: rect))
        path.addCurve(
            to: point(27.724, 17.097, in: rect),
            control1: point(18.984, -2.611, in: rect),
            control2: point(27.609, 10.902, in: rect)
        )
        path.addCurve(
            to: point(19.113, 29.143, in: rect),
            control1: point(27.820, 22.268, in: rect),
            control2: point(25.872, 26.703, in: rect)
        )
        path.addCurve(
            to: point(15.059, 12.397, in: rect),
            control1: point(9.439, 32.637, in: rect),
            control2: point(-3.067, 17.773, in: rect)
        )

        return path
    }

    private static func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + ((x / ShopSpinnerMetrics.lottieCanvasSize) * rect.width),
            y: rect.minY + ((y / ShopSpinnerMetrics.lottieCanvasSize) * rect.height)
        )
    }
}

#Preview("ShopSpinner") {
    HStack(spacing: GravitySpacing.space16) {
        ShopSpinner(size: .small)
        ShopSpinner(size: .medium)
        ShopSpinner(size: .large)
        ShopSpinner(size: .xLarge)
    }
    .padding()
}
