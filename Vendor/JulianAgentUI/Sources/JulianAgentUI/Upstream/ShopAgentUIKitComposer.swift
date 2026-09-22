import Gravity
import Nuke
import SwiftUI
import UIKit

private struct ShopAgentComposerHostedExternallyKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var shopAgentComposerHostedExternally: Bool {
        get { self[ShopAgentComposerHostedExternallyKey.self] }
        set { self[ShopAgentComposerHostedExternallyKey.self] = newValue }
    }
}

enum ShopAgentUIKitComposerMetrics {
    static let landingHorizontalInset: CGFloat = GravitySpacing.space20
    static let attachedHorizontalInset: CGFloat = GravitySpacing.space20
    static let focusedHorizontalInset: CGFloat = GravitySpacing.space12
    static let keyboardSpacing: CGFloat = GravitySpacing.space8
    static let focusedKeyboardSpacing: CGFloat = GravitySpacing.space12
    static let minimumAttachedBottomInset: CGFloat = GravitySpacing.space24
    static let bottomButtonSpacing: CGFloat = GravitySpacing.space8
    static let barHeight: CGFloat = 56
    static let buttonSize: CGFloat = GravitySpacing.space40
    static let rowInset: CGFloat = GravitySpacing.space8
    static let rowSpacing: CGFloat = GravitySpacing.space10
    static let cornerRadius: CGFloat = GravityRadius.radius28
    static let attachmentInset: CGFloat = GravitySpacing.space8
    static let contextLaneHeight: CGFloat = GravitySpacing.space48
    static let contextImageSize: CGFloat = GravitySpacing.space24
    static let attachmentSize: CGFloat = GravitySpacing.space64
    static let attachmentLaneHeight: CGFloat = attachmentSize + attachmentInset
    static let maximumTextHeight: CGFloat = 66
    static let navigationBackPassthroughWidth: CGFloat = 160
    static let navigationBackPassthroughHeight: CGFloat = 64
    static let focusTransitionDuration: TimeInterval = 0.42
    static let focusTransitionBounce: CGFloat = 0.04
    static let attachmentTransitionDuration: TimeInterval = 0.34
    static let attachmentTransitionBounce: CGFloat = 0.08
}

enum ShopAgentUIKitComposerContextKind {
    case product
    case shop
    case order
    case image
    case page
}

struct ShopAgentUIKitComposerContext: Equatable {
    let kind: ShopAgentUIKitComposerContextKind
    let title: String
    let subtitle: String?
    let imageURL: String?
    let fallbackIcon: GravityIconName
    let showsImagePlaceholder: Bool

    var accessibilitySummary: String {
        guard let subtitle else { return title }
        return "\(title), \(subtitle)"
    }

    init(
        kind: ShopAgentUIKitComposerContextKind,
        title: String,
        subtitle: String? = nil,
        imageURL: String? = nil,
        fallbackIcon: GravityIconName,
        showsImagePlaceholder: Bool = false
    ) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.fallbackIcon = fallbackIcon
        self.showsImagePlaceholder = showsImagePlaceholder
    }

    init?(contextItems: [ShopAgentMessageContextItem]) {
        guard let item = contextItems.first else { return nil }
        if contextItems.count > 1 {
            self.init(kind: .product, title: localizedString("Agent.Attach.Selected"),
                      subtitle: shopAgentMessageContextSummary(for: contextItems),
                      imageURL: item.imageURL, fallbackIcon: .tag)
            return
        }
        switch item.type {
        case .product:
            self.init(
                kind: .product,
                title: item.title.nonEmpty ?? item.productID.nonEmpty ?? item.id,
                subtitle: item.subtitle.nonEmpty ?? item.name.nonEmpty,
                imageURL: item.imageURL.nonEmpty,
                fallbackIcon: .noImage
            )
        case .shop:
            self.init(
                kind: .shop,
                title: item.name.nonEmpty ?? item.shopID.nonEmpty ?? item.id,
                subtitle: item.subtitle.nonEmpty,
                imageURL: item.logoImageURL.nonEmpty,
                fallbackIcon: .shop
            )
        case .order:
            self.init(
                kind: .order,
                title: item.title.nonEmpty ?? item.orderID.nonEmpty ?? item.id,
                subtitle: item.subtitle.nonEmpty ?? item.name.nonEmpty,
                imageURL: item.imageURL.nonEmpty,
                fallbackIcon: .box
            )
        case .image:
            self.init(
                kind: .image,
                title: item.title.nonEmpty ?? item.imageID.nonEmpty ?? item.id,
                subtitle: item.subtitle.nonEmpty,
                imageURL: item.imageURL.nonEmpty,
                fallbackIcon: .noImage
            )
        case .page:
            self.init(
                kind: .page,
                title: item.screen.nonEmpty ?? item.title.nonEmpty ?? item.id,
                subtitle: item.subtitle.nonEmpty,
                imageURL: item.imageURL.nonEmpty,
                fallbackIcon: .tag
            )
        }
    }
}

/// The shared UIKit composer used by the Agent landing, conversation, and pushed child screens.
/// UIKit owns focus, hit testing, and keyboard-relative positioning. SwiftUI supplies state and
/// actions through one representable boundary.
struct ShopAgentUIKitComposer: UIViewControllerRepresentable {
    @Binding private var query: String

    private let focus: Binding<Bool>?
    private let composing: Binding<Bool>?
    private let placeholder: String
    private let context: ShopAgentUIKitComposerContext?
    private let imageAttachments: [ShopAgentImageAttachment]
    private let canSubmit: Bool
    private let canAddContext: Bool
    private let isStreaming: Bool
    private let showsBackButton: Bool
    private let usesCartButton: Bool
    private let restingBottomInset: CGFloat
    private let bottomSpacing: CGFloat
    private let preservesNavigationBackTapRegion: Bool
    private let resolvesAttachmentPlaceholder: Bool
    private let usesLandingAccessibilityIdentifiers: Bool
    private let onHeightChange: (CGFloat) -> Void
    private let onFocus: () -> Void
    private let onOpen: () -> Void
    private let onDismiss: () -> Void
    private let onBack: () -> Void
    private let onClose: () -> Void
    private let onAddContext: (ShopAgentComposerAttachmentPickerSource) -> Void
    private let onRemoveContext: (() -> Void)?
    private let onRemoveImageAttachment: (UUID) -> Void
    private let onSubmit: () -> Void
    private let onStop: () -> Void

    init(
        query: Binding<String>,
        isFocused: Binding<Bool>,
        placeholder: String,
        contextSummary: String?,
        selectedContext: ShopAgentUIKitComposerContext? = nil,
        imageAttachments: [ShopAgentImageAttachment],
        canSubmit: Bool,
        canAddContext: Bool,
        restingBottomInset: CGFloat,
        onHeightChange: @escaping (CGFloat) -> Void,
        onFocus: @escaping () -> Void,
        onAddContext: @escaping (ShopAgentComposerAttachmentPickerSource) -> Void,
        onRemoveContext: (() -> Void)?,
        onRemoveImageAttachment: @escaping (UUID) -> Void,
        onSubmit: @escaping () -> Void
    ) {
        _query = query
        focus = isFocused
        composing = nil
        self.placeholder = placeholder
        context = selectedContext ?? contextSummary.map {
            ShopAgentUIKitComposerContext(kind: .page, title: $0, fallbackIcon: .tag)
        }
        self.imageAttachments = imageAttachments
        self.canSubmit = canSubmit
        self.canAddContext = canAddContext
        isStreaming = false
        showsBackButton = false
        usesCartButton = false
        self.restingBottomInset = restingBottomInset
        bottomSpacing = 0
        preservesNavigationBackTapRegion = false
        resolvesAttachmentPlaceholder = true
        usesLandingAccessibilityIdentifiers = true
        self.onHeightChange = onHeightChange
        self.onFocus = onFocus
        self.onOpen = {}
        self.onDismiss = {}
        self.onBack = {}
        self.onClose = {}
        self.onAddContext = onAddContext
        self.onRemoveContext = onRemoveContext
        self.onRemoveImageAttachment = onRemoveImageAttachment
        self.onSubmit = onSubmit
        self.onStop = {}
    }

    init(
        query: Binding<String>,
        isComposing: Binding<Bool>,
        context: ShopAgentUIKitComposerContext?,
        placeholder: String? = nil,
        imageAttachments: [ShopAgentImageAttachment],
        canSubmit: Bool,
        isStreaming: Bool,
        showsBackButton: Bool,
        usesCartButton: Bool = false,
        restingBottomInset: CGFloat,
        bottomSpacing: CGFloat,
        preservesNavigationBackTapRegion: Bool,
        onOpen: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onBack: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onAddContext: @escaping (ShopAgentComposerAttachmentPickerSource) -> Void,
        onRemoveImageAttachment: @escaping (UUID) -> Void,
        onSubmit: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        _query = query
        focus = nil
        composing = isComposing
        self.placeholder = placeholder ?? localizedString("Agent.Index.AskFollowUp")
        self.context = context
        self.imageAttachments = imageAttachments
        self.canSubmit = canSubmit
        canAddContext = true
        self.isStreaming = isStreaming
        self.showsBackButton = showsBackButton
        self.usesCartButton = usesCartButton
        self.restingBottomInset = restingBottomInset
        self.bottomSpacing = bottomSpacing
        self.preservesNavigationBackTapRegion = preservesNavigationBackTapRegion
        resolvesAttachmentPlaceholder = false
        usesLandingAccessibilityIdentifiers = false
        onHeightChange = { _ in }
        onFocus = {}
        self.onOpen = onOpen
        self.onDismiss = onDismiss
        self.onBack = onBack
        self.onClose = onClose
        self.onAddContext = onAddContext
        onRemoveContext = nil
        self.onRemoveImageAttachment = onRemoveImageAttachment
        self.onSubmit = onSubmit
        self.onStop = onStop
    }

    func makeUIViewController(context: Context) -> ShopAgentComposerHostViewController {
        ShopAgentComposerHostViewController(
            session: context.environment.shopAgentComposerSession ?? ShopAgentComposerSession()
        )
    }

    func updateUIViewController(
        _ viewController: ShopAgentComposerHostViewController,
        context: Context
    ) {
        viewController.update(
            composer: self,
            priority: context.environment.shopAgentComposerPriority,
            isEnabled: context.environment.shopAgentComposerIsEnabled
        )
    }

    static func dismantleUIViewController(_ controller: ShopAgentComposerHostViewController, coordinator: ()) {
        controller.disconnect()
    }

    /// Reuse the same bindings and actions whether the input lives in the session or shell dock.
    @ViewBuilder
    func hosted(in navigation: ShopBottomNavigationConversation?, isEnabled: Bool = true) -> some View {
        if let navigation {
            if isEnabled {
                ShopBottomNavigationComposerSource(navigation: navigation, composer: self)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        } else {
            self.environment(\.shopAgentComposerIsEnabled, isEnabled)
        }
    }

    var requestsFocus: Bool { focus?.wrappedValue ?? composing?.wrappedValue ?? false }
    var hasText: Bool { !query.isEmpty }

    func dismissFocus() {
        focus?.wrappedValue = false
        composing?.wrappedValue = false
    }

    func requestFocus() {
        if let composing {
            composing.wrappedValue = true
            onOpen()
        } else {
            focus?.wrappedValue = true
        }
    }

    /// Shell-owned Back uses the same action as the composer's own navigation control.
    func navigateBack() {
        dismissFocus()
        onBack()
    }

    /// The shell can own this same input controller without rendering another representable.
    func configure(
        _ viewController: ShopAgentUIKitComposerViewController,
        navigationDockInset: CGFloat? = nil,
        navigationDockTrailingInset: CGFloat? = nil,
        allowsFocus: Bool = true,
        focusOverride: Bool? = nil,
        inlineContainer: UIView? = nil,
        showsBackButtonOverride: Bool? = nil
    ) {
        let isCollapsible = composing != nil || navigationDockInset != nil
        // Explicit dock actions reach UIKit immediately, before SwiftUI refreshes
        // the source's cached bindings. Later updates return to the bound state.
        let isComposing = allowsFocus && (focusOverride ?? composing?.wrappedValue ?? (navigationDockInset == nil || focus?.wrappedValue == true))
        let isFocused = allowsFocus && (focusOverride ?? focus?.wrappedValue ?? isComposing)
        viewController.beginHostChange()
        if let inlineContainer {
            viewController.prepareInlineReturn(to: inlineContainer)
        } else {
            viewController.setInlineContainer(nil, preservesInlinePosition: isFocused)
        }
        let resolvedPlaceholder = resolvesAttachmentPlaceholder ? shopAgentComposerPlaceholder(
            defaultPlaceholder: placeholder,
            singleAttachmentPlaceholder: localizedString("Agent.Composer.AskAboutAttachment"),
            multipleAttachmentPlaceholder: localizedString("Agent.Composer.AskAboutAttachments"),
            hasContextSummary: context != nil,
            imageAttachmentCount: imageAttachments.count
        ) : placeholder

        viewController.update(
            configuration: ShopAgentUIKitComposerConfiguration(
                query: query,
                placeholder: resolvedPlaceholder,
                context: context,
                imageAttachments: imageAttachments,
                canSubmit: canSubmit,
                canAddContext: canAddContext,
                isStreaming: isStreaming,
                isCollapsible: isCollapsible,
                isComposing: isComposing,
                isFocused: isFocused,
                showsBackButton: showsBackButtonOverride ?? showsBackButton,
                usesCartButton: usesCartButton,
                navigationDockInset: navigationDockInset,
                navigationDockTrailingInset: navigationDockTrailingInset,
                restingBottomInset: restingBottomInset,
                bottomSpacing: bottomSpacing,
                preservesNavigationBackTapRegion: preservesNavigationBackTapRegion || navigationDockInset != nil,
                usesLandingAccessibilityIdentifiers: usesLandingAccessibilityIdentifiers,
                canRemoveContext: onRemoveContext != nil,
                isInline: inlineContainer != nil
            ),
            onQueryChange: { query = $0 },
            onFocusChange: { focused in
                focus?.wrappedValue = focused
                if focused { onFocus() }
            },
            onHeightChange: onHeightChange,
            onOpen: {
                if let composing {
                    guard !composing.wrappedValue else { return }
                    composing.wrappedValue = true
                    onOpen()
                } else {
                    focus?.wrappedValue = true
                }
            },
            onDismiss: {
                if let composing {
                    guard composing.wrappedValue else { return }
                    composing.wrappedValue = false
                    onDismiss()
                } else {
                    focus?.wrappedValue = false
                }
            },
            onBack: onBack,
            onClose: onClose,
            onAddContext: onAddContext,
            onRemoveContext: onRemoveContext,
            onRemoveImageAttachment: onRemoveImageAttachment,
            onSubmit: onSubmit,
            onStop: onStop
        )
        if let inlineContainer { viewController.setInlineContainer(inlineContainer) }
        viewController.endHostChange()
    }
}

private struct ShopAgentUIKitComposerConfiguration: Equatable {
    let query: String
    let placeholder: String
    let context: ShopAgentUIKitComposerContext?
    let imageAttachments: [ShopAgentImageAttachment]
    let canSubmit: Bool
    let canAddContext: Bool
    let isStreaming: Bool
    let isCollapsible: Bool
    let isComposing: Bool
    let isFocused: Bool
    let showsBackButton: Bool
    let usesCartButton: Bool
    let navigationDockInset: CGFloat?
    let navigationDockTrailingInset: CGFloat?
    let restingBottomInset: CGFloat
    let bottomSpacing: CGFloat
    let preservesNavigationBackTapRegion: Bool
    let usesLandingAccessibilityIdentifiers: Bool
    let canRemoveContext: Bool
    let isInline: Bool

    var hasExpandedDockWidth: Bool {
        guard let navigationDockInset, let navigationDockTrailingInset else { return false }
        return navigationDockTrailingInset < navigationDockInset
    }
}

@MainActor
final class ShopAgentUIKitComposerViewController: UIViewController {
    private let ownsNavigationButtons: Bool
    private let composerView = ShopAgentUIKitComposerView()
    private let backButton = ShopUIKitGlassButton()
    private let closeButton = ShopUIKitGlassButton()
    private let dismissButton = UIButton(type: .custom)
    private var composerLeadingConstraint: NSLayoutConstraint?
    private var composerTrailingConstraint: NSLayoutConstraint?
    private var keyboardBottomConstraint: NSLayoutConstraint?
    private var restingBottomConstraint: NSLayoutConstraint?
    private var restingBottomCeilingConstraint: NSLayoutConstraint?
    private var backButtonBottomConstraint: NSLayoutConstraint?
    private var closeButtonBottomConstraint: NSLayoutConstraint?
    private var previousConfiguration: ShopAgentUIKitComposerConfiguration?
    private var pendingBackButtonLeadingConstant: CGFloat?
    private var pendingComposerTrailingConstant: CGFloat?
    private var lastReportedHeight: CGFloat = 0
    private var keyboardIsVisible = false
    private var floatingConstraints: [NSLayoutConstraint] = []
    private var inlineConstraints: [NSLayoutConstraint] = []
    private var isLiftingInlineComposer = false
    let inlinePresentation = ShopAgentInlineComposerPresentation()
    private enum InlineTransition { case awaitingKeyboard, opening, returning }
    private var inlineTransition: InlineTransition?
    private weak var inlineReturnContainer: UIView?
    private var inlineReturnIsAnimating = false
    private var inlineAnimationGeneration = 0
    private var usesNavigationReturnAnimation = false
    private var navigationReturnCompletion: (() -> Void)?
    private var keyboardAnimationDuration: TimeInterval = 0.25
    private var keyboardAnimationOptions: UIView.AnimationOptions = .curveEaseInOut
    private var keyboardEndFrame: CGRect?
    private var inlineOpeningTargetGuideTop: CGFloat?
    var isReturningToInline: Bool { inlineTransition == .returning }
    private var onHeightChange: (CGFloat) -> Void = { _ in }
    private var onDismiss: () -> Void = {}
    private var onBack: () -> Void = {}
    private var onClose: () -> Void = {}
    private var dockIsVisible: Bool?
    private weak var compactDockAnchor: UIView?
    private var compactDockPrompt: ShopCompactComposerPrompt?
    private var compactDockNavigationStyle = ShopBottomNavigationStyle.rodeo
    var dockSurfaceContentView: UIView { composerView.dockSurfaceContentView }
    var accessoryBottomAnchor: NSLayoutYAxisAnchor { composerView.topAnchor }

    func placeAccessoryBehindComposer(_ accessory: UIView) {
        // Above the full-screen dismissal target, but under the glass input so
        // starter rows can unfurl from (and fold back beneath) the composer.
        view.insertSubview(accessory, belowSubview: composerView)
    }

    init(ownsNavigationButtons: Bool = true) {
        self.ownsNavigationButtons = ownsNavigationButtons
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ShopAgentUIKitComposerPassthroughView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.keyboardLayoutGuide.followsUndockedKeyboard = true

        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.backgroundColor = .clear
        dismissButton.addAction(UIAction { [weak self] _ in self?.onDismiss() }, for: .touchUpInside)
        view.addSubview(dismissButton)

        configureNavigationButton(
            backButton,
            icon: .leftChevron,
            accessibilityLabel: localizedString("Header.BackA11yLabel"),
            accessibilityIdentifier: "agent-modal-back-button"
        )
        backButton.addAction(UIAction { [weak self] _ in self?.onBack() }, for: .touchUpInside)
        if ownsNavigationButtons { view.addSubview(backButton) }

        configureNavigationButton(
            closeButton,
            icon: .cross,
            accessibilityLabel: localizedString("Header.CloseA11yLabel"),
            accessibilityIdentifier: "agent-close-button"
        )
        closeButton.addAction(UIAction { [weak self] _ in self?.onClose() }, for: .touchUpInside)
        if ownsNavigationButtons { view.addSubview(closeButton) }

        composerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(composerView)

        let leading = composerView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        let trailing = composerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        composerLeadingConstraint = leading
        composerTrailingConstraint = trailing

        let keyboardBottom = composerView.bottomAnchor.constraint(
            equalTo: view.keyboardLayoutGuide.topAnchor,
            constant: -ShopAgentUIKitComposerMetrics.focusedKeyboardSpacing
        )
        keyboardBottom.priority = UILayoutPriority(999)
        keyboardBottom.identifier = "AgentComposer.keyboardBottom"
        keyboardBottomConstraint = keyboardBottom

        let restingBottom = composerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        restingBottom.priority = UILayoutPriority(998)
        restingBottom.identifier = "AgentComposer.restingBottom"
        restingBottomConstraint = restingBottom

        let restingCeiling = composerView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor)
        restingCeiling.identifier = "AgentComposer.restingBottomCeiling"
        restingBottomCeilingConstraint = restingCeiling

        let backButtonBottom = backButton.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: -ShopAgentUIKitComposerMetrics.keyboardSpacing
        )
        backButtonBottom.identifier = "AgentComposer.backButtonRestingBottom"
        backButtonBottomConstraint = backButtonBottom

        let closeButtonBottom = closeButton.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: -ShopAgentUIKitComposerMetrics.keyboardSpacing
        )
        closeButtonBottom.identifier = "AgentComposer.closeButtonRestingBottom"
        closeButtonBottomConstraint = closeButtonBottom

        floatingConstraints = [
            leading,
            trailing,
            composerView.topAnchor.constraint(
                greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor,
                constant: ShopAgentUIKitComposerMetrics.keyboardSpacing
            ),
            keyboardBottom,
            restingBottom,
            restingCeiling,
        ]
        NSLayoutConstraint.activate(floatingConstraints)
        NSLayoutConstraint.activate([
            dismissButton.topAnchor.constraint(equalTo: view.topAnchor),
            dismissButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dismissButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dismissButton.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        if ownsNavigationButtons {
            NSLayoutConstraint.activate([
                backButton.leadingAnchor.constraint(
                    equalTo: view.leadingAnchor,
                    constant: ShopAgentUIKitComposerMetrics.attachedHorizontalInset
                ),
                backButtonBottom,
                backButton.widthAnchor.constraint(equalToConstant: ShopAgentUIKitComposerMetrics.barHeight),
                backButton.heightAnchor.constraint(equalToConstant: ShopAgentUIKitComposerMetrics.barHeight),
                closeButton.trailingAnchor.constraint(
                    equalTo: view.trailingAnchor,
                    constant: -ShopAgentUIKitComposerMetrics.attachedHorizontalInset
                ),
                closeButtonBottom,
                closeButton.widthAnchor.constraint(equalToConstant: ShopAgentUIKitComposerMetrics.barHeight),
                closeButton.heightAnchor.constraint(equalToConstant: ShopAgentUIKitComposerMetrics.barHeight),
            ])
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidHide),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        composerView.applyFocusState()
        if dockIsVisible == false {
            composerView.startTryAskingShimmerIfNeeded()
        }
        animatePendingBackButtonAppearanceIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        finishInlineOpeningIfKeyboardGuideIsAligned()
        updateAttachedRestingBaseline()
        if dockIsVisible == false, let compactDockAnchor {
            composerView.setDockAppearance(
                compactFrame: resolvedCompactFrame(
                    anchoredTo: compactDockAnchor,
                    compactPrompt: compactDockPrompt,
                    navigationStyle: compactDockNavigationStyle
                ),
                compactPrompt: compactDockPrompt
            )
        }
        let height = composerView.bounds.height
        guard height > 0, abs(height - lastReportedHeight) > 0.5 else { return }
        lastReportedHeight = height
        onHeightChange(height)
    }

    var isInputFocused: Bool { composerView.isInputFocused }

    /// Containment changes must not send a blur to the old screen or focus its stale binding.
    func beginHostChange() {
        composerView.isChangingHost = true
    }

    func endHostChange() {
        composerView.isChangingHost = false
        composerView.applyFocusState()
    }

    /// Keep the actual glass alive as the chat circle. Its bounds morph independently
    /// of the input's layout, so the text never gets squeezed into a 56pt button.
    func setDockVisible(
        _ visible: Bool,
        compactView: UIView,
        compactPrompt: ShopCompactComposerPrompt?,
        animated: Bool,
        navigationStyle: ShopBottomNavigationStyle
    ) {
        let compactAnchorChanged = compactDockAnchor !== compactView
        let compactPresentationChanged = compactAnchorChanged || self.compactDockPrompt != compactPrompt
        if compactPresentationChanged { view.layoutIfNeeded() }
        compactDockAnchor = compactView
        self.compactDockPrompt = compactPrompt
        compactDockNavigationStyle = navigationStyle
        // A route's source may briefly disconnect while SwiftUI mounts the next one.
        // Restore the same surface even when its dock state hasn't changed.
        view.isHidden = false
        guard dockIsVisible != visible else {
            if !visible {
                let compactFrame = resolvedCompactFrame(
                    anchoredTo: compactView,
                    compactPrompt: compactPrompt,
                    navigationStyle: navigationStyle
                )
                let changes = { [self] in
                    composerView.setDockAppearance(
                        compactFrame: compactFrame,
                        compactPrompt: compactPrompt,
                        animatesPromptTransition: compactPresentationChanged && animated
                    )
                    composerView.layoutDockSurfaceIfNeeded()
                }
                // Cart appears/disappears: slide the existing chat glass between its two
                // resting anchors with the dock spring, without replaying the composer swap.
                if compactPresentationChanged, animated, view.window != nil, !UIAccessibility.isReduceMotionEnabled {
                    UIView.animate(springDuration: ShopTabBarMetrics.dockSwapDuration,
                                   bounce: ShopTabBarMetrics.dockSwapBounce,
                                   options: [.allowUserInteraction, .beginFromCurrentState],
                                   animations: changes) { [weak self] finished in
                        guard finished else { return }
                        self?.composerView.startTryAskingShimmerIfNeeded()
                    }
                } else {
                    changes()
                    composerView.startTryAskingShimmerIfNeeded()
                }
            } else {
                composerView.applyFocusState()
            }
            return
        }
        // Inline keyboard transitions already have an explicit destination. Don't put
        // a second surface animation on top of that scroll/keyboard choreography.
        if inlineTransition != nil {
            resetDockVisibility()
            dockIsVisible = visible
            view.isHidden = false
            return
        }
        let hadDockState = dockIsVisible != nil
        view.layoutIfNeeded()
        let compactFrame = resolvedCompactFrame(
            anchoredTo: compactView,
            compactPrompt: compactPrompt,
            navigationStyle: navigationStyle
        )
        if !hadDockState {
            UIView.performWithoutAnimation {
                composerView.setDockAppearance(compactFrame: compactFrame, compactPrompt: compactPrompt)
                composerView.layoutDockSurfaceIfNeeded()
            }
        }
        dockIsVisible = visible
        view.isHidden = false
        // The compact glass remains interactive; only the hidden input is disabled.
        // Its embedded dock button must receive touches for native glass feedback.
        composerView.isUserInteractionEnabled = true
        view.accessibilityElementsHidden = false
        let animatesSwap = animated && view.window != nil && compactFrame.width > 0
            && (visible || hadDockState) && !UIAccessibility.isReduceMotionEnabled
        let quicklyFadesCollapsedIcon = animatesSwap && visible
        if animatesSwap, !visible {
            // Resolve the compact prompt's intrinsic size while its content is still
            // hidden. The dock spring should move one stable label frame rather than
            // also animating a newly inserted label from zero width.
            composerView.prepareCompactPrompt(compactPrompt)
            composerView.layoutDockSurfaceIfNeeded()
        }
        let changes = { [self] in
            composerView.setDockAppearance(
                compactFrame: visible ? nil : compactFrame,
                compactPrompt: visible ? nil : compactPrompt,
                updatesCompactContent: !quicklyFadesCollapsedIcon,
                animatesPromptVisibility: animatesSwap
            )
            composerView.layoutDockSurfaceIfNeeded()
        }
        if quicklyFadesCollapsedIcon {
            composerView.fadeOutDockCompactContent()
        }
        // The composer owns its shadow outside the glass surface. Scale their
        // common layer so the shadow stays attached during the depth dip.
        ShopDockSwapDepthAnimation.animate(
            on: composerView.layer, recedes: !visible,
            bumps: visible,
            recedingScale: navigationStyle.usesDepthDip
                ? ShopDockSwapDepthAnimation.minimumScale
                : ShopDockSwapDepthAnimation.subtleMinimumScale,
            duration: ShopTabBarMetrics.dockSwapDuration,
            animated: animatesSwap
        )
        if animatesSwap {
            UIView.animate(springDuration: ShopTabBarMetrics.dockSwapDuration,
                           bounce: visible
                               ? ShopTabBarMetrics.dockExpansionBounce
                               : ShopTabBarMetrics.dockSwapBounce,
                           options: [.allowUserInteraction, .beginFromCurrentState],
                           animations: changes) { [weak self] finished in
                guard finished else { return }
                if self?.dockIsVisible == true {
                    self?.composerView.applyFocusState()
                } else if self?.dockIsVisible == false {
                    self?.composerView.startTryAskingShimmerIfNeeded()
                }
            }
        } else {
            UIView.performWithoutAnimation(changes)
            if !visible {
                composerView.startTryAskingShimmerIfNeeded()
            }
        }
        // The input cannot acquire focus while its compact surface has hidden and
        // disabled the content. Reveal it first, then ask UIKit for the keyboard.
        if visible { composerView.applyFocusState() }
    }

    private func resolvedCompactFrame(
        anchoredTo compactView: UIView,
        compactPrompt: ShopCompactComposerPrompt?,
        navigationStyle: ShopBottomNavigationStyle
    ) -> CGRect {
        var frame = compactView.convert(compactView.bounds, to: composerView)
        guard let compactPrompt else { return frame }

        let labeledWidth = composerView.compactDockWidth(for: compactPrompt)
        if navigationStyle == .pistons {
            frame.origin.x = frame.maxX - labeledWidth
        }
        frame.size.width = labeledWidth
        return frame
    }

    func resetDockVisibility() {
        guard dockIsVisible != nil else { return }
        ShopDockSwapDepthAnimation.reset(on: composerView.layer)
        dockIsVisible = nil
        compactDockAnchor = nil
        compactDockPrompt = nil
        UIView.performWithoutAnimation {
            composerView.setDockAppearance(compactFrame: nil)
            composerView.clearCompactPrompt()
            composerView.layoutDockSurfaceIfNeeded()
        }
        composerView.isUserInteractionEnabled = true
        view.accessibilityElementsHidden = false
    }

    func disconnect() {
        completeNavigationInlineReturn(cancelled: true)
        inlineAnimationGeneration += 1
        inlineTransition = nil
        inlineOpeningTargetGuideTop = nil
        inlineReturnContainer = nil
        setInlineContainer(nil)
        inlinePresentation.finish()
        onHeightChange = { _ in }
        onDismiss = {}
        onBack = {}
        onClose = {}
        composerView.disconnect()
    }

    /// Keep the input and glass alive while changing their placement. In the inline state
    /// the real view is inside the scroll content, so scrolling needs no geometry polling.
    func setInlineContainer(_ container: UIView?, preservesInlinePosition: Bool = true) {
        loadViewIfNeeded()
        if let container, isReturningToInline {
            animateInlineReturn(to: container)
            return
        }
        if container == nil, isReturningToInline {
            inlineAnimationGeneration += 1
            inlineReturnContainer = nil
            inlineReturnIsAnimating = false
            inlineTransition = .awaitingKeyboard
        }
        let destination = container ?? view!
        guard composerView.superview !== destination else { return }
        let sourceFrame = composerView.convert(composerView.bounds, to: view)
        inlineTransition = nil
        inlineOpeningTargetGuideTop = nil
        isLiftingInlineComposer = container == nil && !inlineConstraints.isEmpty && preservesInlinePosition
        NSLayoutConstraint.deactivate(floatingConstraints + inlineConstraints)
        inlineConstraints = []
        destination.addSubview(composerView)
        // Preserve the inline elevation while lifting the composer. Its shadow changes
        // with the keyboard/card expansion instead of snapping during reparenting.
        if container != nil || !isLiftingInlineComposer {
            composerView.setInlineShadow(container != nil, animated: false)
        }
        if container != nil {
            inlineConstraints = [
                composerView.leadingAnchor.constraint(equalTo: destination.leadingAnchor),
                composerView.trailingAnchor.constraint(equalTo: destination.trailingAnchor),
                composerView.topAnchor.constraint(equalTo: destination.topAnchor),
                composerView.bottomAnchor.constraint(equalTo: destination.bottomAnchor),
            ]
            NSLayoutConstraint.activate(inlineConstraints)
        } else {
            NSLayoutConstraint.activate(floatingConstraints)
            if isLiftingInlineComposer {
                // Preserve the on-screen scroll position across the reparent. The normal
                // focus/keyboard constraint animation then starts here, not at the dock.
                keyboardBottomConstraint?.isActive = false
                restingBottomCeilingConstraint?.isActive = false
                composerLeadingConstraint?.constant = sourceFrame.minX
                composerTrailingConstraint?.constant = sourceFrame.maxX - view.bounds.width
                restingBottomConstraint?.constant = sourceFrame.maxY - view.bounds.height
                view.layoutIfNeeded()
                inlinePresentation.begin(in: view, composer: composerView)
            }
        }
    }

    /// Freeze the floating frame before applying the compact configuration. Reparenting
    /// happens only after the surface has arrived at this placeholder's screen position.
    func prepareInlineReturn(to container: UIView) {
        guard composerView.superview === view, view.window != nil,
              previousConfiguration?.isInline == false, !view.isHidden,
              container.window === view.window else { return }
        guard inlineReturnContainer !== container || !isReturningToInline else { return }
        view.layoutIfNeeded()
        inlineAnimationGeneration += 1
        inlineReturnContainer = container
        inlineReturnIsAnimating = false
        inlineTransition = .returning
        inlineOpeningTargetGuideTop = nil
        let frame = composerView.frame
        NSLayoutConstraint.deactivate([keyboardBottomConstraint!, restingBottomCeilingConstraint!])
        restingBottomConstraint?.constant = frame.maxY - view.bounds.height
    }

    // Called inside the native transition coordinator's animation block. Defer only
    // the reparenting, not the motion, until that same transition completes.
    func beginNavigationInlineReturn() {
        usesNavigationReturnAnimation = true
    }

    func completeNavigationInlineReturn(cancelled: Bool) {
        let completion = navigationReturnCompletion
        navigationReturnCompletion = nil
        usesNavigationReturnAnimation = false
        if !cancelled { completion?() }
    }

    private func animateInlineReturn(to container: UIView) {
        guard !inlineReturnIsAnimating else { return }
        inlineReturnIsAnimating = true
        let frame = container.convert(container.bounds, to: view)
        composerLeadingConstraint?.constant = frame.minX
        composerTrailingConstraint?.constant = frame.maxX - view.bounds.width
        restingBottomConstraint?.constant = frame.maxY - view.bounds.height
        inlinePresentation.prepareReturn()
        let generation = inlineAnimationGeneration
        let completion = { [weak self, weak container] in
            guard let self, let container, self.inlineAnimationGeneration == generation,
                  self.isReturningToInline else { return }
            self.inlineTransition = nil
            self.inlineReturnContainer = nil
            self.inlineReturnIsAnimating = false
            self.inlinePresentation.finish()
            self.setInlineContainer(container)
            container.layoutIfNeeded()
            self.view.isHidden = true
        }
        if usesNavigationReturnAnimation {
            navigationReturnCompletion = completion
            composerView.applyDeferredLayoutUpdates()
            inlinePresentation.fadeOut()
            view.layoutIfNeeded()
        } else {
            animateInlineLayout(alongside: { [weak self] in
                self?.inlinePresentation.fadeOut()
            }, completion: completion)
        }
    }

    private func animateInlineLayout(
        alongside: @escaping () -> Void = {},
        completion: @escaping () -> Void = {}
    ) {
        let animationsWereEnabled = UIView.areAnimationsEnabled
        let duration = UIAccessibility.isReduceMotionEnabled ? 0 : keyboardAnimationDuration
        guard animationsWereEnabled, duration > 0 else {
            composerView.applyDeferredLayoutUpdates()
            alongside()
            view.layoutIfNeeded()
            completion()
            return
        }
        UIView.setAnimationsEnabled(true)
        defer { UIView.setAnimationsEnabled(animationsWereEnabled) }
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [keyboardAnimationOptions, .allowUserInteraction, .beginFromCurrentState]
        ) { [weak self] in
            guard let self else { return }
            self.composerView.applyDeferredLayoutUpdates()
            alongside()
            self.view.layoutIfNeeded()
        } completion: { finished in
            if finished { completion() }
        }
    }

    fileprivate func update(
        configuration: ShopAgentUIKitComposerConfiguration,
        onQueryChange: @escaping (String) -> Void,
        onFocusChange: @escaping (Bool) -> Void,
        onHeightChange: @escaping (CGFloat) -> Void,
        onOpen: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onBack: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onAddContext: @escaping (ShopAgentComposerAttachmentPickerSource) -> Void,
        onRemoveContext: (() -> Void)?,
        onRemoveImageAttachment: @escaping (UUID) -> Void,
        onSubmit: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        self.onHeightChange = onHeightChange
        self.onDismiss = onDismiss
        self.onBack = onBack
        self.onClose = onClose

        let inset = if configuration.isFocused {
            ShopAgentUIKitComposerMetrics.focusedHorizontalInset
        } else if configuration.isCollapsible {
            ShopAgentUIKitComposerMetrics.attachedHorizontalInset
        } else {
            ShopAgentUIKitComposerMetrics.landingHorizontalInset
        }
        let reservedWidth = ShopAgentUIKitComposerMetrics.barHeight + ShopAgentUIKitComposerMetrics.bottomButtonSpacing
        let dockInset = configuration.isComposing ? nil : configuration.navigationDockInset
        let dockTrailingInset = dockInset.map { configuration.navigationDockTrailingInset ?? $0 }
        let composerLeadingConstant = dockInset ?? (inset + (
            configuration.isCollapsible && configuration.showsBackButton && !configuration.isComposing ? reservedWidth : 0
        ))
        let composerTrailingConstant = -(dockTrailingInset ?? (inset + (
            configuration.isCollapsible && !configuration.isComposing ? reservedWidth : 0
        )))
        let backButtonIsVisible = configuration.isCollapsible &&
            configuration.navigationDockInset == nil &&
            !configuration.isComposing &&
            configuration.showsBackButton
        let backButtonWasVisible = previousConfiguration.map {
            $0.isCollapsible && $0.navigationDockInset == nil && !$0.isComposing && $0.showsBackButton
        } ?? false
        let animatesBackButtonOut = !backButtonIsVisible &&
            backButtonWasVisible &&
            !UIAccessibility.isReduceMotionEnabled &&
            view.window != nil
        let focusStateChanged = previousConfiguration.map {
            $0.isCollapsible != configuration.isCollapsible ||
                $0.isFocused != configuration.isFocused ||
                $0.isComposing != configuration.isComposing
        } ?? false
        let animatesFocusTransition = focusStateChanged &&
            !UIAccessibility.isReduceMotionEnabled &&
            view.window != nil
        let animatesDockResize = dockInset != nil && dockIsVisible == true &&
            previousConfiguration.map { $0.navigationDockTrailingInset != configuration.navigationDockTrailingInset } == true &&
            !UIAccessibility.isReduceMotionEnabled && view.window != nil

        let previous = previousConfiguration
        // Flush the old layout, then publish the new state before any animation or
        // focus callback lays out again.
        view.layoutIfNeeded()
        previousConfiguration = configuration
        if isLiftingInlineComposer {
            isLiftingInlineComposer = false
            inlineTransition = configuration.isFocused ? .awaitingKeyboard : nil
        }
        if !configuration.isFocused, !isReturningToInline { inlineTransition = nil }
        if inlineTransition == nil, inlineConstraints.isEmpty {
            keyboardBottomConstraint?.isActive = true
            restingBottomCeilingConstraint?.isActive = true
        }

        let restingOffset = configuration.restingBottomInset + configuration.bottomSpacing
        if inlineTransition == nil {
            restingBottomConstraint?.constant = -restingOffset
            restingBottomCeilingConstraint?.constant = -restingOffset
        }
        if !configuration.isCollapsible, !keyboardIsVisible {
            keyboardBottomConstraint?.constant = -ShopAgentUIKitComposerMetrics.focusedKeyboardSpacing
        }
        updateAttachedRestingBaseline()

        if inlineTransition != nil {
            // The inline transition owns all geometry until it reaches its destination.
        } else if backButtonIsVisible && !backButtonWasVisible && !UIAccessibility.isReduceMotionEnabled {
            prepareBackButtonAppearance(
                initialComposerLeadingConstant: inset,
                finalComposerLeadingConstant: composerLeadingConstant,
                finalComposerTrailingConstant: composerTrailingConstant
            )
        } else if animatesBackButtonOut {
            animateBackButtonDisappearance(
                finalComposerLeadingConstant: composerLeadingConstant,
                finalComposerTrailingConstant: composerTrailingConstant
            )
        } else if pendingBackButtonLeadingConstant == nil || !backButtonIsVisible {
            if animatesFocusTransition {
                animateComposerLayout(
                    leadingConstant: composerLeadingConstant,
                    trailingConstant: composerTrailingConstant
                )
            } else if animatesDockResize {
                animateComposerLayout(
                    leadingConstant: composerLeadingConstant,
                    trailingConstant: composerTrailingConstant,
                    duration: ShopTabBarMetrics.dockSwapDuration,
                    bounce: ShopTabBarMetrics.dockSwapBounce
                )
            } else {
                composerLeadingConstraint?.constant = composerLeadingConstant
                composerTrailingConstraint?.constant = composerTrailingConstant
            }
        }

        if !animatesBackButtonOut {
            backButton.isHidden = !backButtonIsVisible
        }
        closeButton.isHidden = !configuration.isCollapsible || configuration.navigationDockInset != nil
        if previous?.usesCartButton != configuration.usesCartButton {
            configureNavigationButton(
                closeButton,
                icon: configuration.usesCartButton ? .navigationCartFilled : .cross,
                accessibilityLabel: configuration.usesCartButton
                    ? localizedString("Common.CartCapitalized")
                    : localizedString("Header.CloseA11yLabel"),
                accessibilityIdentifier: configuration.usesCartButton ? "agent-cart-button" : "agent-close-button"
            )
            if configuration.usesCartButton {
                closeButton.setGlassTint(UIColor(GravityColor.bgFillBrand), prominent: true)
                closeButton.setGlassImage(renderedIcon(.navigationCartFilled, color: GravityColor.textFixedLight, points: 28))
            }
        }
        dismissButton.isHidden = !ownsNavigationButtons || !configuration.isCollapsible || !configuration.isComposing

        if (!backButtonIsVisible && !animatesBackButtonOut) || UIAccessibility.isReduceMotionEnabled {
            pendingBackButtonLeadingConstant = nil
            pendingComposerTrailingConstant = nil
            backButton.alpha = 1
            backButton.transform = .identity
        }

        if let passthroughView = view as? ShopAgentUIKitComposerPassthroughView {
            passthroughView.capturesBackground = ownsNavigationButtons && configuration.isCollapsible && configuration.isComposing
            passthroughView.preservesNavigationBackTapRegion = configuration.preservesNavigationBackTapRegion
        }

        composerView.defersLayoutUpdates = inlineTransition == .awaitingKeyboard ||
            (isReturningToInline && !inlineReturnIsAnimating)
        composerView.update(
            configuration: configuration,
            onQueryChange: onQueryChange,
            onFocusChange: onFocusChange,
            onOpen: onOpen,
            onDismiss: onDismiss,
            onAddContext: onAddContext,
            onRemoveContext: onRemoveContext,
            onRemoveImageAttachment: onRemoveImageAttachment,
            onSubmit: onSubmit,
            onStop: onStop
        )
        if inlineTransition == .awaitingKeyboard, keyboardIsVisible, let keyboardEndFrame {
            animateInlineOpening(to: keyboardEndFrame)
        }
        updateAttachedRestingBaseline()
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        keyboardIsVisible = true
        updateKeyboardAnimation(notification)
        keyboardEndFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        if inlineTransition == .awaitingKeyboard, let keyboardEndFrame {
            animateInlineOpening(to: keyboardEndFrame)
        }
        keyboardBottomConstraint?.constant = -ShopAgentUIKitComposerMetrics.focusedKeyboardSpacing
    }

    private func animateInlineOpening(to screenFrame: CGRect) {
        guard let window = view.window else { return }
        // UIKit publishes the final frame before the keyboard starts moving. Use
        // that one destination, not the layout guide's intermediate animated frames.
        let keyboardFrame = view.convert(screenFrame, from: window.screen.coordinateSpace)
        inlineTransition = .opening
        NSLayoutConstraint.deactivate([keyboardBottomConstraint!, restingBottomCeilingConstraint!])
        let targetGuideTop = min(view.bounds.maxY, keyboardFrame.minY)
        inlineOpeningTargetGuideTop = targetGuideTop
        let targetBottom = targetGuideTop - ShopAgentUIKitComposerMetrics.focusedKeyboardSpacing
        let alignedBottom = inlinePresentation.alignedBottom(to: targetBottom) ?? targetBottom
        composerLeadingConstraint?.constant = ShopAgentUIKitComposerMetrics.focusedHorizontalInset
        composerTrailingConstraint?.constant = -ShopAgentUIKitComposerMetrics.focusedHorizontalInset
        restingBottomConstraint?.constant = targetBottom - view.bounds.height
        composerView.setInlineShadow(
            false,
            animated: !UIAccessibility.isReduceMotionEnabled,
            duration: keyboardAnimationDuration,
            timingFunction: keyboardShadowTimingFunction
        )
        let generation = inlineAnimationGeneration
        // Scroll alignment, upward growth, starter movement, and backdrop fade
        // share the keyboard's timing and final destination in one animation.
        animateInlineLayout(alongside: { [weak self] in
            self?.inlinePresentation.scroll(to: alignedBottom)
            self?.inlinePresentation.expand()
        }) { [weak self] in
            guard let self, self.inlineAnimationGeneration == generation,
                  self.inlineTransition == .opening else { return }
            self.finishInlineOpening()
        }
    }

    private func finishInlineOpening() {
        finishInlineOpeningIfKeyboardGuideIsAligned()
    }

    private func finishInlineOpeningIfKeyboardGuideIsAligned() {
        guard inlineTransition == .opening, let inlineOpeningTargetGuideTop,
              abs(view.keyboardLayoutGuide.layoutFrame.minY - inlineOpeningTargetGuideTop) < 0.5 else { return }
        self.inlineOpeningTargetGuideTop = nil
        inlineTransition = nil
        NSLayoutConstraint.activate([keyboardBottomConstraint!, restingBottomCeilingConstraint!])
        updateAttachedRestingBaseline()
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        keyboardIsVisible = false
        inlineOpeningTargetGuideTop = nil
        updateKeyboardAnimation(notification)
        updateAttachedRestingBaseline()
    }

    @objc private func keyboardDidHide() {
        composerView.reconcileDismissedFocus()
    }

    private func updateKeyboardAnimation(_ notification: Notification) {
        if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
            keyboardAnimationDuration = duration
        }
        if let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt {
            keyboardAnimationOptions = UIView.AnimationOptions(rawValue: curve << 16)
        }
    }

    private var keyboardShadowTimingFunction: CAMediaTimingFunction {
        if keyboardAnimationOptions.contains(.curveEaseIn) {
            return CAMediaTimingFunction(name: .easeIn)
        }
        if keyboardAnimationOptions.contains(.curveEaseOut) {
            return CAMediaTimingFunction(name: .easeOut)
        }
        if keyboardAnimationOptions.contains(.curveLinear) {
            return CAMediaTimingFunction(name: .linear)
        }
        return CAMediaTimingFunction(name: .easeInEaseOut)
    }

    private func updateAttachedRestingBaseline() {
        guard !isLiftingInlineComposer, inlineTransition == nil else { return }
        guard previousConfiguration?.isCollapsible == true else { return }
        if previousConfiguration?.navigationDockInset != nil {
            // Match the existing shell navigation's baseline, not the standalone footer's.
            let padding = ShopTabBarMetrics.visualBottomPadding(
                for: view.window?.safeAreaInsets.bottom ?? view.safeAreaInsets.bottom
            )
            restingBottomConstraint?.constant = -padding
            restingBottomCeilingConstraint?.constant = -padding
            if !keyboardIsVisible {
                keyboardBottomConstraint?.constant = view.safeAreaInsets.bottom - padding
            }
            return
        }
        let additionalInset = max(
            0,
            ShopAgentUIKitComposerMetrics.minimumAttachedBottomInset - view.safeAreaInsets.bottom
        )
        backButtonBottomConstraint?.constant = -additionalInset
        closeButtonBottomConstraint?.constant = -additionalInset
        if keyboardIsVisible == false {
            keyboardBottomConstraint?.constant = -additionalInset
        }
    }

    private func animateBackButtonDisappearance(
        finalComposerLeadingConstant: CGFloat,
        finalComposerTrailingConstant: CGFloat
    ) {
        pendingBackButtonLeadingConstant = nil
        pendingComposerTrailingConstant = nil
        view.layoutIfNeeded()
        composerLeadingConstraint?.constant = finalComposerLeadingConstant
        composerTrailingConstraint?.constant = finalComposerTrailingConstant
        backButton.isHidden = false

        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) { [weak self] in
            guard let self else { return }
            self.backButton.alpha = 0
            self.backButton.transform = CGAffineTransform(scaleX: 0.86, y: 0.86)
            self.view.layoutIfNeeded()
        } completion: { [weak self] finished in
            guard let self, finished, let configuration = self.previousConfiguration,
                  !(configuration.isCollapsible && !configuration.isComposing && configuration.showsBackButton) else { return }
            self.backButton.isHidden = true
            self.backButton.alpha = 1
            self.backButton.transform = .identity
        }
    }

    private func prepareBackButtonAppearance(
        initialComposerLeadingConstant: CGFloat,
        finalComposerLeadingConstant: CGFloat,
        finalComposerTrailingConstant: CGFloat
    ) {
        composerLeadingConstraint?.constant = initialComposerLeadingConstant
        backButton.isHidden = false
        backButton.alpha = 0
        backButton.transform = CGAffineTransform(scaleX: 0.86, y: 0.86)
        pendingBackButtonLeadingConstant = finalComposerLeadingConstant
        pendingComposerTrailingConstant = finalComposerTrailingConstant

        if view.window != nil {
            Task { @MainActor [weak self] in
                self?.animatePendingBackButtonAppearanceIfNeeded()
            }
        }
    }

    private func animatePendingBackButtonAppearanceIfNeeded() {
        guard let finalLeadingConstant = pendingBackButtonLeadingConstant else { return }
        pendingBackButtonLeadingConstant = nil
        let finalTrailingConstant = pendingComposerTrailingConstant
        pendingComposerTrailingConstant = nil

        view.layoutIfNeeded()
        composerLeadingConstraint?.constant = finalLeadingConstant
        if let finalTrailingConstant {
            composerTrailingConstraint?.constant = finalTrailingConstant
        }
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) { [weak self] in
            guard let self else { return }
            self.backButton.alpha = 1
            self.backButton.transform = .identity
            self.view.layoutIfNeeded()
        }
    }

    private func animateComposerLayout(
        leadingConstant: CGFloat,
        trailingConstant: CGFloat,
        duration: TimeInterval = ShopAgentUIKitComposerMetrics.focusTransitionDuration,
        bounce: CGFloat = ShopAgentUIKitComposerMetrics.focusTransitionBounce
    ) {
        // update() already flushed the old frame. Keep the new dock baseline in this animation
        // as well as the side insets when transferring between Search and a conversation.
        composerLeadingConstraint?.constant = leadingConstant
        composerTrailingConstraint?.constant = trailingConstant

        // Representable updates can arrive inside SwiftUI's animation-disabled
        // transaction. This explicitly requested UIKit transition owns its timing.
        // The caller already respects Reduce Motion; restore the surrounding flag.
        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(true)
        defer { UIView.setAnimationsEnabled(animationsWereEnabled) }
        UIView.animate(
            springDuration: duration,
            bounce: bounce,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) { [weak self] in
            self?.view.layoutIfNeeded()
        }
    }

    private func configureNavigationButton(
        _ button: ShopUIKitGlassButton,
        icon: GravityIconName,
        accessibilityLabel: String,
        accessibilityIdentifier: String
    ) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setGlassImage(renderedIcon(icon, color: GravityColor.textFixedDark, points: 28))
        button.accessibilityLabel = accessibilityLabel
        button.accessibilityIdentifier = accessibilityIdentifier
    }

    private func renderedIcon(_ name: GravityIconName, color: Color, points: CGFloat) -> UIImage? {
        let scheme: ColorScheme = traitCollection.userInterfaceStyle == .dark ? .dark : .light
        let renderer = ImageRenderer(
            content: ShopIcon(name, size: .large, color: color)
                .frame(width: points, height: points)
                .environment(\.colorScheme, scheme)
        )
        renderer.scale = traitCollection.displayScale
        return renderer.uiImage?.withRenderingMode(.alwaysOriginal)
    }
}

private final class ShopAgentUIKitComposerPassthroughView: UIView {
    var capturesBackground = false
    var preservesNavigationBackTapRegion = false

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if capturesBackground {
            // Preserve the whole system toolbar, including trailing actions, while the
            // focused composer captures taps on the conversation to dismiss the keyboard.
            if preservesNavigationBackTapRegion,
               point.y <= safeAreaInsets.top + ShopAgentUIKitComposerMetrics.navigationBackPassthroughHeight {
                return false
            }
            return true
        }
        return subviews.contains { subview in
            guard !subview.isHidden, subview.alpha > 0.01, subview.isUserInteractionEnabled else { return false }
            return subview.point(inside: subview.convert(point, from: self), with: event)
        }
    }
}

@MainActor
private final class ShopAgentCompactPromptShimmerView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        guard let gradient = layer as? CAGradientLayer else { return }
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.32).cgColor,
            UIColor.clear.cgColor,
        ]
        gradient.locations = [0, 0.5, 1]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
@Observable
private final class ShopAgentCompactPromptPresentation {
    var prompt: ShopCompactComposerPrompt?
    var isVisible = false
}

private struct ShopAgentCompactPromptView: View {
    private static let hiddenBlurRadius: CGFloat = 6

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let presentation: ShopAgentCompactPromptPresentation

    var body: some View {
        ZStack {
            if let prompt = presentation.prompt {
                if accessibilityReduceMotion {
                    promptText(prompt)
                        .transition(.opacity)
                } else {
                    promptText(prompt)
                        .transition(.blurReplace)
                }
            }
        }
        .opacity(presentation.isVisible ? 1 : 0)
        .blur(
            radius: accessibilityReduceMotion || presentation.isVisible
                ? 0
                : Self.hiddenBlurRadius
        )
        .accessibilityHidden(true)
    }

    private func promptText(_ prompt: ShopCompactComposerPrompt) -> some View {
        ShopText(prompt.title, style: .buttonLarge, color: GravityColor.text)
            .fixedSize()
            .id(prompt)
    }
}

@MainActor
private final class ShopAgentUIKitComposerView: UIView, UITextViewDelegate, UIGestureRecognizerDelegate {
    var isChangingHost = false
    var defersLayoutUpdates = false
    private var isInlineShadow = false
    private var hasDeferredLayoutUpdates = false
    private let surfaceView = ShopUIKitGlassSurfaceView(
        interactive: true,
        cornerRadius: ShopAgentUIKitComposerMetrics.cornerRadius
    )
    var dockSurfaceContentView: UIView { surfaceView.contentView }
    private let contentStack = UIStackView()
    private let dockCompactContent = UIStackView()
    private let dockChatIcon = UIImageView()
    private let compactPromptPresentation = ShopAgentCompactPromptPresentation()
    private lazy var dockAskLabel: UIView = {
        let configuration = UIHostingConfiguration {
            ShopAgentCompactPromptView(presentation: compactPromptPresentation)
        }
        .margins(.all, 0)
        let view = configuration.makeContentView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.clipsToBounds = false
        view.isUserInteractionEnabled = false
        return view
    }()
    private var dockAskLabelWidthConstraint: NSLayoutConstraint!
    private var currentCompactPrompt: ShopCompactComposerPrompt?
    private weak var compactPromptShimmerView: UIView?
    private var surfaceLeadingConstraint: NSLayoutConstraint!
    private var surfaceTrailingConstraint: NSLayoutConstraint!
    private var surfaceTopConstraint: NSLayoutConstraint!
    private var surfaceBottomConstraint: NSLayoutConstraint!
    private let contextLaneContainer = UIView()
    private let contextLane = ShopAgentUIKitComposerContextLane()
    private let attachmentScrollView = UIScrollView()
    private let attachmentStack = UIStackView()
    private let inputRow = UIStackView()
    private let contextButton = UIButton(type: .system)
    private lazy var contextImageOverlay = ShopAgentComposerProductImageOverlay(on: contextButton)
    private let textInputContainer = UIView()
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private var textHeightConstraint: NSLayoutConstraint?
    private var lastMeasuredTextWidth: CGFloat = 0
    private var typographyContentSizeCategory: UIContentSizeCategory?
    private var configuration: ShopAgentUIKitComposerConfiguration?
    private var isEndingEditingInternally = false

    private var onQueryChange: (String) -> Void = { _ in }
    private var onFocusChange: (Bool) -> Void = { _ in }
    private var onOpen: () -> Void = {}
    private var onDismiss: () -> Void = {}
    private var onAddContext: (ShopAgentComposerAttachmentPickerSource) -> Void = { _ in }
    private var onRemoveContext: (() -> Void)?
    private var onRemoveImageAttachment: (UUID) -> Void = { _ in }
    private var onSubmit: () -> Void = {}
    private var onStop: () -> Void = {}

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // In compact mode the material sits left of the input's reserved layout frame.
        // Hit-test the visible shape, not that empty center frame.
        surfaceView.point(inside: surfaceView.convert(point, from: self), with: event)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyFocusState()
    }

    override func action(for layer: CALayer, forKey event: String) -> (any CAAction)? {
        if event == "shadowPath", let animation = ShopUIKitFloatingShadow.pathAnimation(
            for: layer, matching: super.action(for: layer, forKey: "backgroundColor")
        ) {
            return animation
        }
        return super.action(for: layer, forKey: event)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyShadowStyle()
        let width = textView.bounds.width
        guard width > 0, abs(width - lastMeasuredTextWidth) > 0.5 else { return }
        lastMeasuredTextWidth = width
        updateTextHeight()
    }

    /// A material-only resize: the same input and attachment views retain their
    /// measured width while the surrounding glass moves between circle and capsule.
    func setDockAppearance(
        compactFrame: CGRect?,
        compactPrompt: ShopCompactComposerPrompt? = nil,
        updatesCompactContent: Bool = true,
        animatesPromptTransition: Bool = false,
        animatesPromptVisibility: Bool = false
    ) {
        let frame = compactFrame ?? bounds
        surfaceLeadingConstraint.constant = frame.minX
        surfaceTrailingConstraint.constant = frame.maxX - bounds.width
        surfaceTopConstraint.constant = frame.minY
        surfaceBottomConstraint.constant = frame.maxY - bounds.height
        contentStack.alpha = compactFrame == nil ? 1 : 0
        contentStack.isUserInteractionEnabled = compactFrame == nil
        contentStack.accessibilityElementsHidden = compactFrame != nil
        if compactFrame != nil {
            updateCompactPrompt(compactPrompt, animated: animatesPromptTransition)
        }
        updateCompactPromptVisibility(
            compactFrame != nil,
            animated: animatesPromptVisibility
        )
        if updatesCompactContent {
            dockCompactContent.alpha = compactFrame == nil ? 0 : 1
        }
    }

    func prepareCompactPrompt(_ prompt: ShopCompactComposerPrompt?) {
        updateCompactPrompt(prompt, animated: false)
        updateCompactPromptVisibility(false, animated: false)
    }

    func clearCompactPrompt() {
        updateCompactPrompt(nil, animated: false)
    }

    func fadeOutDockCompactContent() {
        UIView.animate(
            withDuration: ShopTabBarMetrics.dockChatIconFadeOutDuration,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
        ) { [weak self] in
            self?.dockCompactContent.alpha = 0
        }
    }

    func compactDockWidth(for prompt: ShopCompactComposerPrompt) -> CGFloat {
        return max(
            ShopTabBarMetrics.contentHeight,
            24 + GravitySpacing.space6 + compactPromptTextWidth(prompt) + GravitySpacing.space16 * 2
        )
    }

    private func compactPromptTextWidth(_ prompt: ShopCompactComposerPrompt) -> CGFloat {
        ceil((prompt.title as NSString).size(withAttributes: [
            .font: GravityTextStyle.buttonLarge.scaledUIFont,
        ]).width)
    }

    private func updateCompactPrompt(_ prompt: ShopCompactComposerPrompt?, animated: Bool) {
        dockAskLabelWidthConstraint.constant = prompt.map(compactPromptTextWidth) ?? 0
        dockCompactContent.spacing = prompt == nil ? 0 : GravitySpacing.space6
        guard currentCompactPrompt != prompt else {
            return
        }
        currentCompactPrompt = prompt
        if prompt != .tryAsking {
            compactPromptShimmerView?.layer.removeAllAnimations()
            compactPromptShimmerView?.removeFromSuperview()
        }

        if animated && window != nil {
            withAnimation(.easeOut(duration: ShopTabBarMetrics.dockIconFadeDuration)) {
                compactPromptPresentation.prompt = prompt
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                compactPromptPresentation.prompt = prompt
            }
        }
    }

    private func updateCompactPromptVisibility(_ isVisible: Bool, animated: Bool) {
        guard compactPromptPresentation.isVisible != isVisible else { return }

        let changes = { [compactPromptPresentation] in
            compactPromptPresentation.isVisible = isVisible
        }
        if animated && window != nil {
            let duration = isVisible
                ? ShopTabBarMetrics.dockIconFadeDuration
                : ShopTabBarMetrics.dockChatIconFadeOutDuration
            withAnimation(.easeOut(duration: duration), changes)
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, changes)
        }
    }

    func startTryAskingShimmerIfNeeded() {
        guard !UIAccessibility.isReduceMotionEnabled,
              currentCompactPrompt == .tryAsking,
              compactPromptPresentation.isVisible,
              dockCompactContent.alpha >= 0.99,
              dockAskLabel.bounds.width > 0,
              window != nil,
              ShopAppFirstInteractionTracker.shared.claimTryAskingShimmer() else { return }

        let shimmerContainer = UIView(frame: dockAskLabel.bounds)
        shimmerContainer.isUserInteractionEnabled = false
        shimmerContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let textMask = UILabel(frame: shimmerContainer.bounds)
        textMask.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        textMask.text = currentCompactPrompt?.title
        textMask.font = GravityTextStyle.buttonLarge.scaledUIFont
        textMask.textAlignment = .center
        textMask.textColor = .black
        shimmerContainer.mask = textMask

        let shimmerWidth = max(24, dockAskLabel.bounds.width * 0.44)
        let shimmer = ShopAgentCompactPromptShimmerView()
        shimmer.frame = CGRect(
            x: -shimmerWidth,
            y: 0,
            width: shimmerWidth,
            height: dockAskLabel.bounds.height
        )
        shimmer.autoresizingMask = [.flexibleHeight]
        shimmerContainer.addSubview(shimmer)
        dockAskLabel.addSubview(shimmerContainer)
        compactPromptShimmerView = shimmerContainer
        UIView.animate(
            withDuration: 1.1,
            delay: 0.12,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            shimmer.transform = CGAffineTransform(
                translationX: self.dockAskLabel.bounds.width + shimmerWidth * 2,
                y: 0
            )
        } completion: { [weak self, weak shimmerContainer] _ in
            shimmerContainer?.removeFromSuperview()
            if self?.compactPromptShimmerView === shimmerContainer {
                self?.compactPromptShimmerView = nil
            }
        }
    }

    func layoutDockSurfaceIfNeeded() {
        layoutIfNeeded()
        applyShadowStyle()
    }

    func setInlineShadow(
        _ isInline: Bool,
        animated: Bool,
        duration: TimeInterval = ShopAgentUIKitComposerMetrics.focusTransitionDuration,
        timingFunction: CAMediaTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    ) {
        guard isInlineShadow != isInline else { return }

        let presentation = layer.presentation()
        let oldColor = presentation?.shadowColor ?? layer.shadowColor
        let oldRadius = presentation?.shadowRadius ?? layer.shadowRadius
        let oldOffset = presentation?.shadowOffset ?? layer.shadowOffset
        isInlineShadow = isInline

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        applyShadowStyle()
        CATransaction.commit()

        guard animated, duration > 0, window != nil else { return }
        let animations: [CABasicAnimation] = [
            shadowAnimation(keyPath: "shadowColor", from: oldColor, to: layer.shadowColor),
            shadowAnimation(keyPath: "shadowRadius", from: oldRadius, to: layer.shadowRadius),
            shadowAnimation(keyPath: "shadowOffset", from: oldOffset, to: layer.shadowOffset),
        ]
        let group = CAAnimationGroup()
        group.animations = animations
        group.duration = duration
        group.timingFunction = timingFunction
        layer.add(group, forKey: "ShopAgentUIKitComposer.shadowStyle")
    }

    private func applyShadowStyle() {
        clipsToBounds = false
        layer.shadowOpacity = 1
        if isInlineShadow {
            let shadow = GravityShadowLevel.s.attributes
            layer.shadowColor = UIColor(shadow.color).resolvedColor(with: traitCollection).cgColor
            layer.shadowRadius = shadow.radius
            layer.shadowOffset = CGSize(width: shadow.x, height: shadow.y)
        } else {
            layer.shadowColor = UIColor(GravityColor.shadow300).resolvedColor(with: traitCollection).cgColor
            layer.shadowRadius = ShopAgentFloatingSurfaceMetrics.shadowRadius
            layer.shadowOffset = CGSize(width: 0, height: ShopAgentFloatingSurfaceMetrics.shadowYOffset)
        }
        guard !bounds.isEmpty else { return }
        layer.shadowPath = UIBezierPath(
            roundedRect: surfaceView.frame,
            cornerRadius: ShopAgentUIKitComposerMetrics.cornerRadius
        ).cgPath
    }

    private func shadowAnimation(keyPath: String, from: Any?, to: Any?) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        return animation
    }

    private func setupViews() {
        backgroundColor = .clear

        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        surfaceView.accessibilityIdentifier = "agent-composer-surface"
        surfaceView.layer.cornerRadius = ShopAgentUIKitComposerMetrics.cornerRadius
        surfaceView.layer.cornerCurve = .continuous
        // The material rounds itself. Masking its parent clips native glass expansion.
        surfaceView.clipsToBounds = false
        addSubview(surfaceView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(focusOrOpenComposer))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        surfaceView.addGestureRecognizer(tap)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 0
        surfaceView.contentView.addSubview(contentStack)

        dockCompactContent.translatesAutoresizingMaskIntoConstraints = false
        dockCompactContent.axis = .horizontal
        dockCompactContent.alignment = .center
        dockCompactContent.spacing = 0
        dockCompactContent.alpha = 0
        dockCompactContent.isUserInteractionEnabled = false
        surfaceView.contentView.addSubview(dockCompactContent)

        dockChatIcon.translatesAutoresizingMaskIntoConstraints = false
        dockChatIcon.image = renderedIcon(.shopChatFilled, color: GravityColor.text, points: 24)
        dockChatIcon.contentMode = .scaleAspectFit
        dockChatIcon.isAccessibilityElement = false
        dockCompactContent.addArrangedSubview(dockChatIcon)

        dockCompactContent.addArrangedSubview(dockAskLabel)
        dockAskLabelWidthConstraint = dockAskLabel.widthAnchor.constraint(equalToConstant: 0)

        contextLaneContainer.isHidden = true
        contentStack.addArrangedSubview(contextLaneContainer)
        contextLane.translatesAutoresizingMaskIntoConstraints = false
        contextLaneContainer.addSubview(contextLane)

        attachmentScrollView.showsHorizontalScrollIndicator = false
        attachmentScrollView.isHidden = true
        contentStack.addArrangedSubview(attachmentScrollView)

        attachmentStack.translatesAutoresizingMaskIntoConstraints = false
        attachmentStack.axis = .horizontal
        attachmentStack.spacing = GravitySpacing.space6
        attachmentScrollView.addSubview(attachmentStack)

        inputRow.axis = .horizontal
        inputRow.alignment = .bottom
        inputRow.spacing = ShopAgentUIKitComposerMetrics.rowSpacing
        inputRow.isLayoutMarginsRelativeArrangement = true
        // The controller handles safe-area positioning; visible buttons keep an 8-point inset.
        inputRow.insetsLayoutMarginsFromSafeArea = false
        inputRow.layoutMargins = UIEdgeInsets(
            top: ShopAgentUIKitComposerMetrics.rowInset,
            left: ShopAgentUIKitComposerMetrics.rowInset,
            bottom: ShopAgentUIKitComposerMetrics.rowInset,
            right: ShopAgentUIKitComposerMetrics.rowInset
        )
        contentStack.addArrangedSubview(inputRow)

        configureCircularButton(contextButton, icon: .camera)
        contextButton.translatesAutoresizingMaskIntoConstraints = false
        contextButton.addAction(UIAction { [weak self] _ in self?.performContextButtonAction() }, for: .touchUpInside)
        // Keep the camera in the glass hierarchy so it shares the native press deformation.
        inputRow.addArrangedSubview(contextButton)

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        textView.backgroundColor = .clear
        textView.adjustsFontForContentSizeCategory = true
        textView.tintColor = UIColor(GravityColor.text)
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.returnKeyType = .send
        textView.keyboardDismissMode = .interactive
        textView.contentInsetAdjustmentBehavior = .never

        textInputContainer.addSubview(textView)
        inputRow.addArrangedSubview(textInputContainer)

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.numberOfLines = 1
        placeholderLabel.lineBreakMode = .byTruncatingTail
        placeholderLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        placeholderLabel.isAccessibilityElement = false
        textInputContainer.addSubview(placeholderLabel)

        applyTypography()

        configureCircularButton(actionButton, icon: .arrowRight, filled: true)
        actionButton.addAction(UIAction { [weak self] _ in self?.performAction() }, for: .touchUpInside)
        inputRow.addArrangedSubview(actionButton)

        let textHeight = textView.heightAnchor.constraint(equalToConstant: ShopAgentUIKitComposerMetrics.buttonSize)
        textHeight.identifier = "AgentComposer.textHeight"
        textHeightConstraint = textHeight
    }

    private func setupConstraints() {
        guard let textHeightConstraint else { return }
        // Hidden arranged buttons collapse to zero width without fighting the stack.
        let contextButtonWidth = contextButton.widthAnchor.constraint(equalTo: contextButton.heightAnchor)
        // Outrank the loaded image's intrinsic width, while still allowing the
        // stack's required zero-width constraint when the camera is hidden.
        contextButtonWidth.priority = UILayoutPriority(999)
        contextButtonWidth.identifier = "AgentComposer.squareContextPreview"
        let actionButtonWidth = actionButton.widthAnchor.constraint(equalToConstant: ShopAgentUIKitComposerMetrics.buttonSize)
        actionButtonWidth.priority = .defaultHigh
        surfaceTopConstraint = surfaceView.topAnchor.constraint(equalTo: topAnchor)
        surfaceLeadingConstraint = surfaceView.leadingAnchor.constraint(equalTo: leadingAnchor)
        surfaceTrailingConstraint = surfaceView.trailingAnchor.constraint(equalTo: trailingAnchor)
        surfaceBottomConstraint = surfaceView.bottomAnchor.constraint(equalTo: bottomAnchor)
        NSLayoutConstraint.activate([
            surfaceTopConstraint,
            surfaceLeadingConstraint,
            surfaceTrailingConstraint,
            surfaceBottomConstraint,
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.widthAnchor.constraint(equalTo: widthAnchor),
            contentStack.centerXAnchor.constraint(equalTo: surfaceView.contentView.centerXAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            dockCompactContent.centerXAnchor.constraint(equalTo: surfaceView.contentView.centerXAnchor),
            dockCompactContent.centerYAnchor.constraint(equalTo: surfaceView.contentView.centerYAnchor),
            dockChatIcon.widthAnchor.constraint(equalToConstant: 24),
            dockChatIcon.heightAnchor.constraint(equalToConstant: 24),
            dockAskLabelWidthConstraint,
            contextLane.topAnchor.constraint(
                equalTo: contextLaneContainer.topAnchor,
                constant: ShopAgentUIKitComposerMetrics.attachmentInset
            ),
            contextLane.leadingAnchor.constraint(
                equalTo: contextLaneContainer.leadingAnchor,
                constant: ShopAgentUIKitComposerMetrics.attachmentInset
            ),
            contextLane.trailingAnchor.constraint(
                equalTo: contextLaneContainer.trailingAnchor,
                constant: -ShopAgentUIKitComposerMetrics.attachmentInset
            ),
            contextLane.bottomAnchor.constraint(equalTo: contextLaneContainer.bottomAnchor),
            contextLane.heightAnchor.constraint(equalToConstant: ShopAgentUIKitComposerMetrics.contextLaneHeight),
            attachmentScrollView.heightAnchor.constraint(
                equalToConstant: ShopAgentUIKitComposerMetrics.attachmentLaneHeight
            ),
            attachmentStack.leadingAnchor.constraint(
                equalTo: attachmentScrollView.contentLayoutGuide.leadingAnchor,
                constant: ShopAgentUIKitComposerMetrics.attachmentInset
            ),
            attachmentStack.trailingAnchor.constraint(
                equalTo: attachmentScrollView.contentLayoutGuide.trailingAnchor,
                constant: -ShopAgentUIKitComposerMetrics.attachmentInset
            ),
            attachmentStack.topAnchor.constraint(
                equalTo: attachmentScrollView.contentLayoutGuide.topAnchor,
                constant: ShopAgentUIKitComposerMetrics.attachmentInset
            ),
            attachmentStack.bottomAnchor.constraint(equalTo: attachmentScrollView.contentLayoutGuide.bottomAnchor),
            attachmentStack.heightAnchor.constraint(
                equalTo: attachmentScrollView.frameLayoutGuide.heightAnchor,
                constant: -ShopAgentUIKitComposerMetrics.attachmentInset
            ),
            inputRow.heightAnchor.constraint(greaterThanOrEqualToConstant: ShopAgentUIKitComposerMetrics.barHeight),
            contextButtonWidth,
            contextButton.heightAnchor.constraint(equalToConstant: ShopAgentUIKitComposerMetrics.buttonSize),
            actionButtonWidth,
            actionButton.heightAnchor.constraint(equalToConstant: ShopAgentUIKitComposerMetrics.buttonSize),
            textView.topAnchor.constraint(equalTo: textInputContainer.topAnchor),
            textView.leadingAnchor.constraint(equalTo: textInputContainer.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: textInputContainer.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: textInputContainer.bottomAnchor),
            textHeightConstraint,
            placeholderLabel.leadingAnchor.constraint(equalTo: textInputContainer.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: textInputContainer.trailingAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: textInputContainer.centerYAnchor),
        ])
    }

    func update(
        configuration: ShopAgentUIKitComposerConfiguration,
        onQueryChange: @escaping (String) -> Void,
        onFocusChange: @escaping (Bool) -> Void,
        onOpen: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onAddContext: @escaping (ShopAgentComposerAttachmentPickerSource) -> Void,
        onRemoveContext: (() -> Void)?,
        onRemoveImageAttachment: @escaping (UUID) -> Void,
        onSubmit: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        let previous = self.configuration
        self.configuration = configuration
        self.onQueryChange = onQueryChange
        self.onFocusChange = onFocusChange
        self.onOpen = onOpen
        self.onDismiss = onDismiss
        self.onAddContext = onAddContext
        self.onRemoveContext = onRemoveContext
        self.onRemoveImageAttachment = onRemoveImageAttachment
        self.onSubmit = onSubmit
        self.onStop = onStop
        // This icon is pre-rendered, unlike the adjacent hosted prompt label.
        // Refresh it when the host's media contrast changes the UIKit trait.
        dockChatIcon.image = renderedIcon(.shopChatFilled, color: GravityColor.text, points: 24)

        let typographyChanged = typographyContentSizeCategory != traitCollection.preferredContentSizeCategory
        if typographyChanged { applyTypography() }
        // While editing, UIKit owns the text and selection. The standalone host's
        // render snapshot may lag a keystroke; replaying it here deletes/reorders
        // input. Reconcile external text after editing, without changing presentation.
        if !textView.isFirstResponder && (typographyChanged || textView.text != configuration.query) {
            setQueryText(configuration.query)
        }
        let collapsed = configuration.isCollapsible && !configuration.isComposing
        contextButton.showsMenuAsPrimaryAction = !collapsed || configuration.context == nil
        contextButton.menu = addPhotosMenu()
        if textView.isEditable == collapsed { textView.isEditable = !collapsed }
        if textView.isSelectable == collapsed { textView.isSelectable = !collapsed }
        placeholderLabel.attributedText = attributedText(
            configuration.placeholder,
            color: UIColor(GravityColor.textPlaceholder)
        )
        placeholderLabel.isHidden = !configuration.query.isEmpty
        textView.accessibilityLabel = configuration.placeholder
        textView.accessibilityIdentifier = configuration.usesLandingAccessibilityIdentifiers
            ? "DYNAMIC_TYPEAHEAD_TEXT_INPUT"
            : "agent-follow-up-text-input"

        contextButton.isEnabled = configuration.canAddContext
        contextButton.accessibilityIdentifier = configuration.usesLandingAccessibilityIdentifiers
            ? "ADD_CONTEXT_BUTTON"
            : "agent-follow-up-add-context-button"
        updateContextButton()
        updateActionButton()
        if defersLayoutUpdates {
            // Keep the compact geometry intact while becomeFirstResponder asks UIKit
            // for the keyboard destination. Reveal the lanes in that same animation.
            hasDeferredLayoutUpdates = true
            applyFocusState()
            return
        }
        applyDeferredLayoutUpdates()
        updateInputRowLayout()
        updateTextHeight()

        if previous?.context != configuration.context ||
            previous?.isComposing != configuration.isComposing ||
            previous?.canRemoveContext != configuration.canRemoveContext {
            updateContextLane()
        }
        if previous?.imageAttachments != configuration.imageAttachments ||
            previous?.isComposing != configuration.isComposing {
            let imageLaneWasVisible = previous.map(showsImageAttachmentLane) ?? false
            let imageLaneIsVisible = showsImageAttachmentLane(configuration)
            rebuildAttachmentLane(
                animated: imageLaneWasVisible != imageLaneIsVisible &&
                    !UIAccessibility.isReduceMotionEnabled &&
                    window != nil
            )
        }
        applyFocusState()
    }

    func applyDeferredLayoutUpdates() {
        defersLayoutUpdates = false
        guard hasDeferredLayoutUpdates else { return }
        hasDeferredLayoutUpdates = false
        updateInputRowLayout()
        updateTextHeight()
        updateContextLane()
        rebuildAttachmentLane(animated: false)
        // UIStackView applies arranged-subview visibility through its next
        // constraint update. Flush that update before the controller captures
        // the expanded frame for the keyboard animation.
        contentStack.setNeedsUpdateConstraints()
        contentStack.updateConstraintsIfNeeded()
    }

    private func updateInputRowLayout() {
        guard let configuration else { return }
        let collapsed = configuration.isCollapsible && !configuration.isComposing
        // Keep attached context visible; only hide the camera affordance when collapsed.
        contextButton.isHidden = collapsed && configuration.context == nil
        // The shell can reveal the full dock without focusing the input. Keep the
        // existing stop action available in that expanded dock while a response streams;
        // the compact chat-circle presentation still hides the whole content stack.
        actionButton.isHidden = collapsed &&
            !configuration.isInline &&
            !configuration.isStreaming &&
            !configuration.hasExpandedDockWidth
        inputRow.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: ShopAgentUIKitComposerMetrics.rowInset,
            leading: contextButton.isHidden ? GravitySpacing.space20 : ShopAgentUIKitComposerMetrics.rowInset,
            bottom: ShopAgentUIKitComposerMetrics.rowInset,
            trailing: actionButton.isHidden ? GravitySpacing.space20 : ShopAgentUIKitComposerMetrics.rowInset
        )
    }

    fileprivate var isInputFocused: Bool { textView.isFirstResponder }

    fileprivate func applyFocusState() {
        guard !isChangingHost, window != nil, let configuration else { return }
        let shouldFocus = configuration.isFocused && (!configuration.isCollapsible || configuration.isComposing)
        if shouldFocus, !textView.isFirstResponder {
            guard contentStack.isUserInteractionEnabled, !isHidden else { return }
            textView.becomeFirstResponder()
        } else if !shouldFocus, textView.isFirstResponder {
            isEndingEditingInternally = true
            textView.resignFirstResponder()
            isEndingEditingInternally = false
        }
    }

    fileprivate func reconcileDismissedFocus() {
        // UIKit can end editing while a new navigation surface is being mounted,
        // when delegate writes are intentionally suppressed. Don't leave a wide,
        // supposedly focused input behind after the keyboard has gone away.
        guard !isChangingHost, window != nil, configuration?.isFocused == true,
              !textView.isFirstResponder else { return }
        onFocusChange(false)
        if configuration?.isCollapsible == true { onDismiss() }
    }

    func disconnect() {
        configuration = nil
        onQueryChange = { _ in }
        onFocusChange = { _ in }
        onOpen = {}
        onDismiss = {}
        onAddContext = { _ in }
        onRemoveContext = nil
        onRemoveImageAttachment = { _ in }
        onSubmit = {}
        onStop = {}
        contextButton.menu = nil
        contextLaneContainer.isHidden = true
        contextLane.clearAction()
        textView.resignFirstResponder()
    }

    private func updateContextLane() {
        guard let configuration,
              (!configuration.isCollapsible || configuration.isComposing),
              let context = configuration.context else {
            contextLaneContainer.isHidden = true
            return
        }
        contextLane.update(
            context: context,
            onRemove: configuration.canRemoveContext ? onRemoveContext : nil,
            iconRenderer: renderedIcon
        )
        contextLaneContainer.isHidden = false
    }

    private func showsImageAttachmentLane(_ configuration: ShopAgentUIKitComposerConfiguration) -> Bool {
        (!configuration.isCollapsible || configuration.isComposing) &&
            !configuration.imageAttachments.isEmpty
    }

    private func rebuildAttachmentLane(animated: Bool) {
        if animated {
            superview?.layoutIfNeeded()
        }
        attachmentStack.arrangedSubviews.forEach {
            attachmentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        guard let configuration,
              (!configuration.isCollapsible || configuration.isComposing),
              !configuration.imageAttachments.isEmpty else {
            attachmentScrollView.isHidden = true
            animateAttachmentLaneHeightIfNeeded(animated)
            return
        }
        configuration.imageAttachments.forEach { attachment in
            attachmentStack.addArrangedSubview(
                ShopAgentUIKitAttachmentPreview(
                    attachment: attachment,
                    onRemove: { [weak self] in self?.onRemoveImageAttachment(attachment.id) }
                )
            )
        }
        attachmentScrollView.isHidden = false
        animateAttachmentLaneHeightIfNeeded(animated)
    }

    private func animateAttachmentLaneHeightIfNeeded(_ animated: Bool) {
        guard animated else { return }
        UIView.animate(
            springDuration: ShopAgentUIKitComposerMetrics.attachmentTransitionDuration,
            bounce: ShopAgentUIKitComposerMetrics.attachmentTransitionBounce,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) { [weak self] in
            self?.superview?.layoutIfNeeded()
        }
    }

    private func updateContextButton() {
        guard let configuration else { return }
        let collapsed = configuration.isCollapsible && !configuration.isComposing
        if collapsed, let context = configuration.context {
            contextImageOverlay.isHidden = context.kind != .product || context.imageURL == nil
            contextButton.isEnabled = true
            contextButton.accessibilityLabel = localizedString(
                "Agent.Landing.ContextAccessibilityLabel",
                context.accessibilitySummary
            )
            contextButton.layer.borderWidth = 0
            contextButton.backgroundColor = context.showsImagePlaceholder
                ? UIColor(GravityColor.bgFillPlaceholder)
                : .clear
            contextButton.setImage(context.showsImagePlaceholder ? nil : renderedIcon(
                context.fallbackIcon, color: GravityColor.textPlaceholder, points: 24
            ), for: .normal)
            ShopAgentUIKitRemoteImageLoader.shared.load(context.imageURL, into: contextButton)
        } else {
            ShopAgentUIKitRemoteImageLoader.shared.cancel(for: contextButton)
            contextImageOverlay.isHidden = true
            contextButton.accessibilityLabel = localizedString("Agent.Landing.AddContextAccessibilityLabel")
            contextButton.layer.borderWidth = ShopAgentFloatingSurfaceMetrics.borderWidth
            contextButton.backgroundColor = .clear
            contextButton.setImage(
                renderedIcon(.camera, color: GravityColor.textTertiary, points: 24),
                for: .normal
            )
        }
    }

    private func updateActionButton() {
        guard let configuration else { return }
        if configuration.isStreaming {
            actionButton.isEnabled = true
            actionButton.accessibilityLabel = localizedString("Agent.Landing.StopAccessibilityLabel")
            actionButton.accessibilityIdentifier = "agent-follow-up-stop-button"
            actionButton.backgroundColor = UIColor(GravityColor.bgFillSecondary)
            actionButton.setImage(stopImage(), for: .normal)
        } else {
            actionButton.isEnabled = configuration.canSubmit || configuration.isInline
            actionButton.accessibilityLabel = localizedString("Agent.Landing.SubmitAccessibilityLabel")
            actionButton.accessibilityIdentifier = configuration.usesLandingAccessibilityIdentifiers
                ? "DYNAMIC_TYPEAHEAD_SUBMIT_BUTTON"
                : "agent-follow-up-submit-button"
            actionButton.backgroundColor = UIColor(
                configuration.canSubmit ? GravityColor.bgFillBrand : GravityColor.bgOverlayFixedDark04
            )
            actionButton.setImage(
                renderedIcon(
                    .arrowRight,
                    color: configuration.canSubmit ? GravityColor.textInverse : GravityColor.textTertiary,
                    points: 24
                ),
                for: .normal
            )
        }
    }

    private func configureCircularButton(
        _ button: UIButton,
        icon: GravityIconName,
        filled: Bool = false
    ) {
        button.tintColor = UIColor(GravityColor.textTertiary)
        button.setImage(renderedIcon(icon, color: GravityColor.textTertiary, points: 24), for: .normal)
        button.layer.cornerRadius = ShopAgentUIKitComposerMetrics.buttonSize / 2
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = filled ? 0 : ShopAgentFloatingSurfaceMetrics.borderWidth
        button.layer.borderColor = UIColor(GravityColor.border).cgColor
        button.backgroundColor = filled ? UIColor(GravityColor.bgOverlayFixedDark04) : .clear
        button.clipsToBounds = true
    }

    private func renderedIcon(_ name: GravityIconName, color: Color, points: CGFloat) -> UIImage? {
        let scheme: ColorScheme = traitCollection.userInterfaceStyle == .dark ? .dark : .light
        let renderer = ImageRenderer(
            content: ShopIcon(name, size: .medium, color: color)
                .frame(width: points, height: points)
                .environment(\.colorScheme, scheme)
        )
        renderer.scale = traitCollection.displayScale
        return renderer.uiImage?.withRenderingMode(.alwaysOriginal)
    }

    private func stopImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        return renderer.image { _ in
            UIColor(GravityColor.text).setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 10, height: 10), cornerRadius: 2).fill()
        }.withRenderingMode(.alwaysOriginal)
    }

    private func updateTextHeight() {
        guard !defersLayoutUpdates else { return }
        if let configuration, configuration.isCollapsible && !configuration.isComposing {
            // Docked chrome is a single 40-point row plus 8 points above and below.
            textView.isScrollEnabled = false
            textHeightConstraint?.constant = ShopAgentUIKitComposerMetrics.buttonSize
            return
        }
        let width = max(textView.bounds.width, 1)
        let fittingHeight = textView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        ).height
        let height = min(
            ShopAgentUIKitComposerMetrics.maximumTextHeight,
            max(ShopAgentUIKitComposerMetrics.buttonSize, ceil(fittingHeight))
        )
        textView.isScrollEnabled = fittingHeight > ShopAgentUIKitComposerMetrics.maximumTextHeight
        textHeightConstraint?.constant = height
    }

    private func applyTypography() {
        let font = GravityTextStyle.bodyLarge.scaledUIFont
        textView.font = font
        textView.textColor = UIColor(GravityColor.text)
        textView.typingAttributes = textAttributes(color: UIColor(GravityColor.text))
        placeholderLabel.font = font
        placeholderLabel.textColor = UIColor(GravityColor.textPlaceholder)
        typographyContentSizeCategory = traitCollection.preferredContentSizeCategory
    }

    private func setQueryText(_ text: String) {
        let selection = textView.selectedRange
        textView.attributedText = attributedText(text, color: UIColor(GravityColor.text))
        textView.selectedRange = NSRange(
            location: min(selection.location, text.utf16.count),
            length: min(selection.length, max(0, text.utf16.count - selection.location))
        )
        textView.typingAttributes = textAttributes(color: UIColor(GravityColor.text))
    }

    private func attributedText(_ text: String, color: UIColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: textAttributes(color: color))
    }

    private func textAttributes(color: UIColor) -> [NSAttributedString.Key: Any] {
        let style = GravityTextStyle.bodyLarge
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = max(0, style.lineHeight - style.size)
        return [
            .font: style.scaledUIFont,
            .foregroundColor: color,
            .kern: style.kerning,
            .paragraphStyle: paragraphStyle,
        ]
    }

    private func performAction() {
        guard let configuration else { return }
        if configuration.isInline {
            onOpen()
        } else if configuration.isStreaming {
            onStop()
        } else if configuration.canSubmit {
            onSubmit()
        }
    }

    private func performContextButtonAction() {
        guard let configuration else { return }
        if configuration.isCollapsible && !configuration.isComposing && configuration.context != nil {
            onOpen()
            textView.becomeFirstResponder()
        }
    }

    private func addPhotosMenu() -> UIMenu {
        UIMenu(
            title: localizedString("Agent.Attach.MenuTitle"),
            children: [
                UIAction(title: localizedString("Agent.Attach.Title"), image: UIImage(systemName: "paperclip")) { [weak self] _ in
                    self?.onAddContext(.attach)
                },
                UIAction(
                    title: localizedString("Account.MainPage.Avatar.ChoosePhoto"),
                    image: UIImage(systemName: "photo.on.rectangle.angled")
                ) { [weak self] _ in
                    self?.onAddContext(.library)
                },
                UIAction(
                    title: localizedString("Account.MainPage.Avatar.TakePhoto"),
                    image: UIImage(systemName: "camera")
                ) { [weak self] _ in
                    self?.onAddContext(.camera)
                },
            ]
        )
    }

    @objc private func focusOrOpenComposer() {
        guard let configuration else { return }
        if configuration.isCollapsible && !configuration.isComposing {
            onOpen()
            // The collapsed text view is read-only. Let the expanded configuration
            // enable editing before applyFocusState acquires first responder;
            // changing isEditable on a focused text view ends editing again.
            return
        }
        textView.becomeFirstResponder()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var touchedView = touch.view
        while let view = touchedView, view !== surfaceView {
            if view is UIControl { return false }
            touchedView = view.superview
        }
        return true
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        guard !isChangingHost else { return }
        onFocusChange(true)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        guard !isChangingHost, !isEndingEditingInternally else { return }
        onFocusChange(false)
        if configuration?.isCollapsible == true, configuration?.isComposing == true {
            onDismiss()
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        let cappedText = String(textView.text.prefix(shopAgentComposerInputMaxLength))
        if cappedText != textView.text { setQueryText(cappedText) }
        textView.typingAttributes = textAttributes(color: UIColor(GravityColor.text))
        placeholderLabel.isHidden = !cappedText.isEmpty
        onQueryChange(cappedText)
        updateTextHeight()
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard text.contains("\n") else {
            guard let swiftRange = Range(range, in: textView.text) else { return false }
            return textView.text.replacingCharacters(in: swiftRange, with: text).count <=
                shopAgentComposerInputMaxLength
        }
        if configuration?.canSubmit == true { onSubmit() }
        return false
    }
}

@MainActor
private final class ShopAgentUIKitComposerContextLane: UIView {
    private let imageView = UIImageView()
    private lazy var imageOverlay = ShopAgentComposerProductImageOverlay(on: imageView)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let labels = UIStackView()
    private let removeButton = UIButton(type: .system)
    private var onRemove: (() -> Void)?

    func clearAction() { onRemove = nil }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = UIColor(GravityColor.bgOverlayFixedDark04)
        layer.cornerRadius = GravityRadius.radius20
        layer.cornerCurve = .continuous
        clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = UIColor(GravityColor.bgFillPlaceholder)
        imageView.layer.cornerRadius = ShopAgentUIKitComposerMetrics.contextImageSize / 2
        imageView.clipsToBounds = true
        addSubview(imageView)

        titleLabel.font = GravityTextStyle.captionMedium.scaledUIFont
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = UIColor(GravityColor.text)
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.font = GravityTextStyle.badge.scaledUIFont
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = UIColor(GravityColor.textTertiary)
        subtitleLabel.lineBreakMode = .byTruncatingTail

        labels.translatesAutoresizingMaskIntoConstraints = false
        labels.axis = .vertical
        labels.addArrangedSubview(titleLabel)
        labels.addArrangedSubview(subtitleLabel)
        addSubview(labels)

        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.setImage(renderedSystemImage("xmark", pointSize: 12), for: .normal)
        removeButton.tintColor = UIColor(GravityColor.textTertiary)
        removeButton.accessibilityLabel = localizedString("Agent.Composer.RemoveContextAccessibilityLabel")
        removeButton.accessibilityIdentifier = "REMOVE_CONTEXT_BUTTON"
        removeButton.addAction(UIAction { [weak self] _ in self?.onRemove?() }, for: .touchUpInside)
        addSubview(removeButton)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: GravitySpacing.space16),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: ShopAgentUIKitComposerMetrics.contextImageSize),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            labels.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: GravitySpacing.space8),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: removeButton.leadingAnchor, constant: -GravitySpacing.space8),
            labels.centerYAnchor.constraint(equalTo: centerYAnchor),
            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -GravitySpacing.space12),
            removeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 32),
            removeButton.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    func update(
        context: ShopAgentUIKitComposerContext,
        onRemove: (() -> Void)?,
        iconRenderer: (GravityIconName, Color, CGFloat) -> UIImage?
    ) {
        self.onRemove = onRemove
        titleLabel.text = context.title
        subtitleLabel.text = context.subtitle
        subtitleLabel.isHidden = context.subtitle == nil
        removeButton.isHidden = onRemove == nil
        accessibilityLabel = localizedString("Agent.Landing.ContextAccessibilityLabel", context.accessibilitySummary)
        accessibilityIdentifier = "agent-follow-up-context-summary"
        isAccessibilityElement = true
        imageView.image = context.showsImagePlaceholder
            ? nil
            : iconRenderer(context.fallbackIcon, GravityColor.textPlaceholder, 20)
        imageOverlay.isHidden = context.kind != .product || context.imageURL == nil
        ShopAgentUIKitRemoteImageLoader.shared.load(context.imageURL, into: imageView)
    }

    private func renderedSystemImage(_ name: String, pointSize: CGFloat) -> UIImage? {
        UIImage(
            systemName: name,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        )
    }
}

@MainActor
private final class ShopAgentUIKitRemoteImageLoader {
    static let shared = ShopAgentUIKitRemoteImageLoader()
    private var tasks: [ObjectIdentifier: ImageTask] = [:]
    private var urls: [ObjectIdentifier: String] = [:]

    func load(_ urlString: String?, into imageView: UIImageView) {
        load(urlString, target: imageView) { imageView, image in imageView.image = image }
    }

    func load(_ urlString: String?, into button: UIButton) {
        load(urlString, target: button) { button, image in
            // System buttons treat an automatic-rendering image as a template. Product photos are
            // fully opaque, so that turns the entire clipped thumbnail into one tinted circle.
            button.setImage(image.withRenderingMode(.alwaysOriginal), for: .normal)
            button.imageView?.contentMode = .scaleAspectFill
        }
    }

    func cancel(for button: UIButton) {
        cancel(for: ObjectIdentifier(button))
    }

    private func load<T: AnyObject>(
        _ urlString: String?,
        target: T,
        apply: @escaping @MainActor (T, UIImage) -> Void
    ) {
        let key = ObjectIdentifier(target)
        guard let urlString,
              let url = ShopRemoteImageURLBuilder.url(
                  for: urlString,
                  displayWidth: ShopAgentUIKitComposerMetrics.contextImageSize
              ) else {
            cancel(for: key)
            return
        }

        var request = ImageRequest(url: url, priority: .high)
        request.thumbnail = ImageRequest.ThumbnailOptions(
            size: CGSize(
                width: ShopAgentUIKitComposerMetrics.contextImageSize,
                height: ShopAgentUIKitComposerMetrics.contextImageSize
            ),
            unit: .points,
            contentMode: .aspectFill
        )

        if let cachedImage = ImagePipeline.shared.cache[request], cachedImage.isPreview == false {
            tasks[key]?.cancel()
            tasks[key] = nil
            urls[key] = urlString
            apply(target, cachedImage.image)
            return
        }

        guard urls[key] != urlString else { return }
        urls[key] = urlString
        tasks[key]?.cancel()
        tasks[key] = ImagePipeline.shared.loadImage(with: request) { [weak self, weak target] result in
            guard let self, urls[key] == urlString else { return }
            tasks[key] = nil
            guard case let .success(response) = result, let target else { return }
            apply(target, response.image)
        }
    }

    private func cancel(for key: ObjectIdentifier) {
        tasks[key]?.cancel()
        tasks[key] = nil
        urls[key] = nil
    }
}

@MainActor
final class ShopAgentUIKitAttachmentPreview: UIView {
    init(attachment: ShopAgentImageAttachment, onRemove: @escaping () -> Void) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: UIImage(contentsOfFile: attachment.fileURL.path))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = UIColor(GravityColor.bgFillPlaceholder)
        imageView.layer.cornerRadius = ShopAgentImageAttachmentPreviewMetrics.imageCornerRadius
        imageView.layer.cornerCurve = .continuous
        imageView.clipsToBounds = true
        addSubview(imageView)

        let removeButton = UIButton(type: .system)
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.setImage(
            UIImage(
                systemName: "xmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            ),
            for: .normal
        )
        removeButton.tintColor = .white
        removeButton.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        removeButton.layer.cornerRadius = ShopAgentImageAttachmentPreviewMetrics.removeButtonSize / 2
        removeButton.accessibilityLabel = localizedString("Header.CloseA11yLabel")
        removeButton.addAction(UIAction { _ in onRemove() }, for: .touchUpInside)
        addSubview(removeButton)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: ShopAgentUIKitComposerMetrics.attachmentSize),
            heightAnchor.constraint(equalToConstant: ShopAgentUIKitComposerMetrics.attachmentSize),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: ShopAgentImageAttachmentPreviewMetrics.removeButtonSize),
            removeButton.heightAnchor.constraint(equalToConstant: ShopAgentImageAttachmentPreviewMetrics.removeButtonSize),
            removeButton.topAnchor.constraint(
                equalTo: topAnchor,
                constant: ShopAgentImageAttachmentPreviewMetrics.removeButtonInset
            ),
            removeButton.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -ShopAgentImageAttachmentPreviewMetrics.removeButtonInset
            ),
        ])

        if attachment.isUploading {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.translatesAutoresizingMaskIntoConstraints = false
            spinner.color = .white
            spinner.startAnimating()
            addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
