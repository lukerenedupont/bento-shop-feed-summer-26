import SwiftUI
import UIKit
import FloatingPanel

// MARK: - Anchors (non-generic, so they can be shared across instances)

/// Anchor positions a `FloatingPanelSheet` can rest at. Map to `FloatingPanelState`:
/// `.tip` → `.tip`, `.half` → `.half`, `.full` → `.full`.
enum FloatingPanelAnchor: Hashable {
    /// Panel peeks up from the bottom by `fraction` of the screen height.
    case tip(fraction: CGFloat)
    /// Panel sits at `fraction` of the screen height.
    case half(fraction: CGFloat)
    /// Panel sits `topInset` points below the top safe area edge.
    case full(topInset: CGFloat)

    var state: FloatingPanelState {
        switch self {
        case .tip: .tip
        case .half: .half
        case .full: .full
        }
    }
}

enum FloatingPanelInitialAnchor {
    case tip, half, full
    var state: FloatingPanelState {
        switch self {
        case .tip: .tip
        case .half: .half
        case .full: .full
        }
    }
}

// MARK: - FloatingPanelSheet

/// A SwiftUI wrapper around `FloatingPanel` (https://github.com/scenee/FloatingPanel).
///
/// Replaces the hand-rolled draggable sheets in `DeliveriesPage` / `DeliveryDetailPage`
/// with a native UIKit panel that gives you:
/// - Multiple anchor positions (tip / half / full) with rubber-banding
/// - Automatic scroll ↔ drag handoff for an embedded `ScrollView`
/// - A real grabber handle styled to Gravity
/// - Proper z-ordering — sits below the `BottomNavBar` overlay in the root `ZStack`
///
/// ```swift
/// FloatingPanelSheet(
///     anchors: [.tip(fraction: 0.42), .full(topInset: 54)],
///     initialAnchor: .tip,
///     background: { mapBackground },
///     content: { sheetContent }
/// )
/// ```
struct FloatingPanelSheet<Background: View, Content: View>: UIViewControllerRepresentable {

    var anchors: [FloatingPanelAnchor]
    var initialAnchor: FloatingPanelInitialAnchor = .tip
    var cornerRadius: CGFloat = GravityRadius.r40
    var grabberColor: Color = GravityColors.borderSecondary
    var surfaceColor: Color = GravityColors.bg
    var showsShadow: Bool = true
    /// Top padding applied to the panel content so the first element clears
    /// the grabber handle with breathing room. Default is 32pt (grabber sits
    /// at ~12pt from surface top; this gives ~20pt of air below it).
    var contentTopInset: CGFloat = 32
    var onStateChange: ((FloatingPanelInitialAnchor) -> Void)?

    @ViewBuilder var background: () -> Background
    @ViewBuilder var content: () -> Content

    // MARK: UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        let coord = context.coordinator
        let host = PanelHostViewController()

        // Background SwiftUI view — full bleed under the panel
        let bgVC = UIHostingController(rootView: background())
        bgVC.view.backgroundColor = .clear
        host.embedBackground(bgVC)
        coord.backgroundVC = bgVC

        // Content SwiftUI view — hosted in a scroll-tracking controller so we can
        // grab the underlying UIScrollView and hand it to FloatingPanel.
        // Top padding is applied directly in SwiftUI rather than via
        // additionalSafeAreaInsets because FloatingPanel manages content insets
        // for its scroll tracking and overrides safe-area changes.
        let paddedContent = AnyView(content().padding(.top, contentTopInset))
        let contentVC = ScrollTrackingHostingController(rootView: paddedContent)
        contentVC.view.backgroundColor = UIColor(surfaceColor)
        contentVC.onScrollViewFound = { [weak coord] scrollView in
            guard let coord, let fpc = coord.fpc else { return }
            fpc.track(scrollView: scrollView)
        }
        coord.contentVC = contentVC

        // FloatingPanel
        let fpc = FloatingPanelController()
        fpc.delegate = coord
        fpc.contentMode = .static
        fpc.isRemovalInteractionEnabled = false
        fpc.set(contentViewController: contentVC)
        fpc.layout = PanelLayout(anchors: anchors, initial: initialAnchor.state)
        fpc.behavior = PanelBehavior()
        applySurfaceAppearance(to: fpc)

        coord.parent = self
        coord.fpc = fpc

        fpc.addPanel(toParent: host, animated: false)
        return host
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        let coord = context.coordinator
        coord.parent = self

        // Refresh hosted SwiftUI roots so state propagates.
        if let bgVC = coord.backgroundVC as? UIHostingController<Background> {
            bgVC.rootView = background()
        }
        coord.contentVC?.rootView = AnyView(content().padding(.top, contentTopInset))

        if let fpc = coord.fpc {
            applySurfaceAppearance(to: fpc)
        }
    }

    private func applySurfaceAppearance(to fpc: FloatingPanelController) {
        let appearance = SurfaceAppearance()
        appearance.cornerRadius = cornerRadius
        appearance.backgroundColor = UIColor(surfaceColor)
        if showsShadow {
            let shadow = SurfaceAppearance.Shadow()
            shadow.color = .black
            shadow.offset = CGSize(width: 0, height: -2)
            shadow.radius = 24
            shadow.opacity = 0.12
            appearance.shadows = [shadow]
        } else {
            appearance.shadows = []
        }
        fpc.surfaceView.appearance = appearance
        fpc.surfaceView.grabberHandle.barColor = UIColor(grabberColor)
        fpc.surfaceView.grabberHandlePadding = 8
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, FloatingPanelControllerDelegate {
        var parent: FloatingPanelSheet?
        weak var fpc: FloatingPanelController?
        weak var backgroundVC: UIViewController?
        weak var contentVC: ScrollTrackingHostingController?

        func floatingPanelDidChangeState(_ fpc: FloatingPanelController) {
            let anchor: FloatingPanelInitialAnchor = switch fpc.state {
            case .full: .full
            case .half: .half
            default: .tip
            }
            parent?.onStateChange?(anchor)
        }
    }
}

// MARK: - Layout

private final class PanelLayout: FloatingPanelLayout {
    let position: FloatingPanelPosition = .bottom
    let initialState: FloatingPanelState
    let anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring]

    init(anchors specs: [FloatingPanelAnchor], initial: FloatingPanelState) {
        self.initialState = initial
        var built: [FloatingPanelState: FloatingPanelLayoutAnchoring] = [:]
        for spec in specs {
            switch spec {
            case .tip(let fraction):
                built[.tip] = FloatingPanelLayoutAnchor(
                    fractionalInset: fraction,
                    edge: .bottom,
                    referenceGuide: .superview
                )
            case .half(let fraction):
                built[.half] = FloatingPanelLayoutAnchor(
                    fractionalInset: fraction,
                    edge: .bottom,
                    referenceGuide: .superview
                )
            case .full(let topInset):
                built[.full] = FloatingPanelLayoutAnchor(
                    absoluteInset: topInset,
                    edge: .top,
                    referenceGuide: .safeArea
                )
            }
        }
        self.anchors = built
    }
}

// MARK: - Behavior

/// Tuned to feel like a native iOS sheet — snappy settle, no overshoot bounce,
/// no rubber-band at the anchor edges. The default FloatingPanel behavior is
/// quite springy; this damps it down significantly.
private final class PanelBehavior: FloatingPanelBehavior {
    // Snappier settle than the 0.4 default.
    let springResponseTime: CGFloat = 0.28

    // Fast deceleration — closer to UIScrollView.fast than .normal so the panel
    // doesn't coast far past the user's finger.
    let springDecelerationRate: CGFloat = UIScrollView.DecelerationRate.fast.rawValue

    // Don't project user momentum into overshoot past the destination anchor.
    let momentumProjectionRate: CGFloat = UIScrollView.DecelerationRate.fast.rawValue

    /// Disable the elastic rubber-band you get when dragging past the topmost
    /// or bottommost anchor. This is the single biggest contributor to the
    /// "crazy bounce" feeling.
    func allowsRubberBanding(for edge: UIRectEdge) -> Bool { false }

    /// Don't let flick momentum carry the panel past the next anchor — it
    /// should settle at whichever anchor the user's gesture is closest to.
    func shouldProjectMomentum(_ fpc: FloatingPanelController, to proposedState: FloatingPanelState) -> Bool {
        false
    }
}

// MARK: - Host VC

private final class PanelHostViewController: UIViewController {
    private weak var background: UIViewController?

    func embedBackground(_ child: UIViewController) {
        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        child.didMove(toParent: self)
        background = child
    }
}

// MARK: - Scroll-tracking hosting controller

/// Finds the first descendant `UIScrollView` after layout and reports it once.
/// FloatingPanel needs this scroll view passed to `track(scrollView:)` to enable
/// seamless drag↔scroll handoff.
final class ScrollTrackingHostingController: UIHostingController<AnyView> {
    var onScrollViewFound: ((UIScrollView) -> Void)?
    private var reported = false

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !reported, let scrollView = view.firstScrollView() else { return }
        reported = true
        onScrollViewFound?(scrollView)
    }
}

private extension UIView {
    func firstScrollView() -> UIScrollView? {
        if let sv = self as? UIScrollView { return sv }
        for sub in subviews {
            if let found = sub.firstScrollView() { return found }
        }
        return nil
    }
}
