// Adapted from shopify-playground/canvas-agent at a5957f4.
// The UIKit canvas mechanics remain intentionally aligned with that prototype.
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct CanvasOrbMotion: Equatable {
    var displacement: CGSize
    var velocity: CGSize
    var speed: CGFloat

    static let zero = CanvasOrbMotion(
        displacement: .zero,
        velocity: .zero,
        speed: 0
    )
}

struct CanvasOpeningChoreography: Equatable {
    enum Style: Equatable {
        case editorial
        case gallery
        case universe
    }

    let style: Style
    let focusProductIDs: [String]
}

struct CanvasLayoutPolicy: Equatable {
    static let defaultSpatialVisibleColumnCount = 3

    let columnCount: Int

    init(resultColumnCount: Int?) {
        columnCount = min(5, max(1, resultColumnCount ?? 5))
    }

    var isSingleColumnFeed: Bool { columnCount == 1 }
    var allowsHorizontalPanning: Bool { !isSingleColumnFeed }
    var allowsZoom: Bool { !isSingleColumnFeed }
}

struct CanvasVoiceCommand: Equatable {
    enum PanDirection: String, Equatable {
        case left
        case right
        case up
        case down
    }

    enum PanDistance: String, Equatable {
        case small
        case medium
        case large
    }

    enum ZoomDirection: String, Equatable {
        case closer = "in"
        case farther = "out"
    }

    enum ZoomAmount: String, Equatable {
        case small
        case medium
        case large

        var columnDelta: Int {
            switch self {
            case .small: 1
            case .medium: 2
            case .large: .max
            }
        }
    }

    enum Action: Equatable {
        case voiceEntrance
        case pan(direction: PanDirection, distance: PanDistance)
        case zoom(direction: ZoomDirection, amount: ZoomAmount)
        case highlight(productIDs: [String])
        case point(productIDs: [String])
        case endSpokenItemFocus
        case showcase(resultCount: Int)
        case opening(CanvasOpeningChoreography)
        case play(CanvasPlayCommand)
    }

    let id = UUID()
    let action: Action

    static func requestsSingleProductFocus(
        direction: ZoomDirection,
        amount: ZoomAmount
    ) -> Bool {
        direction == .closer && amount == .large
    }
}

struct CanvasPlayCommand: Equatable {
    enum Action: String, CaseIterable, Equatable {
        case pile
        case remove
        case cascade
        case spotlight
        case reset
    }

    enum Sequence: String, CaseIterable, Equatable {
        case centerOut = "center_out"
        case leftToRight = "left_to_right"
        case topToBottom = "top_to_bottom"
    }

    let action: Action
    let productIDs: [String]
    let sequence: Sequence
}

struct CanvasProductPlacement {
    /// Spatial canvases repeat their edit through every row so a short live
    /// response can never create a large dead band inside the infinite field.
    /// The intentionally finite single-column feed still stops at its exact
    /// requested item count.
    static func productIndex(
        row: Int,
        column: Int,
        columnCount: Int,
        productCount: Int,
        repeatsSpatially: Bool
    ) -> Int? {
        guard row >= 0,
              column >= 0,
              column < columnCount,
              columnCount > 0,
              productCount > 0 else { return nil }
        let index = row * columnCount + column
        if repeatsSpatially {
            return index % productCount
        }
        return index < productCount ? index : nil
    }
}

struct CanvasSpiralOrdering {
    private struct RankedPoint {
        let index: Int
        let radius: CGFloat
        let clockwiseAngle: CGFloat
        let spiralPosition: CGFloat
    }

    /// Orders points along a clockwise spiral that begins at twelve o'clock.
    /// The angular term is deliberately smaller than one radial step, so the
    /// wave keeps expanding even as it curls around the viewport.
    static func indices(
        for points: [CGPoint],
        around center: CGPoint,
        radialStep: CGFloat
    ) -> [Int] {
        let safeRadialStep = max(1, radialStep)
        let fullTurn = CGFloat.pi * 2

        return points.enumerated()
            .map { index, point in
                let deltaX = point.x - center.x
                let deltaY = point.y - center.y
                let radius = hypot(deltaX, deltaY)
                var angle = atan2(deltaX, -deltaY)
                if angle < 0 { angle += fullTurn }
                let turnProgress = angle / fullTurn
                return RankedPoint(
                    index: index,
                    radius: radius,
                    clockwiseAngle: angle,
                    spiralPosition: radius / safeRadialStep + turnProgress * 0.72
                )
            }
            .sorted { lhs, rhs in
                if abs(lhs.spiralPosition - rhs.spiralPosition) > 0.0001 {
                    return lhs.spiralPosition < rhs.spiralPosition
                }
                if abs(lhs.radius - rhs.radius) > 0.0001 {
                    return lhs.radius < rhs.radius
                }
                if abs(lhs.clockwiseAngle - rhs.clockwiseAngle) > 0.0001 {
                    return lhs.clockwiseAngle < rhs.clockwiseAngle
                }
                return lhs.index < rhs.index
            }
            .map(\.index)
    }
}

struct CanvasViewportOrdering {
    static func indices(
        for points: [CGPoint],
        around center: CGPoint,
        sequence: CanvasPlayCommand.Sequence
    ) -> [Int] {
        switch sequence {
        case .centerOut:
            return CanvasSpiralOrdering.indices(
                for: points,
                around: center,
                radialStep: 160
            )
        case .leftToRight:
            return points.indices.sorted { lhs, rhs in
                if abs(points[lhs].x - points[rhs].x) > 0.5 {
                    return points[lhs].x < points[rhs].x
                }
                return points[lhs].y < points[rhs].y
            }
        case .topToBottom:
            return points.indices.sorted { lhs, rhs in
                if abs(points[lhs].y - points[rhs].y) > 0.5 {
                    return points[lhs].y < points[rhs].y
                }
                return points[lhs].x < points[rhs].x
            }
        }
    }
}

/// Everything the SwiftUI shell needs to preserve one spatial product
/// transition after the UIKit canvas has handed the tap off.
struct ProductTransitionSource {
    let frame: CGRect
    let image: UIImage?
    let imageBackgroundColor: UIColor
    let blurredGrid: UIImage
    let cornerRadius: CGFloat
    let presentExperience: @MainActor () -> Void
    let finishExperiencePresentation: @MainActor () -> Void
    let revealTile: @MainActor () -> Void
}

struct InfiniteProductCanvas: View {
    let products: [CatalogProduct]
    let resultColumnCount: Int?
    let resetToken: Int
    let voiceCommand: CanvasVoiceCommand?
    @Binding var hasInteracted: Bool
    let onSelect: (CatalogProduct, ProductTransitionSource?) -> Void
    let onRequestSimilar: (CatalogProduct) -> Void
    let onRemove: (CatalogProduct) -> Void
    let onMotion: (CanvasOrbMotion) -> Void

    private var effectiveResultColumnCount: Int? {
        CatalogCanvasDensity.resolvedColumnCount(
            configuredColumnCount: resultColumnCount,
            displayedProductCount: products.count
        )
    }

    private var layoutPolicy: CanvasLayoutPolicy {
        CanvasLayoutPolicy(resultColumnCount: effectiveResultColumnCount)
    }

    var body: some View {
        ZStack {
            InfiniteCanvasRepresentable(
                products: products,
                resultColumnCount: effectiveResultColumnCount,
                resetToken: resetToken,
                voiceCommand: voiceCommand,
                hasInteracted: $hasInteracted,
                onSelect: onSelect,
                onRequestSimilar: onRequestSimilar,
                onRemove: onRemove,
                onMotion: onMotion
            )

            viewportWash

            if products.isEmpty {
                ContentUnavailableView.search(text: "No products here yet")
                    .foregroundStyle(ShopDropStyle.muted)
                    .allowsHitTesting(false)
            }
        }
        .background(ShopDropStyle.canvas)
    }

    private var viewportWash: some View {
        ZStack {
            if layoutPolicy.allowsHorizontalPanning {
                LinearGradient(
                    stops: [
                        .init(color: ShopDropStyle.canvas.opacity(0.5), location: 0),
                        .init(color: ShopDropStyle.canvas.opacity(0.25), location: 0.055),
                        .init(color: .clear, location: 0.14),
                        .init(color: .clear, location: 0.86),
                        .init(color: ShopDropStyle.canvas.opacity(0.25), location: 0.945),
                        .init(color: ShopDropStyle.canvas.opacity(0.5), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }

            LinearGradient(
                stops: [
                    .init(color: ShopDropStyle.canvas.opacity(0.5), location: 0),
                    .init(color: ShopDropStyle.canvas.opacity(0.25), location: 0.04),
                    .init(color: .clear, location: 0.105),
                    .init(color: .clear, location: 0.895),
                    .init(color: ShopDropStyle.canvas.opacity(0.25), location: 0.96),
                    .init(color: ShopDropStyle.canvas.opacity(0.5), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Rectangle()
                .strokeBorder(ShopDropStyle.canvas.opacity(0.48), lineWidth: 2)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct InfiniteCanvasRepresentable: UIViewRepresentable {
    let products: [CatalogProduct]
    let resultColumnCount: Int?
    let resetToken: Int
    let voiceCommand: CanvasVoiceCommand?
    @Binding var hasInteracted: Bool
    let onSelect: (CatalogProduct, ProductTransitionSource?) -> Void
    let onRequestSimilar: (CatalogProduct) -> Void
    let onRemove: (CatalogProduct) -> Void
    let onMotion: (CanvasOrbMotion) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> InfiniteCanvasScrollView {
        let canvas = InfiniteCanvasScrollView()
        context.coordinator.connect(to: canvas)
        canvas.setProducts(
            products,
            resultColumnCount: resultColumnCount,
            transitionToken: resetToken
        )
        canvas.lastResetToken = resetToken
        return canvas
    }

    func updateUIView(_ canvas: InfiniteCanvasScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.connect(to: canvas)
        canvas.setProducts(
            products,
            resultColumnCount: resultColumnCount,
            transitionToken: resetToken
        )
        canvas.execute(voiceCommand)

        if canvas.lastResetToken != resetToken {
            canvas.lastResetToken = resetToken
            canvas.recenter(animated: true)
        }
    }

    final class Coordinator {
        var parent: InfiniteCanvasRepresentable

        init(parent: InfiniteCanvasRepresentable) {
            self.parent = parent
        }

        func connect(to canvas: InfiniteCanvasScrollView) {
            canvas.onSelect = { [weak self] product, source in
                self?.parent.onSelect(product, source)
            }
            canvas.onRequestSimilar = { [weak self] product in
                self?.parent.onRequestSimilar(product)
            }
            canvas.onRemove = { [weak self] product in
                self?.parent.onRemove(product)
            }
            canvas.onInteraction = { [weak self] in
                guard let self, !parent.hasInteracted else { return }
                parent.hasInteracted = true
            }
            canvas.onViewportMotion = { [weak self] motion in
                self?.parent.onMotion(motion)
            }
        }
    }
}

private enum ViewportHapticAxis {
    case rows
    case columns
}

private struct ViewportBands {
    var rows = Set<Int>()
    var columns = Set<Int>()
}

private final class InfiniteCanvasScrollView: UIScrollView, UIScrollViewDelegate {
    private enum Layout {
        static let columnCount = 5
        static let rowCount = 16
        static let tileWidth: CGFloat = 150
        static let columnPitch: CGFloat = 160
        static let verticalGap: CGFloat = 10
        static let tileAspectRatio: CGFloat = 1.14
        static let edgePeek: CGFloat = 0.42
        static let singleColumnHorizontalInset: CGFloat = 12
        static let singleColumnGap: CGFloat = 12
        static let detailHorizontalInset: CGFloat = 18
        // The full catalog lands as a dense spatial field on a phone while
        // preserving room to zoom into one piece or pull back to all lanes.
        static let defaultVisibleColumns = CanvasLayoutPolicy.defaultSpatialVisibleColumnCount
        static let masonryPeriodHeight = tileAspectRatio
            * CGFloat(rowCount) * tileWidth
            + verticalGap * CGFloat(rowCount)
        static let patternSize = CGSize(
            width: columnPitch * CGFloat(columnCount),
            height: masonryPeriodHeight
        )

        static func aspectRatio(row: Int, column: Int) -> CGFloat {
            // Every product gets the same portrait viewport, so aspect-fill
            // applies one predictable centered crop across the catalog. Lane
            // phase still keeps the canvas staggered instead of forming rows.
            tileAspectRatio
        }

        static func lanePhase(column: Int) -> CGFloat {
            CGFloat((column * 47) % 127)
        }
    }

    private struct TileSlot {
        let button: CanvasProductButton
        let panelRow: Int
        let panelColumn: Int
        let row: Int
        let column: Int
    }

    private struct SpokenFocusReturnState {
        let center: CGPoint
    }

    private let patternSize = Layout.patternSize
    private let canvasContentView = UIView()
    private let canvasInteractionView = UIView()
    private var tileSlots: [TileSlot] = []
    private var productIDs: [String] = []
    private var requestedProductIDs: [String] = []
    private var requestedResultColumnCount: Int?
    private var activeResultColumnCount = Layout.columnCount
    private var desiredVisibleColumnCount = Layout.defaultVisibleColumns
    private var didConfigureProducts = false
    private var lastProductTransitionToken = 0
    private var productTransitionGeneration = 0
    private var lastVoiceCommandID: UUID?
    private var voiceHighlightGeneration = 0
    private var voiceEntranceGeneration = 0
    private var voiceEntrancePendingAnimationCount = 0
    private var voiceEntranceCameraAnimator: UIViewPropertyAnimator?
    private var voiceEntranceTileAnimators: [UIViewPropertyAnimator] = []
    private var spokenFocusGeneration = 0
    private var spokenFocusAnimator: UIViewPropertyAnimator?
    private var spokenFocusWorkItem: DispatchWorkItem?
    private var spokenFocusReturnState: SpokenFocusReturnState?
    private var isSpokenItemFocusActive = false
    private var canvasPlayGeneration = 0
    private var canvasPlayAnimators: [UIViewPropertyAnimator] = []
    private var canvasPlayButtons: [CanvasProductButton] = []
    private var isCanvasPlayActive = false
    private var showcaseGeneration = 0
    private var showcaseAnimator: UIViewPropertyAnimator?
    private var showcaseReturnCenter: CGPoint?
    private var showcaseReturnsToOverview = false
    private var canvasInteractionAnimator: UIViewPropertyAnimator?
    private var imagePrefetchWorkItem: DispatchWorkItem?
    private var showcaseWorkItem: DispatchWorkItem?
    private var isShowcasing = false
    private var isCanvasInteractionScaled = false
    private var didSetInitialPosition = false
    private var isRecentering = false
    private var isSettlingZoom = false
    private var isPerformingVoiceEntrance = false
    private var hasPendingVoiceEntrance = false
    private var configuredViewportWidth: CGFloat = 0
    private var configuredSingleColumnViewportSize = CGSize.zero
    private var usesSingleColumnTileLayout = false
    private var isConstrainingSingleColumnOffset = false
    private var imagePriorityCoverage = CGRect.null
    private var settledColumnCount = Layout.defaultVisibleColumns
    private var lastMotionOffset = CGPoint.zero
    private var lastMotionTimestamp = CACurrentMediaTime()
    private var smoothedMotionVelocity = CGPoint.zero
    private var orbMotionTarget = CGPoint.zero
    private var orbMotionPosition = CGPoint.zero
    private var orbMotionVelocity = CGPoint.zero
    private var orbElasticTarget = CGPoint.zero
    private var orbElasticPosition = CGPoint.zero
    private var orbElasticVelocity = CGPoint.zero
    private var orbMotionDisplayLink: CADisplayLink?
    private var lastOrbMotionTimestamp = CACurrentMediaTime()
    private let viewportHaptics = ViewportHapticWheel()
    private let canvasPressFeedback = UIImpactFeedbackGenerator(style: .rigid)

    private var layoutPolicy: CanvasLayoutPolicy {
        CanvasLayoutPolicy(resultColumnCount: activeResultColumnCount)
    }

    private var isSingleColumnFeed: Bool {
        layoutPolicy.isSingleColumnFeed
    }

    var onSelect: ((CatalogProduct, ProductTransitionSource?) -> Void)?
    var onRequestSimilar: ((CatalogProduct) -> Void)?
    var onRemove: ((CatalogProduct) -> Void)?
    var onInteraction: (() -> Void)?
    var onViewportMotion: ((CanvasOrbMotion) -> Void)?
    var lastResetToken = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureScrollView()
        buildRepeatingCanvas()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        showcaseWorkItem?.cancel()
        showcaseAnimator?.stopAnimation(true)
        voiceEntranceCameraAnimator?.stopAnimation(true)
        voiceEntranceTileAnimators.forEach { $0.stopAnimation(true) }
        spokenFocusWorkItem?.cancel()
        spokenFocusAnimator?.stopAnimation(true)
        canvasPlayAnimators.forEach { $0.stopAnimation(true) }
        canvasInteractionAnimator?.stopAnimation(true)
        imagePrefetchWorkItem?.cancel()
        orbMotionDisplayLink?.invalidate()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window == nil else { return }
        orbMotionDisplayLink?.invalidate()
        orbMotionDisplayLink = nil
    }

    private func configureScrollView() {
        delegate = self
        backgroundColor = UIColor(ShopDropStyle.canvas)
        contentInsetAdjustmentBehavior = .never
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        alwaysBounceHorizontal = true
        alwaysBounceVertical = true
        bounces = true
        bouncesZoom = true
        isDirectionalLockEnabled = false
        delaysContentTouches = false
        canCancelContentTouches = true
        keyboardDismissMode = .onDrag
        decelerationRate = UIScrollView.DecelerationRate(rawValue: 0.996)
        minimumZoomScale = 0.34
        maximumZoomScale = 1
        panGestureRecognizer.addTarget(self, action: #selector(handleOrbPanGesture(_:)))

        let canvasSize = CGSize(width: patternSize.width * 3, height: patternSize.height * 3)
        canvasContentView.frame = CGRect(origin: .zero, size: canvasSize)
        canvasContentView.backgroundColor = UIColor(ShopDropStyle.canvas)
        canvasInteractionView.frame = canvasContentView.bounds
        canvasInteractionView.backgroundColor = .clear
        canvasInteractionView.isUserInteractionEnabled = false
        canvasInteractionView.accessibilityElementsHidden = true
        canvasContentView.addSubview(canvasInteractionView)
        addSubview(canvasContentView)
        contentSize = canvasSize
        isScrollEnabled = false

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)

        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        twoFingerTap.numberOfTouchesRequired = 2
        if let pinchGestureRecognizer {
            twoFingerTap.require(toFail: pinchGestureRecognizer)
        }
        addGestureRecognizer(twoFingerTap)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let tileLayoutChanged = layoutTilesForCurrentMode()
        configureZoomLimitsIfNeeded()
        guard bounds.width > 0, bounds.height > 0 else { return }

        if didSetInitialPosition {
            if tileLayoutChanged, isSingleColumnFeed {
                zoomScale = 1
                recenter(animated: false)
                prioritizeViewportImageLoads(force: true)
            } else if isSingleColumnFeed {
                constrainSingleColumnOffsetIfNeeded()
            }
            beginVoiceEntranceIfPossible()
            return
        }

        didSetInitialPosition = true
        let targetColumns = min(activeResultColumnCount, desiredVisibleColumnCount)
        zoomScale = scale(forVisibleColumns: targetColumns)
        settledColumnCount = targetColumns
        recenter(animated: false)
        resetMotionTracking()
        prioritizeViewportImageLoads(force: true)
        viewportHaptics.update(visibleBands: visibleBands(), axis: nil, emitsFeedback: false)
        beginVoiceEntranceIfPossible()
    }

    private func beginVoiceEntranceIfPossible() {
        guard hasPendingVoiceEntrance,
              didSetInitialPosition,
              bounds.width > 0,
              bounds.height > 0,
              !productIDs.isEmpty else { return }

        hasPendingVoiceEntrance = false
        cancelVoiceEntranceAnimation(cancelPending: false)
        cancelShowcaseAnimation()
        isScrollEnabled = true
        canvasInteractionView.isUserInteractionEnabled = true
        canvasInteractionView.accessibilityElementsHidden = false

        let targetColumns = max(1, activeResultColumnCount)
        let startingColumns = min(2, targetColumns)
        let targetCenter: CGPoint
        let targetRect: CGRect
        let startingRect: CGRect

        if isSingleColumnFeed {
            targetCenter = CGPoint(
                x: (contentOffset.x + bounds.width / 2) / max(zoomScale, 0.01),
                y: (contentOffset.y + bounds.height / 2) / max(zoomScale, 0.01)
            )
            targetRect = viewportRect(around: targetCenter, visibleColumns: 1)
            startingRect = targetRect
        } else {
            targetCenter = landingCenter(visibleColumns: targetColumns)
            targetRect = viewportRect(
                around: targetCenter,
                visibleColumns: targetColumns
            )
            let startingCenter = CGPoint(
                x: alignedHorizontalCenter(
                    near: targetCenter.x,
                    visibleColumns: startingColumns
                ),
                y: targetCenter.y
            )
            startingRect = viewportRect(
                around: startingCenter,
                visibleColumns: startingColumns
            )
        }

        guard !UIAccessibility.isReduceMotionEnabled else {
            UIView.performWithoutAnimation {
                self.tileSlots.forEach {
                    $0.button.setVoiceEntranceAppearance(
                        alpha: 1,
                        scale: 1,
                        translation: .zero
                    )
                }
                if !self.isSingleColumnFeed {
                    self.zoom(to: targetRect, animated: false)
                }
            }
            settledColumnCount = targetColumns
            prioritizeViewportImageLoads(force: true)
            viewportHaptics.update(
                visibleBands: visibleBands(),
                axis: nil,
                emitsFeedback: false
            )
            return
        }

        let candidateRect = targetRect.insetBy(
            dx: -Layout.tileWidth * 0.16,
            dy: -Layout.tileWidth * 0.16
        )
        let candidates = tileSlots.filter {
            !$0.button.isHidden && $0.button.restingFrame.intersects(candidateRect)
        }
        let orderedIndices = CanvasSpiralOrdering.indices(
            for: candidates.map {
                CGPoint(x: $0.button.restingFrame.midX, y: $0.button.restingFrame.midY)
            },
            around: targetCenter,
            radialStep: Layout.columnPitch * 0.82
        )
        let orderedSlots = orderedIndices.map { candidates[$0] }

        voiceEntranceGeneration += 1
        let generation = voiceEntranceGeneration
        isPerformingVoiceEntrance = true
        isSettlingZoom = startingColumns != targetColumns
        settledColumnCount = targetColumns

        UIView.performWithoutAnimation {
            self.tileSlots.forEach {
                $0.button.setVoiceEntranceAppearance(
                    alpha: 0,
                    scale: 0.58,
                    translation: .zero
                )
            }
            orderedSlots.forEach { slot in
                let tileCenter = CGPoint(
                    x: slot.button.restingFrame.midX,
                    y: slot.button.restingFrame.midY
                )
                slot.button.prepareForVoiceEntrance()
                slot.button.setVoiceEntranceAppearance(
                    alpha: 0,
                    scale: 0.58,
                    translation: voiceEntranceOffset(
                        from: tileCenter,
                        toward: targetCenter
                    )
                )
            }
            if !self.isSingleColumnFeed {
                self.zoom(to: startingRect, animated: false)
            }
            self.layoutIfNeeded()
        }

        // Load the eventual full field first. Intermediate zoom callbacks are
        // ignored until the camera lands so they cannot steal network priority.
        prioritizeViewportImageLoads(force: true, viewport: targetRect)
        viewportHaptics.update(visibleBands: visibleBands(), axis: nil, emitsFeedback: false)

        voiceEntrancePendingAnimationCount = orderedSlots.count
        if startingColumns != targetColumns {
            voiceEntrancePendingAnimationCount += 1
            let cameraAnimator = UIViewPropertyAnimator(
                duration: 2.05,
                dampingRatio: 0.86
            ) {
                self.zoom(to: targetRect, animated: false)
            }
            cameraAnimator.addCompletion { [weak self] _ in
                self?.voiceEntranceAnimationCompleted(generation: generation)
            }
            voiceEntranceCameraAnimator = cameraAnimator
            cameraAnimator.startAnimation(afterDelay: 0.08)
        }

        let lastIndex = max(1, orderedSlots.count - 1)
        let staggerWindow = min(1.65, Double(lastIndex) * 0.062)
        let stagger = staggerWindow / Double(lastIndex)
        for (index, slot) in orderedSlots.enumerated() {
            let animator = UIViewPropertyAnimator(
                duration: 0.82,
                dampingRatio: 0.66
            ) {
                slot.button.setVoiceEntranceAppearance(
                    alpha: 1,
                    scale: 1,
                    translation: .zero
                )
            }
            animator.addCompletion { [weak self] _ in
                self?.voiceEntranceAnimationCompleted(generation: generation)
            }
            voiceEntranceTileAnimators.append(animator)
            animator.startAnimation(afterDelay: Double(index) * stagger)
        }

        if voiceEntrancePendingAnimationCount == 0 {
            finishVoiceEntrance(generation: generation)
        }
    }

    private func viewportRect(
        around center: CGPoint,
        visibleColumns: Int
    ) -> CGRect {
        let targetScale = scale(forVisibleColumns: visibleColumns)
        let size = CGSize(
            width: bounds.width / targetScale,
            height: bounds.height / targetScale
        )
        return CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func voiceEntranceOffset(
        from tileCenter: CGPoint,
        toward viewportCenter: CGPoint
    ) -> CGPoint {
        let outwardX = tileCenter.x - viewportCenter.x
        let outwardY = tileCenter.y - viewportCenter.y
        let distance = max(1, hypot(outwardX, outwardY))
        let radialPull = min(46, max(16, distance * 0.075))
        let curl = min(14, radialPull * 0.34)
        let unitX = outwardX / distance
        let unitY = outwardY / distance
        return CGPoint(
            x: -unitX * radialPull - unitY * curl,
            y: -unitY * radialPull + unitX * curl
        )
    }

    private func voiceEntranceAnimationCompleted(generation: Int) {
        guard generation == voiceEntranceGeneration,
              isPerformingVoiceEntrance else { return }
        voiceEntrancePendingAnimationCount = max(
            0,
            voiceEntrancePendingAnimationCount - 1
        )
        guard voiceEntrancePendingAnimationCount == 0 else { return }
        finishVoiceEntrance(generation: generation)
    }

    private func finishVoiceEntrance(generation: Int) {
        guard generation == voiceEntranceGeneration else { return }
        UIView.performWithoutAnimation {
            self.tileSlots.forEach {
                $0.button.setVoiceEntranceAppearance(
                    alpha: 1,
                    scale: 1,
                    translation: .zero
                )
            }
        }
        voiceEntranceCameraAnimator = nil
        voiceEntranceTileAnimators.removeAll()
        voiceEntrancePendingAnimationCount = 0
        isPerformingVoiceEntrance = false
        isSettlingZoom = false
        recenterIfNeeded()
        prioritizeViewportImageLoads(force: true)
        settleTileDynamics()
        resetMotionTracking()
    }

    private func cancelVoiceEntranceAnimation(cancelPending: Bool = true) {
        if cancelPending {
            hasPendingVoiceEntrance = false
        }
        guard isPerformingVoiceEntrance
                || voiceEntranceCameraAnimator != nil
                || !voiceEntranceTileAnimators.isEmpty else { return }

        voiceEntranceGeneration += 1
        voiceEntrancePendingAnimationCount = 0
        if let voiceEntranceCameraAnimator {
            voiceEntranceCameraAnimator.stopAnimation(false)
            voiceEntranceCameraAnimator.finishAnimation(at: .current)
        }
        self.voiceEntranceCameraAnimator = nil
        for animator in voiceEntranceTileAnimators {
            animator.stopAnimation(false)
            animator.finishAnimation(at: .current)
        }
        voiceEntranceTileAnimators.removeAll()
        UIView.performWithoutAnimation {
            self.tileSlots.forEach {
                $0.button.setVoiceEntranceAppearance(
                    alpha: 1,
                    scale: 1,
                    translation: .zero
                )
            }
        }
        isPerformingVoiceEntrance = false
        isSettlingZoom = false
        settledColumnCount = nearestVisibleColumnCount(to: zoomScale)
        restoreInteractiveZoomLimitsIfPossible()
        prioritizeViewportImageLoads(force: true)
        settleTileDynamics()
        resetMotionTracking()
    }

    override func touchesShouldCancel(in view: UIView) -> Bool {
        if view is UIControl {
            return true
        }
        return super.touchesShouldCancel(in: view)
    }

    @discardableResult
    private func layoutTilesForCurrentMode(force: Bool = false) -> Bool {
        configureInteractionPolicy()
        guard bounds.width > 0, bounds.height > 0 else { return false }

        let viewportSize = bounds.size
        let modeChanged = usesSingleColumnTileLayout != isSingleColumnFeed
        let feedSizeChanged = isSingleColumnFeed
            && abs(configuredSingleColumnViewportSize.width - viewportSize.width) > 0.5
        guard force || modeChanged || feedSizeChanged else { return false }

        usesSingleColumnTileLayout = isSingleColumnFeed
        configuredSingleColumnViewportSize = isSingleColumnFeed ? viewportSize : .zero

        let feedWidth = max(1, viewportSize.width - Layout.singleColumnHorizontalInset * 2)
        let feedHeight = feedWidth * Layout.tileAspectRatio
        let feedCenterX = patternSize.width * 1.5
        let feedStartY = patternSize.height + Layout.singleColumnGap

        for slot in tileSlots {
            let frame: CGRect
            if isSingleColumnFeed, isCentralFeedSlot(slot) {
                frame = CGRect(
                    x: feedCenterX - feedWidth / 2,
                    y: feedStartY + CGFloat(slot.row) * (feedHeight + Layout.singleColumnGap),
                    width: feedWidth,
                    height: feedHeight
                )
            } else {
                frame = standardFrame(
                    panelRow: slot.panelRow,
                    panelColumn: slot.panelColumn,
                    row: slot.row,
                    column: slot.column
                )
            }
            slot.button.bounds = CGRect(origin: .zero, size: frame.size)
            slot.button.center = CGPoint(x: frame.midX, y: frame.midY)
            slot.button.setNeedsLayout()
        }
        return true
    }

    private func configureInteractionPolicy() {
        alwaysBounceHorizontal = layoutPolicy.allowsHorizontalPanning
        bouncesZoom = layoutPolicy.allowsZoom
        isDirectionalLockEnabled = isSingleColumnFeed
        pinchGestureRecognizer?.isEnabled = layoutPolicy.allowsZoom
        decelerationRate = isSingleColumnFeed
            ? .fast
            : UIScrollView.DecelerationRate(rawValue: 0.996)
    }

    private func isCentralFeedSlot(_ slot: TileSlot) -> Bool {
        slot.panelRow == 1
            && slot.panelColumn == 1
            && slot.column == Layout.columnCount / 2
    }

    private func standardFrame(
        panelRow: Int,
        panelColumn: Int,
        row: Int,
        column: Int
    ) -> CGRect {
        let panelOrigin = CGPoint(
            x: CGFloat(panelColumn) * patternSize.width,
            y: CGFloat(panelRow) * patternSize.height
        )
        let width = Layout.tileWidth
        let height = width * Layout.aspectRatio(row: row, column: column)
        let center = CGPoint(
            x: panelOrigin.x + (CGFloat(column) + 0.5) * Layout.columnPitch,
            y: panelOrigin.y
                + Layout.lanePhase(column: column)
                + CGFloat(row) * (height + Layout.verticalGap)
                + height / 2
        )
        return CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
    }

    func setProducts(
        _ products: [CatalogProduct],
        resultColumnCount: Int?,
        transitionToken: Int
    ) {
        let incomingIDs = products.map(\.id)
        let previousIDs = requestedProductIDs
        let normalizedColumnCount = CatalogCanvasDensity.resolvedColumnCount(
            configuredColumnCount: resultColumnCount,
            displayedProductCount: products.count
        )
        let contentChanged = incomingIDs != requestedProductIDs
        let densityChanged = normalizedColumnCount != requestedResultColumnCount
        let transitionRequested = transitionToken != lastProductTransitionToken
        guard contentChanged || densityChanged || transitionRequested else { return }
        requestedProductIDs = incomingIDs
        requestedResultColumnCount = normalizedColumnCount
        lastProductTransitionToken = transitionToken

        guard didConfigureProducts else {
            didConfigureProducts = true
            applyProducts(products, resultColumnCount: normalizedColumnCount)
            return
        }

        productTransitionGeneration += 1
        let generation = productTransitionGeneration
        let removedIDs = Set(previousIDs).subtracting(incomingIDs)
        let removalOnly = contentChanged
            && !removedIDs.isEmpty
            && Set(incomingIDs).isSubset(of: Set(previousIDs))
        let visible = visibleButtons(extraMargin: 80)
        let exitingButtons = removalOnly
            ? visible.filter { button in
                button.product.map { removedIDs.contains($0.id) } ?? false
            }
            : visible

        let replace = { [weak self] in
            guard let self, generation == self.productTransitionGeneration else { return }
            self.applyProducts(products, resultColumnCount: normalizedColumnCount)
            if contentChanged {
                self.playViewportCascade(
                    sequence: removalOnly ? .topToBottom : .centerOut,
                    productIDs: []
                )
            }
        }

        guard !UIAccessibility.isReduceMotionEnabled, !exitingButtons.isEmpty else {
            replace()
            return
        }

        UIView.animate(
            withDuration: 0.22,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseIn]
        ) {
            exitingButtons.forEach { $0.setQueryAppearance(alpha: 0, scale: 0.94) }
        } completion: { _ in
            replace()
        }
    }

    func execute(_ command: CanvasVoiceCommand?) {
        guard let command, command.id != lastVoiceCommandID else { return }
        lastVoiceCommandID = command.id
        switch command.action {
        case .voiceEntrance:
            hasPendingVoiceEntrance = true
            setNeedsLayout()
            beginVoiceEntranceIfPossible()
        case .pan(let direction, let distance):
            cancelShowcaseForInteraction()
            panCanvas(direction: direction, distance: distance)
        case .zoom(let direction, let amount):
            cancelShowcaseForInteraction()
            zoomCanvas(direction: direction, amount: amount)
        case .highlight(let productIDs):
            beginSpokenItemFocus(productIDs: productIDs, showsPointer: false)
        case .point(let productIDs):
            beginSpokenItemFocus(productIDs: productIDs, showsPointer: true)
        case .endSpokenItemFocus:
            endSpokenItemFocus()
        case .showcase(let resultCount):
            showcaseProducts(resultCount: resultCount)
        case .opening(let choreography):
            showcaseOpening(choreography)
        case .play(let playCommand):
            playCanvas(playCommand)
        }
    }

    private func applyProducts(_ products: [CatalogProduct], resultColumnCount: Int?) {
        cancelVoiceEntranceAnimation()
        cancelSpokenItemFocusForContentChange()
        cancelCanvasPlayAnimation(animated: false)
        cancelShowcaseAnimation()
        imagePrefetchWorkItem?.cancel()
        imagePrefetchWorkItem = nil
        imagePriorityCoverage = .null
        productIDs = products.map(\.id)
        activeResultColumnCount = resultColumnCount ?? Layout.columnCount
        desiredVisibleColumnCount = resultColumnCount ?? Layout.defaultVisibleColumns
        layoutTilesForCurrentMode(force: true)
        let firstActiveColumn = (Layout.columnCount - activeResultColumnCount + 1) / 2
        let activeColumns = firstActiveColumn..<(firstActiveColumn + activeResultColumnCount)

        for slot in tileSlots {
            slot.button.setVoiceHighlighted(false)
            slot.button.setVoicePointed(false)
            if isSingleColumnFeed, !isCentralFeedSlot(slot) {
                slot.button.isHidden = true
                continue
            }
            guard activeColumns.contains(slot.column) else {
                slot.button.isHidden = true
                continue
            }
            let columnRank = slot.column - firstActiveColumn
            guard let productIndex = CanvasProductPlacement.productIndex(
                row: slot.row,
                column: columnRank,
                columnCount: activeResultColumnCount,
                productCount: products.count,
                repeatsSpatially: !isSingleColumnFeed
            ) else {
                slot.button.isHidden = true
                continue
            }
            let product = products[productIndex]
            slot.button.configure(with: product)
            slot.button.isHidden = false
        }

        guard didSetInitialPosition else { return }
        configureZoomLimitsIfNeeded(force: true)
        if isSingleColumnFeed {
            zoomScale = 1
            recenter(animated: false)
            prioritizeViewportImageLoads(force: true)
            return
        }
        settleZoom(
            toVisibleColumns: desiredVisibleColumnCount,
            around: landingCenter(visibleColumns: desiredVisibleColumnCount)
        )
        prioritizeViewportImageLoads(force: true)
    }

    private func visibleButtons(extraMargin: CGFloat) -> [CanvasProductButton] {
        guard zoomScale > 0 else { return tileSlots.map(\.button) }
        let viewport = CGRect(
            x: contentOffset.x / zoomScale - extraMargin,
            y: contentOffset.y / zoomScale - extraMargin,
            width: bounds.width / zoomScale + extraMargin * 2,
            height: bounds.height / zoomScale + extraMargin * 2
        )
        return tileSlots.compactMap { slot in
            !slot.button.isHidden && slot.button.restingFrame.intersects(viewport)
                ? slot.button
                : nil
        }
    }

    private func playCanvas(_ command: CanvasPlayCommand) {
        cancelVoiceEntranceAnimation()
        cancelSpokenItemFocusForContentChange()
        cancelShowcaseAnimation()

        switch command.action {
        case .pile:
            playProductPile(productIDs: command.productIDs)
        case .cascade:
            playViewportCascade(
                sequence: command.sequence,
                productIDs: command.productIDs
            )
        case .spotlight:
            playProductSpotlight(productIDs: command.productIDs)
        case .reset:
            cancelCanvasPlayAnimation(animated: true)
        case .remove:
            // Product removal is applied to the source collection by the
            // controller. setProducts(_:...) owns the exit and reflow motion.
            break
        }
    }

    private func playProductPile(productIDs: [String]) {
        cancelCanvasPlayAnimation(animated: false)
        guard let viewportCenter = currentViewportCenter() else { return }
        let targets = canvasPlayTargets(productIDs: productIDs, maximumCount: 7)
        guard !targets.isEmpty else { return }
        if targets.count == 1 {
            playProductSpotlight(productIDs: targets.compactMap { $0.product?.id })
            return
        }

        let visible = visibleButtons(extraMargin: 8)
        let targetIdentities = Set(targets.map(ObjectIdentifier.init))
        let visibleIdentities = Set(visible.map(ObjectIdentifier.init))
        canvasPlayGeneration += 1
        let generation = canvasPlayGeneration
        isCanvasPlayActive = true
        canvasPlayButtons = visible + targets.filter {
            !visibleIdentities.contains(ObjectIdentifier($0))
        }
        canvasPressFeedback.prepare()
        canvasPressFeedback.impactOccurred(intensity: 1)

        let visualScale = min(
            1.9,
            max(1.04, bounds.width * 0.48 / max(1, targets[0].bounds.width * zoomScale))
        )
        for button in visible where !targetIdentities.contains(ObjectIdentifier(button)) {
            let changes = {
                button.setCanvasPlayAppearance(alpha: 0.24, transform: .identity, zPosition: 0)
            }
            guard !UIAccessibility.isReduceMotionEnabled else {
                changes()
                continue
            }
            let animator = UIViewPropertyAnimator(duration: 0.28, curve: .easeOut) {
                changes()
            }
            canvasPlayAnimators.append(animator)
            animator.startAnimation()
        }

        let middleIndex = CGFloat(targets.count - 1) / 2
        for (index, button) in targets.enumerated() {
            button.loadImageIfNeeded(priority: .userInitiated)
            canvasInteractionView.bringSubviewToFront(button)
            let rank = CGFloat(index) - middleIndex
            let screenOffset = CGPoint(x: rank * 4.5, y: rank * 5.5)
            let targetCenter = CGPoint(
                x: viewportCenter.x + screenOffset.x / max(zoomScale, 0.01),
                y: viewportCenter.y + screenOffset.y / max(zoomScale, 0.01)
            )
            let translation = CGPoint(
                x: targetCenter.x - button.restingFrame.midX,
                y: targetCenter.y - button.restingFrame.midY
            )
            let rotation = rank * 0.035
            let transform = CGAffineTransform(
                translationX: translation.x,
                y: translation.y
            )
            .rotated(by: rotation)
            .scaledBy(x: visualScale, y: visualScale)
            let changes = {
                button.setCanvasPlayAppearance(
                    alpha: 1,
                    transform: transform,
                    zPosition: CGFloat(200 + index)
                )
            }
            guard !UIAccessibility.isReduceMotionEnabled else {
                changes()
                if index == targets.count - 1 {
                    UIAccessibility.post(notification: .layoutChanged, argument: button)
                }
                continue
            }
            let animator = UIViewPropertyAnimator(duration: 0.64, dampingRatio: 0.74) {
                changes()
            }
            animator.addCompletion { [weak self] position in
                guard position == .end,
                      self?.canvasPlayGeneration == generation else { return }
                if index == targets.count - 1 {
                    UIAccessibility.post(notification: .layoutChanged, argument: button)
                }
            }
            canvasPlayAnimators.append(animator)
            animator.startAnimation(afterDelay: Double(index) * 0.045)
        }
    }

    private func playProductSpotlight(productIDs: [String]) {
        cancelCanvasPlayAnimation(animated: false)
        guard let viewportCenter = currentViewportCenter(),
              let button = canvasPlayTargets(
                  productIDs: productIDs,
                  maximumCount: 1
              ).first else { return }

        let visible = visibleButtons(extraMargin: 8)
        let isVisible = visible.contains { $0 === button }
        canvasPlayGeneration += 1
        let generation = canvasPlayGeneration
        isCanvasPlayActive = true
        canvasPlayButtons = isVisible ? visible : visible + [button]
        canvasInteractionView.bringSubviewToFront(button)
        canvasPressFeedback.prepare()
        canvasPressFeedback.impactOccurred(intensity: 1)
        button.loadImageIfNeeded(priority: .userInitiated)

        for candidate in visible where candidate !== button {
            let changes = {
                candidate.setCanvasPlayAppearance(
                    alpha: 0.2,
                    transform: CGAffineTransform(scaleX: 0.96, y: 0.96),
                    zPosition: 0
                )
            }
            guard !UIAccessibility.isReduceMotionEnabled else {
                changes()
                continue
            }
            let animator = UIViewPropertyAnimator(duration: 0.3, curve: .easeOut) {
                changes()
            }
            canvasPlayAnimators.append(animator)
            animator.startAnimation()
        }

        let targetWidth = min(bounds.width * 0.76, 330)
        let visualScale = targetWidth / max(1, button.bounds.width * zoomScale)
        let translation = CGPoint(
            x: viewportCenter.x - button.restingFrame.midX,
            y: viewportCenter.y - button.restingFrame.midY
        )
        let transform = CGAffineTransform(
            translationX: translation.x,
            y: translation.y
        ).scaledBy(x: visualScale, y: visualScale)
        button.setCanvasSpotlighted(true)
        button.playCanvasFlip(afterDelay: 0.04)
        let changes = {
            button.setCanvasPlayAppearance(
                alpha: 1,
                transform: transform,
                zPosition: 2_000
            )
        }
        guard !UIAccessibility.isReduceMotionEnabled else {
            changes()
            UIAccessibility.post(notification: .layoutChanged, argument: button)
            return
        }
        let animator = UIViewPropertyAnimator(duration: 0.7, dampingRatio: 0.78) {
            changes()
        }
        animator.addCompletion { [weak self] position in
            guard position == .end,
                  self?.canvasPlayGeneration == generation else { return }
            UIAccessibility.post(notification: .layoutChanged, argument: button)
        }
        canvasPlayAnimators.append(animator)
        animator.startAnimation()
    }

    private func playViewportCascade(
        sequence: CanvasPlayCommand.Sequence,
        productIDs: [String]
    ) {
        cancelCanvasPlayAnimation(animated: false)
        guard !UIAccessibility.isReduceMotionEnabled,
              let viewportCenter = currentViewportCenter() else {
            visibleButtons(extraMargin: 8).forEach { $0.resetCanvasPlayAppearance() }
            return
        }

        let requestedIDs = Set(productIDs)
        let candidates = visibleButtons(extraMargin: 8).filter { button in
            requestedIDs.isEmpty
                || button.product.map { requestedIDs.contains($0.id) } == true
        }
        guard !candidates.isEmpty else { return }
        let indices = CanvasViewportOrdering.indices(
            for: candidates.map {
                CGPoint(x: $0.restingFrame.midX, y: $0.restingFrame.midY)
            },
            around: viewportCenter,
            sequence: sequence
        )
        let ordered = indices.map { candidates[$0] }
        canvasPlayGeneration += 1
        let generation = canvasPlayGeneration
        isCanvasPlayActive = true
        canvasPlayButtons = ordered
        canvasPressFeedback.prepare()
        canvasPressFeedback.impactOccurred(intensity: 0.72)

        UIView.performWithoutAnimation {
            for button in ordered {
                let offset: CGPoint = switch sequence {
                case .centerOut:
                    CGPoint(
                        x: (viewportCenter.x - button.restingFrame.midX) * 0.1,
                        y: (viewportCenter.y - button.restingFrame.midY) * 0.1
                    )
                case .leftToRight:
                    CGPoint(x: -26 / max(self.zoomScale, 0.01), y: 0)
                case .topToBottom:
                    CGPoint(x: 0, y: 24 / max(self.zoomScale, 0.01))
                }
                button.setCanvasPlayAppearance(
                    alpha: 0,
                    transform: CGAffineTransform(
                        translationX: offset.x,
                        y: offset.y
                    ).scaledBy(x: 0.86, y: 0.86),
                    zPosition: 0
                )
            }
        }

        let lastIndex = max(1, ordered.count - 1)
        let stagger = min(0.055, 0.64 / Double(lastIndex))
        for (index, button) in ordered.enumerated() {
            let animator = UIViewPropertyAnimator(duration: 0.52, dampingRatio: 0.76) {
                button.resetCanvasPlayAppearance()
            }
            animator.addCompletion { [weak self] position in
                guard let self,
                      position == .end,
                      self.canvasPlayGeneration == generation,
                      index == ordered.count - 1 else { return }
                self.canvasPlayAnimators.removeAll()
                self.canvasPlayButtons.removeAll()
                self.isCanvasPlayActive = false
            }
            canvasPlayAnimators.append(animator)
            animator.startAnimation(afterDelay: Double(index) * stagger)
        }
    }

    private func canvasPlayTargets(
        productIDs: [String],
        maximumCount: Int
    ) -> [CanvasProductButton] {
        guard let viewportCenter = currentViewportCenter() else { return [] }
        let visible = visibleButtons(extraMargin: 24)
        let orderedIDs = productIDs.reduce(into: [String]()) { result, productID in
            guard !result.contains(productID) else { return }
            result.append(productID)
        }

        if orderedIDs.isEmpty {
            var seen = Set<String>()
            return visible
                .sorted {
                    distance(from: $0.restingFrame, to: viewportCenter)
                        < distance(from: $1.restingFrame, to: viewportCenter)
                }
                .filter { button in
                    guard let id = button.product?.id else { return false }
                    return seen.insert(id).inserted
                }
                .prefix(maximumCount)
                .map { $0 }
        }

        let active = tileSlots.compactMap { slot -> CanvasProductButton? in
            guard !slot.button.isHidden, slot.button.product != nil else { return nil }
            return slot.button
        }
        return orderedIDs.prefix(maximumCount).compactMap { productID in
            active
                .filter { $0.product?.id == productID }
                .min {
                    distance(from: $0.restingFrame, to: viewportCenter)
                        < distance(from: $1.restingFrame, to: viewportCenter)
                }
        }
    }

    private func cancelCanvasPlayAnimation(animated: Bool) {
        guard isCanvasPlayActive
                || !canvasPlayAnimators.isEmpty
                || !canvasPlayButtons.isEmpty else { return }
        canvasPlayGeneration += 1
        canvasPlayAnimators.forEach {
            $0.stopAnimation(false)
            $0.finishAnimation(at: .current)
        }
        canvasPlayAnimators.removeAll()
        let buttons = canvasPlayButtons
        canvasPlayButtons.removeAll()
        isCanvasPlayActive = false

        let reset = {
            buttons.forEach {
                $0.setCanvasSpotlighted(false)
                $0.resetCanvasPlayAppearance()
            }
        }
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            UIView.performWithoutAnimation(reset)
            return
        }
        UIView.animate(
            withDuration: 0.46,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.24,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: reset
        )
    }

    private func prioritizeViewportImageLoads(
        force: Bool = false,
        viewport requestedViewport: CGRect? = nil
    ) {
        guard didSetInitialPosition, zoomScale > 0, bounds.width > 0, bounds.height > 0 else {
            return
        }
        guard force || !isPerformingVoiceEntrance else { return }

        let viewport = requestedViewport ?? CGRect(
            x: contentOffset.x / zoomScale,
            y: contentOffset.y / zoomScale,
            width: bounds.width / zoomScale,
            height: bounds.height / zoomScale
        )
        let viewportCenter = CGPoint(x: viewport.midX, y: viewport.midY)
        let visibleSlots = tileSlots
            .filter { !$0.button.isHidden && $0.button.restingFrame.intersects(viewport) }
            .sorted { lhs, rhs in
                let left = lhs.button.restingFrame
                let right = rhs.button.restingFrame
                return hypot(left.midX - viewportCenter.x, left.midY - viewportCenter.y)
                    < hypot(right.midX - viewportCenter.x, right.midY - viewportCenter.y)
            }
        visibleSlots.forEach { $0.button.loadImageIfNeeded(priority: .userInitiated) }

        // Always revisit the exact visible set. Besides catching transient
        // failures, this lets a tile promote an in-flight nearby request as
        // soon as it crosses into the viewport. Coverage only throttles the
        // lower-priority look-ahead work.
        guard force || !imagePriorityCoverage.contains(viewport) else { return }
        // The grid is hidden while voice connects, so use that time to warm a
        // full movement radius around the landing view. A person can now flick
        // roughly one screen in any direction without outrunning image loads.
        let nearbyRect = viewport.insetBy(
            dx: -max(280, viewport.width * 0.75),
            dy: -max(420, viewport.height * 0.9)
        )
        imagePriorityCoverage = nearbyRect
        let visibleButtonIDs = Set(visibleSlots.map { ObjectIdentifier($0.button) })
        let nearbyButtons = tileSlots.compactMap { slot -> CanvasProductButton? in
            guard !slot.button.isHidden,
                  !visibleButtonIDs.contains(ObjectIdentifier(slot.button)),
                  slot.button.restingFrame.intersects(nearbyRect) else { return nil }
            return slot.button
        }
        .sorted { lhs, rhs in
            distance(from: lhs.restingFrame, to: viewportCenter)
                < distance(from: rhs.restingFrame, to: viewportCenter)
        }
        scheduleNearbyImageLoads(
            after: visibleSlots.map(\.button),
            nearbyButtons: nearbyButtons
        )
    }

    /// Network task priority alone does not stop URLSession from starting
    /// utility requests alongside user-initiated ones. Hold all offscreen
    /// work until every current viewport tile has resolved (successfully or
    /// to its placeholder), so the first available connections always belong
    /// to what the user can see.
    private func scheduleNearbyImageLoads(
        after visibleButtons: [CanvasProductButton],
        nearbyButtons: [CanvasProductButton],
        attempt: Int = 0
    ) {
        imagePrefetchWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.imagePrefetchWorkItem = nil
            guard visibleButtons.allSatisfy(\.hasResolvedImage) || attempt >= 2 else {
                self.scheduleNearbyImageLoads(
                    after: visibleButtons,
                    nearbyButtons: nearbyButtons,
                    attempt: attempt + 1
                )
                return
            }
            nearbyButtons.forEach { $0.loadImageIfNeeded(priority: .utility) }
        }
        imagePrefetchWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }

    private func panCanvas(
        direction: CanvasVoiceCommand.PanDirection,
        distance: CanvasVoiceCommand.PanDistance
    ) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        if isSingleColumnFeed && (direction == .left || direction == .right) {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }
        onInteraction?()

        let fraction: CGFloat = switch distance {
        case .small: 0.42
        case .medium: 0.78
        case .large: 1.24
        }
        var target = contentOffset
        var visibleMotion = CGPoint.zero
        switch direction {
        case .left:
            target.x += bounds.width * fraction
            visibleMotion.x = -0.82
        case .right:
            target.x -= bounds.width * fraction
            visibleMotion.x = 0.82
        case .up:
            target.y += bounds.height * fraction
            visibleMotion.y = -0.74
        case .down:
            target.y -= bounds.height * fraction
            visibleMotion.y = 0.74
        }

        if !isSingleColumnFeed && (direction == .left || direction == .right) {
            let columns = nearestVisibleColumnCount(to: zoomScale)
            let centerX = (target.x + bounds.width / 2) / max(zoomScale, 0.01)
            target.x = alignedHorizontalCenter(near: centerX, visibleColumns: columns)
                * zoomScale - bounds.width / 2
        }
        if isSingleColumnFeed {
            target = constrainedSingleColumnOffset(target)
            visibleMotion.x = 0
        }

        setOrbMotionTarget(visibleMotion, elasticTarget: visibleMotion)
        let duration = UIAccessibility.isReduceMotionEnabled ? 0 : 0.58 + Double(fraction) * 0.14
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.92,
            initialSpringVelocity: 0.08,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.contentOffset = target
        } completion: { [weak self] _ in
            guard let self else { return }
            self.setOrbMotionTarget(.zero)
            self.recenterIfNeeded()
            self.resetMotionTracking()
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func zoomCanvas(
        direction: CanvasVoiceCommand.ZoomDirection,
        amount: CanvasVoiceCommand.ZoomAmount
    ) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        guard layoutPolicy.allowsZoom else {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }
        onInteraction?()

        if CanvasVoiceCommand.requestsSingleProductFocus(
            direction: direction,
            amount: amount
        ), let button = nearestVisibleProductButton() {
            focusOnSingleProduct(button)
            return
        }

        let currentColumns = nearestVisibleColumnCount(to: zoomScale)
        let targetColumns: Int
        switch (direction, amount) {
        case (.closer, .large):
            targetColumns = 1
        case (.farther, .large):
            targetColumns = activeResultColumnCount
        case (.closer, _):
            targetColumns = max(1, currentColumns - amount.columnDelta)
        case (.farther, _):
            targetColumns = min(activeResultColumnCount, currentColumns + amount.columnDelta)
        }

        guard targetColumns != currentColumns else {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }
        settleZoom(toVisibleColumns: targetColumns)
    }

    private func beginSpokenItemFocus(
        productIDs requestedProductIDs: [String],
        showsPointer: Bool
    ) {
        guard bounds.width > 0, bounds.height > 0, zoomScale > 0 else { return }
        var seen = Set<String>()
        let availableProductIDs = Set(productIDs)
        let focusedProductIDs = requestedProductIDs.filter {
            availableProductIDs.contains($0) && seen.insert($0).inserted
        }
        guard !focusedProductIDs.isEmpty else {
            clearVoiceAttentionImmediately()
            return
        }

        cancelVoiceEntranceAnimation()
        cancelShowcaseAnimation()
        cancelCanvasPlayAnimation(animated: true)
        captureSpokenFocusReturnStateIfNeeded()
        spokenFocusGeneration += 1
        let generation = spokenFocusGeneration
        stopSpokenFocusMotion()
        isSpokenItemFocusActive = true
        focusSpokenItem(
            at: 0,
            productIDs: focusedProductIDs,
            showsPointer: showsPointer,
            generation: generation
        )
    }

    private func focusSpokenItem(
        at index: Int,
        productIDs: [String],
        showsPointer: Bool,
        generation: Int
    ) {
        guard generation == spokenFocusGeneration,
              isSpokenItemFocusActive,
              productIDs.indices.contains(index),
              let viewportCenter = currentViewportCenter() else { return }
        let productID = productIDs[index]
        let matchingSlots = tileSlots.filter {
            !$0.button.isHidden && $0.button.product?.id == productID
        }
        guard let target = matchingSlots.min(by: {
            distance(from: $0.button.restingFrame, to: viewportCenter)
                < distance(from: $1.button.restingFrame, to: viewportCenter)
        }) else { return }

        voiceHighlightGeneration += 1
        for button in tileSlots.map(\.button) {
            let isTarget = !button.isHidden && button.product?.id == productID
            button.setVoiceHighlighted(isTarget)
            button.setVoicePointed(isTarget && showsPointer)
        }

        target.button.loadImageIfNeeded(priority: .userInitiated)
        let frame = target.button.restingFrame
        // One focused lane remains centered while the neighboring lanes keep
        // their edge peeks, preserving the spatial canvas around the subject.
        let targetScale = scale(forVisibleColumns: 1)
        maximumZoomScale = max(maximumZoomScale, targetScale)
        settledColumnCount = 1
        let rectSize = CGSize(
            width: bounds.width / targetScale,
            height: bounds.height / targetScale
        )
        let targetRect = CGRect(
            x: frame.midX - rectSize.width / 2,
            y: frame.midY - rectSize.height / 2,
            width: rectSize.width,
            height: rectSize.height
        )
        prioritizeViewportImageLoads(force: true, viewport: targetRect)
        isSettlingZoom = true

        let completion = { [weak self] in
            guard let self,
                  generation == self.spokenFocusGeneration,
                  self.isSpokenItemFocusActive else { return }
            self.spokenFocusAnimator = nil
            self.isSettlingZoom = false
            self.recenterIfNeeded()
            self.settleTileDynamics()
            self.resetMotionTracking()
            UIAccessibility.post(notification: .layoutChanged, argument: target.button)

            let nextIndex = index + 1
            guard productIDs.indices.contains(nextIndex) else { return }
            let work = DispatchWorkItem { [weak self] in
                self?.focusSpokenItem(
                    at: nextIndex,
                    productIDs: productIDs,
                    showsPointer: showsPointer,
                    generation: generation
                )
            }
            self.spokenFocusWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.45, execute: work)
        }

        let changes = { self.zoom(to: targetRect, animated: false) }
        guard !UIAccessibility.isReduceMotionEnabled else {
            changes()
            completion()
            return
        }

        let animator = UIViewPropertyAnimator(duration: 0.72, dampingRatio: 0.9)
        animator.addAnimations(changes)
        animator.addCompletion { [weak self] position in
            guard position == .end else { return }
            self?.spokenFocusWorkItem = nil
            completion()
        }
        spokenFocusAnimator = animator
        animator.startAnimation()
    }

    private func endSpokenItemFocus() {
        guard isSpokenItemFocusActive
                || spokenFocusReturnState != nil
                || spokenFocusAnimator != nil
                || spokenFocusWorkItem != nil else { return }

        let returnCenter = spokenFocusReturnState?.center ?? currentViewportCenter()
        spokenFocusGeneration += 1
        let generation = spokenFocusGeneration
        stopSpokenFocusMotion()
        cancelShowcaseAnimation()
        isSpokenItemFocusActive = false
        clearVoiceAttentionImmediately()
        configureZoomLimitsIfNeeded(force: true)

        guard let returnCenter else {
            spokenFocusReturnState = nil
            return
        }
        let targetColumns = isSingleColumnFeed ? 1 : activeResultColumnCount
        let targetScale = scale(forVisibleColumns: targetColumns)
        let targetCenter = CGPoint(
            x: alignedHorizontalCenter(near: returnCenter.x, visibleColumns: targetColumns),
            y: returnCenter.y
        )
        let rectSize = CGSize(
            width: bounds.width / targetScale,
            height: bounds.height / targetScale
        )
        let targetRect = CGRect(
            x: targetCenter.x - rectSize.width / 2,
            y: targetCenter.y - rectSize.height / 2,
            width: rectSize.width,
            height: rectSize.height
        )
        settledColumnCount = targetColumns
        prioritizeViewportImageLoads(force: true, viewport: targetRect)
        isSettlingZoom = true

        let completion = { [weak self] in
            guard let self, generation == self.spokenFocusGeneration else { return }
            self.spokenFocusAnimator = nil
            self.spokenFocusReturnState = nil
            self.isSettlingZoom = false
            self.recenterIfNeeded()
            self.prioritizeViewportImageLoads(force: true)
            self.settleTileDynamics()
            self.resetMotionTracking()
        }
        let changes = { self.zoom(to: targetRect, animated: false) }
        guard !UIAccessibility.isReduceMotionEnabled else {
            changes()
            completion()
            return
        }

        let animator = UIViewPropertyAnimator(duration: 0.72, dampingRatio: 0.92)
        animator.addAnimations(changes)
        animator.addCompletion { [weak self] position in
            guard position == .end else { return }
            completion()
            self?.spokenFocusAnimator = nil
        }
        spokenFocusAnimator = animator
        animator.startAnimation()
    }

    private func captureSpokenFocusReturnStateIfNeeded() {
        guard spokenFocusReturnState == nil,
              let center = currentViewportCenter() else { return }
        spokenFocusReturnState = SpokenFocusReturnState(center: center)
    }

    private func currentViewportCenter() -> CGPoint? {
        guard zoomScale > 0 else { return nil }
        return CGPoint(
            x: (contentOffset.x + bounds.width / 2) / zoomScale,
            y: (contentOffset.y + bounds.height / 2) / zoomScale
        )
    }

    private func stopSpokenFocusMotion() {
        spokenFocusWorkItem?.cancel()
        spokenFocusWorkItem = nil
        if let spokenFocusAnimator {
            spokenFocusAnimator.stopAnimation(false)
            spokenFocusAnimator.finishAnimation(at: .current)
        }
        spokenFocusAnimator = nil
        isSettlingZoom = false
    }

    private func cancelSpokenItemFocusForContentChange() {
        guard isSpokenItemFocusActive
                || spokenFocusReturnState != nil
                || spokenFocusAnimator != nil
                || spokenFocusWorkItem != nil else { return }
        spokenFocusGeneration += 1
        stopSpokenFocusMotion()
        spokenFocusReturnState = nil
        isSpokenItemFocusActive = false
        clearVoiceAttentionImmediately()
        restoreInteractiveZoomLimitsIfPossible()
    }

    private func clearVoiceAttentionImmediately() {
        voiceHighlightGeneration += 1
        tileSlots.forEach {
            $0.button.setVoiceHighlighted(false)
            $0.button.setVoicePointed(false)
        }
    }

    private func highlightProducts(productIDs: Set<String>) {
        voiceHighlightGeneration += 1
        let generation = voiceHighlightGeneration
        let buttons = tileSlots.map(\.button)
        for button in buttons {
            button.setVoicePointed(false)
            button.setVoiceHighlighted(
                button.product.map { productIDs.contains($0.id) } ?? false
            )
        }

        clearVoiceAttention(after: 7.5, generation: generation)
    }

    private func pointToProducts(productIDs: [String]) {
        voiceHighlightGeneration += 1
        let generation = voiceHighlightGeneration
        let orderedIDs = productIDs.reduce(into: [String]()) { result, productID in
            guard !result.contains(productID) else { return }
            result.append(productID)
        }
        guard !orderedIDs.isEmpty, zoomScale > 0 else {
            tileSlots.forEach {
                $0.button.setVoiceHighlighted(false)
                $0.button.setVoicePointed(false)
            }
            return
        }

        let viewportCenter = CGPoint(
            x: (contentOffset.x + bounds.width / 2) / zoomScale,
            y: (contentOffset.y + bounds.height / 2) / zoomScale
        )
        let matchingSlots = tileSlots.filter {
            !$0.button.isHidden
                && $0.button.product.map { orderedIDs.contains($0.id) } == true
        }
        guard let anchor = matchingSlots.min(by: {
            distance(from: $0.button.restingFrame, to: viewportCenter)
                < distance(from: $1.button.restingFrame, to: viewportCenter)
        }) else { return }

        let targets = orderedIDs.prefix(3).compactMap { productID in
            let samePanel = matchingSlots.filter {
                $0.panelRow == anchor.panelRow
                    && $0.panelColumn == anchor.panelColumn
                    && $0.button.product?.id == productID
            }
            let candidates = samePanel.isEmpty
                ? matchingSlots.filter { $0.button.product?.id == productID }
                : samePanel
            return candidates.min {
                distance(from: $0.button.restingFrame, to: viewportCenter)
                    < distance(from: $1.button.restingFrame, to: viewportCenter)
            }
        }
        let targetButtons = targets.map(\.button)
        let targetIdentities = Set(targetButtons.map(ObjectIdentifier.init))
        for button in tileSlots.map(\.button) {
            let isTarget = targetIdentities.contains(ObjectIdentifier(button))
            button.setVoiceHighlighted(isTarget)
            button.setVoicePointed(isTarget)
        }

        guard !targetButtons.isEmpty else { return }
        onInteraction?()
        if targetButtons.count == 1 {
            focusOnSingleProduct(targetButtons[0])
            UIAccessibility.post(notification: .layoutChanged, argument: targetButtons[0])
            clearVoiceAttention(after: 8.5, generation: generation)
            return
        }
        focusPointedProducts(targetButtons)
        UIAccessibility.post(notification: .layoutChanged, argument: targetButtons.first)
        clearVoiceAttention(after: 8.5, generation: generation)
    }

    private func focusPointedProducts(_ buttons: [CanvasProductButton]) {
        guard zoomScale > 0, bounds.width > 0, bounds.height > 0,
              var targetBounds = buttons.first?.restingFrame else { return }
        for button in buttons.dropFirst() {
            targetBounds = targetBounds.union(button.restingFrame)
        }

        let viewport = CGRect(
            x: contentOffset.x / zoomScale,
            y: contentOffset.y / zoomScale,
            width: bounds.width / zoomScale,
            height: bounds.height / zoomScale
        )
        let safeViewport = viewport.insetBy(dx: 18, dy: 30)
        guard !safeViewport.contains(targetBounds) else {
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }

        let currentColumns = nearestVisibleColumnCount(to: zoomScale)
        var targetColumns = currentColumns
        while targetColumns < activeResultColumnCount {
            let candidateScale = scale(forVisibleColumns: targetColumns)
            let availableSize = CGSize(
                width: bounds.width / candidateScale - 36,
                height: bounds.height / candidateScale - 60
            )
            if targetBounds.width <= availableSize.width,
               targetBounds.height <= availableSize.height {
                break
            }
            targetColumns += 1
        }
        settleZoom(
            toVisibleColumns: targetColumns,
            around: CGPoint(x: targetBounds.midX, y: targetBounds.midY)
        )
    }

    private func nearestVisibleProductButton() -> CanvasProductButton? {
        guard zoomScale > 0 else { return nil }
        let viewport = CGRect(
            x: contentOffset.x / zoomScale,
            y: contentOffset.y / zoomScale,
            width: bounds.width / zoomScale,
            height: bounds.height / zoomScale
        )
        let center = CGPoint(x: viewport.midX, y: viewport.midY)
        let activeButtons = tileSlots.compactMap { slot -> CanvasProductButton? in
            guard !slot.button.isHidden, slot.button.product != nil else { return nil }
            return slot.button
        }
        let visibleButtons = activeButtons.filter { $0.restingFrame.intersects(viewport) }
        return (visibleButtons.isEmpty ? activeButtons : visibleButtons).min {
            distance(from: $0.restingFrame, to: center)
                < distance(from: $1.restingFrame, to: center)
        }
    }

    private func focusOnSingleProduct(_ button: CanvasProductButton) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let frame = button.restingFrame
        let targetScale = scale(forVisibleColumns: 1)
        maximumZoomScale = max(maximumZoomScale, targetScale)
        settledColumnCount = 1
        isSettlingZoom = true

        let rectSize = CGSize(
            width: bounds.width / targetScale,
            height: bounds.height / targetScale
        )
        let targetRect = CGRect(
            x: frame.midX - rectSize.width / 2,
            y: frame.midY - rectSize.height / 2,
            width: rectSize.width,
            height: rectSize.height
        )
        let changes = { self.zoom(to: targetRect, animated: false) }
        let completion: (Bool) -> Void = { [weak self] _ in
            guard let self else { return }
            self.isSettlingZoom = false
            self.recenterIfNeeded()
            self.settleTileDynamics()
            self.resetMotionTracking()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.82)
        }

        if UIAccessibility.isReduceMotionEnabled {
            changes()
            completion(true)
        } else {
            UIView.animate(
                withDuration: 0.52,
                delay: 0,
                usingSpringWithDamping: 0.9,
                initialSpringVelocity: 0.08,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                changes()
            } completion: { finished in
                completion(finished)
            }
        }
    }

    private func distance(from frame: CGRect, to point: CGPoint) -> CGFloat {
        hypot(frame.midX - point.x, frame.midY - point.y)
    }

    private func clearVoiceAttention(after delay: TimeInterval, generation: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, generation == self.voiceHighlightGeneration else { return }
            self.tileSlots.forEach {
                $0.button.setVoiceHighlighted(false)
                $0.button.setVoicePointed(false)
            }
        }
    }

    /// Runs a voice-synchronized opening as a camera move through the canvas.
    /// Every leg uses an interruptible property animator; touching the canvas
    /// immediately hands control back to the person at the current frame.
    private func showcaseOpening(_ choreography: CanvasOpeningChoreography) {
        cancelVoiceEntranceAnimation()
        cancelSpokenItemFocusForContentChange()
        cancelShowcaseAnimation()
        guard bounds.width > 0,
              bounds.height > 0,
              !productIDs.isEmpty else { return }

        let focusIDs = Array(choreography.focusProductIDs.prefix(2))
        guard !UIAccessibility.isReduceMotionEnabled else {
            highlightProducts(productIDs: Set(focusIDs))
            return
        }

        showcaseGeneration += 1
        let generation = showcaseGeneration
        isShowcasing = true
        showcaseReturnCenter = currentViewportCenter()
        showcaseReturnsToOverview = true
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, generation == self.showcaseGeneration else { return }
            switch choreography.style {
            case .editorial:
                self.runEditorialOpening(focusIDs: focusIDs, generation: generation)
            case .gallery:
                self.runGalleryOpening(focusIDs: focusIDs, generation: generation)
            case .universe:
                self.runUniverseOpening(focusIDs: focusIDs, generation: generation)
            }
        }
        showcaseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func runEditorialOpening(focusIDs: [String], generation: Int) {
        guard let first = focusIDs.first else {
            finishShowcase(generation: generation)
            return
        }
        animateShowcaseFocus(
            productID: first,
            visibleColumns: 1,
            duration: 1.05,
            motion: CGPoint(x: 0, y: -0.2),
            generation: generation
        ) { [weak self] in
            guard let self else { return }
            self.continueShowcase(after: 0.62, generation: generation) { [weak self] in
                guard let self, let second = focusIDs.dropFirst().first else {
                    self?.finishShowcase(generation: generation)
                    return
                }
                self.animateShowcaseFocus(
                    productID: second,
                    visibleColumns: 1,
                    duration: 1.28,
                    motion: CGPoint(x: 0.04, y: 0.34),
                    generation: generation
                ) { [weak self] in
                    self?.finishShowcase(generation: generation)
                }
            }
        }
    }

    private func runGalleryOpening(focusIDs: [String], generation: Int) {
        guard let first = focusIDs.first else {
            finishShowcase(generation: generation)
            return
        }

        // The entrance has already established the full canvas underneath the
        // welcome. Once audible playback drains, go straight into the first
        // product instead of replaying a wide zoom and pan for two seconds.
        animateShowcaseFocus(
            productID: first,
            visibleColumns: 1,
            duration: 1.02,
            motion: CGPoint(x: 0.2, y: 0.18),
            generation: generation
        ) { [weak self] in
            guard let self else { return }
            self.continueShowcase(after: 0.48, generation: generation) { [weak self] in
                guard let self, let second = focusIDs.dropFirst().first else {
                    self?.finishShowcase(generation: generation)
                    return
                }
                self.animateShowcaseFocus(
                    productID: second,
                    visibleColumns: 1,
                    duration: 1.16,
                    motion: CGPoint(x: -0.22, y: 0.28),
                    generation: generation
                ) { [weak self] in
                    self?.finishShowcase(generation: generation)
                }
            }
        }
    }

    private func runUniverseOpening(focusIDs: [String], generation: Int) {
        guard let first = focusIDs.first else {
            finishShowcase(generation: generation)
            return
        }

        animateShowcaseFocus(
            productID: first,
            visibleColumns: 1,
            duration: 1.06,
            motion: CGPoint(x: 0.26, y: 0.2),
            generation: generation
        ) { [weak self] in
            guard let self else { return }
            self.continueShowcase(after: 0.5, generation: generation) { [weak self] in
                guard let self, let second = focusIDs.dropFirst().first else {
                    self?.finishShowcase(generation: generation)
                    return
                }
                let travelColumns = max(3, self.activeResultColumnCount)
                self.animateShowcaseZoom(
                    toVisibleColumns: travelColumns,
                    duration: 0.72,
                    motion: CGPoint(x: -0.12, y: -0.18),
                    generation: generation
                ) { [weak self] in
                    guard let self else { return }
                    self.animateShowcasePan(
                        by: CGSize(
                            width: -self.bounds.width * 0.42,
                            height: self.bounds.height * 0.12
                        ),
                        duration: 0.62,
                        motion: CGPoint(x: 0.56, y: -0.16),
                        generation: generation
                    ) { [weak self] in
                        guard let self else { return }
                        self.animateShowcaseFocus(
                            productID: second,
                            visibleColumns: 1,
                            duration: 1.02,
                            motion: CGPoint(x: -0.2, y: 0.24),
                            generation: generation
                        ) { [weak self] in
                            self?.finishShowcase(generation: generation)
                        }
                    }
                }
            }
        }
    }

    private func continueShowcase(
        after delay: TimeInterval,
        generation: Int,
        _ continuation: @escaping () -> Void
    ) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  generation == self.showcaseGeneration,
                  self.isShowcasing else { return }
            continuation()
        }
        showcaseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func animateShowcaseFocus(
        productID: String,
        visibleColumns: Int,
        duration: TimeInterval,
        motion: CGPoint,
        generation: Int,
        completion: @escaping () -> Void
    ) {
        highlightProducts(productIDs: [productID])
        guard let focus = nearestPoint(forProductID: productID) else {
            completion()
            return
        }
        animateShowcaseZoom(
            toVisibleColumns: visibleColumns,
            around: focus,
            duration: duration,
            motion: motion,
            generation: generation,
            completion: completion
        )
    }

    private func nearestPoint(forProductID productID: String) -> CGPoint? {
        guard zoomScale > 0 else { return nil }
        let viewportCenter = CGPoint(
            x: (contentOffset.x + bounds.width / 2) / zoomScale,
            y: (contentOffset.y + bounds.height / 2) / zoomScale
        )
        return tileSlots
            .filter { !$0.button.isHidden && $0.button.product?.id == productID }
            .min { lhs, rhs in
                let left = lhs.button.restingFrame
                let right = rhs.button.restingFrame
                return hypot(left.midX - viewportCenter.x, left.midY - viewportCenter.y)
                    < hypot(right.midX - viewportCenter.x, right.midY - viewportCenter.y)
            }
            .map { CGPoint(x: $0.button.restingFrame.midX, y: $0.button.restingFrame.midY) }
    }

    /// Gives a fresh result field a short, camera-like reveal while Realtime
    /// talks about it. Direct manipulation cancels every animator immediately.
    private func showcaseProducts(resultCount: Int) {
        cancelVoiceEntranceAnimation()
        cancelShowcaseAnimation()
        guard !UIAccessibility.isReduceMotionEnabled,
              bounds.width > 0,
              bounds.height > 0,
              !productIDs.isEmpty else { return }

        showcaseGeneration += 1
        let generation = showcaseGeneration
        let originalColumns = nearestVisibleColumnCount(to: zoomScale)
        let revealsLargeField = resultCount > 20
        isShowcasing = true
        showcaseReturnCenter = nil
        showcaseReturnsToOverview = false

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, generation == self.showcaseGeneration else { return }
            if revealsLargeField {
                let overviewColumns = min(
                    activeResultColumnCount,
                    max(3, originalColumns + 1)
                )
                self.animateShowcaseZoom(
                    toVisibleColumns: overviewColumns,
                    duration: 0.72,
                    motion: CGPoint(x: -0.16, y: -0.12),
                    generation: generation
                ) { [weak self] in
                    self?.runShowcaseDrift(
                        resultCount: resultCount,
                        originalColumns: originalColumns,
                        generation: generation
                    )
                }
            } else {
                self.runShowcaseDrift(
                    resultCount: resultCount,
                    originalColumns: originalColumns,
                    generation: generation
                )
            }
        }
        showcaseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }

    private func runShowcaseDrift(
        resultCount: Int,
        originalColumns: Int,
        generation: Int
    ) {
        let wideField = resultCount > 20
        animateShowcasePan(
            by: CGSize(width: bounds.width * 0.34, height: bounds.height * 0.15),
            duration: 0.9,
            motion: CGPoint(x: -0.5, y: -0.24),
            generation: generation
        ) { [weak self] in
            guard let self else { return }
            self.animateShowcasePan(
                by: CGSize(width: -self.bounds.width * 0.62, height: self.bounds.height * 0.12),
                duration: 1.16,
                motion: CGPoint(x: 0.64, y: -0.18),
                generation: generation
            ) { [weak self] in
                guard let self else { return }
                if wideField {
                    self.animateShowcaseZoom(
                        toVisibleColumns: originalColumns,
                        duration: 0.78,
                        motion: CGPoint(x: 0.12, y: 0.16),
                        generation: generation
                    ) { [weak self] in
                        self?.finishShowcase(generation: generation)
                    }
                } else {
                    self.animateShowcasePan(
                        by: CGSize(
                            width: self.bounds.width * 0.22,
                            height: -self.bounds.height * 0.1
                        ),
                        duration: 0.76,
                        motion: CGPoint(x: -0.3, y: 0.18),
                        generation: generation
                    ) { [weak self] in
                        self?.finishShowcase(generation: generation)
                    }
                }
            }
        }
    }

    private func animateShowcasePan(
        by delta: CGSize,
        duration: TimeInterval,
        motion: CGPoint,
        generation: Int,
        completion: @escaping () -> Void
    ) {
        var target = CGPoint(
            x: contentOffset.x + (isSingleColumnFeed ? 0 : delta.width),
            y: contentOffset.y + delta.height
        )
        var constrainedMotion = motion
        if isSingleColumnFeed {
            target = constrainedSingleColumnOffset(target)
            constrainedMotion.x = 0
        }
        animateShowcase(
            duration: duration,
            motion: constrainedMotion,
            generation: generation,
            changes: { self.contentOffset = target },
            completion: completion
        )
    }

    private func animateShowcaseZoom(
        toVisibleColumns columns: Int,
        around focus: CGPoint? = nil,
        duration: TimeInterval,
        motion: CGPoint,
        generation: Int,
        completion: @escaping () -> Void
    ) {
        let targetScale = scale(forVisibleColumns: columns)
        let currentCenter = CGPoint(
            x: (contentOffset.x + bounds.width / 2) / max(zoomScale, 0.01),
            y: (contentOffset.y + bounds.height / 2) / max(zoomScale, 0.01)
        )
        let requestedCenter = focus ?? currentCenter
        let targetCenter = CGPoint(
            x: alignedHorizontalCenter(near: requestedCenter.x, visibleColumns: columns),
            y: requestedCenter.y
        )
        let targetSize = CGSize(
            width: bounds.width / targetScale,
            height: bounds.height / targetScale
        )
        let targetRect = CGRect(
            x: targetCenter.x - targetSize.width / 2,
            y: targetCenter.y - targetSize.height / 2,
            width: targetSize.width,
            height: targetSize.height
        )
        settledColumnCount = min(activeResultColumnCount, columns)
        animateShowcase(
            duration: duration,
            motion: motion,
            generation: generation,
            changes: { self.zoom(to: targetRect, animated: false) },
            completion: completion
        )
    }

    private func animateShowcase(
        duration: TimeInterval,
        motion: CGPoint,
        generation: Int,
        changes: @escaping () -> Void,
        completion: @escaping () -> Void
    ) {
        guard generation == showcaseGeneration, isShowcasing else { return }
        setOrbMotionTarget(motion, elasticTarget: motion)
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeInOut)
        animator.addAnimations(changes)
        animator.addCompletion { [weak self] position in
            guard let self,
                  generation == self.showcaseGeneration,
                  self.isShowcasing,
                  position == .end else { return }
            self.showcaseAnimator = nil
            self.recenterIfNeeded()
            completion()
        }
        showcaseAnimator = animator
        animator.startAnimation()
    }

    private func finishShowcase(generation: Int) {
        guard generation == showcaseGeneration else { return }
        if showcaseReturnsToOverview {
            showcaseReturnsToOverview = false
            let returnCenter = showcaseReturnCenter
            animateShowcaseZoom(
                toVisibleColumns: activeResultColumnCount,
                around: returnCenter,
                duration: 0.78,
                motion: CGPoint(x: 0.08, y: 0.14),
                generation: generation
            ) { [weak self] in
                self?.completeShowcase(generation: generation)
            }
            return
        }
        completeShowcase(generation: generation)
    }

    private func completeShowcase(generation: Int) {
        guard generation == showcaseGeneration else { return }
        isShowcasing = false
        showcaseWorkItem = nil
        showcaseAnimator = nil
        showcaseReturnCenter = nil
        configureZoomLimitsIfNeeded(force: true)
        setOrbMotionTarget(.zero)
        snapHorizontalOffset(animated: true)
    }

    private func cancelShowcaseForInteraction(cancelCanvasPlay: Bool = true) {
        cancelVoiceEntranceAnimation()
        cancelSpokenItemFocusForContentChange()
        if cancelCanvasPlay {
            cancelCanvasPlayAnimation(animated: true)
        }
        guard isShowcasing || showcaseWorkItem != nil || showcaseAnimator != nil else {
            settleTileDynamics()
            resetMotionTracking()
            return
        }
        cancelShowcaseAnimation()
        settleTileDynamics()
        resetMotionTracking()
    }

    private func cancelShowcaseAnimation() {
        showcaseGeneration += 1
        showcaseWorkItem?.cancel()
        showcaseWorkItem = nil
        if let showcaseAnimator {
            showcaseAnimator.stopAnimation(false)
            showcaseAnimator.finishAnimation(at: .current)
        }
        showcaseAnimator = nil
        isShowcasing = false
        showcaseReturnCenter = nil
        showcaseReturnsToOverview = false
        restoreInteractiveZoomLimitsIfPossible()
        setOrbMotionTarget(.zero)
    }

    private func restoreInteractiveZoomLimitsIfPossible() {
        guard bounds.width > 0 else { return }
        if isSingleColumnFeed {
            minimumZoomScale = 1
            maximumZoomScale = 1
            return
        }
        let interactiveMinimum = scale(forVisibleColumns: activeResultColumnCount)
        maximumZoomScale = detailZoomScale
        // If someone grabs the canvas during the enormous overview, preserve
        // that exact frame instead of snapping inward beneath their fingers.
        if zoomScale >= interactiveMinimum - 0.001 {
            minimumZoomScale = interactiveMinimum
        }
    }

    private var singleColumnProductBounds: CGRect? {
        let frames = tileSlots.compactMap { slot -> CGRect? in
            guard isCentralFeedSlot(slot),
                  !slot.button.isHidden,
                  slot.button.product != nil else { return nil }
            return slot.button.restingFrame
        }
        guard var productBounds = frames.first else { return nil }
        for frame in frames.dropFirst() {
            productBounds = productBounds.union(frame)
        }
        return productBounds
    }

    private var singleColumnTopClearance: CGFloat {
        max(18, safeAreaInsets.top + 10)
    }

    private var singleColumnBottomClearance: CGFloat {
        max(96, safeAreaInsets.bottom + 84)
    }

    private var singleColumnVerticalOffsetRange: ClosedRange<CGFloat>? {
        guard let productBounds = singleColumnProductBounds, zoomScale > 0 else { return nil }
        let topClearance = singleColumnTopClearance
        let bottomClearance = singleColumnBottomClearance
        let scaledMinY = productBounds.minY * zoomScale
        let scaledMaxY = productBounds.maxY * zoomScale
        let productHeight = scaledMaxY - scaledMinY
        let availableHeight = max(1, bounds.height - topClearance - bottomClearance)

        if productHeight <= availableHeight {
            let viewportCenterY = topClearance + availableHeight / 2
            let centeredOffset = (scaledMinY + scaledMaxY) / 2 - viewportCenterY
            return centeredOffset...centeredOffset
        }

        let firstItemOffset = scaledMinY - topClearance
        let lastItemOffset = scaledMaxY - bounds.height + bottomClearance
        return min(firstItemOffset, lastItemOffset)...max(firstItemOffset, lastItemOffset)
    }

    private func constrainedSingleColumnOffset(_ proposed: CGPoint) -> CGPoint {
        guard isSingleColumnFeed, zoomScale > 0 else { return proposed }
        let lockedX = patternSize.width * 1.5 * zoomScale - bounds.width / 2
        guard let verticalRange = singleColumnVerticalOffsetRange else {
            return CGPoint(x: lockedX, y: proposed.y)
        }
        return CGPoint(
            x: lockedX,
            y: min(verticalRange.upperBound, max(verticalRange.lowerBound, proposed.y))
        )
    }

    private func constrainSingleColumnOffsetIfNeeded() {
        guard isSingleColumnFeed, !isConstrainingSingleColumnOffset else { return }
        let constrained = constrainedSingleColumnOffset(contentOffset)
        guard hypot(constrained.x - contentOffset.x, constrained.y - contentOffset.y) > 0.25 else {
            return
        }
        isConstrainingSingleColumnOffset = true
        contentOffset = constrained
        isConstrainingSingleColumnOffset = false
    }

    func recenter(animated: Bool) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        if isSingleColumnFeed {
            let firstItemY = singleColumnVerticalOffsetRange?.lowerBound ?? contentOffset.y
            let target = constrainedSingleColumnOffset(
                CGPoint(x: contentOffset.x, y: firstItemY)
            )
            setContentOffset(target, animated: animated)
            return
        }
        let columns = nearestVisibleColumnCount(to: zoomScale)
        let center = landingCenter(visibleColumns: columns)
        let alignedX = alignedHorizontalCenter(
            near: center.x,
            visibleColumns: columns
        )
        let target = CGPoint(
            x: alignedX * zoomScale - bounds.width / 2,
            y: center.y * zoomScale - bounds.height / 2
        )
        setContentOffset(target, animated: animated)
    }

    private func landingCenter(visibleColumns: Int) -> CGPoint {
        let activeColumns = max(1, activeResultColumnCount)
        let rowCount = min(
            Layout.rowCount,
            max(1, Int(ceil(Double(max(1, productIDs.count)) / Double(activeColumns))))
        )
        let firstActiveColumn = (Layout.columnCount - activeColumns + 1) / 2
        let occupiedColumnCount = min(activeColumns, max(1, productIDs.count))
        let occupiedColumns = firstActiveColumn..<(firstActiveColumn + occupiedColumnCount)
        let phases = occupiedColumns.map { Layout.lanePhase(column: $0) }
        let tileHeight = Layout.tileWidth * Layout.tileAspectRatio
        let groupHeight = CGFloat(rowCount) * tileHeight
            + CGFloat(max(0, rowCount - 1)) * Layout.verticalGap
        let groupTop = phases.min() ?? 0
        let groupBottom = (phases.max() ?? 0) + groupHeight
        let centerY = patternSize.height + (groupTop + groupBottom) / 2
        let canvasCenterX = patternSize.width * 1.5
        return CGPoint(
            x: alignedHorizontalCenter(
                near: canvasCenterX,
                visibleColumns: visibleColumns
            ),
            y: centerY
        )
    }

    private func buildRepeatingCanvas() {
        for panelRow in 0..<3 {
            for panelColumn in 0..<3 {
                let panelOrigin = CGPoint(
                    x: CGFloat(panelColumn) * patternSize.width,
                    y: CGFloat(panelRow) * patternSize.height
                )

                for column in 0..<Layout.columnCount {
                    var tileTop = panelOrigin.y + Layout.lanePhase(column: column)

                    for row in 0..<Layout.rowCount {
                        let value = stableHash(row: row, column: column)

                        let width = Layout.tileWidth
                        let height = width * Layout.aspectRatio(row: row, column: column)
                        let center = CGPoint(
                            x: panelOrigin.x + (CGFloat(column) + 0.5) * Layout.columnPitch,
                            y: tileTop + height / 2
                        )
                        tileTop += height + Layout.verticalGap

                        let button = CanvasProductButton(
                            frame: CGRect(
                                x: center.x - width / 2,
                                y: center.y - height / 2,
                                width: width,
                                height: height
                            )
                        )
                        button.onTap = { [weak self, weak button] source in
                            guard let product = button?.product else { return }
                            self?.cancelShowcaseForInteraction()
                            self?.onSelect?(product, source)
                        }
                        button.onRequestSimilar = { [weak self, weak button] in
                            guard let product = button?.product else { return }
                            self?.cancelShowcaseForInteraction()
                            self?.onInteraction?()
                            self?.onRequestSimilar?(product)
                        }
                        button.onRemove = { [weak self, weak button] in
                            guard let product = button?.product else { return }
                            self?.cancelShowcaseForInteraction()
                            self?.onInteraction?()
                            self?.onRemove?(product)
                        }
                        button.onTouchBegan = { [weak self] in
                            self?.cancelShowcaseForInteraction(cancelCanvasPlay: false)
                        }
                        button.configureDynamics(
                            depth: 0.78 + CGFloat((value / 53) % 15) / 100
                        )
                        canvasInteractionView.addSubview(button)
                        tileSlots.append(
                            TileSlot(
                                button: button,
                                panelRow: panelRow,
                                panelColumn: panelColumn,
                                row: row,
                                column: column
                            )
                        )
                    }
                }
            }
        }
    }

    private func stableHash(row: Int, column: Int) -> UInt64 {
        var value = UInt64(bitPattern: Int64(row)) &* 0x9E3779B185EBCA87
        value ^= UInt64(bitPattern: Int64(column)) &* 0xC2B2AE3D27D4EB4F
        value ^= value >> 33
        value &*= 0xFF51AFD7ED558CCD
        value ^= value >> 33
        return value
    }

    private func recenterIfNeeded() {
        guard !isRecentering, !isZooming, zoomScale > 0 else { return }
        if isSingleColumnFeed {
            constrainSingleColumnOffsetIfNeeded()
            return
        }

        let scale = zoomScale
        let viewportCenter = CGPoint(
            x: (contentOffset.x + bounds.width / 2) / scale,
            y: (contentOffset.y + bounds.height / 2) / scale
        )
        var adjustment = CGPoint.zero

        if viewportCenter.x < patternSize.width {
            adjustment.x = patternSize.width * scale
        } else if viewportCenter.x > patternSize.width * 2 {
            adjustment.x = -patternSize.width * scale
        }

        if viewportCenter.y < patternSize.height {
            adjustment.y = patternSize.height * scale
        } else if viewportCenter.y > patternSize.height * 2 {
            adjustment.y = -patternSize.height * scale
        }

        guard adjustment != .zero else { return }
        isRecentering = true
        contentOffset = CGPoint(x: contentOffset.x + adjustment.x, y: contentOffset.y + adjustment.y)
        isRecentering = false
        resetMotionTracking()
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard !isSingleColumnFeed else { return }
        cancelShowcaseForInteraction()
        onInteraction?()
        let current = nearestVisibleColumnCount(to: zoomScale)
        let target = current == 1 ? Layout.defaultVisibleColumns : current - 1
        settleZoom(
            toVisibleColumns: target,
            around: recognizer.location(in: canvasContentView)
        )
    }

    @objc private func handleTwoFingerTap(_ recognizer: UITapGestureRecognizer) {
        guard !isSingleColumnFeed else { return }
        cancelShowcaseForInteraction()
        onInteraction?()
        let current = nearestVisibleColumnCount(to: zoomScale)
        settleZoom(
            toVisibleColumns: min(activeResultColumnCount, current + 1),
            around: recognizer.location(in: canvasContentView)
        )
    }

    @objc private func handleOrbPanGesture(_ recognizer: UIPanGestureRecognizer) {
        var velocity = recognizer.velocity(in: self)
        if isSingleColumnFeed {
            velocity.x = 0
        }
        switch recognizer.state {
        case .began:
            cancelShowcaseForInteraction()
            driveOrb(withVisualVelocity: velocity)
        case .changed:
            driveOrb(withVisualVelocity: velocity)
        case .cancelled, .failed:
            setOrbMotionTarget(.zero)
        default:
            break
        }
    }

    private func configureZoomLimitsIfNeeded(force: Bool = false) {
        guard bounds.width > 0,
              force || abs(configuredViewportWidth - bounds.width) > 0.5 else { return }
        configuredViewportWidth = bounds.width
        if isSingleColumnFeed {
            minimumZoomScale = 1
            maximumZoomScale = 1
            return
        }
        minimumZoomScale = scale(forVisibleColumns: activeResultColumnCount)
        maximumZoomScale = detailZoomScale
    }

    private var detailZoomScale: CGFloat {
        let availableWidth = max(1, bounds.width - Layout.detailHorizontalInset * 2)
        return max(scale(forVisibleColumns: 1), availableWidth / Layout.tileWidth)
    }

    private func scale(forVisibleColumns columns: Int) -> CGFloat {
        if isSingleColumnFeed { return 1 }
        let visiblePitches = CGFloat(columns) + Layout.edgePeek * 2
        return max(0.01, bounds.width / (Layout.columnPitch * visiblePitches))
    }

    private func nearestVisibleColumnCount(to scale: CGFloat) -> Int {
        (1...activeResultColumnCount).min { lhs, rhs in
            abs(log(scale / self.scale(forVisibleColumns: lhs)))
                < abs(log(scale / self.scale(forVisibleColumns: rhs)))
        } ?? desiredVisibleColumnCount
    }

    private func alignedHorizontalCenter(near center: CGFloat, visibleColumns: Int) -> CGFloat {
        let visibleColumns = min(activeResultColumnCount, max(1, visibleColumns))
        let units = center / Layout.columnPitch

        // The full five-column canvas has no gaps, so every adjacent window is
        // valid—even when it straddles the repeating pattern boundary.
        if activeResultColumnCount == Layout.columnCount {
            let phase: CGFloat = visibleColumns.isMultiple(of: 2) ? 0 : 0.5
            return (round(units - phase) + phase) * Layout.columnPitch
        }

        // Sparse searches occupy one centered, contiguous group per repeating
        // panel. Snap only to windows inside that group so a horizontal flick
        // can never settle on an intentionally empty lane.
        let firstActiveColumn = (Layout.columnCount - activeResultColumnCount + 1) / 2
        let windowCount = activeResultColumnCount - visibleColumns + 1
        let nearestPanel = Int(round(units / CGFloat(Layout.columnCount)))
        var best = CGFloat(nearestPanel * Layout.columnCount + firstActiveColumn)
            + CGFloat(visibleColumns) / 2
        var bestDistance = abs(best - units)

        for panel in (nearestPanel - 1)...(nearestPanel + 1) {
            for window in 0..<windowCount {
                let candidate = CGFloat(
                    panel * Layout.columnCount + firstActiveColumn + window
                ) + CGFloat(visibleColumns) / 2
                let distance = abs(candidate - units)
                if distance < bestDistance {
                    best = candidate
                    bestDistance = distance
                }
            }
        }
        return best * Layout.columnPitch
    }

    private func settleZoom(toVisibleColumns columns: Int, around focus: CGPoint? = nil) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let columns = min(activeResultColumnCount, max(1, columns))
        let targetScale = scale(forVisibleColumns: columns)
        let currentCenter = CGPoint(
            x: (contentOffset.x + bounds.width / 2) / max(zoomScale, 0.01),
            y: (contentOffset.y + bounds.height / 2) / max(zoomScale, 0.01)
        )
        let focus = focus ?? currentCenter
        let targetCenter = CGPoint(
            x: alignedHorizontalCenter(near: focus.x, visibleColumns: columns),
            y: focus.y
        )
        let rectSize = CGSize(
            width: bounds.width / targetScale,
            height: bounds.height / targetScale
        )
        let targetRect = CGRect(
            x: targetCenter.x - rectSize.width / 2,
            y: targetCenter.y - rectSize.height / 2,
            width: rectSize.width,
            height: rectSize.height
        )

        if columns != settledColumnCount {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        settledColumnCount = columns
        isSettlingZoom = true

        let changes = { self.zoom(to: targetRect, animated: false) }
        let completion: (Bool) -> Void = { [weak self] _ in
            guard let self else { return }
            self.isSettlingZoom = false
            self.recenterIfNeeded()
            self.settleTileDynamics()
            self.resetMotionTracking()
        }

        if UIAccessibility.isReduceMotionEnabled {
            changes()
            completion(true)
        } else {
            UIView.animate(
                withDuration: 0.42,
                delay: 0,
                usingSpringWithDamping: 0.9,
                initialSpringVelocity: 0.12,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                changes()
            } completion: { finished in
                completion(finished)
            }
        }
    }

    private func snapHorizontalOffset(animated: Bool) {
        guard bounds.width > 0, zoomScale > 0 else { return }
        let columns = nearestVisibleColumnCount(to: zoomScale)
        let centerX = (contentOffset.x + bounds.width / 2) / zoomScale
        let targetCenterX = alignedHorizontalCenter(near: centerX, visibleColumns: columns)
        let target = CGPoint(
            x: targetCenterX * zoomScale - bounds.width / 2,
            y: contentOffset.y
        )
        guard hypot(target.x - contentOffset.x, target.y - contentOffset.y) > 0.5 else {
            settleTileDynamics()
            return
        }
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            contentOffset = target
            settleTileDynamics()
            return
        }

        UIView.animate(
            withDuration: 0.46,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.16,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.contentOffset = target
        } completion: { [weak self] _ in
            self?.settleTileDynamics()
            self?.resetMotionTracking()
        }
    }

    private func updateTileDynamics() {
        guard !isRecentering, zoomScale > 0 else { return }
        let now = CACurrentMediaTime()
        let elapsed = now - lastMotionTimestamp
        guard elapsed > 0.004, elapsed < 0.12 else {
            resetMotionTracking()
            return
        }

        let offsetVelocity = CGPoint(
            x: -(contentOffset.x - lastMotionOffset.x) / elapsed,
            y: -(contentOffset.y - lastMotionOffset.y) / elapsed
        )
        let panVelocity = panGestureRecognizer.velocity(in: self)
        var velocity = isDragging ? panVelocity : offsetVelocity
        if isSingleColumnFeed {
            velocity.x = 0
        }
        let normalized = CGPoint(
            x: min(1, max(-1, velocity.x / 1_800)),
            y: min(1, max(-1, velocity.y / 1_800))
        )
        let smoothing = CGFloat(1 - exp(-elapsed * 14))
        smoothedMotionVelocity = CGPoint(
            x: smoothedMotionVelocity.x + (normalized.x - smoothedMotionVelocity.x) * smoothing,
            y: smoothedMotionVelocity.y + (normalized.y - smoothedMotionVelocity.y) * smoothing
        )
        driveOrb(withVisualVelocity: velocity)
        let visibleRect = CGRect(
            x: contentOffset.x / zoomScale - 80,
            y: contentOffset.y / zoomScale - 80,
            width: bounds.width / zoomScale + 160,
            height: bounds.height / zoomScale + 160
        )

        for slot in tileSlots where !slot.button.isHidden
            && slot.button.restingFrame.intersects(visibleRect) {
            slot.button.applyScrollMotion(normalizedVelocity: smoothedMotionVelocity)
        }
        lastMotionOffset = contentOffset
        lastMotionTimestamp = now
    }

    private func settleTileDynamics() {
        smoothedMotionVelocity = .zero
        setOrbMotionTarget(.zero)
        for slot in tileSlots where slot.button.hasMotion {
            slot.button.settleScrollMotion()
        }
    }

    private func softLimit(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        limit * tanh(value / limit)
    }

    private func driveOrb(withVisualVelocity velocity: CGPoint) {
        // Keep a wider velocity range for the orb than the product tiles.
        // The soft limit preserves the difference between a drag and a flick
        // without letting a very fast gesture throw the control off-screen.
        let elasticTarget = CGPoint(
            x: softLimit(velocity.x / 1_150, limit: 1.55),
            y: softLimit(velocity.y / 1_250, limit: 1.48)
        )
        setOrbMotionTarget(
            CGPoint(x: elasticTarget.x * 0.82, y: elasticTarget.y * 0.78),
            elasticTarget: elasticTarget
        )
    }

    private func setOrbMotionTarget(
        _ target: CGPoint,
        elasticTarget: CGPoint? = nil
    ) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            orbMotionTarget = .zero
            orbMotionPosition = .zero
            orbMotionVelocity = .zero
            orbElasticTarget = .zero
            orbElasticPosition = .zero
            orbElasticVelocity = .zero
            onViewportMotion?(.zero)
            return
        }
        orbMotionTarget = CGPoint(
            x: min(1.25, max(-1.25, target.x)),
            y: min(1.2, max(-1.2, target.y))
        )
        let elasticTarget = elasticTarget ?? target
        orbElasticTarget = CGPoint(
            x: min(1.55, max(-1.55, elasticTarget.x)),
            y: min(1.48, max(-1.48, elasticTarget.y))
        )
        guard orbMotionDisplayLink == nil else { return }
        lastOrbMotionTimestamp = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(updateOrbMotion(_:)))
        link.add(to: .main, forMode: .common)
        orbMotionDisplayLink = link
    }

    @objc private func updateOrbMotion(_ displayLink: CADisplayLink) {
        let timestamp = displayLink.timestamp
        let elapsed = min(1.0 / 30.0, max(1.0 / 240.0, timestamp - lastOrbMotionTimestamp))
        lastOrbMotionTimestamp = timestamp

        // Independent spring/friction on each axis keeps the orb loosely
        // tethered to the viewport instead of copying the scroll offset.
        let accelerationX = (orbMotionTarget.x - orbMotionPosition.x) * 24
        let accelerationY = (orbMotionTarget.y - orbMotionPosition.y) * 20
        orbMotionVelocity.x = (orbMotionVelocity.x + accelerationX * elapsed)
            * exp(-6.8 * elapsed)
        orbMotionVelocity.y = (orbMotionVelocity.y + accelerationY * elapsed)
            * exp(-6.1 * elapsed)
        orbMotionPosition.x += orbMotionVelocity.x * elapsed
        orbMotionPosition.y += orbMotionVelocity.y * elapsed
        orbMotionPosition.x = min(1.28, max(-1.28, orbMotionPosition.x))
        orbMotionPosition.y = min(1.22, max(-1.22, orbMotionPosition.y))

        // A second, slightly under-damped spring carries the physical pan
        // velocity. It holds a directional stretch during motion, then crosses
        // zero once on release for a soft recoil before coming to rest.
        let elasticAccelerationX = (orbElasticTarget.x - orbElasticPosition.x) * 64
        let elasticAccelerationY = (orbElasticTarget.y - orbElasticPosition.y) * 58
        orbElasticVelocity.x = (orbElasticVelocity.x + elasticAccelerationX * elapsed)
            * exp(-10.8 * elapsed)
        orbElasticVelocity.y = (orbElasticVelocity.y + elasticAccelerationY * elapsed)
            * exp(-10.2 * elapsed)
        orbElasticPosition.x += orbElasticVelocity.x * elapsed
        orbElasticPosition.y += orbElasticVelocity.y * elapsed
        orbElasticPosition.x = min(1.62, max(-1.62, orbElasticPosition.x))
        orbElasticPosition.y = min(1.55, max(-1.55, orbElasticPosition.y))

        let elasticSpeed = min(1.65, hypot(orbElasticPosition.x, orbElasticPosition.y))
        onViewportMotion?(
            CanvasOrbMotion(
                displacement: CGSize(
                    width: orbMotionPosition.x,
                    height: orbMotionPosition.y
                ),
                velocity: CGSize(
                    width: orbElasticPosition.x,
                    height: orbElasticPosition.y
                ),
                speed: elasticSpeed
            )
        )

        let targetEnergy = hypot(orbMotionTarget.x, orbMotionTarget.y)
        let positionEnergy = hypot(orbMotionPosition.x, orbMotionPosition.y)
        let velocityEnergy = hypot(orbMotionVelocity.x, orbMotionVelocity.y)
        let elasticTargetEnergy = hypot(orbElasticTarget.x, orbElasticTarget.y)
        let elasticPositionEnergy = hypot(orbElasticPosition.x, orbElasticPosition.y)
        let elasticVelocityEnergy = hypot(orbElasticVelocity.x, orbElasticVelocity.y)
        guard targetEnergy < 0.001,
              positionEnergy < 0.003,
              velocityEnergy < 0.01,
              elasticTargetEnergy < 0.001,
              elasticPositionEnergy < 0.003,
              elasticVelocityEnergy < 0.01 else { return }

        orbMotionPosition = .zero
        orbMotionVelocity = .zero
        orbElasticPosition = .zero
        orbElasticVelocity = .zero
        onViewportMotion?(.zero)
        orbMotionDisplayLink?.invalidate()
        orbMotionDisplayLink = nil
    }

    private func visibleBands() -> ViewportBands {
        guard zoomScale > 0, !productIDs.isEmpty else { return ViewportBands() }
        let viewport = CGRect(
            x: contentOffset.x / zoomScale,
            y: contentOffset.y / zoomScale,
            width: bounds.width / zoomScale,
            height: bounds.height / zoomScale
        )
        var bands = ViewportBands()

        for slot in tileSlots where !slot.button.isHidden {
            let frame = slot.button.restingFrame
            let intersection = frame.intersection(viewport)
            guard !intersection.isNull else { continue }
            let visibleArea = intersection.width * intersection.height
            let tileArea = max(1, frame.width * frame.height)
            guard visibleArea / tileArea >= 0.08 else { continue }
            // Row and column are canonical across the repeated panels, so the
            // invisible infinite-canvas recenter never produces a false band.
            bands.rows.insert(slot.row)
            bands.columns.insert(slot.column)
        }

        return bands
    }

    private var dominantHapticAxis: ViewportHapticAxis? {
        var velocity = smoothedMotionVelocity
        if max(abs(velocity.x), abs(velocity.y)) < 0.01 {
            let panVelocity = panGestureRecognizer.velocity(in: self)
            velocity = CGPoint(x: panVelocity.x / 1_800, y: panVelocity.y / 1_800)
        }
        if isSingleColumnFeed {
            velocity.x = 0
        }
        guard max(abs(velocity.x), abs(velocity.y)) >= 0.01 else { return nil }
        return abs(velocity.x) >= abs(velocity.y) ? .columns : .rows
    }

    private func resetMotionTracking() {
        lastMotionOffset = contentOffset
        lastMotionTimestamp = CACurrentMediaTime()
        smoothedMotionVelocity = .zero
    }

    private func setCanvasInteractionScaled(_ scaled: Bool) {
        guard scaled != isCanvasInteractionScaled else { return }
        isCanvasInteractionScaled = scaled

        if let canvasInteractionAnimator {
            canvasInteractionAnimator.stopAnimation(false)
            canvasInteractionAnimator.finishAnimation(at: .current)
            self.canvasInteractionAnimator = nil
        }
        if scaled {
            anchorCanvasInteractionToViewport()
        }

        let animator = UIViewPropertyAnimator(
            duration: scaled ? 0.2 : 0.46,
            dampingRatio: scaled ? 0.9 : 0.78
        ) {
            self.canvasInteractionView.transform = scaled
                ? CGAffineTransform(scaleX: 0.975, y: 0.975)
                : .identity
        }
        animator.addCompletion { [weak self] position in
            guard let self,
                  position == .end,
                  self.isCanvasInteractionScaled == scaled else { return }
            self.canvasInteractionAnimator = nil
            if !scaled {
                self.setAnchorPoint(CGPoint(x: 0.5, y: 0.5), for: self.canvasInteractionView)
            }
        }
        canvasInteractionAnimator = animator
        animator.startAnimation()
    }

    private func anchorCanvasInteractionToViewport() {
        guard zoomScale > 0,
              canvasInteractionView.bounds.width > 0,
              canvasInteractionView.bounds.height > 0 else { return }
        let viewportCenter = CGPoint(
            x: (contentOffset.x + bounds.width / 2) / zoomScale,
            y: (contentOffset.y + bounds.height / 2) / zoomScale
        )
        let anchor = CGPoint(
            x: min(1, max(0, viewportCenter.x / canvasInteractionView.bounds.width)),
            y: min(1, max(0, viewportCenter.y / canvasInteractionView.bounds.height))
        )
        setAnchorPoint(anchor, for: canvasInteractionView)
    }

    private func setAnchorPoint(_ anchorPoint: CGPoint, for view: UIView) {
        var newPoint = CGPoint(
            x: view.bounds.width * anchorPoint.x,
            y: view.bounds.height * anchorPoint.y
        )
        var oldPoint = CGPoint(
            x: view.bounds.width * view.layer.anchorPoint.x,
            y: view.bounds.height * view.layer.anchorPoint.y
        )
        newPoint = newPoint.applying(view.transform)
        oldPoint = oldPoint.applying(view.transform)

        var position = view.layer.position
        position.x += newPoint.x - oldPoint.x
        position.y += newPoint.y - oldPoint.y
        view.layer.position = position
        view.layer.anchorPoint = anchorPoint
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        canvasContentView
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        cancelShowcaseForInteraction()
        onInteraction?()
        canvasPressFeedback.impactOccurred(intensity: 1)
        setCanvasInteractionScaled(true)
        resetMotionTracking()
        viewportHaptics.beginInteraction(visibleBands: visibleBands())
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        cancelShowcaseForInteraction()
        onInteraction?()
        setCanvasInteractionScaled(false)
        resetMotionTracking()
        viewportHaptics.endInteraction()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        recenterIfNeeded()
        prioritizeViewportImageLoads()
        if isDragging || isDecelerating || isShowcasing {
            updateTileDynamics()
        }
        viewportHaptics.update(
            visibleBands: visibleBands(),
            axis: dominantHapticAxis,
            emitsFeedback: (isDragging || isDecelerating) && !isZooming && !isRecentering
        )
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        prioritizeViewportImageLoads()
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        setCanvasInteractionScaled(false)
        if isSingleColumnFeed {
            targetContentOffset.pointee = constrainedSingleColumnOffset(
                targetContentOffset.pointee
            )
            return
        }
        let columns = nearestVisibleColumnCount(to: zoomScale)
        let predictedCenterX = (targetContentOffset.pointee.x + bounds.width / 2) / max(zoomScale, 0.01)
        let alignedCenterX = alignedHorizontalCenter(near: predictedCenterX, visibleColumns: columns)
        targetContentOffset.pointee.x = alignedCenterX * zoomScale - bounds.width / 2
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        setCanvasInteractionScaled(false)
        canvasPressFeedback.prepare()
        if !decelerate {
            viewportHaptics.endInteraction()
            snapHorizontalOffset(animated: true)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // The final column target is chosen in scrollViewWillEndDragging.
        // Do not correct it again after momentum has visibly come to rest.
        settleTileDynamics()
        resetMotionTracking()
        viewportHaptics.endInteraction()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        settleTileDynamics()
        resetMotionTracking()
        viewportHaptics.endInteraction()
        viewportHaptics.update(visibleBands: visibleBands(), axis: nil, emitsFeedback: false)
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        guard !isSettlingZoom else { return }
        recenterIfNeeded()
        settleZoom(toVisibleColumns: nearestVisibleColumnCount(to: scale))
    }
}

private final class ViewportHapticWheel {
    private static let minimumTickInterval: CFTimeInterval = 0.06

    private let feedback = UISelectionFeedbackGenerator()
    private var visibleBands = ViewportBands()
    private var hasBaseline = false
    private var pendingTicks = 0
    private var lastTickTime: CFTimeInterval = 0
    private var scheduledTick: DispatchWorkItem?

    deinit {
        scheduledTick?.cancel()
    }

    func beginInteraction(visibleBands: ViewportBands) {
        cancelPendingTicks()
        self.visibleBands = visibleBands
        hasBaseline = true
        feedback.prepare()
    }

    func update(
        visibleBands newVisibleBands: ViewportBands,
        axis: ViewportHapticAxis?,
        emitsFeedback: Bool
    ) {
        guard hasBaseline else {
            visibleBands = newVisibleBands
            hasBaseline = true
            return
        }

        let enteringCount: Int
        switch axis {
        case .rows:
            enteringCount = newVisibleBands.rows.subtracting(visibleBands.rows).count
        case .columns:
            enteringCount = newVisibleBands.columns.subtracting(visibleBands.columns).count
        case nil:
            enteringCount = 0
        }
        visibleBands = newVisibleBands

        guard emitsFeedback else {
            cancelPendingTicks()
            return
        }
        guard enteringCount > 0 else { return }

        // A fast fling can cross several bands in a single display frame. Keep
        // one notch per row or column, capped so the texture never becomes a buzz.
        pendingTicks = min(3, pendingTicks + enteringCount)
        deliverNextTickWhenReady()
    }

    func endInteraction() {
        cancelPendingTicks()
    }

    private func deliverNextTickWhenReady() {
        guard pendingTicks > 0, scheduledTick == nil else { return }
        let elapsed = CACurrentMediaTime() - lastTickTime
        let delay = max(0, Self.minimumTickInterval - elapsed)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.scheduledTick = nil
            guard self.pendingTicks > 0 else { return }
            self.pendingTicks -= 1
            self.lastTickTime = CACurrentMediaTime()
            self.feedback.selectionChanged()
            self.feedback.prepare()
            self.deliverNextTickWhenReady()
        }
        scheduledTick = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelPendingTicks() {
        scheduledTick?.cancel()
        scheduledTick = nil
        pendingTicks = 0
    }
}

private final class CanvasProductButton: UIControl {
    private struct TransitionBackdrop {
        let view: UIView
        let image: UIImage
    }

    private static let transitionCIContext = CIContext(options: [
        .cacheIntermediates: false,
    ])
    private let voiceEntranceView = UIView()
    private let surfaceView = UIView()
    private let imageView = UIImageView()
    private let productDataView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemUltraThinMaterialLight)
    )
    private let productTitleLabel = UILabel()
    private let productMetadataLabel = UILabel()
    private let voicePointerView = UIView()
    private let voicePointerLabel = UILabel()
    private let voicePointerIcon = UIImageView()
    private let pressFeedback = UIImpactFeedbackGenerator(style: .soft)
    private let releaseFeedback = UIImpactFeedbackGenerator(style: .rigid)
    private let contextMenuFeedback = UIImpactFeedbackGenerator(style: .rigid)
    private var imageTask: Task<Void, Never>?
    private var imageTaskPriority: TaskPriority?
    private var imageRetryWorkItem: DispatchWorkItem?
    private var imageLoadGeneration = 0
    private var imageFailureCount = 0
    private var representedURL: URL?
    private var completedImageURL: URL?
    private var motionTransform = CGAffineTransform.identity
    private var motionDepth: CGFloat = 1
    private var queryTransitionAlpha: CGFloat = 1
    private var queryTransitionScale: CGFloat = 1
    private var canvasPlayAlpha: CGFloat = 1
    private var canvasPlayTransform = CGAffineTransform.identity
    private var canvasPlayZPosition: CGFloat = 0
    private var isVoiceHighlighted = false
    private var isVoicePointed = false
    private var isCanvasSpotlighted = false
    private var isTouchTracking = false
    private var isOpeningProduct = false

    var product: CatalogProduct?
    var onTap: ((ProductTransitionSource?) -> Void)?
    var onRequestSimilar: (() -> Void)?
    var onRemove: (() -> Void)?
    var onTouchBegan: (() -> Void)?
    var restingFrame: CGRect {
        CGRect(
            x: center.x - bounds.width / 2,
            y: center.y - bounds.height / 2,
            width: bounds.width,
            height: bounds.height
        )
    }
    var hasMotion: Bool { !motionTransform.isIdentity }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "Try this") { [weak self] _ in
                guard let self, self.product != nil else { return false }
                self.tapped()
                return true
            },
            UIAccessibilityCustomAction(name: "More like this") { [weak self] _ in
                guard let self, self.product != nil else { return false }
                self.requestSimilarProducts()
                return true
            },
            UIAccessibilityCustomAction(name: "Remove from canvas") { [weak self] _ in
                guard let self, self.product != nil else { return false }
                self.requestRemoval()
                return true
            },
        ]
        addInteraction(UIContextMenuInteraction(delegate: self))
        voiceEntranceView.isUserInteractionEnabled = false
        voiceEntranceView.alpha = 0
        voiceEntranceView.transform = CGAffineTransform(scaleX: 0.58, y: 0.58)
        voiceEntranceView.layer.shadowColor = UIColor.black.cgColor
        voiceEntranceView.layer.shadowOpacity = 0.075
        voiceEntranceView.layer.shadowRadius = 13
        voiceEntranceView.layer.shadowOffset = CGSize(width: 0, height: 7)
        addSubview(voiceEntranceView)

        surfaceView.isUserInteractionEnabled = false
        surfaceView.clipsToBounds = true
        surfaceView.layer.cornerRadius = 20
        surfaceView.layer.cornerCurve = .continuous
        voiceEntranceView.addSubview(surfaceView)

        imageView.frame = surfaceView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFill
        imageView.transform = CGAffineTransform(scaleX: 1.008, y: 1.008)
        surfaceView.addSubview(imageView)

        productDataView.isUserInteractionEnabled = false
        productDataView.alpha = 0
        productDataView.transform = CGAffineTransform(translationX: 0, y: 8)
            .scaledBy(x: 0.96, y: 0.96)
        productDataView.clipsToBounds = true
        productDataView.layer.cornerRadius = 14
        productDataView.layer.cornerCurve = .continuous
        productDataView.contentView.backgroundColor = UIColor.white.withAlphaComponent(0.46)
        surfaceView.addSubview(productDataView)

        productTitleLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        productTitleLabel.textColor = UIColor.black.withAlphaComponent(0.88)
        productTitleLabel.lineBreakMode = .byTruncatingTail
        productTitleLabel.numberOfLines = 1
        productDataView.contentView.addSubview(productTitleLabel)

        productMetadataLabel.font = .systemFont(ofSize: 10.5, weight: .medium)
        productMetadataLabel.textColor = UIColor.black.withAlphaComponent(0.58)
        productMetadataLabel.lineBreakMode = .byTruncatingTail
        productMetadataLabel.numberOfLines = 1
        productMetadataLabel.adjustsFontSizeToFitWidth = true
        productMetadataLabel.minimumScaleFactor = 0.84
        productDataView.contentView.addSubview(productMetadataLabel)

        voicePointerView.isUserInteractionEnabled = false
        voicePointerView.isAccessibilityElement = false
        voicePointerView.backgroundColor = UIColor(
            red: 0.25,
            green: 0.3,
            blue: 0.96,
            alpha: 0.96
        )
        voicePointerView.layer.cornerRadius = 15
        voicePointerView.layer.cornerCurve = .continuous
        voicePointerView.layer.shadowColor = UIColor.black.cgColor
        voicePointerView.layer.shadowOpacity = 0.2
        voicePointerView.layer.shadowRadius = 10
        voicePointerView.layer.shadowOffset = CGSize(width: 0, height: 5)
        voicePointerView.alpha = 0
        voicePointerView.transform = CGAffineTransform(
            translationX: 0,
            y: 4
        ).scaledBy(x: 0.25, y: 0.25)
        voiceEntranceView.addSubview(voicePointerView)

        voicePointerLabel.text = "Here"
        voicePointerLabel.font = .systemFont(ofSize: 12, weight: .bold)
        voicePointerLabel.textColor = .white
        voicePointerLabel.textAlignment = .center
        voicePointerView.addSubview(voicePointerLabel)

        voicePointerIcon.image = UIImage(
            systemName: "arrow.down",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        )
        voicePointerIcon.tintColor = .white
        voicePointerIcon.contentMode = .center
        voicePointerView.addSubview(voicePointerIcon)

        addTarget(self, action: #selector(pressedDown), for: .touchDown)
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        imageTask?.cancel()
        imageRetryWorkItem?.cancel()
    }

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let product, !isOpeningProduct else { return nil }

        isTouchTracking = false
        settleSurfaceMotion()
        contextMenuFeedback.impactOccurred(intensity: 1)
        contextMenuFeedback.prepare()

        return UIContextMenuConfiguration(
            identifier: product.id as NSString,
            previewProvider: nil
        ) { [weak self] _ in
            guard let self else { return nil }
            let tryAction = UIAction(
                title: "View product",
                image: UIImage(systemName: "bag")
            ) { [weak self] _ in
                self?.tapped()
            }
            let similarAction = UIAction(
                title: "More like this",
                image: UIImage(systemName: "square.grid.2x2")
            ) { [weak self] _ in
                self?.requestSimilarProducts()
            }
            let removeAction = UIAction(
                title: "Remove from canvas",
                image: UIImage(systemName: "eye.slash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.requestRemoval()
            }
            return UIMenu(children: [tryAction, similarAction, removeAction])
        }
    }

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        contextMenuPreview()
    }

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        contextMenuPreview()
    }

    private func contextMenuPreview() -> UITargetedPreview {
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(
            roundedRect: surfaceView.bounds,
            cornerRadius: surfaceView.layer.cornerRadius
        )
        return UITargetedPreview(view: surfaceView, parameters: parameters)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        voiceEntranceView.bounds = bounds
        voiceEntranceView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        surfaceView.bounds = bounds
        surfaceView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        imageView.bounds = surfaceView.bounds
        imageView.center = CGPoint(x: surfaceView.bounds.midX, y: surfaceView.bounds.midY)

        let dataInset = min(10, max(7, bounds.width * 0.055))
        let dataHeight: CGFloat = 50
        productDataView.bounds = CGRect(
            origin: .zero,
            size: CGSize(
                width: max(0, bounds.width - dataInset * 2),
                height: dataHeight
            )
        )
        productDataView.center = CGPoint(
            x: bounds.midX,
            y: max(
                dataInset + dataHeight / 2,
                bounds.height - dataInset - dataHeight / 2
            )
        )
        let labelWidth = max(0, productDataView.bounds.width - 20)
        productTitleLabel.frame = CGRect(x: 10, y: 7, width: labelWidth, height: 18)
        productMetadataLabel.frame = CGRect(x: 10, y: 26, width: labelWidth, height: 16)

        voicePointerView.bounds = CGRect(x: 0, y: 0, width: 64, height: 30)
        voicePointerView.center = CGPoint(x: bounds.midX, y: 1)
        voicePointerLabel.frame = CGRect(x: 10, y: 0, width: 34, height: 30)
        voicePointerIcon.frame = CGRect(x: 42, y: 0, width: 14, height: 30)

        voiceEntranceView.layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: 20
        ).cgPath
    }

    override var isHighlighted: Bool {
        didSet {
            guard !isOpeningProduct else { return }
            let duration = isHighlighted ? 0.11 : 0.24
            let damping: CGFloat = isHighlighted ? 1 : 0.72
            UIView.animate(
                withDuration: duration,
                delay: 0,
                usingSpringWithDamping: damping,
                initialSpringVelocity: isHighlighted ? 0 : 0.62,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                self.transform = self.presentedTransform
                self.applyShadow(isPressed: self.isHighlighted)
            }
        }
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let tracks = super.beginTracking(touch, with: event)
        if tracks {
            onTouchBegan?()
        }
        guard tracks, !UIAccessibility.isReduceMotionEnabled else { return tracks }
        isTouchTracking = true
        applyTouchSurface(at: touch.location(in: self))
        return tracks
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let tracks = super.continueTracking(touch, with: event)
        guard tracks, isTouchTracking, !UIAccessibility.isReduceMotionEnabled else { return tracks }
        applyTouchSurface(at: touch.location(in: self))
        return tracks
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)
        isTouchTracking = false
        settleSurfaceMotion()
    }

    override func cancelTracking(with event: UIEvent?) {
        super.cancelTracking(with: event)
        isTouchTracking = false
        settleSurfaceMotion()
    }

    func configureDynamics(depth: CGFloat) {
        motionDepth = depth
    }

    func setQueryAppearance(alpha: CGFloat, scale: CGFloat) {
        queryTransitionAlpha = alpha
        queryTransitionScale = scale
        self.alpha = queryTransitionAlpha * canvasPlayAlpha
        transform = presentedTransform
    }

    func setCanvasPlayAppearance(
        alpha: CGFloat,
        transform: CGAffineTransform,
        zPosition: CGFloat
    ) {
        canvasPlayAlpha = alpha
        canvasPlayTransform = transform
        canvasPlayZPosition = zPosition
        self.alpha = queryTransitionAlpha * canvasPlayAlpha
        self.transform = presentedTransform
        layer.zPosition = isVoiceHighlighted ? 1_000 : canvasPlayZPosition
    }

    func resetCanvasPlayAppearance() {
        voiceEntranceView.layer.removeAnimation(forKey: "shopdrop.canvas-flip")
        setCanvasPlayAppearance(alpha: 1, transform: .identity, zPosition: 0)
    }

    func setCanvasSpotlighted(_ spotlighted: Bool) {
        guard isCanvasSpotlighted != spotlighted else { return }
        isCanvasSpotlighted = spotlighted
        productDataView.alpha = spotlighted || isVoiceHighlighted ? 1 : 0
        productDataView.transform = spotlighted || isVoiceHighlighted
            ? .identity
            : CGAffineTransform(translationX: 0, y: 7).scaledBy(x: 0.97, y: 0.97)
        voiceEntranceView.layer.shadowColor = isVoiceHighlighted
            ? UIColor(red: 0.28, green: 0.34, blue: 1, alpha: 1).cgColor
            : UIColor.black.cgColor
        voiceEntranceView.layer.shadowOpacity = spotlighted ? 0.34 : 0.075
        voiceEntranceView.layer.shadowRadius = spotlighted ? 30 : 13
        voiceEntranceView.layer.shadowOffset = spotlighted
            ? CGSize(width: 0, height: 16)
            : CGSize(width: 0, height: 7)
    }

    func playCanvasFlip(afterDelay delay: TimeInterval) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        var start = CATransform3DIdentity
        start.m34 = -1 / 780
        var quarter = start
        quarter = CATransform3DRotate(quarter, .pi * 0.5, 0, 1, 0)
        var threeQuarter = start
        threeQuarter = CATransform3DRotate(threeQuarter, .pi * 1.5, 0, 1, 0)
        var full = start
        full = CATransform3DRotate(full, .pi * 2, 0, 1, 0)

        let flip = CAKeyframeAnimation(keyPath: "transform")
        flip.values = [
            NSValue(caTransform3D: start),
            NSValue(caTransform3D: quarter),
            NSValue(caTransform3D: threeQuarter),
            NSValue(caTransform3D: full),
        ]
        flip.keyTimes = [0, 0.28, 0.72, 1]
        flip.duration = 0.78
        flip.beginTime = CACurrentMediaTime() + delay
        flip.timingFunctions = [
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeOut),
        ]
        voiceEntranceView.layer.add(flip, forKey: "shopdrop.canvas-flip")
    }

    func setVoiceEntranceAppearance(
        alpha: CGFloat,
        scale: CGFloat,
        translation: CGPoint
    ) {
        voiceEntranceView.alpha = alpha
        voiceEntranceView.transform = CGAffineTransform(
            translationX: translation.x,
            y: translation.y
        ).scaledBy(x: scale, y: scale)
    }

    func prepareForVoiceEntrance() {
        layer.removeAllAnimations()
        setQueryAppearance(alpha: 1, scale: 1)
    }

    func setVoiceHighlighted(_ highlighted: Bool) {
        guard highlighted != isVoiceHighlighted else { return }
        isVoiceHighlighted = highlighted
        voiceEntranceView.layer.removeAnimation(forKey: "shopdrop.voice-highlight")
        if highlighted {
            layer.zPosition = 1_000
        }

        let changes = {
            self.transform = self.presentedTransform
            let showsDetails = highlighted || self.isCanvasSpotlighted
            self.productDataView.alpha = showsDetails ? 1 : 0
            self.productDataView.transform = showsDetails
                ? .identity
                : CGAffineTransform(translationX: 0, y: 7).scaledBy(x: 0.97, y: 0.97)
            self.voiceEntranceView.layer.shadowColor = highlighted
                ? UIColor(red: 0.28, green: 0.34, blue: 1, alpha: 1).cgColor
                : UIColor.black.cgColor
            self.voiceEntranceView.layer.shadowOpacity = highlighted
                ? 0.28
                : (self.isHighlighted ? 0.025 : 0.075)
            self.voiceEntranceView.layer.shadowRadius = highlighted
                ? 24
                : (self.isHighlighted ? 3 : 13)
            self.voiceEntranceView.layer.shadowOffset = highlighted
                ? CGSize(width: 0, height: 8)
                : (self.isHighlighted ? CGSize(width: 0, height: 1) : CGSize(width: 0, height: 7))
        }

        guard !UIAccessibility.isReduceMotionEnabled else {
            changes()
            if !highlighted {
                layer.zPosition = 0
            }
            return
        }
        UIView.animate(
            withDuration: highlighted ? 0.42 : 0.3,
            delay: 0,
            usingSpringWithDamping: highlighted ? 0.7 : 0.86,
            initialSpringVelocity: highlighted ? 0.55 : 0.2,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: changes
        ) { [weak self] _ in
            guard let self, !self.isVoiceHighlighted else { return }
            self.layer.zPosition = self.canvasPlayZPosition
        }

        guard highlighted else { return }
        let pulse = CABasicAnimation(keyPath: "shadowOpacity")
        pulse.fromValue = 0.18
        pulse.toValue = 0.38
        pulse.duration = 0.72
        pulse.autoreverses = true
        pulse.repeatCount = 3
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        voiceEntranceView.layer.add(pulse, forKey: "shopdrop.voice-highlight")
    }

    func setVoicePointed(_ pointed: Bool) {
        guard pointed != isVoicePointed else { return }
        isVoicePointed = pointed
        voicePointerView.layer.removeAllAnimations()

        let hiddenTransform = CGAffineTransform(
            translationX: 0,
            y: pointed ? 4 : -4
        ).scaledBy(x: pointed ? 0.25 : 0.92, y: pointed ? 0.25 : 0.92)
        if pointed {
            voicePointerView.alpha = 0
            voicePointerView.transform = hiddenTransform
        }
        let changes = {
            self.voicePointerView.alpha = pointed ? 1 : 0
            self.voicePointerView.transform = pointed ? .identity : hiddenTransform
        }
        accessibilityHint = pointed
            ? "ShopDrop is pointing here. \(product?.tryKind.actionTitle ?? "Open product")"
            : product?.tryKind.actionTitle

        guard !UIAccessibility.isReduceMotionEnabled else {
            changes()
            return
        }
        UIView.animate(
            withDuration: pointed ? 0.3 : 0.2,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: changes
        )
    }

    func applyScrollMotion(normalizedVelocity: CGPoint) {
        let speed = min(1, hypot(normalizedVelocity.x, normalizedVelocity.y))
        let translation = CGAffineTransform(
            translationX: normalizedVelocity.x * 4.5 * motionDepth,
            y: normalizedVelocity.y * 3 * motionDepth
        )
        let rotation = normalizedVelocity.x * 0.008 * motionDepth
        let scale = 1 - speed * 0.006
        motionTransform = translation.rotated(by: rotation).scaledBy(x: scale, y: scale)

        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / 900
        perspective = CATransform3DRotate(
            perspective,
            -normalizedVelocity.y * 0.018 * motionDepth,
            1,
            0,
            0
        )
        perspective = CATransform3DRotate(
            perspective,
            normalizedVelocity.x * 0.024 * motionDepth,
            0,
            1,
            0
        )
        UIView.performWithoutAnimation {
            transform = presentedTransform
            surfaceView.layer.transform = perspective
            imageView.transform = CGAffineTransform(
                translationX: -normalizedVelocity.x * 1.1,
                y: -normalizedVelocity.y * 0.8
            ).scaledBy(x: 1.012, y: 1.012)
        }
    }

    func settleScrollMotion() {
        guard hasMotion else { return }
        motionTransform = .identity
        let changes = {
            self.transform = self.presentedTransform
            self.resetSurfaceMotion()
        }
        guard !UIAccessibility.isReduceMotionEnabled else {
            changes()
            return
        }
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.28,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            changes()
        }
    }

    private func applyTouchSurface(at location: CGPoint) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let x = min(1, max(-1, (location.x / bounds.width - 0.5) * 2))
        let y = min(1, max(-1, (location.y / bounds.height - 0.5) * 2))
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / 850
        perspective = CATransform3DRotate(perspective, -y * 0.026, 1, 0, 0)
        perspective = CATransform3DRotate(perspective, x * 0.032, 0, 1, 0)
        UIView.performWithoutAnimation {
            surfaceView.layer.transform = perspective
            imageView.transform = CGAffineTransform(
                translationX: -x * 1.15,
                y: -y * 0.9
            ).scaledBy(x: 1.012, y: 1.012)
        }
    }

    private func settleSurfaceMotion() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            resetSurfaceMotion()
            return
        }
        UIView.animate(
            withDuration: 0.38,
            delay: 0,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.34,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.resetSurfaceMotion()
        }
    }

    private func resetSurfaceMotion() {
        surfaceView.layer.transform = CATransform3DIdentity
        imageView.transform = CGAffineTransform(scaleX: 1.008, y: 1.008)
    }

    private var presentedTransform: CGAffineTransform {
        transform(isPressed: isHighlighted)
    }

    private func transform(isPressed: Bool) -> CGAffineTransform {
        let pressScale: CGFloat = isPressed ? 0.96 : 1
        let highlightScale: CGFloat = isVoiceHighlighted ? 1.08 : 1
        let scale = pressScale * highlightScale * queryTransitionScale
        let lift: CGFloat = isVoiceHighlighted ? -7 : 0
        let translated = motionTransform.translatedBy(x: 0, y: lift + (isPressed ? 2 : 0))
        return translated
            .scaledBy(x: scale, y: scale)
            .concatenating(canvasPlayTransform)
    }

    private func applyShadow(isPressed: Bool) {
        guard !isVoiceHighlighted, !isCanvasSpotlighted else { return }
        voiceEntranceView.layer.shadowOpacity = isPressed ? 0.025 : 0.075
        voiceEntranceView.layer.shadowRadius = isPressed ? 3 : 13
        voiceEntranceView.layer.shadowOffset = isPressed
            ? CGSize(width: 0, height: 1)
            : CGSize(width: 0, height: 7)
    }

    func configure(with product: CatalogProduct) {
        self.product = product
        accessibilityLabel = "\(product.title), \(product.formattedPrice), from \(product.merchant)"
        accessibilityHint = product.tryKind.actionTitle
        productTitleLabel.text = product.title
        productMetadataLabel.text = "\(product.merchant)  •  \(product.formattedPrice)"
        surfaceView.backgroundColor = UIColor(hex: product.accentHex).withAlphaComponent(0.11)
        prepareForImageReveal()

        guard representedURL != product.imageURL else {
            if completedImageURL == product.imageURL {
                revealLoadedImage(for: product.imageURL)
            }
            return
        }
        representedURL = product.imageURL
        completedImageURL = nil
        imageLoadGeneration += 1
        imageFailureCount = 0
        imageTask?.cancel()
        imageTask = nil
        imageTaskPriority = nil
        imageRetryWorkItem?.cancel()
        imageRetryWorkItem = nil
        imageView.image = nil
        imageView.alpha = 0
        imageView.backgroundColor = .clear
    }

    func loadImageIfNeeded(priority: TaskPriority) {
        guard let url = representedURL else { return }
        if completedImageURL == url {
            revealLoadedImage(for: url)
            return
        }
        if imageTask != nil {
            guard priority.rawValue > (imageTaskPriority?.rawValue ?? 0) else { return }
            imageTask?.cancel()
            imageTask = nil
        }

        imageRetryWorkItem?.cancel()
        imageRetryWorkItem = nil
        imageLoadGeneration += 1
        let generation = imageLoadGeneration
        imageTaskPriority = priority
        imageTask = Task(priority: priority) { [weak self] in
            let image = await CanvasImageRepository.shared.image(for: url, priority: priority)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self,
                      self.representedURL == url,
                      self.imageLoadGeneration == generation else { return }
                self.imageTask = nil
                self.imageTaskPriority = nil
                guard let image else {
                    self.handleImageFailure(for: url, priority: priority)
                    return
                }
                self.imageFailureCount = 0
                self.imageView.image = image
                self.completedImageURL = url
                self.revealLoadedImage(for: url)
            }
        }
    }

    private func handleImageFailure(for url: URL, priority: TaskPriority) {
        guard representedURL == url else { return }
        imageFailureCount += 1
        // A failed download should never leave an invisible hole in the grid.
        // Keep the accent placeholder visible while retrying transient errors.
        revealLoadedImage(for: url)
        guard imageFailureCount <= 3 else { return }

        let delay = min(2.4, 0.55 * pow(2, Double(imageFailureCount - 1)))
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.representedURL == url,
                  self.completedImageURL != url,
                  self.isVisibleInViewport else { return }
            self.imageRetryWorkItem = nil
            self.loadImageIfNeeded(priority: priority)
        }
        imageRetryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    var hasResolvedImage: Bool {
        representedURL != nil && completedImageURL == representedURL
    }

    private func prepareForImageReveal() {
        // A network image may still be loading, but its physical card must
        // already occupy the infinite field. Only the image fades in; the
        // accent placeholder never disappears beneath the user's finger.
        isUserInteractionEnabled = true
        layer.removeAllAnimations()
        setQueryAppearance(alpha: 1, scale: 1)
    }

    private func revealLoadedImage(for url: URL) {
        guard representedURL == url else { return }
        let changes = {
            self.imageView.alpha = 1
            self.setQueryAppearance(alpha: 1, scale: 1)
        }
        guard !UIAccessibility.isReduceMotionEnabled, isVisibleInViewport else {
            changes()
            isUserInteractionEnabled = true
            return
        }

        UIView.animate(
            withDuration: 0.48,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.22,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut],
            animations: changes
        ) { [weak self] _ in
            guard let self, self.representedURL == url else { return }
            self.isUserInteractionEnabled = true
        }
    }

    private var isVisibleInViewport: Bool {
        guard let window else { return false }
        let frameInWindow = convert(bounds, to: window)
        return frameInWindow.intersects(window.bounds.insetBy(dx: -24, dy: -24))
    }

    @objc private func pressedDown() {
        guard !isOpeningProduct else { return }
        pressFeedback.prepare()
        releaseFeedback.prepare()
        contextMenuFeedback.prepare()
        pressFeedback.impactOccurred(intensity: 0.55)
    }

    @objc private func requestSimilarProducts() {
        guard !isOpeningProduct, product != nil else { return }
        onRequestSimilar?()
    }

    @objc private func requestRemoval() {
        guard !isOpeningProduct, product != nil else { return }
        contextMenuFeedback.impactOccurred(intensity: 1)
        onRemove?()
    }

    @objc private func tapped() {
        guard !isOpeningProduct else { return }

        isOpeningProduct = true
        releaseFeedback.impactOccurred(intensity: 0.82)

        layer.removeAllAnimations()
        voiceEntranceView.layer.removeAllAnimations()
        transform = transform(isPressed: true)
        applyShadow(isPressed: true)

        guard let window, let launchView = makeLaunchView(in: window) else {
            onTap?(nil)
            resetAfterLaunch()
            return
        }

        alpha = 0
        let transitionBackdrop = makeTransitionBackdrop(in: window)
        let preparationOverlay = ProductPreparationOverlay(
            frame: launchView.bounds,
            pulseTarget: launchView.subviews.first
        )
        preparationOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        launchView.addSubview(preparationOverlay)
        window.addSubview(launchView)
        preparationOverlay.startAnimating()

        let source = ProductTransitionSource(
            frame: convert(bounds, to: window),
            image: imageView.image,
            imageBackgroundColor: imageView.backgroundColor ?? .clear,
            blurredGrid: transitionBackdrop?.image ?? imageView.image ?? UIImage(),
            cornerRadius: surfaceView.layer.cornerRadius,
            presentExperience: { [weak self, weak window, weak launchView, weak preparationOverlay] in
                guard let self, let window, let launchView, let preparationOverlay else { return }
                self.presentPreparedExperience(
                    launchView: launchView,
                    preparationOverlay: preparationOverlay,
                    transitionBackdrop: transitionBackdrop,
                    in: window
                )
            },
            finishExperiencePresentation: { [weak self, weak launchView, weak preparationOverlay, weak transitionView = transitionBackdrop?.view] in
                guard let self, let launchView else { return }
                self.finishPreparedExperience(
                    launchView: launchView,
                    preparationOverlay: preparationOverlay,
                    transitionView: transitionView
                )
            },
            revealTile: { [weak self, weak launchView, weak preparationOverlay, weak transitionView = transitionBackdrop?.view] in
                preparationOverlay?.cancelAnimating()
                launchView?.removeFromSuperview()
                transitionView?.removeFromSuperview()
                self?.resetAfterLaunch()
            }
        )
        onTap?(source)
    }

    private func presentPreparedExperience(
        launchView: UIView,
        preparationOverlay: ProductPreparationOverlay,
        transitionBackdrop: TransitionBackdrop?,
        in window: UIWindow
    ) {
        if let transitionView = transitionBackdrop?.view,
           transitionView.superview == nil {
            window.insertSubview(transitionView, belowSubview: launchView)
        }
        guard !UIAccessibility.isReduceMotionEnabled else {
            launchView.frame = ShopDropStyle.experienceFrame(in: window.bounds)
            launchView.subviews.first?.frame = launchView.bounds
            transform = motionTransform
            applyShadow(isPressed: false)
            return
        }

        playLaunchFlip(on: launchView)

        if let transitionBackdrop,
           transitionBackdrop.view.subviews.count >= 2 {
            let edgeFill = transitionBackdrop.view.subviews[0]
            let scaledGrid = transitionBackdrop.view.subviews[1]
            UIView.animate(
                withDuration: 0.26,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
            ) {
                transitionBackdrop.view.alpha = 1
                edgeFill.alpha = 0.62
                scaledGrid.transform = CGAffineTransform(scaleX: 0.945, y: 0.945)
            }
        }

        UIView.animate(
            withDuration: 0.36,
            delay: 0,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0.68,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            launchView.frame = ShopDropStyle.experienceFrame(in: window.bounds)
            launchView.layer.cornerRadius = ShopDropStyle.experienceCornerRadius
            launchView.layer.shadowOpacity = 0.26
            launchView.layer.shadowRadius = 30
            launchView.layer.shadowOffset = CGSize(width: 0, height: 14)
            launchView.subviews.first?.frame = launchView.bounds
            launchView.subviews.first?.layer.cornerRadius = ShopDropStyle.experienceCornerRadius
        } completion: { [weak self] _ in
            guard let self else { return }
            self.transform = self.motionTransform
            self.applyShadow(isPressed: false)
        }
    }

    private func playLaunchFlip(on view: UIView) {
        var start = CATransform3DIdentity
        start.m34 = -1 / 760
        var quarter = start
        quarter = CATransform3DRotate(quarter, -.pi * 0.5, 0, 1, 0)
        var threeQuarter = start
        threeQuarter = CATransform3DRotate(threeQuarter, -.pi * 1.5, 0, 1, 0)
        var full = start
        full = CATransform3DRotate(full, -.pi * 2, 0, 1, 0)

        let flip = CAKeyframeAnimation(keyPath: "transform")
        flip.values = [
            NSValue(caTransform3D: start),
            NSValue(caTransform3D: quarter),
            NSValue(caTransform3D: threeQuarter),
            NSValue(caTransform3D: full),
        ]
        flip.keyTimes = [0, 0.3, 0.72, 1]
        flip.duration = 0.62
        flip.timingFunctions = [
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeOut),
        ]
        view.layer.add(flip, forKey: "shopdrop.product-launch-flip")
    }

    private func finishPreparedExperience(
        launchView: UIView,
        preparationOverlay: ProductPreparationOverlay?,
        transitionView: UIView?
    ) {
        preparationOverlay?.finishAnimating()
        UIView.animate(
            withDuration: 0.18,
            delay: 0.04,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) {
            launchView.alpha = 0
            transitionView?.alpha = 0
        } completion: { [weak self, weak launchView, weak transitionView] _ in
            launchView?.removeFromSuperview()
            transitionView?.removeFromSuperview()
            self?.isOpeningProduct = false
        }
    }

    /// Captures the visible grid after this tile is hidden, producing a cheap
    /// bitmap backdrop with a true product-shaped hole. The blur is rendered
    /// once at 1× instead of continuously filtering the masonry view tree.
    private func makeTransitionBackdrop(in window: UIWindow) -> TransitionBackdrop? {
        guard let canvas = ancestorCanvas else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        let snapshot = renderer.image { context in
            UIColor.white.setFill()
            context.fill(window.bounds)
            let canvasFrame = canvas.convert(canvas.bounds, to: window)
            canvas.drawHierarchy(in: canvasFrame, afterScreenUpdates: false)
        }

        guard let input = CIImage(image: snapshot) else { return nil }
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = input.clampedToExtent()
        blur.radius = 22
        guard let output = blur.outputImage?.cropped(to: input.extent),
              let cgImage = Self.transitionCIContext.createCGImage(
                output,
                from: input.extent
              ) else { return nil }

        let blurredSnapshot = UIImage(
            cgImage: cgImage,
            scale: snapshot.scale,
            orientation: snapshot.imageOrientation
        )
        let backdrop = UIView(frame: window.bounds)
        backdrop.isUserInteractionEnabled = false
        backdrop.clipsToBounds = true
        backdrop.backgroundColor = .white
        backdrop.alpha = 0

        let edgeFill = UIImageView(frame: backdrop.bounds)
        edgeFill.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        edgeFill.image = blurredSnapshot
        edgeFill.contentMode = .scaleAspectFill
        edgeFill.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
        edgeFill.alpha = 0
        backdrop.addSubview(edgeFill)

        let scaledGrid = UIImageView(frame: backdrop.bounds)
        scaledGrid.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scaledGrid.image = blurredSnapshot
        scaledGrid.contentMode = .scaleAspectFill
        backdrop.addSubview(scaledGrid)
        return TransitionBackdrop(view: backdrop, image: blurredSnapshot)
    }

    private var ancestorCanvas: InfiniteCanvasScrollView? {
        var candidate = superview
        while let view = candidate {
            if let canvas = view as? InfiniteCanvasScrollView {
                return canvas
            }
            candidate = view.superview
        }
        return nil
    }

    private func makeLaunchView(in window: UIWindow) -> UIView? {
        let startFrame = convert(bounds, to: window)
        guard startFrame.width > 1, startFrame.height > 1 else { return nil }

        let container = UIView(frame: startFrame)
        container.isUserInteractionEnabled = false
        container.clipsToBounds = false
        container.backgroundColor = .clear
        container.layer.cornerCurve = .continuous
        container.layer.cornerRadius = 20 * (startFrame.width / max(bounds.width, 1))
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.2
        container.layer.shadowRadius = 24
        container.layer.shadowOffset = CGSize(width: 0, height: 14)

        let launchImage = UIImageView(frame: container.bounds)
        launchImage.autoresizingMask = []
        launchImage.image = imageView.image
        launchImage.contentMode = .scaleAspectFill
        launchImage.backgroundColor = imageView.backgroundColor
        launchImage.clipsToBounds = true
        launchImage.layer.cornerCurve = .continuous
        launchImage.layer.cornerRadius = container.layer.cornerRadius
        container.addSubview(launchImage)
        return container
    }

    private func resetAfterLaunch() {
        alpha = 1
        transform = motionTransform
        applyShadow(isPressed: false)
        isOpeningProduct = false
    }
}

/// A deliberately non-literal loading treatment: the product dissolves into
/// a dense, breathing blur while slow light fields move above it. This belongs
/// to the tapped tile rather than the eventual camera surface.
private final class ProductPreparationOverlay: UIView {
    private let blurView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemThickMaterialDark)
    )
    private let flowingLight = CAGradientLayer()
    private let softGlow = CAGradientLayer()
    private weak var pulseTarget: UIView?

    init(frame: CGRect, pulseTarget: UIView? = nil) {
        self.pulseTarget = pulseTarget
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.cornerCurve = .continuous
        layer.cornerRadius = 20
        alpha = 0

        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.alpha = 0.94
        addSubview(blurView)

        softGlow.type = .radial
        softGlow.colors = [
            UIColor.white.withAlphaComponent(0.38).cgColor,
            UIColor.systemPurple.withAlphaComponent(0.2).cgColor,
            UIColor.clear.cgColor,
        ]
        softGlow.locations = [0, 0.36, 1]
        softGlow.startPoint = CGPoint(x: 0.5, y: 0.5)
        softGlow.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(softGlow)

        flowingLight.colors = [
            UIColor.clear.cgColor,
            UIColor.systemPurple.withAlphaComponent(0.22).cgColor,
            UIColor.systemCyan.withAlphaComponent(0.2).cgColor,
            UIColor.white.withAlphaComponent(0.34).cgColor,
            UIColor.clear.cgColor,
        ]
        flowingLight.locations = [0, 0.18, 0.46, 0.7, 1]
        flowingLight.startPoint = CGPoint(x: 0, y: 0.12)
        flowingLight.endPoint = CGPoint(x: 1, y: 0.88)
        layer.addSublayer(flowingLight)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        flowingLight.frame = bounds.insetBy(dx: -bounds.width * 0.35, dy: 0)
        softGlow.bounds = CGRect(
            x: 0,
            y: 0,
            width: bounds.width * 1.35,
            height: bounds.height * 0.9
        )
        softGlow.position = CGPoint(x: bounds.width * 0.24, y: bounds.height * 0.3)
    }

    func startAnimating() {
        UIView.animate(
            withDuration: 0.22,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseOut]
        ) {
            self.alpha = 1
        }

        guard !UIAccessibility.isReduceMotionEnabled else { return }

        let flow = CABasicAnimation(keyPath: "locations")
        flow.fromValue = [-0.72, -0.5, -0.26, -0.02, 0.22]
        flow.toValue = [0.78, 1, 1.24, 1.48, 1.72]
        flow.duration = 1.65
        flow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        flow.repeatCount = .infinity
        flowingLight.add(flow, forKey: "shopdrop.flow")

        let drift = CAKeyframeAnimation(keyPath: "position")
        drift.values = [
            CGPoint(x: bounds.width * 0.18, y: bounds.height * 0.28),
            CGPoint(x: bounds.width * 0.76, y: bounds.height * 0.44),
            CGPoint(x: bounds.width * 0.34, y: bounds.height * 0.72),
        ]
        drift.keyTimes = [0, 0.54, 1]
        drift.duration = 3.4
        drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        drift.repeatCount = .infinity
        drift.isAdditive = false
        softGlow.add(drift, forKey: "shopdrop.drift")

        let breathe = CABasicAnimation(keyPath: "opacity")
        breathe.fromValue = 0.58
        breathe.toValue = 1
        breathe.duration = 1.15
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        softGlow.add(breathe, forKey: "shopdrop.breathe")

        let imagePulse = CABasicAnimation(keyPath: "transform.scale")
        imagePulse.fromValue = 1
        imagePulse.toValue = 1.06
        imagePulse.duration = 0.92
        imagePulse.autoreverses = true
        imagePulse.repeatCount = .infinity
        imagePulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseTarget?.layer.add(imagePulse, forKey: "shopdrop.loadingPulse")
    }

    func finishAnimating() {
        pulseTarget?.layer.removeAnimation(forKey: "shopdrop.loadingPulse")
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseOut]
        ) {
            self.alpha = 0
        } completion: { [weak self] _ in
            self?.flowingLight.removeAllAnimations()
            self?.softGlow.removeAllAnimations()
            self?.removeFromSuperview()
        }
    }

    func cancelAnimating() {
        pulseTarget?.layer.removeAnimation(forKey: "shopdrop.loadingPulse")
        flowingLight.removeAllAnimations()
        softGlow.removeAllAnimations()
        removeFromSuperview()
    }
}

/// SwiftUI bridge for reusing the same abstract processing treatment on a
/// selected product outside the UIKit canvas tile.
struct ProductPreparationEffect: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.isUserInteractionEnabled = false
        container.clipsToBounds = true

        let overlay = ProductPreparationOverlay(frame: container.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(overlay)
        overlay.startAnimating()
        return container
    }

    func updateUIView(_ view: UIView, context: Context) {
        view.subviews.first?.frame = view.bounds
    }
}

private actor CanvasImageRepository {
    private struct Request {
        let id: UUID
        let priority: TaskPriority
        let task: Task<UIImage?, Never>
    }

    static let shared = CanvasImageRepository()

    private var images: [URL: UIImage] = [:]
    private var requests: [URL: Request] = [:]

    func image(for url: URL, priority: TaskPriority) async -> UIImage? {
        if let image = images[url] { return image }
        if let request = requests[url] {
            if priority.rawValue <= request.priority.rawValue {
                return await request.task.value
            }
            // The URL has entered the viewport. Replace its speculative
            // utility request so URLSession schedules it with visible work.
            request.task.cancel()
        }

        let task = Task<UIImage?, Never>(priority: priority) {
            guard
                let (data, response) = try? await URLSession.shared.data(from: url),
                (response as? HTTPURLResponse).map({ (200...299).contains($0.statusCode) }) ?? true
            else { return nil }
            return UIImage(data: data)
        }
        let request = Request(id: UUID(), priority: priority, task: task)
        requests[url] = request
        let image = await task.value
        if requests[url]?.id == request.id {
            requests[url] = nil
            if let image { images[url] = image }
        }
        return image
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)
        self.init(
            red: CGFloat((number >> 16) & 0xff) / 255,
            green: CGFloat((number >> 8) & 0xff) / 255,
            blue: CGFloat(number & 0xff) / 255,
            alpha: 1
        )
    }
}
