import Foundation
import Gravity
import Nuke
import SwiftUI
import UIKit

enum ShopBottomNavigationStyle: Sendable, Hashable {
    case rodeo
    case pistons

    var usesDepthDip: Bool { self == .rodeo }
}

enum ShopCompactComposerPrompt: Equatable {
    case tryAsking
    case ask

    var title: String {
        switch self {
        case .tryAsking:
            localizedString("Agent.ConversationStarters.SectionTitle")
        case .ask:
            localizedString("Agent.Ask.Title")
        }
    }
}

@MainActor
final class ShopAppFirstInteractionTracker {
    static let shared = ShopAppFirstInteractionTracker()
    static let didInteractNotification = Notification.Name("ShopAppFirstInteractionTracker.didInteract")

    private(set) var hasInteracted = false
    private var didClaimTryAskingShimmer = false
    private weak var recognizer: ShopAppFirstInteractionGestureRecognizer?

    private init() {}

    func install(in window: UIWindow) {
        guard !hasInteracted, recognizer?.view !== window else { return }
        if let recognizer, let view = recognizer.view {
            view.removeGestureRecognizer(recognizer)
        }
        let recognizer = ShopAppFirstInteractionGestureRecognizer { [weak self] in
            self?.recordInteraction()
        }
        window.addGestureRecognizer(recognizer)
        self.recognizer = recognizer
    }

    func claimTryAskingShimmer() -> Bool {
        guard !didClaimTryAskingShimmer else { return false }
        didClaimTryAskingShimmer = true
        return true
    }

    private func recordInteraction() {
        guard !hasInteracted else { return }
        hasInteracted = true
        if let recognizer, let view = recognizer.view {
            view.removeGestureRecognizer(recognizer)
        }
        recognizer = nil
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didInteractNotification, object: nil)
        }
    }
}

@MainActor
private final class ShopAppFirstInteractionGestureRecognizer: UIGestureRecognizer {
    private let onFirstTouch: () -> Void

    init(onFirstTouch: @escaping () -> Void) {
        self.onFirstTouch = onFirstTouch
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onFirstTouch()
        // Observe only: failing immediately leaves the touched control and any
        // competing scroll or navigation recognizers completely undisturbed.
        state = .failed
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}


extension ShopTabBarMetrics {
    static let horizontalInset: CGFloat = GravitySpacing.space24
    static let composerSideGap: CGFloat = GravitySpacing.space12
    static let composerHorizontalInset = horizontalInset + ShopFloatingChromeMetrics.buttonSize + composerSideGap
    static let dockSwapDuration: TimeInterval = 0.38
    static let dockSwapBounce: CGFloat = 0
    static let dockExpansionBounce: CGFloat = 0.14
    static let dockIconFadeDuration: TimeInterval = 0.20
    static let dockChatIconFadeOutDuration: TimeInterval = 0.12
    static let initialCartRevealDelay: Duration = .seconds(1)

    static func tabSectionWidth(tabCount: Int) -> CGFloat {
        50 * CGFloat(tabCount) + GravitySpacing.space4 * 2
    }

    static func chromeHeight(for bottomInset: CGFloat) -> CGFloat {
        max(backdropHeight + bottomInset, topPadding + contentHeight + visualBottomPadding(for: bottomInset))
    }
}

/// SwiftUI owns the shell's state; this representable is the one stable ownership boundary for
/// all visible bottom chrome. UIKit owns its geometry, interaction, glass, and transitions.
struct ShopBottomNavigation: UIViewControllerRepresentable {
    var navigationStyle = ShopBottomNavigationStyle.rodeo
    let selectedTab: ShopRootTab
    let tabs: [ShopRootTab]
    let isNativeAgentEnabled: Bool
    let usesSearchIconForExplore: Bool
    let cartStore: ShopCartShellStore
    let addToCartAnimationCoordinator: ShopAddToCartAnimationCoordinator
    let cartAnimations: [ShopAddToCartAnimation]
    let cartButtonBounceTrigger: Int
    let bottomInset: CGFloat
    let backdropColor: Color
    let onTabPressed: (ShopRootTab) -> Void
    let onOpenCart: () -> Void
    var onNavigationStyleLongPressed: (() -> Void)? = nil
    var conversation: ShopBottomNavigationConversation? = nil
    var usesChatTabSwap = false

    private var cartTotalItemCount: Int { cartStore.visibleBadgeCount }

    private var cartButtonVisible: Bool {
        cartStore.snapshot.isCartButtonTargetVisible
            || addToCartAnimationCoordinator.isCartButtonOptimisticallyVisible
    }

    private var cartButtonMode: ShopFloatingCartButtonMode {
        ShopFloatingCartButtonMode.resolve(
            hasActiveCarts: cartStore.snapshot.carts.isEmpty == false,
            hasSavedForLaterItems: cartStore.snapshot.hasSavedForLaterItems,
            isShowingOptimistically: addToCartAnimationCoordinator.isCartButtonOptimisticallyVisible
        )
    }

    func makeUIViewController(context: Context) -> ShopBottomNavigationViewController {
        ShopBottomNavigationViewController()
    }

    func updateUIViewController(_ controller: ShopBottomNavigationViewController, context: Context) {
        controller.overrideUserInterfaceStyle = context.environment.colorScheme == .dark ? .dark : .light
        controller.loadViewIfNeeded()
        let view = controller.chrome
        let isConversationPresented = conversation?.isConversationVisible == true
        let swapsComposer = usesChatTabSwap && conversation != nil
        // The destination's dock preference is enough to begin the swap. A PDP
        // publishes that preference before its product-bound composer source is
        // ready; waiting for the source makes the tabs linger until loading ends.
        // The controller keeps the existing composer surface alive through that
        // brief source handoff, then reconfigures it with the product context.
        let navigationMode = conversation?.navigationMode ?? .tabs
        view.onBack = { [weak controller] in
            if swapsComposer { controller?.toggleComposerDock() }
        }
        view.onTabPressed = onTabPressed
        view.onOpenCart = onOpenCart
        view.onNavigationStyleLongPressed = onNavigationStyleLongPressed
        view.update(
            selectedTab: selectedTab,
            tabs: tabs,
            isNativeAgentEnabled: isNativeAgentEnabled,
            usesSearchIconForExplore: usesSearchIconForExplore,
            showsBackButton: swapsComposer,
            cartTotalItemCount: cartTotalItemCount,
            cartButtonVisible: cartButtonVisible,
            cartButtonMode: cartButtonMode,
            coordinator: addToCartAnimationCoordinator,
            cartAnimations: cartAnimations,
            cartButtonBounceTrigger: cartButtonBounceTrigger,
            bottomInset: bottomInset,
            backdropColor: UIColor(backdropColor),
            hidesTabSection: swapsComposer ? navigationMode == .composer : isConversationPresented,
            animated: context.transaction.animation != nil || context.transaction.disablesAnimations == false,
            swapsComposer: swapsComposer,
            // Navigation style is a persistent layout choice, not a readiness state.
            // A route/source handoff must not briefly restore centered tabs.
            navigationStyle: navigationStyle
        )
        controller.update(conversation: conversation, bottomInset: bottomInset,
                          usesChatTabSwap: swapsComposer, navigationStyle: navigationStyle)
    }

    static func dismantleUIViewController(_ controller: ShopBottomNavigationViewController, coordinator: ()) {
        controller.disconnect()
    }
}

@MainActor
final class ShopUIKitTabBarChromeView: UIView, UIGestureRecognizerDelegate {
    var onBack: (() -> Void)?
    var onTabPressed: ((ShopRootTab) -> Void)?
    var onOpenCart: (() -> Void)?
    var onNavigationStyleLongPressed: (() -> Void)?
    var onCartPresentationChanged: (() -> Void)?

    private enum Metrics {
        static let buttonSize = ShopFloatingChromeMetrics.buttonSize
        static let horizontalInset = ShopTabBarMetrics.horizontalInset
        static let tabButtonWidth: CGFloat = 50
        static let tabButtonHeight: CGFloat = 44
        static let indicatorSize: CGFloat = 44
        static let tabHorizontalPadding = GravitySpacing.space4
        static let hiddenOffset: CGFloat = 40
        static let scrubIndicatorScale = CGAffineTransform(scaleX: 1.5, y: 1.22)
        static let scrubIconScale = CGAffineTransform(scaleX: 1.06, y: 1.06)
        static let indicatorTravelDuration: TimeInterval = 0.20
        static let conversationTransitionDuration: TimeInterval = 0.55
    }

    private let backdropView = ShopUIKitTabBarBackdropView()
    private let chromeRow = UIStackView()
    private let flexibleDockSpace = UIView()
    private let backSlot = UIView()
    private let backButton = ShopUIKitGlassButton()
    // Lives inside the compact material so its native interactive glass sees touches.
    private let dockToggleButton = UIButton(type: .custom)
    private var dockToggleConstraints: [NSLayoutConstraint] = []
    private let tabSlot = UIView()
    private let tabSurface = ShopUIKitGlassSurfaceView(interactive: true, hasFloatingShadow: true)
    private let tabButtonsRow = UIStackView()
    private let compactTabIcon = UIImageView()
    private let selectedIndicator = UIView()
    private let cartSlot = UIView()
    private let cartButton = ShopUIKitGlassButton()
    private let cartContent = UIView()
    private let cartIconView = UIImageView()
    private let badgeLabel = UILabel()

    private var bottomConstraint: NSLayoutConstraint!
    private var backButtonCenterConstraint: NSLayoutConstraint!
    private var backButtonCartCenterConstraint: NSLayoutConstraint!
    private var backdropHeightConstraint: NSLayoutConstraint!
    private var backdropConstraints: [NSLayoutConstraint] = []
    private var tabSurfaceWidthConstraint: NSLayoutConstraint!
    private var tabSurfaceLeadingConstraint: NSLayoutConstraint!
    private var tabMaterialWidthConstraint: NSLayoutConstraint!
    private var tabContentWidthConstraint: NSLayoutConstraint!
    private var indicatorLeadingConstraint: NSLayoutConstraint!
    private var tabButtons: [UIButton] = []
    private var tabs: [ShopRootTab] = []
    private var selectedTab: ShopRootTab = .home
    private var isNativeAgentEnabled = false
    private var usesSearchIconForExplore = false
    private var showsBackButton = false
    private var cartButtonVisible = false
    private var requestedCartButtonVisible = false
    private var hasCompletedInitialCartReveal = false
    private var initialCartRevealTask: Task<Void, Never>?
    private var cartButtonMode: ShopFloatingCartButtonMode = .activeCart
    private var cartTotalItemCount = 0
    private var previousBounceTrigger = 0
    private var scrubStartTab: ShopRootTab?
    private var isScrubbing = false
    private var hidesTabSection = false
    private var swapsComposer = false
    private var navigationStyle = ShopBottomNavigationStyle.rodeo
    private weak var composerDockContentView: UIView?
    private var tabPanRecognizer: UIPanGestureRecognizer?
    private var navigationStyleLongPressRecognizer: UILongPressGestureRecognizer?
    private var coordinator: ShopAddToCartAnimationCoordinator?
    private let cartTargetID = UUID()
    private var animationImageTasks: [Int: ImageTask] = [:]
    private var animationImageViews: [Int: UIImageView] = [:]
    private var startedAnimationIDs: Set<Int> = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = false
        accessibilityViewIsModal = false
        buildViewHierarchy()
        buildConstraints()
        configureInteractions()
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitPreferredContentSizeCategory.self]) { (view: ShopUIKitTabBarChromeView, _) in
            view.updateTabAppearance()
            view.updateCartAppearance()
            view.updateLeadingButton(animated: false)
            view.selectedIndicator.backgroundColor = UIColor(GravityColor.bgOverlayFixedDark04)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: ShopTabBarMetrics.chromeHeight(for: safeAreaInsets.bottom))
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        [backButton, tabSurface, cartButton].contains { view in
            view.isHidden == false && view.isUserInteractionEnabled && view.alpha > 0.01 && view.point(inside: view.convert(point, from: self), with: event)
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // The fallback chat button can occupy the empty Cart slot outside backSlot.
        if swapsComposer, !hidesTabSection, !isHidden, alpha > 0.01, isUserInteractionEnabled,
           let hit = backButton.hitTest(backButton.convert(point, from: self), with: event) {
            return hit
        }
        // The compact tab material is outside its reserved center slot. Route into
        // its real hierarchy instead of letting the empty leading slot swallow taps.
        if swapsComposer, hidesTabSection, !isHidden, alpha > 0.01, isUserInteractionEnabled,
           let hit = tabSurface.hitTest(tabSurface.convert(point, from: self), with: event) {
            return hit
        }
        return super.hitTest(point, with: event)
    }

    func update(
        selectedTab: ShopRootTab,
        tabs: [ShopRootTab],
        isNativeAgentEnabled: Bool,
        usesSearchIconForExplore: Bool = false,
        showsBackButton: Bool,
        cartTotalItemCount: Int,
        cartButtonVisible: Bool,
        cartButtonMode: ShopFloatingCartButtonMode,
        coordinator: ShopAddToCartAnimationCoordinator,
        cartAnimations: [ShopAddToCartAnimation],
        cartButtonBounceTrigger: Int,
        bottomInset: CGFloat,
        backdropColor: UIColor,
        hidesTabSection: Bool,
        animated: Bool,
        swapsComposer: Bool = false,
        navigationStyle: ShopBottomNavigationStyle = .rodeo
    ) {
        requestedCartButtonVisible = cartButtonVisible
        let presentedCartButtonVisible = resolvedCartButtonVisibility(
            requestedVisibility: cartButtonVisible,
            animated: animated
        )
        let tabsChanged = self.tabs != tabs || self.isNativeAgentEnabled != isNativeAgentEnabled
        let selectionChanged = self.selectedTab != selectedTab
        let backVisibilityChanged = self.showsBackButton != showsBackButton
        let cartVisibilityChanged = self.cartButtonVisible != presentedCartButtonVisible
        let tabSectionVisibilityChanged = self.hidesTabSection != hidesTabSection
        let swapModeChanged = self.swapsComposer != swapsComposer
        let navigationStyleChanged = self.navigationStyle != navigationStyle
        let searchIconModeChanged = self.usesSearchIconForExplore != usesSearchIconForExplore
        let leadingRoleChanged = self.swapsComposer != swapsComposer || tabSectionVisibilityChanged || selectionChanged || searchIconModeChanged

        self.selectedTab = selectedTab
        self.tabs = tabs
        self.isNativeAgentEnabled = isNativeAgentEnabled
        self.usesSearchIconForExplore = usesSearchIconForExplore
        self.showsBackButton = showsBackButton
        self.cartButtonVisible = presentedCartButtonVisible
        self.cartButtonMode = cartButtonMode
        self.cartTotalItemCount = cartTotalItemCount
        self.coordinator = coordinator
        self.hidesTabSection = hidesTabSection
        self.swapsComposer = swapsComposer
        self.navigationStyle = navigationStyle

        if navigationStyleChanged { updateDockAlignment() }

        bottomConstraint.constant = -ShopTabBarMetrics.visualBottomPadding(for: bottomInset)
        backdropHeightConstraint.constant = ShopTabBarMetrics.backdropHeight + bottomInset
        backdropView.update(color: backdropColor)

        if tabsChanged {
            rebuildTabButtons()
        }
        updateTabAppearance()
        updateCartAppearance()
        updateLeadingButton(animated: animated && leadingRoleChanged)

        layoutIfNeeded()
        updateIndicator(animated: animated && selectionChanged && !isScrubbing)
        updateBackButtonVisibility(animated: animated && (backVisibilityChanged || cartVisibilityChanged || navigationStyleChanged))
        setRollingVisibility(
            cartButton,
            visible: presentedCartButtonVisible,
            fromRight: false,
            animated: animated && cartVisibilityChanged
        )
        if tabSectionVisibilityChanged || swapModeChanged || tabsChanged || navigationStyleChanged {
            updateTabSectionVisibility(animated: animated)
        }

        if cartButtonBounceTrigger != previousBounceTrigger {
            previousBounceTrigger = cartButtonBounceTrigger
            bounceCartButton()
        }

        coordinator.updateCartTarget(
            id: cartTargetID,
            source: .standard,
            isReady: presentedCartButtonVisible && bounds.width > 0 && bounds.height > 0
        )
        reconcileAnimations(cartAnimations)
        invalidateIntrinsicContentSize()
    }

    func prepareForRemoval() {
        onNavigationStyleLongPressed = nil
        onCartPresentationChanged = nil
        initialCartRevealTask?.cancel()
        initialCartRevealTask = nil
        setDockToggleHost(nil)
        composerDockContentView = nil
        coordinator?.removeCartTarget(id: cartTargetID, source: .standard)
        animationImageTasks.values.forEach { $0.cancel() }
        animationImageTasks.removeAll()
        animationImageViews.values.forEach { $0.removeFromSuperview() }
        animationImageViews.removeAll()
        startedAnimationIDs.removeAll()
    }

    private func resolvedCartButtonVisibility(
        requestedVisibility: Bool,
        animated: Bool
    ) -> Bool {
        guard requestedVisibility else {
            initialCartRevealTask?.cancel()
            initialCartRevealTask = nil
            return false
        }
        guard !hasCompletedInitialCartReveal,
              !ShopAppFirstInteractionTracker.shared.hasInteracted,
              animated else {
            hasCompletedInitialCartReveal = true
            initialCartRevealTask?.cancel()
            initialCartRevealTask = nil
            return true
        }

        if initialCartRevealTask == nil {
            initialCartRevealTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: ShopTabBarMetrics.initialCartRevealDelay)
                guard !Task.isCancelled else { return }
                self?.revealInitialCartIfNeeded()
            }
        }
        return false
    }

    private func revealInitialCartIfNeeded() {
        initialCartRevealTask = nil
        guard requestedCartButtonVisible, !cartButtonVisible else { return }
        hasCompletedInitialCartReveal = true
        cartButtonVisible = true
        updateCartAppearance()
        layoutIfNeeded()
        updateBackButtonVisibility(animated: true)
        setRollingVisibility(cartButton, visible: true, fromRight: false, animated: true)
        coordinator?.updateCartTarget(
            id: cartTargetID,
            source: .standard,
            isReady: bounds.width > 0 && bounds.height > 0
        )
        onCartPresentationChanged?()
    }

    var compactComposerAnchor: UIView {
        // In the leading-tabs layout, chat takes the trailing position when Cart is absent.
        navigationStyle == .pistons && !cartButtonVisible ? cartSlot : backSlot
    }

    var compactComposerPrompt: ShopCompactComposerPrompt? {
        guard !cartButtonVisible else { return nil }
        return ShopAppFirstInteractionTracker.shared.hasInteracted ? .ask : .tryAsking
    }

    var composerTrailingInset: CGFloat {
        cartButtonVisible ? ShopTabBarMetrics.composerHorizontalInset : ShopTabBarMetrics.horizontalInset
    }

    /// The shared backdrop must stay behind both morphing surfaces, even when
    /// their owners exchange front-to-back order.
    func mountBackdrop(behindChromeIn container: UIView) {
        NSLayoutConstraint.deactivate(backdropConstraints)
        container.insertSubview(backdropView, at: 0)
        NSLayoutConstraint.activate(backdropConstraints)
    }

    /// Keep both halves of a user-triggered swap in the same UIKit update, without
    /// waiting for SwiftUI to republish the navigation state on a later frame.
    func setComposerDockPresentation(showsComposer: Bool, compactComposerContentView: UIView?) {
        guard swapsComposer else { return }
        composerDockContentView = compactComposerContentView
        if hidesTabSection != showsComposer {
            hidesTabSection = showsComposer
            updateLeadingButton(animated: false)
            updateTabSectionVisibility(animated: true)
        }
        updateBackButtonVisibility(animated: false)
    }

    private func updateBackButtonVisibility(animated: Bool) {
        let usesFallbackChatButton = swapsComposer && !hidesTabSection && composerDockContentView == nil
        setRollingVisibility(backButton, visible: swapsComposer ? usesFallbackChatButton : showsBackButton,
                             fromRight: true, animated: animated && !swapsComposer)
        backButton.accessibilityElementsHidden = swapsComposer ? !usesFallbackChatButton : !showsBackButton
        backButton.isAccessibilityElement = !swapsComposer || usesFallbackChatButton
        let occupiesCartSlot = swapsComposer && compactComposerAnchor === cartSlot
        if backButtonCartCenterConstraint.isActive != occupiesCartSlot {
            layoutIfNeeded()
            NSLayoutConstraint.deactivate([occupiesCartSlot ? backButtonCenterConstraint : backButtonCartCenterConstraint])
            NSLayoutConstraint.activate([occupiesCartSlot ? backButtonCartCenterConstraint : backButtonCenterConstraint])
            if animated, usesFallbackChatButton, window != nil, !UIAccessibility.isReduceMotionEnabled {
                UIView.animate(springDuration: ShopTabBarMetrics.dockSwapDuration,
                               bounce: ShopTabBarMetrics.dockSwapBounce,
                               options: [.allowUserInteraction, .beginFromCurrentState]) { [weak self] in
                    self?.layoutIfNeeded()
                }
            } else {
                layoutIfNeeded()
            }
        }
        setDockToggleHost(swapsComposer ? (hidesTabSection ? tabSurface.contentView : composerDockContentView) : nil)
    }

    private func setDockToggleHost(_ host: UIView?) {
        dockToggleButton.isHidden = host == nil
        guard dockToggleButton.superview !== host else { return }
        NSLayoutConstraint.deactivate(dockToggleConstraints)
        dockToggleConstraints = []
        dockToggleButton.removeFromSuperview()
        guard let host else { return }
        host.addSubview(dockToggleButton)
        dockToggleConstraints = [
            dockToggleButton.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            dockToggleButton.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            dockToggleButton.topAnchor.constraint(equalTo: host.topAnchor),
            dockToggleButton.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ]
        NSLayoutConstraint.activate(dockToggleConstraints)
    }

    private func updateLeadingButton(animated: Bool) {
        let icon: GravityIconName = swapsComposer
            ? (hidesTabSection
                ? selectedTab.icon(
                    isNativeAgentEnabled: isNativeAgentEnabled,
                    usesSearchIconForExplore: usesSearchIconForExplore
                )
                : .shopChatFilled)
            : .leftChevron
        dockToggleButton.accessibilityLabel = swapsComposer
            ? (hidesTabSection
                ? String.localizedStringWithFormat(localizedString("Agent.Navigation.ShowTabs"), selectedTab.title)
                : localizedString("Agent.Navigation.ShowComposer"))
            : localizedString("Header.BackA11yLabel")
        backButton.accessibilityLabel = localizedString(swapsComposer ? "Agent.Navigation.ShowComposer" : "Header.BackA11yLabel")
        compactTabIcon.image = renderedIcon(selectedTab.icon(
            isNativeAgentEnabled: isNativeAgentEnabled,
            usesSearchIconForExplore: usesSearchIconForExplore
        ),
                                           color: GravityColor.text, points: 24)
        dockToggleButton.largeContentTitle = dockToggleButton.accessibilityLabel
        dockToggleButton.largeContentImage = renderedIcon(icon, color: GravityColor.text, points: 24)
        backButton.largeContentTitle = backButton.accessibilityLabel
        backButton.largeContentImage = dockToggleButton.largeContentImage
        let changes = { [self] in
            backButton.setGlassImage(renderedIcon(icon, color: GravityColor.text, points: 24))
        }
        if animated, !swapsComposer, window != nil, !UIAccessibility.isReduceMotionEnabled {
            UIView.transition(with: backButton, duration: ShopTabBarMetrics.dockIconFadeDuration,
                              options: [.transitionCrossDissolve, .allowUserInteraction, .beginFromCurrentState],
                              animations: changes)
        } else {
            changes()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window {
            ShopAppFirstInteractionTracker.shared.install(in: window)
        }
        coordinator?.updateCartTarget(
            id: cartTargetID,
            source: .standard,
            isReady: window != nil && cartButtonVisible
        )
    }

    private func buildViewHierarchy() {
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdropView)

        chromeRow.translatesAutoresizingMaskIntoConstraints = false
        chromeRow.axis = .horizontal
        chromeRow.alignment = .bottom
        // Equal side slots and equal gaps keep the tabs centered independently.
        chromeRow.distribution = .equalSpacing
        chromeRow.spacing = ShopTabBarMetrics.composerSideGap
        addSubview(chromeRow)

        [backSlot, cartSlot].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            chromeRow.addArrangedSubview($0)
        }
        tabSlot.translatesAutoresizingMaskIntoConstraints = false
        chromeRow.insertArrangedSubview(tabSlot, at: 1)
        flexibleDockSpace.translatesAutoresizingMaskIntoConstraints = false
        flexibleDockSpace.isHidden = true
        flexibleDockSpace.isUserInteractionEnabled = false
        chromeRow.insertArrangedSubview(flexibleDockSpace, at: 2)
        // The spacer contributes the flexible part of the gap, not another 12pt.
        chromeRow.setCustomSpacing(0, after: flexibleDockSpace)
        tabSurface.accessibilityIdentifier = "navigation-tab-surface"
        tabSlot.addSubview(tabSurface)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setGlassImage(renderedIcon(.leftChevron, color: GravityColor.text, points: 24))
        backButton.accessibilityLabel = localizedString("Header.BackA11yLabel")
        backButton.accessibilityIdentifier = "floating-back-button"
        backButton.alpha = 0
        backButton.isHidden = true
        backButton.transform = CGAffineTransform(translationX: Metrics.hiddenOffset, y: 0)
            .scaledBy(x: 0.5, y: 0.5)
        backSlot.addSubview(backButton)
        configureLargeContentViewer(backButton)

        dockToggleButton.translatesAutoresizingMaskIntoConstraints = false
        dockToggleButton.accessibilityIdentifier = "navigation-composer-toggle"
        dockToggleButton.isHidden = true
        configureLargeContentViewer(dockToggleButton)

        tabSurface.translatesAutoresizingMaskIntoConstraints = false

        selectedIndicator.translatesAutoresizingMaskIntoConstraints = false
        selectedIndicator.isUserInteractionEnabled = false
        selectedIndicator.backgroundColor = UIColor(GravityColor.bgOverlayFixedDark04)
        selectedIndicator.layer.cornerRadius = Metrics.indicatorSize / 2
        selectedIndicator.layer.cornerCurve = .continuous
        tabSurface.contentView.addSubview(selectedIndicator)

        tabButtonsRow.translatesAutoresizingMaskIntoConstraints = false
        tabButtonsRow.axis = .horizontal
        tabButtonsRow.alignment = .center
        tabButtonsRow.spacing = 0
        tabSurface.contentView.addSubview(tabButtonsRow)

        compactTabIcon.translatesAutoresizingMaskIntoConstraints = false
        compactTabIcon.contentMode = .scaleAspectFit
        compactTabIcon.isAccessibilityElement = false
        compactTabIcon.alpha = 0
        tabSurface.contentView.addSubview(compactTabIcon)

        cartButton.translatesAutoresizingMaskIntoConstraints = false
        cartButton.accessibilityLabel = localizedString("Common.CartCapitalized")
        cartButton.accessibilityIdentifier = "rolling-cart-button"
        cartButton.alpha = 0
        cartButton.isHidden = true
        cartButton.transform = CGAffineTransform(translationX: -Metrics.hiddenOffset, y: 0)
            .scaledBy(x: 0.5, y: 0.5)
        cartSlot.addSubview(cartButton)
        configureLargeContentViewer(cartButton)

        cartContent.translatesAutoresizingMaskIntoConstraints = false
        cartContent.isUserInteractionEnabled = false
        cartButton.addSubview(cartContent)
        cartIconView.translatesAutoresizingMaskIntoConstraints = false
        cartIconView.contentMode = .scaleAspectFit
        cartContent.addSubview(cartIconView)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.textAlignment = .center
        badgeLabel.adjustsFontForContentSizeCategory = true
        cartContent.addSubview(badgeLabel)
    }

    private func buildConstraints() {
        bottomConstraint = chromeRow.bottomAnchor.constraint(equalTo: bottomAnchor)
        backButtonCenterConstraint = backButton.centerXAnchor.constraint(equalTo: backSlot.centerXAnchor)
        backButtonCartCenterConstraint = backButton.centerXAnchor.constraint(equalTo: cartSlot.centerXAnchor)
        backdropHeightConstraint = backdropView.heightAnchor.constraint(equalToConstant: ShopTabBarMetrics.backdropHeight)
        tabSurfaceWidthConstraint = tabSlot.widthAnchor.constraint(equalToConstant: 0)
        tabSurfaceLeadingConstraint = tabSurface.leadingAnchor.constraint(equalTo: tabSlot.leadingAnchor)
        tabMaterialWidthConstraint = tabSurface.widthAnchor.constraint(equalToConstant: 0)
        tabContentWidthConstraint = tabButtonsRow.widthAnchor.constraint(equalToConstant: 0)
        indicatorLeadingConstraint = selectedIndicator.leadingAnchor.constraint(
            equalTo: tabButtonsRow.leadingAnchor,
            constant: (Metrics.tabButtonWidth - Metrics.indicatorSize) / 2
        )
        backdropConstraints = [
            backdropView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: bottomAnchor),
            backdropHeightConstraint,
        ]
        NSLayoutConstraint.activate(backdropConstraints)
        NSLayoutConstraint.activate([
            chromeRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.horizontalInset),
            chromeRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Metrics.horizontalInset),
            bottomConstraint,
            chromeRow.heightAnchor.constraint(equalToConstant: Metrics.buttonSize),
            flexibleDockSpace.widthAnchor.constraint(greaterThanOrEqualToConstant: 0),
            flexibleDockSpace.heightAnchor.constraint(equalToConstant: Metrics.buttonSize),

            backSlot.widthAnchor.constraint(equalToConstant: Metrics.buttonSize),
            backSlot.heightAnchor.constraint(equalToConstant: Metrics.buttonSize),
            cartSlot.widthAnchor.constraint(equalToConstant: Metrics.buttonSize),
            cartSlot.heightAnchor.constraint(equalToConstant: Metrics.buttonSize),

            backButtonCenterConstraint,
            backButton.widthAnchor.constraint(equalToConstant: Metrics.buttonSize),
            backButton.topAnchor.constraint(equalTo: backSlot.topAnchor),
            backButton.bottomAnchor.constraint(equalTo: backSlot.bottomAnchor),

            tabSurfaceWidthConstraint,
            tabSlot.heightAnchor.constraint(equalToConstant: Metrics.buttonSize),
            tabSurfaceLeadingConstraint,
            tabMaterialWidthConstraint,
            tabSurface.topAnchor.constraint(equalTo: tabSlot.topAnchor),
            tabSurface.bottomAnchor.constraint(equalTo: tabSlot.bottomAnchor),
            tabSurface.heightAnchor.constraint(equalToConstant: Metrics.buttonSize),

            selectedIndicator.widthAnchor.constraint(equalToConstant: Metrics.indicatorSize),
            selectedIndicator.heightAnchor.constraint(equalToConstant: Metrics.indicatorSize),
            selectedIndicator.centerYAnchor.constraint(equalTo: tabSurface.contentView.centerYAnchor),
            indicatorLeadingConstraint,

            // Preserve content size while the glass itself contracts into a circle.
            tabContentWidthConstraint,
            tabButtonsRow.centerXAnchor.constraint(equalTo: tabSurface.contentView.centerXAnchor),
            tabButtonsRow.centerYAnchor.constraint(equalTo: tabSurface.contentView.centerYAnchor),
            tabButtonsRow.heightAnchor.constraint(equalToConstant: Metrics.tabButtonHeight),
            compactTabIcon.centerXAnchor.constraint(equalTo: tabSurface.contentView.centerXAnchor),
            compactTabIcon.centerYAnchor.constraint(equalTo: tabSurface.contentView.centerYAnchor),
            compactTabIcon.widthAnchor.constraint(equalToConstant: 24),
            compactTabIcon.heightAnchor.constraint(equalToConstant: 24),

            cartButton.leadingAnchor.constraint(equalTo: cartSlot.leadingAnchor),
            cartButton.trailingAnchor.constraint(equalTo: cartSlot.trailingAnchor),
            cartButton.topAnchor.constraint(equalTo: cartSlot.topAnchor),
            cartButton.bottomAnchor.constraint(equalTo: cartSlot.bottomAnchor),

            cartContent.leadingAnchor.constraint(equalTo: cartButton.leadingAnchor),
            cartContent.trailingAnchor.constraint(equalTo: cartButton.trailingAnchor),
            cartContent.topAnchor.constraint(equalTo: cartButton.topAnchor),
            cartContent.bottomAnchor.constraint(equalTo: cartButton.bottomAnchor),
            cartIconView.centerXAnchor.constraint(equalTo: cartContent.centerXAnchor),
            cartIconView.centerYAnchor.constraint(equalTo: cartContent.centerYAnchor),
            cartIconView.widthAnchor.constraint(equalToConstant: 24),
            cartIconView.heightAnchor.constraint(equalToConstant: 24),
            badgeLabel.centerXAnchor.constraint(equalTo: cartContent.centerXAnchor, constant: 1),
            badgeLabel.centerYAnchor.constraint(equalTo: cartContent.centerYAnchor),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 12),
            badgeLabel.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    private func configureLargeContentViewer(_ button: UIButton) {
        button.showsLargeContentViewer = true
        button.scalesLargeContentImage = true
        button.largeContentTitle = button.accessibilityLabel
        button.addInteraction(UILargeContentViewerInteraction())
    }

    private func configureInteractions() {
        backButton.addAction(UIAction { [weak self] _ in
            ShopHaptics.light()
            self?.onBack?()
        }, for: .touchUpInside)
        dockToggleButton.addAction(UIAction { [weak self] _ in
            ShopHaptics.light()
            self?.onBack?()
        }, for: .touchUpInside)
        cartButton.addAction(UIAction { [weak self] _ in
            ShopHaptics.light()
            self?.window?.endEditing(true)
            self?.onOpenCart?()
        }, for: .touchUpInside)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleTabPan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        tabPanRecognizer = pan
        tabSurface.addGestureRecognizer(pan)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleNavigationStyleLongPress(_:)))
        longPress.minimumPressDuration = 0.6
        longPress.cancelsTouchesInView = false
        longPress.delegate = self
        navigationStyleLongPressRecognizer = longPress
        tabSurface.addGestureRecognizer(longPress)
    }

    private func rebuildTabButtons() {
        tabButtons.forEach { $0.removeFromSuperview() }
        tabButtons.removeAll()
        tabSurfaceWidthConstraint.constant = ShopTabBarMetrics.tabSectionWidth(tabCount: tabs.count)
        tabContentWidthConstraint.constant = CGFloat(tabs.count) * Metrics.tabButtonWidth

        for (index, tab) in tabs.enumerated() {
            let button = UIButton(type: .custom)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.tag = index
            button.accessibilityLabel = tab.title
            configureLargeContentViewer(button)
            button.addTarget(self, action: #selector(tabButtonPressed(_:)), for: .touchUpInside)
            tabButtonsRow.addArrangedSubview(button)
            button.widthAnchor.constraint(equalToConstant: Metrics.tabButtonWidth).isActive = true
            button.heightAnchor.constraint(equalToConstant: Metrics.tabButtonHeight).isActive = true
            tabButtons.append(button)
        }
    }

    private func updateTabAppearance() {
        for (index, button) in tabButtons.enumerated() where tabs.indices.contains(index) {
            let tab = tabs[index]
            let isSelected = tab == selectedTab
            button.setImage(
                renderedIcon(
                    tab.icon(
                        isNativeAgentEnabled: isNativeAgentEnabled,
                        usesSearchIconForExplore: usesSearchIconForExplore
                    ),
                    color: isSelected ? GravityColor.text : GravityColor.textTertiary,
                    points: 24
                ),
                for: .normal
            )
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
            button.largeContentTitle = tab.title
            button.largeContentImage = button.image(for: .normal)
        }
    }

    private func updateCartAppearance() {
        let savedForLaterOnly = cartButtonMode == .savedForLaterOnly
        cartButton.setGlassTint(
            savedForLaterOnly ? UIColor(GravityColor.bgFill) : UIColor(GravityColor.bgFillBrand),
            prominent: savedForLaterOnly == false
        )
        cartIconView.image = renderedIcon(
            .navigationCartFilled,
            color: savedForLaterOnly ? GravityColor.textTertiary : GravityColor.textFixedLight,
            points: 24
        )
        cartButton.largeContentTitle = cartButton.accessibilityLabel
        cartButton.largeContentImage = cartIconView.image
        badgeLabel.isHidden = savedForLaterOnly || cartTotalItemCount <= 0
        badgeLabel.text = "\(min(cartTotalItemCount, ShopCartBadgeCount.maxDisplayed))"
        badgeLabel.textColor = UIColor(GravityColor.textFixedBrand)
        let badgePointSize = cartTotalItemCount > 9 ? 9 : GravityTextStyle.badgeBold.size
        let badgeFont = UIFont(name: GravityFonts.semibold, size: badgePointSize)
            ?? UIFont.systemFont(ofSize: badgePointSize, weight: .semibold)
        badgeLabel.font = UIFontMetrics(forTextStyle: .caption2).scaledFont(for: badgeFont)
    }

    private func updateIndicator(animated: Bool) {
        guard let index = tabs.firstIndex(of: selectedTab) else {
            selectedIndicator.isHidden = true
            return
        }
        selectedIndicator.isHidden = false
        indicatorLeadingConstraint.constant = CGFloat(index) * Metrics.tabButtonWidth
            + (Metrics.tabButtonWidth - Metrics.indicatorSize) / 2

        guard animated, UIAccessibility.isReduceMotionEnabled == false else {
            layoutIfNeeded()
            return
        }
        UIView.animate(
            springDuration: Metrics.indicatorTravelDuration,
            bounce: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) { [weak self] in
            self?.layoutIfNeeded()
        }
    }

    private func setRollingVisibility(_ view: UIView, visible: Bool, fromRight: Bool, animated: Bool) {
        view.isUserInteractionEnabled = visible
        view.accessibilityElementsHidden = !visible
        if visible {
            view.isHidden = false
        }
        let changes = {
            view.alpha = visible ? 1 : 0
            view.transform = visible
                ? .identity
                : CGAffineTransform(translationX: fromRight ? Metrics.hiddenOffset : -Metrics.hiddenOffset, y: 0)
                    .scaledBy(x: 0.5, y: 0.5)
        }
        let completion: (Bool) -> Void = { finished in
            guard finished else { return }
            view.isHidden = !visible
        }

        guard animated, UIAccessibility.isReduceMotionEnabled == false else {
            changes()
            completion(true)
            return
        }
        UIView.animate(
            springDuration: 0.48,
            bounce: 0.08,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: changes,
            completion: completion
        )
    }

    private func updateDockAlignment() {
        // Keep the same materials and embedded controls. Only the resting slots change.
        // Rodeo swaps positions and supplies a depth dip; Pistons keeps the tabs leading.
        let usesPistonsLayout = navigationStyle == .pistons
        chromeRow.removeArrangedSubview(backSlot)
        chromeRow.insertArrangedSubview(backSlot, at: usesPistonsLayout ? 2 : 0)
        chromeRow.distribution = usesPistonsLayout ? .fill : .equalSpacing
        flexibleDockSpace.isHidden = !usesPistonsLayout
    }

    private func updateTabSectionVisibility(animated: Bool) {
        layoutIfNeeded()
        let compact = swapsComposer && hidesTabSection
        tabSurfaceLeadingConstraint.constant = compact && navigationStyle == .rodeo
            ? backSlot.frame.minX - tabSlot.frame.minX : 0
        tabMaterialWidthConstraint.constant = compact ? Metrics.buttonSize : tabSurfaceWidthConstraint.constant
        // Conversation: tabs slide below the screen while Back and Cart remain stationary.
        // Return: the same tab slot slides up. Never collapse its stack-layout space.
        tabSurface.isUserInteractionEnabled = swapsComposer || !hidesTabSection
        tabSlot.accessibilityElementsHidden = !swapsComposer && hidesTabSection
        tabButtonsRow.accessibilityElementsHidden = hidesTabSection
        tabPanRecognizer?.isEnabled = !hidesTabSection
        let changes = { [self] in
            // Dock swaps replace tabs with a composer, not the bottom protection.
            backdropView.alpha = swapsComposer || !hidesTabSection ? 1 : 0
            if hidesTabSection, !swapsComposer, !UIAccessibility.isReduceMotionEnabled {
                tabSlot.transform = CGAffineTransform(translationX: 0, y: bounds.height + Metrics.buttonSize)
            } else {
                tabSlot.transform = .identity
            }
            tabSlot.alpha = hidesTabSection && !swapsComposer && UIAccessibility.isReduceMotionEnabled ? 0 : 1
            tabButtonsRow.alpha = compact ? 0 : 1
            selectedIndicator.alpha = compact ? 0 : 1
            compactTabIcon.alpha = compact ? 1 : 0
            layoutIfNeeded()
        }
        guard animated, window != nil, !UIAccessibility.isReduceMotionEnabled else {
            ShopDockSwapDepthAnimation.reset(on: tabSlot.layer)
            changes()
            return
        }
        // Scale the slot so the material and its shadow recede together, without
        // competing with the glass surface's native press feedback.
        ShopDockSwapDepthAnimation.animate(
            on: tabSlot.layer,
            recedes: compact,
            bumps: !compact,
            recedingScale: navigationStyle.usesDepthDip
                ? ShopDockSwapDepthAnimation.minimumScale
                : ShopDockSwapDepthAnimation.subtleMinimumScale,
            duration: ShopTabBarMetrics.dockSwapDuration,
            animated: swapsComposer
        )
        UIView.animate(
            springDuration: swapsComposer ? ShopTabBarMetrics.dockSwapDuration : Metrics.conversationTransitionDuration,
            bounce: swapsComposer && !compact
                ? ShopTabBarMetrics.dockExpansionBounce
                : ShopTabBarMetrics.dockSwapBounce,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: changes
        )
    }

    private func bounceCartButton() {
        guard UIAccessibility.isReduceMotionEnabled == false else { return }
        ShopHaptics.light()
        UIView.animate(
            springDuration: 0.24,
            bounce: 0.32,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) { [weak self] in
            self?.cartButton.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        } completion: { [weak self] _ in
            UIView.animate(
                springDuration: 0.28,
                bounce: 0.16,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                self?.cartButton.transform = .identity
            }
        }
    }

    @objc private func tabButtonPressed(_ sender: UIButton) {
        guard tabs.indices.contains(sender.tag), !isScrubbing else { return }
        select(tabs[sender.tag], allowsReselectAction: true)
    }

    @objc private func handleNavigationStyleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, onNavigationStyleLongPressed != nil else { return }
        ShopHaptics.medium()
        onNavigationStyleLongPressed?()
    }

    @objc private func handleTabPan(_ recognizer: UIPanGestureRecognizer) {
        let point = recognizer.location(in: tabSurface)
        switch recognizer.state {
        case .began:
            isScrubbing = true
            scrubStartTab = selectedTab
            setScrubbingAppearance(true)
            select(tab(at: point.x))
        case .changed:
            select(tab(at: point.x))
        case .ended:
            let target = tab(at: point.x)
            select(target, allowsReselectAction: scrubStartTab == target)
            finishScrubbing()
        case .cancelled, .failed:
            finishScrubbing()
        default:
            break
        }
    }

    private func finishScrubbing() {
        isScrubbing = false
        scrubStartTab = nil
        setScrubbingAppearance(false)
    }

    private func setScrubbingAppearance(_ scrubbing: Bool) {
        let changes = { [weak self] in
            self?.selectedIndicator.transform = scrubbing
                ? Metrics.scrubIndicatorScale
                : .identity
            self?.tabButtonsRow.arrangedSubviews.forEach {
                $0.transform = scrubbing ? Metrics.scrubIconScale : .identity
            }
        }
        UIView.animate(withDuration: 0.14, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: changes)
    }

    private func select(_ tab: ShopRootTab, allowsReselectAction: Bool = false) {
        guard selectedTab != tab else {
            if allowsReselectAction {
                ShopHaptics.selection()
                onTabPressed?(tab)
            }
            return
        }
        selectedTab = tab
        ShopHaptics.selection()
        updateTabAppearance()
        updateIndicator(animated: true)
        onTabPressed?(tab)
    }

    private func tab(at x: CGFloat) -> ShopRootTab {
        guard tabs.isEmpty == false else { return selectedTab }
        let trackX = min(max(x - Metrics.tabHorizontalPadding, 0), Metrics.tabButtonWidth * CGFloat(tabs.count) - 1)
        let index = min(max(Int(trackX / Metrics.tabButtonWidth), 0), tabs.count - 1)
        return tabs[index]
    }

    private func reconcileAnimations(_ animations: [ShopAddToCartAnimation]) {
        let visibleAnimations = animations.filter { $0.source == .standard }
        let activeIDs = Set(visibleAnimations.map(\.id))

        for id in Set(animationImageViews.keys).subtracting(activeIDs) {
            animationImageViews.removeValue(forKey: id)?.removeFromSuperview()
            animationImageTasks.removeValue(forKey: id)?.cancel()
            startedAnimationIDs.remove(id)
        }

        for animation in visibleAnimations {
            if animationImageViews[animation.id] == nil, animationImageTasks[animation.id] == nil {
                loadAnimationImage(for: animation)
            }
            if animation.isReadyToStart {
                startAnimationIfPossible(animation)
            }
        }
    }

    private func loadAnimationImage(for animation: ShopAddToCartAnimation) {
        guard let url = URL(string: animation.imageURL) else {
            DispatchQueue.main.async { [weak self] in
                self?.coordinator?.animationImageLoadEnded(id: animation.id)
            }
            return
        }

        let metrics = flyingImageMetrics(for: animation.variant)
        var request = ImageRequest(url: url, priority: .high)
        request.thumbnail = ImageRequest.ThumbnailOptions(
            size: CGSize(width: metrics.originSize, height: metrics.originSize),
            unit: .points,
            contentMode: .aspectFill
        )
        animationImageTasks[animation.id] = ImagePipeline.shared.loadImage(with: request) { [weak self] result in
            guard let self else { return }
            animationImageTasks[animation.id] = nil
            defer { coordinator?.animationImageLoadEnded(id: animation.id) }
            guard case let .success(response) = result else { return }

            let imageView = UIImageView(image: response.image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerCurve = .continuous
            imageView.layer.cornerRadius = GravityRadius.radius12
            imageView.layer.borderColor = UIColor(GravityColor.border).withAlphaComponent(0.22).cgColor
            imageView.layer.borderWidth = 1
            imageView.layer.shadowColor = UIColor.black.cgColor
            imageView.layer.shadowOpacity = 0.18
            imageView.layer.shadowRadius = 14
            imageView.layer.shadowOffset = CGSize(width: 0, height: 6)
            imageView.bounds = CGRect(x: 0, y: 0, width: metrics.originSize, height: metrics.originSize)
            imageView.center = CGPoint(
                x: cartButton.frame.midX + cartSlot.frame.minX + chromeRow.frame.minX + metrics.originX,
                y: chromeRow.frame.minY + cartButton.frame.midY + metrics.originY
            )
            imageView.alpha = 0
            imageView.transform = CGAffineTransform(rotationAngle: animation.rotationDegrees * .pi / 180)
                .scaledBy(x: 0.5, y: 0.5)
            insertSubview(imageView, belowSubview: chromeRow)
            animationImageViews[animation.id] = imageView
        }
    }

    private func startAnimationIfPossible(_ animation: ShopAddToCartAnimation) {
        guard startedAnimationIDs.insert(animation.id).inserted else { return }
        guard let imageView = animationImageViews[animation.id] else {
            // Failed image loads still have to drain the coordinator's animation lifecycle.
            DispatchQueue.main.async { [weak self] in
                self?.coordinator?.animationDidComplete(id: animation.id)
            }
            return
        }

        guard UIAccessibility.isReduceMotionEnabled == false else {
            coordinator?.animationReachedCart(id: animation.id)
            coordinator?.animationDidComplete(id: animation.id)
            imageView.removeFromSuperview()
            animationImageViews[animation.id] = nil
            return
        }

        let metrics = flyingImageMetrics(for: animation.variant)
        UIView.animate(
            springDuration: 0.38,
            bounce: 0.08,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            imageView.alpha = 1
            imageView.transform = CGAffineTransform(rotationAngle: animation.rotationDegrees * .pi / 180)
        } completion: { [weak self] _ in
            let staggerDelay = Double(animation.staggerIndex) * 0.4
                + (animation.staggerIndex == 0 ? 0.1 : 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + staggerDelay) {
                guard let self, imageView.superview != nil else { return }
                UIView.animate(
                    springDuration: 0.48,
                    bounce: 0.1,
                    options: [.allowUserInteraction, .beginFromCurrentState]
                ) {
                    imageView.center = CGPoint(
                        x: self.chromeRow.frame.minX + self.cartSlot.frame.minX + self.cartButton.frame.midX,
                        y: self.chromeRow.frame.minY + self.cartButton.frame.midY
                    )
                    imageView.transform = CGAffineTransform(scaleX: metrics.destinationScale, y: metrics.destinationScale)
                } completion: { [weak self] _ in
                    self?.coordinator?.animationReachedCart(id: animation.id)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        UIView.animate(withDuration: 0.24, animations: {
                            imageView.alpha = 0
                        }, completion: { [weak self] _ in
                            imageView.removeFromSuperview()
                            self?.animationImageViews[animation.id] = nil
                            self?.coordinator?.animationDidComplete(id: animation.id)
                        })
                    }
                }
            }
        }
    }

    private func flyingImageMetrics(for variant: ShopAddToCartAnimationVariant) -> (
        originSize: CGFloat,
        destinationScale: CGFloat,
        originX: CGFloat,
        originY: CGFloat
    ) {
        let screenBounds = window?.bounds ?? bounds
        switch variant {
        case .default:
            return (200, 0.05, -screenBounds.width / 2 + 50, -screenBounds.height * 0.6)
        case .compact:
            return (60, 0.33, 0, -screenBounds.height * 0.16)
        }
    }

    private func renderedIcon(_ name: GravityIconName, color: Color, points: CGFloat) -> UIImage? {
        let scheme: ColorScheme = traitCollection.userInterfaceStyle == .dark ? .dark : .light
        let renderer = ImageRenderer(
            content: ShopIcon(name, pointSize: points, color: color)
                .frame(width: points, height: points)
                .environment(\.colorScheme, scheme)
        )
        renderer.scale = traitCollection.displayScale
        return renderer.uiImage?.withRenderingMode(.alwaysOriginal)
    }
}

@MainActor
private final class ShopUIKitTabBarBackdropView: UIView {
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let colorGradient = CAGradientLayer()
    private let maskGradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityIdentifier = "navigation-bottom-protection"
        blur.frame = bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blur)
        layer.addSublayer(colorGradient)
        layer.mask = maskGradient
        colorGradient.locations = [0, 0.58, 1]
        maskGradient.colors = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.45).cgColor,
            UIColor.black.withAlphaComponent(0.82).cgColor,
            UIColor.black.cgColor,
        ]
        maskGradient.locations = [0, 0.14, 0.40, 0.64, 1]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        colorGradient.frame = bounds
        maskGradient.frame = bounds
    }

    func update(color: UIColor) {
        var white: CGFloat = 0
        var alpha: CGFloat = 0
        let isDark: Bool
        if color.getWhite(&white, alpha: &alpha) {
            isDark = white < 0.5
        } else {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            isDark = red * 0.299 + green * 0.587 + blue * 0.114 < 0.5
        }
        blur.effect = UIBlurEffect(style: isDark ? .systemMaterialDark : .systemMaterialLight)
        colorGradient.colors = [
            color.withAlphaComponent(0).cgColor,
            color.withAlphaComponent(0.58).cgColor,
            color.withAlphaComponent(0.84).cgColor,
        ]
    }
}
