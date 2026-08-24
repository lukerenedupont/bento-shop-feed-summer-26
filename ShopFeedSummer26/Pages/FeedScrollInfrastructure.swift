import SwiftUI
import UIKit

struct FeedViewportLayout {
    let expandedWidth: CGFloat
    let expandedHeight: CGFloat
    let viewportHeight: CGFloat
    let pinnedTitleTop: CGFloat

    var cardWidth: CGFloat {
        expandedWidth
    }

    var cardHeight: CGFloat {
        expandedHeight
    }

    var foregroundTopPadding: CGFloat {
        GravitySpacing.space20
    }
}

struct FeedViewportMetrics {
    let containerSize: CGSize
    let safeAreaTop: CGFloat
    let isForYou: Bool

    var compactWidth: CGFloat {
        guard isForYou else { return containerSize.width }
        return min(
            containerSize.width - (FeedCardStyle.compactHorizontalInset * 2),
            FeedCardStyle.compactMaximumWidth
        )
    }

    var compactHeight: CGFloat {
        compactWidth * FeedCardStyle.portraitAspectRatio
    }

    var utilityLaunchInset: CGFloat {
        (FeedNavigationStyle.controlSize * 2) + GravitySpacing.space16
    }

    var fullBleedHeight: CGFloat {
        let visibleHeight = containerSize.height - safeAreaTop + utilityLaunchInset
        return max(
            compactHeight,
            visibleHeight
                - FeedCardStyle.bottomNavigationClearance
                - FeedCardStyle.nextCardPeek
                - FeedCardStyle.cardSpacing
                + FeedCardStyle.bottomNavigationOverlap
        )
    }

    var layout: FeedViewportLayout {
        FeedViewportLayout(
            expandedWidth: containerSize.width,
            expandedHeight: fullBleedHeight,
            viewportHeight: containerSize.height,
            pinnedTitleTop: safeAreaTop
                + FeedNavigationStyle.controlSize
                + GravitySpacing.space12
                + FeedCardStyle.titleHeaderGap
        )
    }

    var extendedViewportHeight: CGFloat {
        containerSize.height + safeAreaTop
    }

    var bottomContentPadding: CGFloat {
        max((containerSize.height - compactHeight) / 2, GravitySpacing.space8)
    }
}

/// ScrollView writes its target binding while a drag is in flight. Keeping
/// that transient value outside SwiftUI observation prevents the entire feed
/// from being invalidated when the nearest snap target changes under a finger.
@MainActor
final class FeedScrollState {
    var positionID: String?
    var isScrolling = false
}

/// Pull-to-expand state is reference-backed so live drag updates invalidate
/// only the utility rail host, not the feed or persistent navigation.
@MainActor
@Observable
final class UtilityRailExpansionState {
    private(set) var isArmed = false
    private(set) var isExpanded = false
    private var isInteracting = false
    private var isSettling = false
    private var collapseArmed = false
    private var dragTranslation: CGFloat = 0

    private let openSnapThreshold: CGFloat = 48
    private let closeSnapThreshold: CGFloat = 24
    private let releaseHysteresis: CGFloat = 12

    var restingCardHeight: CGFloat {
        isExpanded
            ? UtilityRailMetrics.expandedCardHeight
            : UtilityRailMetrics.cardHeight
    }

    /// The visible card uses real geometry so media and typography retain
    /// their proportions throughout the pull.
    var presentationCardHeight: CGFloat {
        restingCardHeight + dragTranslation
    }

    var layoutHeight: CGFloat {
        restingCardHeight
            + UtilityRailMetrics.carouselVerticalPadding * 2
    }

    /// Mirrors the belt's live bottom-edge travel without changing the feed's
    /// layout during the gesture. When the endpoint commits, the new resting
    /// layout replaces this offset in the same animation frame.
    var feedCompensationOffset: CGFloat {
        dragTranslation
    }

    var hasActiveInteraction: Bool {
        isInteracting
    }

    /// Expansion and collapse are geometry-only. The belt may retreat only
    /// after it is compact and the feed begins its separate full-bleed move.
    var keepsBeltFullyVisible: Bool {
        isExpanded || isInteracting || isSettling
    }

    func update(dragTranslation proposedTranslation: CGFloat) {
        // A collapsed belt only owns a downward pull. Upward travel belongs
        // to the feed so its first card can take over the viewport natively.
        guard isExpanded || proposedTranslation > 0 else { return }

        if !isInteracting {
            beginInteraction()
        }

        let expansionTravel = UtilityRailMetrics.expandedCardHeight
            - UtilityRailMetrics.cardHeight
        dragTranslation = isExpanded
            ? min(max(proposedTranslation, -expansionTravel), 0)
            : min(max(proposedTranslation, 0), expansionTravel)

        if isExpanded {
            let upwardTravel = max(-dragTranslation, 0)
            if upwardTravel >= closeSnapThreshold, !collapseArmed {
                collapseArmed = true
                HapticFeedback.light.fire()
            } else if upwardTravel < releaseHysteresis {
                collapseArmed = false
            }
            return
        }

        let downwardOverscroll = max(dragTranslation, 0)

        if downwardOverscroll >= openSnapThreshold, !isArmed {
            isArmed = true
            HapticFeedback.light.fire()
        } else if downwardOverscroll < releaseHysteresis {
            isArmed = false
        }
    }

    func beginInteraction() {
        isInteracting = true
        dragTranslation = 0
        collapseArmed = false
        isArmed = false
    }

    @discardableResult
    func settle(reduceMotion: Bool) -> (wasExpanded: Bool, isExpanded: Bool)? {
        guard isInteracting else { return nil }
        let wasExpanded = isExpanded
        let shouldExpand = isExpanded ? !collapseArmed : isArmed
        let expansionTravel = UtilityRailMetrics.expandedCardHeight
            - UtilityRailMetrics.cardHeight
        let endpointTranslation: CGFloat = if shouldExpand == isExpanded {
            0
        } else if shouldExpand {
            expansionTravel
        } else {
            -expansionTravel
        }

        isInteracting = false
        isSettling = true
        isArmed = false
        collapseArmed = false

        let commitEndpoint = {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                self.isExpanded = shouldExpand
                self.dragTranslation = 0
                self.isSettling = false
            }
        }

        if reduceMotion {
            commitEndpoint()
        } else {
            withAnimation(
                .easeOut(duration: 0.20),
                completionCriteria: .logicallyComplete
            ) {
                dragTranslation = endpointTranslation
            } completion: {
                commitEndpoint()
            }
        }

        return (wasExpanded, shouldExpand)
    }

    func reset() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isArmed = false
            isExpanded = false
            isInteracting = false
            isSettling = false
            collapseArmed = false
            dragTranslation = 0
        }
    }
}

/// Observation boundary for the high-frequency pull gesture.
struct UtilityRailExpansionHost<Content: View>: View {
    @Bindable var state: UtilityRailExpansionState
    @ViewBuilder let content: (CGFloat) -> Content

    var body: some View {
        content(state.presentationCardHeight)
            .frame(height: state.layoutHeight, alignment: .top)
    }
}

/// Keeps cards below the belt attached to its moving bottom edge without
/// feeding per-frame geometry back into the vertical ScrollView.
struct UtilityRailFeedMotionHost<Content: View>: View {
    @Bindable var state: UtilityRailExpansionState
    let followsBelt: Bool
    @ViewBuilder let content: () -> Content

    @ViewBuilder
    var body: some View {
        if followsBelt {
            content()
                .offset(y: state.feedCompensationOffset)
        } else {
            content()
        }
    }
}

/// Installs an axis-aware pan recognizer directly on the native vertical
/// scroll view. Belt gestures win only when `shouldBegin` accepts their
/// direction; every other gesture falls through to native feed scrolling.
struct UtilityRailVerticalPanBridge: UIViewRepresentable {
    var shouldBegin: (CGFloat) -> Bool
    var onChanged: (CGFloat) -> Void
    var onEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        context.coordinator.attachWhenAvailable(from: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.attachWhenAvailable(from: uiView)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: UtilityRailVerticalPanBridge
        private weak var scrollView: UIScrollView?
        private lazy var pan = UIPanGestureRecognizer(
            target: self,
            action: #selector(handlePan(_:))
        )

        init(parent: UtilityRailVerticalPanBridge) {
            self.parent = parent
            super.init()
            pan.delegate = self
            pan.maximumNumberOfTouches = 1
            pan.cancelsTouchesInView = true
        }

        func attachWhenAvailable(from view: UIView) {
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                var ancestor = view.superview
                while let candidate = ancestor {
                    if let scrollView = candidate as? UIScrollView {
                        self.attach(to: scrollView)
                        return
                    }
                    ancestor = candidate.superview
                }
            }
        }

        func detach() {
            scrollView?.removeGestureRecognizer(pan)
            scrollView = nil
        }

        private func attach(to scrollView: UIScrollView) {
            guard self.scrollView !== scrollView else { return }
            detach()
            self.scrollView = scrollView
            // A full-height card should settle quickly after the finger
            // releases. The default deceleration leaves this paging feed
            // drifting before view-aligned snapping takes over.
            scrollView.decelerationRate = .fast
            scrollView.addGestureRecognizer(pan)
            scrollView.panGestureRecognizer.require(toFail: pan)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            guard abs(velocity.y) > abs(velocity.x) else { return false }
            return parent.shouldBegin(velocity.y)
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .changed:
                parent.onChanged(recognizer.translation(in: recognizer.view).y)
            case .ended, .cancelled, .failed:
                parent.onEnded()
            default:
                break
            }
        }
    }
}
