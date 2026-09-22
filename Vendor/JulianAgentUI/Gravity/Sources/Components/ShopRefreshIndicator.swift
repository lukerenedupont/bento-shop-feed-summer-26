import SwiftUI

enum ShopRefreshIndicatorMetrics {
    // Legacy parity source:
    // packages/mobile/src/shared/components/List/ReanimatedShopRefreshSpinner/ReanimatedShopRefreshSpinner.tsx
    static let defaultSize: CGFloat = 24
    static let lottieCanvasSize: CGFloat = 34
    static let maxScalePullDistance: CGFloat = 60
    static let visiblePullDistance: CGFloat = 15
    static let bumpScale: CGFloat = 1.16
    static let loopDuration: TimeInterval = 1.12

    // Legacy Lottie progress mapping while dragging:
    // progress = interpolate(pullDistance * 0.3, [0, 51], [0.54, 1])
    static let progressPullDistanceMultiplier: CGFloat = 0.3
    static let maxProgressTravel: CGFloat = 51
    static let pullLottieProgressStart: CGFloat = 0.54

    static let pullLottieProgressEnd: CGFloat = 1

    // Composition timing from packages/mobile/src/assets/lottie/shop-spinner.json.
    static let lottieInFrame: CGFloat = 7
    static let lottieOutFrame: CGFloat = 74

    // Final transformed matte stroke width from packages/mobile/src/assets/lottie/shop-spinner.json,
    // scaled from the original 34pt Lottie canvas to the rendered 24pt indicator.
    static let defaultSwoopStrokeWidth: CGFloat = 6.1

    static func swoopStrokeWidth(for pointSize: CGFloat) -> CGFloat {
        defaultSwoopStrokeWidth * (pointSize / defaultSize)
    }

    static func clampedPullProgress(_ pullDistance: CGFloat) -> CGFloat {
        min(max(pullDistance / maxScalePullDistance, 0), 1)
    }

    static func opacity(for pullDistance: CGFloat) -> CGFloat {
        let range = maxScalePullDistance - visiblePullDistance
        return min(max((pullDistance - visiblePullDistance) / range, 0), 1)
    }

    static func scale(for pullDistance: CGFloat) -> CGFloat {
        0.5 + (clampedPullProgress(pullDistance) * 0.5)
    }

    static func lottieProgress(forPullDistance pullDistance: CGFloat) -> CGFloat {
        let travelProgress = min(max((pullDistance * progressPullDistanceMultiplier) / maxProgressTravel, 0), 1)
        return pullLottieProgressStart + ((pullLottieProgressEnd - pullLottieProgressStart) * travelProgress)
    }

    static func frame(forLottieProgress progress: CGFloat) -> CGFloat {
        lottieInFrame + (min(max(progress, 0), 1) * (lottieOutFrame - lottieInFrame))
    }
}

public struct ShopRefreshIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pullDistance: CGFloat
    private let isRefreshing: Bool
    private let color: Color
    private let pointSize: CGFloat

    @State private var refreshStartDate = Date()
    @State private var bumpScale: CGFloat = 1

    public init(
        pullDistance: CGFloat,
        isRefreshing: Bool,
        color: Color = ShopColor.textBrand,
        pointSize: CGFloat = ShopSpinnerSize.medium.points
    ) {
        self.pullDistance = pullDistance
        self.isRefreshing = isRefreshing
        self.color = color
        self.pointSize = pointSize
    }

    public var body: some View {
        TimelineView(.animation(paused: reduceMotion || isRefreshing == false)) { context in
            ShopRefreshLogoReveal(
                revealWindow: revealWindow(at: context.date),
                color: color,
                reduceMotion: reduceMotion,
                pointSize: pointSize
            )
            .frame(
                width: pointSize,
                height: pointSize
            )
            .opacity(ShopRefreshIndicatorMetrics.opacity(for: pullDistance))
            .scaleEffect(ShopRefreshIndicatorMetrics.scale(for: pullDistance) * bumpScale)
            .animation(.easeOut(duration: 0.12), value: pullDistance)
        }
        .frame(
            width: pointSize,
            height: pointSize
        )
        .task(id: isRefreshing) {
            guard isRefreshing else {
                bumpScale = 1
                return
            }

            refreshStartDate = Date()

            guard reduceMotion == false else {
                return
            }

            withAnimation(.easeOut(duration: 0.06)) {
                bumpScale = ShopRefreshIndicatorMetrics.bumpScale
            }

            try? await Task.sleep(nanoseconds: 80_000_000)

            guard Task.isCancelled == false else {
                return
            }

            withAnimation(.easeInOut(duration: 0.22)) {
                bumpScale = 1
            }
        }
    }

    private func revealWindow(at date: Date) -> ShopRefreshRevealWindow {
        guard reduceMotion == false else {
            return .full
        }

        if isRefreshing {
            let elapsed = date.timeIntervalSince(refreshStartDate)
            let phase = CGFloat(elapsed.truncatingRemainder(dividingBy: ShopRefreshIndicatorMetrics.loopDuration) / ShopRefreshIndicatorMetrics.loopDuration)
            return .looping(phase: phase)
        }

        return .pull(pullDistance: pullDistance)
    }
}

private struct ShopRefreshLogoReveal: View {
    let revealWindow: ShopRefreshRevealWindow
    let color: Color
    let reduceMotion: Bool
    let pointSize: CGFloat

    var body: some View {
        ShopRefreshLogoShape()
            .fill(color)
            .mask {
                if reduceMotion {
                    Rectangle()
                } else {
                    ShopRefreshSwoopShape()
                        .trim(from: revealWindow.trimStart, to: revealWindow.trimEnd)
                        .stroke(
                            style: StrokeStyle(
                                lineWidth: ShopRefreshIndicatorMetrics.swoopStrokeWidth(for: pointSize),
                                lineCap: ShopSpinnerMaskStrokeStyle.lineCap,
                                lineJoin: ShopSpinnerMaskStrokeStyle.lineJoin
                            )
                        )
                }
            }
    }
}

private struct ShopRefreshRevealWindow {
    let trimStart: CGFloat
    let trimEnd: CGFloat

    static let full = ShopRefreshRevealWindow(trimStart: 0, trimEnd: 1)

    static func pull(pullDistance: CGFloat) -> ShopRefreshRevealWindow {
        // RN did not scrub from the start of the Lottie. It mapped pull distance
        // to progress 0.54→1, where the matte's trim start is already chasing
        // trim end. That makes the visible window travel around the swirl and
        // collapse from the trailing end instead of leaving the logo fully revealed.
        window(forFrame: ShopRefreshIndicatorMetrics.frame(
            forLottieProgress: ShopRefreshIndicatorMetrics.lottieProgress(forPullDistance: pullDistance)
        ))
    }

    static func looping(phase: CGFloat) -> ShopRefreshRevealWindow {
        window(forFrame: ShopRefreshIndicatorMetrics.frame(forLottieProgress: phase))
    }

    private static func window(forFrame frame: CGFloat) -> ShopRefreshRevealWindow {
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

        return ShopRefreshRevealWindow(
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

private struct ShopRefreshLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

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

    private func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + ((x / ShopRefreshIndicatorMetrics.lottieCanvasSize) * rect.width),
            y: rect.minY + ((y / ShopRefreshIndicatorMetrics.lottieCanvasSize) * rect.height)
        )
    }
}

private struct ShopRefreshSwoopShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

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

    private func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + ((x / ShopRefreshIndicatorMetrics.lottieCanvasSize) * rect.width),
            y: rect.minY + ((y / ShopRefreshIndicatorMetrics.lottieCanvasSize) * rect.height)
        )
    }
}

#Preview("Shop refresh indicator") {
    VStack(spacing: ShopSpacing.space24) {
        ShopRefreshIndicator(pullDistance: 20, isRefreshing: false)
        ShopRefreshIndicator(pullDistance: 60, isRefreshing: false)
        ShopRefreshIndicator(pullDistance: 110, isRefreshing: false)
        ShopRefreshIndicator(pullDistance: 60, isRefreshing: true)
        ShopSpinner(size: .small)
        ShopSpinner(size: .medium)
        ShopSpinner(size: .large)
        ShopSpinner(size: .xLarge)
    }
    .padding(ShopSpacing.space32)
    .background(ShopColor.background)
}
