import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

// MARK: - Item Model

public enum ShopContextMenuItemRole: Equatable {
    case normal
    case destructive
}

public struct ShopContextMenuItem {
    public let id: String
    public let title: String
    public let icon: ShopIconName?
    public let role: ShopContextMenuItemRole
    public let enabled: Bool
    public let action: () -> Void

    public init(
        _ title: String,
        id: String? = nil,
        icon: ShopIconName? = nil,
        role: ShopContextMenuItemRole = .normal,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.id = id ?? title
        self.title = title
        self.icon = icon
        self.role = role
        self.enabled = enabled
        self.action = action
    }
}

// MARK: - Result Builder

@resultBuilder
public enum ShopContextMenuBuilder {
    public static func buildExpression(_ item: ShopContextMenuItem) -> [ShopContextMenuItem] {
        [item]
    }

    public static func buildExpression(_ items: [ShopContextMenuItem]) -> [ShopContextMenuItem] {
        items
    }

    public static func buildBlock(_ components: [ShopContextMenuItem]...) -> [ShopContextMenuItem] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ item: [ShopContextMenuItem]?) -> [ShopContextMenuItem] {
        item ?? []
    }

    public static func buildEither(first items: [ShopContextMenuItem]) -> [ShopContextMenuItem] {
        items
    }

    public static func buildEither(second items: [ShopContextMenuItem]) -> [ShopContextMenuItem] {
        items
    }

    public static func buildArray(_ components: [[ShopContextMenuItem]]) -> [ShopContextMenuItem] {
        components.flatMap { $0 }
    }
}

// MARK: - Shared helper

/// Converts `ShopContextMenuItem` array into SwiftUI `ShopButton` views for use
/// inside both `Menu` and `contextMenu`.
struct ShopMenuItemButtons: View {
    let items: [ShopContextMenuItem]

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
            SwiftUI.Button(role: item.role == .destructive ? .destructive : nil) {
                item.action()
            } label: {
                if let icon = item.icon {
                    SwiftUI.Label {
                        SwiftUI.Text(item.title)
                    } icon: {
                        Image(icon.assetName, bundle: .gravityResources)
                            .renderingMode(.template)
                    }
                } else {
                    SwiftUI.Text(item.title)
                }
            }
            .foregroundStyle(item.foregroundColor)
            .tint(item.foregroundColor)
            .disabled(!item.enabled)
            .accessibilityIdentifier(item.id)
        }
    }
}

private extension ShopContextMenuItem {
    var foregroundColor: Color {
        guard enabled else { return GravityColor.textPlaceholder }
        return role == .destructive ? GravityColor.textCritical : GravityColor.text
    }
}

// MARK: - Context Menu (long-press)

public extension View {
    /// Attaches a native iOS **context menu** (long-press) to this view.
    ///
    /// Long-press lifts the view with the system glass morphing treatment
    /// and presents the menu items.
    ///
    /// ```swift
    /// ShopCard { ... }
    ///     .shopContextMenu {
    ///         ShopContextMenuItem("Share", icon: .share) { share() }
    ///         ShopContextMenuItem("Delete", icon: .delete, role: .destructive) { delete() }
    ///     }
    /// ```
    func shopContextMenu(
        @ShopContextMenuBuilder items: @escaping () -> [ShopContextMenuItem]
    ) -> some View {
        let menuItems = items()
        return contextMenu {
            ShopMenuItemButtons(items: menuItems)
        }
    }

    /// Attaches a native iOS **context menu** from a pre-built array of items.
    func shopContextMenu(items: [ShopContextMenuItem]) -> some View {
        contextMenu {
            ShopMenuItemButtons(items: items)
        }
    }

    /// Attaches a native iOS **context menu** and reports the long press that opens it.
    ///
    /// Presentation is left entirely to SwiftUI `.contextMenu`, so the lift, preview, corner
    /// radius, and system chrome are unchanged. Reporting is observed by a separate UIKit
    /// recognizer that is configured **not** to interfere.
    ///
    /// A SwiftUI `LongPressGesture` cannot be used for this. `.contextMenu` is backed by a
    /// UIKit `UIContextMenuInteraction`, and SwiftUI gestures always have
    /// `cancelsTouchesInView == true` with no API to change it, so whichever resolves first
    /// cancels the other: a gesture at the system threshold never fires, and a shorter one
    /// suppresses the menu. A raw `UILongPressGestureRecognizer` can opt out of cancelling
    /// touches and permit simultaneous recognition, so both observe the same press.
    ///
    /// Reports on long-press recognition rather than menu display, matching RN
    /// (`ProductCard.tsx` `onLongPress`) and Android (`combinedClickable(onLongClick:)`).
    ///
    /// - Parameters:
    ///   - items: Menu items. When empty, no menu is presented, but the press is still reported.
    ///   - onLongPress: Called once when the long press is recognized.
    func shopContextMenu(
        items: [ShopContextMenuItem],
        onLongPress: @escaping () -> Void
    ) -> some View {
        contextMenu {
            ShopMenuItemButtons(items: items)
        }
        .background(
            ShopContextMenuLongPressObserver(
                isEnabled: true,
                onLongPress: onLongPress
            )
        )
    }
}

// MARK: - Long-press observation

/// Installs a non-interfering `UILongPressGestureRecognizer` on the view that renders the
/// content, so a long press can be reported without affecting the context menu.
///
/// Lives in `.background` so it never participates in hit testing or blocks taps/scrolling.
private struct ShopContextMenuLongPressObserver: UIViewRepresentable {
    let isEnabled: Bool
    let onLongPress: () -> Void

    func makeUIView(context: Context) -> ShopLongPressObserverView {
        let view = ShopLongPressObserverView()
        view.configure(isEnabled: isEnabled, onLongPress: onLongPress)
        return view
    }

    func updateUIView(_ view: ShopLongPressObserverView, context: Context) {
        view.configure(isEnabled: isEnabled, onLongPress: onLongPress)
    }

    static func dismantleUIView(_ view: ShopLongPressObserverView, coordinator: Coordinator) {
        view.removeInstalledRecognizer()
    }
}

/// Transparent, non-interactive view that owns the observing recognizer.
///
/// The recognizer is attached to the **superview** — the view SwiftUI uses to draw and
/// hit-test the content — so it sees the same press the context menu does.
final class ShopLongPressObserverView: UIView, UIGestureRecognizerDelegate {
    /// Slightly below the system context-menu threshold (~0.5s) so the press is observed
    /// before menu presentation cancels the touch.
    private static let pressDuration: TimeInterval = 0.4

    private var onLongPress: (() -> Void)?
    private var reportsLongPress = false

    private weak var installedHost: UIView?
    private var installedRecognizer: ShopLongPressObserverRecognizer?

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(isEnabled: Bool, onLongPress: @escaping () -> Void) {
        reportsLongPress = isEnabled
        self.onLongPress = onLongPress
        installedRecognizer?.isEnabled = isEnabled
        installRecognizerIfNeeded()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        installRecognizerIfNeeded()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        installRecognizerIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // SwiftUI attaches `.contextMenu`'s interaction after the background subtree is
        // mounted, so the host may not exist yet at `didMoveToSuperview`/`didMoveToWindow`.
        installRecognizerIfNeeded()
    }

    /// The view SwiftUI attached `.contextMenu` to.
    ///
    /// `superview` is **not** it: SwiftUI wraps a `UIViewRepresentable` in its own private
    /// `UIKitPlatformViewHost`, a zero-size non-interactive box that never receives the card's
    /// touches. Anchoring to the ancestor that owns the `UIContextMenuInteraction` guarantees
    /// the recognizer observes exactly the press the context menu responds to.
    private func contextMenuHost() -> UIView? {
        var candidate: UIView? = superview
        while let current = candidate {
            if current.interactions.contains(where: { $0 is UIContextMenuInteraction }) {
                return current
            }
            candidate = current.superview
        }
        return nil
    }

    /// SwiftUI recycles backing views, so the host is re-checked on every update and the
    /// recognizer is moved rather than duplicated when the host changes.
    private func installRecognizerIfNeeded() {
        guard let host = contextMenuHost() else { return }

        if installedHost !== host {
            removeInstalledRecognizer()
        }
        guard installedRecognizer == nil else { return }

        let recognizer = ShopLongPressObserverRecognizer()
        recognizer.minimumPressDuration = Self.pressDuration
        // The whole point: observe the press without taking it from anyone else.
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = self
        recognizer.isEnabled = reportsLongPress
        // A hosting view can carry several `.contextMenu` interactions (for example a feed
        // section whose cards all live in one hosting cell), so several observers install
        // recognizers on the same host. This observer's background frame is exactly its own
        // card's frame; gating on it makes only the pressed card report.
        recognizer.hitTestView = self
        recognizer.onLongPress = { [weak self] in
            guard let self, self.reportsLongPress else { return }
            self.onLongPress?()
        }

        host.addGestureRecognizer(recognizer)
        installedRecognizer = recognizer
        installedHost = host
    }

    func removeInstalledRecognizer() {
        if let installedRecognizer, let installedHost {
            installedHost.removeGestureRecognizer(installedRecognizer)
        }
        installedRecognizer = nil
        installedHost = nil
    }

    deinit {
        if let installedRecognizer, let installedHost {
            installedHost.removeGestureRecognizer(installedRecognizer)
        }
    }

    // MARK: UIGestureRecognizerDelegate

    /// Never compete with the context-menu interaction, scrolling, or taps.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }
}

/// A pure touch **observer** that times a long press itself and never recognizes.
///
/// A real `UILongPressGestureRecognizer` cannot be used for observation here: the context
/// menu's private recognizers impose a failure requirement on sibling long-press
/// recognizers, holding them in `.possible` until the menu recognizer fails — and when the
/// menu presents, it never fails, so the sibling never fires. That requirement is created by
/// the system's delegate and cannot be vetoed from this side.
///
/// Failure requirements gate state **transitions**, not touch delivery: a recognizer in
/// `.possible` still receives every touch for its view. So this recognizer stays in
/// `.possible` for the whole press, runs its own timer, and calls `onLongPress` directly
/// when the touch has been held long and still enough. It never transitions to a recognized
/// state, so it cannot win, cancel, delay, or otherwise perturb the system interaction.
private final class ShopLongPressObserverRecognizer: UIGestureRecognizer {
    /// How long the touch must be held before it is reported.
    var minimumPressDuration: TimeInterval = 0.5
    /// Movement tolerance before the press stops counting, matching
    /// `UILongPressGestureRecognizer.allowableMovement`'s default.
    var allowableMovement: CGFloat = 10
    /// When set, only touches that begin inside this view's bounds are observed. Used to
    /// disambiguate multiple observers installed on one shared hosting view.
    weak var hitTestView: UIView?
    var onLongPress: (() -> Void)?

    private var initialLocation: CGPoint?
    private var timer: Timer?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard numberOfTouches == 1, timer == nil, initialLocation == nil else {
            // Multi-touch or re-entry: not a long press.
            cancelObservation()
            return
        }
        if let hitTestView {
            guard hitTestView.bounds.contains(location(in: hitTestView)) else { return }
        }
        initialLocation = location(in: view?.window)
        let timer = Timer(timeInterval: minimumPressDuration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.timer != nil else { return }
                self.timer = nil
                self.onLongPress?()
            }
        }
        // `.common` so the timer still fires if the run loop enters tracking mode.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let initialLocation, timer != nil else { return }
        let current = location(in: view?.window)
        let distance = hypot(current.x - initialLocation.x, current.y - initialLocation.y)
        if distance > allowableMovement {
            // The touch is a scroll/drag, not a press.
            cancelObservation()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        cancelObservation()
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        // Menu presentation cancels the touch at the system threshold; by then the timer
        // has already fired. A cancel before the timer fires ends observation silently.
        cancelObservation()
        state = .failed
    }

    override func reset() {
        super.reset()
        cancelObservation()
    }

    private func cancelObservation() {
        timer?.invalidate()
        timer = nil
        initialLocation = nil
    }
}

// MARK: - Menu (tap)

/// A native iOS **tap menu** that expands from the label with system glass chrome.
///
/// Use for overflow buttons and action triggers where a single tap should
/// open the dropdown — no long-press required.
///
/// The menu is presented through a transparent UIKit button overlaid on the label rather
/// than SwiftUI `Menu`, because `Menu` exposes no dismissal callback: interaction tracking
/// (paired open/close analytics) needs to observe the menu closing *without* a selection.
/// The default presentation is the same native `UIMenu` chrome that SwiftUI `Menu` uses. The
/// opt-in isolated overlay uses equivalent UIKit chrome without changing SwiftUI's private
/// presentation environment across independent hosting roots.
///
/// ```swift
/// ShopMenu(onOpen: { track(.opened) }, onClose: { track(.closed) }) {
///     ShopContextMenuItem("Share", icon: .share) { share() }
///     ShopContextMenuItem("Delete", icon: .delete, role: .destructive) { delete() }
/// } label: {
///     ShopIconButton(.overflow, accessibilityLabel: "More", variant: .glass) {}
/// }
/// ```
public struct ShopMenu<Label: View>: View {
    @Environment(\.shopToolbarIconStyleEnabled) private var usesToolbarIconStyle

    private let items: [ShopContextMenuItem]
    private let label: Label
    private let accessibilityLabel: String?
    private let accessibilityIdentifier: String?
    private let accessibilityHint: String?
    private let userInterfaceStyle: UIUserInterfaceStyle
    private let onOpen: (() -> Void)?
    private let onClose: (() -> Void)?

    /// - Parameters:
    ///   - accessibilityLabel: Names the presenting button itself. Supply this for icon-only
    ///     triggers: it moves the accessibility identity onto the control that owns the menu,
    ///     which is what lets the iOS large content viewer activate the menu at accessibility
    ///     text sizes. Without it the label view is named instead and the menu cannot open.
    ///   - accessibilityIdentifier: Test identifier for the presenting button. Supply alongside
    ///     `accessibilityLabel`, which hides the label view from accessibility.
    ///   - accessibilityHint: Describes the outcome of activating the trigger.
    ///   - onOpen: Called when the menu is presented (tap or long-press).
    ///   - onClose: Called when the menu is dismissed — by selecting an item, tapping
    ///     outside, or cancelling. Every `onOpen` is followed by exactly one `onClose`.
    public init(
        accessibilityLabel: String? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityHint: String? = nil,
        userInterfaceStyle: UIUserInterfaceStyle = .unspecified,
        onOpen: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        @ShopContextMenuBuilder items: () -> [ShopContextMenuItem],
        @ViewBuilder label: () -> Label
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityHint = accessibilityHint
        self.userInterfaceStyle = userInterfaceStyle
        self.onOpen = onOpen
        self.onClose = onClose
        self.items = items()
        self.label = label()
    }

    /// The label is deliberately rendered twice. A `.hidden()` copy keeps SwiftUI layout —
    /// the control sizes exactly like its label — while the visible copy is hosted *inside*
    /// the presenting `UIButton`. The system menu presentation morphs the presenting control
    /// into the menu platter; when the button was a transparent overlay the morph animated an
    /// invisible view, so the label stayed frozen in place beside the appearing menu. Hosting
    /// the label in the button makes it the morph source and lets UIKit hide/restore it with
    /// the platter, matching system controls.
    @ViewBuilder
    public var body: some View {
        if let accessibilityLabel {
            label
                .hidden()
                .accessibilityHidden(true)
                .overlay {
                    ShopMenuPresentingButton(
                        items: items,
                        label: Group {
                            if usesToolbarIconStyle {
                                label.shopToolbarIconStyle()
                            } else {
                                label
                            }
                        },
                        accessibilityLabel: accessibilityLabel,
                        accessibilityIdentifier: accessibilityIdentifier,
                        accessibilityHint: accessibilityHint,
                        userInterfaceStyle: userInterfaceStyle,
                        onOpen: onOpen,
                        onClose: onClose
                    )
                }
        } else {
            // Without an accessibility label the hosted copy inside the button provides the
            // accessibility content (the button itself is not an element in this branch), so
            // the representable must stay accessibility-visible.
            label
                .hidden()
                .accessibilityHidden(true)
                .overlay {
                    ShopMenuPresentingButton(
                        items: items,
                        label: Group {
                            if usesToolbarIconStyle {
                                label.shopToolbarIconStyle()
                            } else {
                                label
                            }
                        },
                        userInterfaceStyle: userInterfaceStyle,
                        onOpen: onOpen,
                        onClose: onClose
                    )
                }
        }
    }
}

// MARK: - UIKit-backed presentation

/// Button overlaid on the `ShopMenu` label's layout slot that owns the native `UIMenu`.
///
/// Fills the label's bounds, so the tap target and menu anchoring match the label exactly.
/// Hosts the visible label content itself so the system menu morph has a real source view.
struct ShopMenuPresentingButton<MenuLabel: View>: UIViewRepresentable {
    let items: [ShopContextMenuItem]
    let label: MenuLabel
    var accessibilityLabel: String? = nil
    var accessibilityIdentifier: String? = nil
    var accessibilityHint: String? = nil
    var userInterfaceStyle: UIUserInterfaceStyle = .unspecified
    let onOpen: (() -> Void)?
    let onClose: (() -> Void)?

    func makeUIView(context: Context) -> ShopMenuReportingButton {
        let button = ShopMenuReportingButton(type: .custom)
        configure(button, isEnabled: context.environment.isEnabled)
        return button
    }

    func updateUIView(_ button: ShopMenuReportingButton, context: Context) {
        configure(button, isEnabled: context.environment.isEnabled)
    }

    func configure(_ button: ShopMenuReportingButton, isEnabled: Bool) {
        button.onMenuOpen = onOpen
        button.onMenuClose = onClose
        button.updateHostedLabel(
            label,
            accessibilityTraits: accessibilityLabel == nil ? .isButton : []
        )
        button.updateMenuItems(items)

        let nextIsEnabled = isEnabled && items.isEmpty == false
        if button.isEnabled != nextIsEnabled {
            button.isEnabled = nextIsEnabled
        }
        if button.overrideUserInterfaceStyle != userInterfaceStyle {
            button.overrideUserInterfaceStyle = userInterfaceStyle
        }
        configureAccessibility(button)
    }

    /// Names the presenting button and opts it into the large content viewer.
    ///
    /// At accessibility text sizes iOS long-presses small controls into the large content viewer
    /// and activates whichever element owns it once the press ends. That element has to be the
    /// button holding the menu, otherwise the press resolves to the label and nothing opens.
    private func configureAccessibility(_ button: ShopMenuReportingButton) {
        let ownsAccessibilityIdentity = accessibilityLabel != nil
        if button.isAccessibilityElement != ownsAccessibilityIdentity {
            button.isAccessibilityElement = ownsAccessibilityIdentity
        }
        if button.accessibilityLabel != accessibilityLabel {
            button.accessibilityLabel = accessibilityLabel
        }
        if button.accessibilityIdentifier != accessibilityIdentifier {
            button.accessibilityIdentifier = accessibilityIdentifier
        }
        if button.accessibilityHint != accessibilityHint {
            button.accessibilityHint = accessibilityHint
        }
        if button.accessibilityTraits != .button {
            button.accessibilityTraits = .button
        }
        if button.showsLargeContentViewer != ownsAccessibilityIdentity {
            button.showsLargeContentViewer = ownsAccessibilityIdentity
        }
        if button.largeContentTitle != accessibilityLabel {
            button.largeContentTitle = accessibilityLabel
        }
    }
}

struct ShopMenuItemPresentation: Equatable {
    let id: String
    let title: String
    let iconAssetName: String?
    let role: ShopContextMenuItemRole
    let enabled: Bool

    init(item: ShopContextMenuItem) {
        id = item.id
        title = item.title
        iconAssetName = item.icon?.assetName
        role = item.role
        enabled = item.enabled
    }
}

/// A `UIButton` that reports its menu opening and closing.
///
/// Open is observed through both `.menuActionTriggered` and the context-menu interaction's
/// will-display callback (deduplicated), close through the will-end callback, which UIKit
/// invokes on every dismissal — selection, tap-outside, or cancel — guaranteeing every
/// reported open has a matching close.
///
/// Carries a `UILargeContentViewerInteraction` so the button, rather than an ancestor, becomes
/// the large content viewer item and receives the activation that ends the press.
final class ShopMenuReportingButton: UIButton {
    var onMenuOpen: (() -> Void)?
    var onMenuClose: (() -> Void)?

    private(set) var menuItemPresentations: [ShopMenuItemPresentation] = []
    private var menuActions: [() -> Void] = []
    private var isMenuOpen = false
    private var hostedLabelView: (UIView & UIContentView)?
    private(set) var hostedLabelAccessibilityTraits: AccessibilityTraits = []

    /// Installs or updates the visible label content inside the button so the system menu
    /// presentation morphs the real control instead of a transparent overlay. The hosted
    /// content never intercepts touches; when the button carries the accessibility identity
    /// (`isAccessibilityElement == true`), UIKit automatically hides the hosted descendants
    /// from the accessibility tree.
    func updateHostedLabel<Content: View>(
        _ content: Content,
        accessibilityTraits: AccessibilityTraits
    ) {
        hostedLabelAccessibilityTraits = accessibilityTraits
        let configuration = UIHostingConfiguration {
            content.accessibilityAddTraits(accessibilityTraits)
        }
        .margins(.all, 0)
        if let hostedLabelView {
            hostedLabelView.configuration = configuration
            return
        }

        let contentView = configuration.makeContentView()
        contentView.isUserInteractionEnabled = false
        contentView.backgroundColor = .clear
        contentView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(contentView, at: 0)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        hostedLabelView = contentView
    }

    /// The hosted label must fill the button exactly.
    ///
    /// `UIHostingConfiguration`'s content view inherits its ancestors' safe-area insets, and its
    /// SwiftUI root lays out inside them. In a screen that draws under the status bar the inherited
    /// top inset pushes the visible label below the button's bounds, so the control looks
    /// misaligned and taps land on empty space above it.
    override var safeAreaInsets: UIEdgeInsets { .zero }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addAction(
            UIAction { [weak self] _ in self?.menuWillOpen() },
            for: .menuActionTriggered
        )
        addInteraction(UILargeContentViewerInteraction())
        showsMenuAsPrimaryAction = true
        menu = UIMenu(children: [])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateMenuItems(_ items: [ShopContextMenuItem]) {
        menuActions = items.map(\.action)

        let nextPresentations = items.map(ShopMenuItemPresentation.init)
        guard menuItemPresentations != nextPresentations else {
            return
        }

        menuItemPresentations = nextPresentations
        menu = UIMenu(children: menuItemPresentations.enumerated().map { index, item in
            menuAction(for: item, at: index)
        })
    }

    func performMenuAction(at index: Int) {
        guard menuActions.indices.contains(index) else { return }
        menuActions[index]()
    }

    private func menuAction(for item: ShopMenuItemPresentation, at index: Int) -> UIAction {
        var attributes: UIMenuElement.Attributes = []
        if item.role == .destructive {
            attributes.insert(.destructive)
        }
        if item.enabled == false {
            attributes.insert(.disabled)
        }

        return UIAction(
            title: item.title,
            image: item.iconAssetName.flatMap { assetName in
                UIImage(named: assetName, in: .gravityResources, compatibleWith: nil)?
                    .withRenderingMode(.alwaysTemplate)
            },
            attributes: attributes
        ) { [weak self] _ in
            self?.performMenuAction(at: index)
        }
    }

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willDisplayMenuFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
        menuWillOpen()
    }

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
        menuWillClose()
    }

    private func menuWillOpen() {
        guard isMenuOpen == false else { return }
        isMenuOpen = true
        onMenuOpen?()
    }

    private func menuWillClose() {
        guard isMenuOpen else { return }
        isMenuOpen = false
        onMenuClose?()
    }
}

// MARK: - Convenience modifier for tap menu

public extension View {
    /// Wraps this view in a native iOS **tap menu** that expands from it.
    ///
    /// Equivalent to wrapping in `ShopMenu { ... } label: { self }`.
    ///
    /// ```swift
    /// ShopIconButton(.overflow, accessibilityLabel: "More", variant: .glass) {}
    ///     .shopMenu {
    ///         ShopContextMenuItem("Share", icon: .share) { share() }
    ///         ShopContextMenuItem("Delete", icon: .delete, role: .destructive) { delete() }
    ///     }
    /// ```
    func shopMenu(
        onOpen: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        @ShopContextMenuBuilder items: @escaping () -> [ShopContextMenuItem]
    ) -> some View {
        ShopMenu(onOpen: onOpen, onClose: onClose, items: items) { self }
    }
}
