import Gravity
import UIKit

/// One persistent owner for the shell's Rodeo/Pistons tabs, composer, and Cart.
/// Only the composer follows the keyboard; the chrome remains pinned to the screen.
final class ShopBottomNavigationViewController: UIViewController {
    let chrome = ShopUIKitTabBarChromeView()
    private(set) var composerController: ShopAgentUIKitComposerViewController?
    private weak var conversation: ShopBottomNavigationConversation?
    private var chromeHeight: NSLayoutConstraint!
    private let standalone: Bool
    private let draftPresentation = ShopAgentDraftPresentationController()
    private var usesChatTabSwap = false
    private var navigationStyle = ShopBottomNavigationStyle.rodeo
    private var pendingDockFocus = false
    private weak var dockedAccessory: ShopAgentInlineAccessoryContainer?
    private var accessoryConstraints: [NSLayoutConstraint] = []
    private var accessoryHeight: NSLayoutConstraint?

    init(standalone: Bool = false) {
        self.standalone = standalone
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateDockedAccessoryHeight()
    }

    override func loadView() {
        view = ShopBottomNavigationPassthroughView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didRegisterFirstAppInteraction),
            name: ShopAppFirstInteractionTracker.didInteractNotification,
            object: nil
        )
        chrome.onCartPresentationChanged = { [weak self] in
            self?.updateComposer()
        }
        addChild(draftPresentation)
        draftPresentation.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(draftPresentation.view)
        NSLayoutConstraint.activate([
            draftPresentation.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            draftPresentation.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            draftPresentation.view.topAnchor.constraint(equalTo: view.topAnchor),
            draftPresentation.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        draftPresentation.didMove(toParent: self)
        chrome.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chrome)
        chrome.isHidden = standalone
        chromeHeight = chrome.heightAnchor.constraint(equalToConstant: ShopTabBarMetrics.reservedHeight)
        NSLayoutConstraint.activate([
            chrome.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chrome.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            chromeHeight,
        ])
        if !standalone { chrome.mountBackdrop(behindChromeIn: view) }
    }

    func update(
        conversation: ShopBottomNavigationConversation?,
        bottomInset: CGFloat,
        usesChatTabSwap: Bool = false,
        navigationStyle: ShopBottomNavigationStyle = .rodeo
    ) {
        if self.conversation !== conversation {
            pendingDockFocus = false
            if self.conversation?.controller === self { self.conversation?.controller = nil }
            // Changing screens changes the draft source, not the navigation's input.
            // Preserve the glass and its current dock geometry for the horizontal swap.
            composerController?.beginHostChange()
            composerController?.view.endEditing(true)
            composerController?.setInlineContainer(nil, preservesInlinePosition: false)
            composerController?.inlinePresentation.finish()
            self.conversation = conversation
        }
        conversation?.controller = self
        self.usesChatTabSwap = usesChatTabSwap
        self.navigationStyle = navigationStyle
        chromeHeight.constant = ShopTabBarMetrics.chromeHeight(for: bottomInset)
        updateComposer()
    }

    func toggleComposerDock() {
        guard usesChatTabSwap, let conversation else { return }
        let showsComposer = conversation.navigationMode == .tabs
        if showsComposer && conversation.opensAskPage {
            conversation.isAskPagePresented = true
        } else if !showsComposer {
            conversation.isAskPagePresented = false
        }
        if showsComposer {
            conversation.composerSource?.composer?.requestFocus()
        } else {
            conversation.composerSource?.composer?.dismissFocus()
            conversation.isDrafting = false
        }
        conversation.showNavigationMode(showsComposer ? .composer : .tabs)
        updateComposer(focusOverride: showsComposer)
    }

    func updateComposer(focusOverride: Bool? = nil) {
        if let focusOverride {
            pendingDockFocus = focusOverride
        } else if composerController?.isInputFocused == true,
                  conversation?.composerSource?.composer?.requestsFocus == true {
            pendingDockFocus = false
        }
        guard let composer = conversation?.composerSource?.composer else {
            // A destination preference arrives before its composer source mounts.
            // Keep the existing surface visible in whichever navigation mode is
            // already selected. Loading can replace the route-owned source, but it
            // must never create an empty leading slot between that source leaving
            // and its replacement attaching.
            let showsDockedComposer = usesChatTabSwap && conversation?.navigationMode == .composer
            draftPresentation.update(navigation: nil)
            if usesChatTabSwap, let composerController {
                chrome.setComposerDockPresentation(
                    showsComposer: showsDockedComposer,
                    compactComposerContentView: composerController.dockSurfaceContentView
                )
                if showsDockedComposer {
                    view.bringSubviewToFront(composerController.view)
                } else {
                    view.bringSubviewToFront(chrome)
                }
                composerController.setDockVisible(
                    showsDockedComposer,
                    compactView: chrome.compactComposerAnchor,
                    compactPrompt: chrome.compactComposerPrompt,
                    animated: true,
                    navigationStyle: navigationStyle
                )
            } else {
                composerController?.beginHostChange()
                composerController?.view.endEditing(true)
                composerController?.view.isHidden = true
                chrome.setComposerDockPresentation(showsComposer: false, compactComposerContentView: nil)
            }
            updateDockedAccessory()
            return
        }
        let controller: ShopAgentUIKitComposerViewController
        if let composerController {
            controller = composerController
        } else {
            controller = ShopAgentUIKitComposerViewController(ownsNavigationButtons: standalone)
            composerController = controller
            addChild(controller)
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            controller.view.isHidden = usesChatTabSwap
            view.insertSubview(controller.view, belowSubview: chrome)
            NSLayoutConstraint.activate([
                controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                controller.view.topAnchor.constraint(equalTo: view.topAnchor),
                controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            controller.didMove(toParent: self)
            // Resolve the new child's frame before converting the compact dock
            // anchor into its coordinates (its initial frame is still zero).
            view.layoutIfNeeded()
        }
        // The composer returns alongside the native pop, while chat chrome stays alive
        // until the transition completes (or a cancelled swipe restores it).
        let isReturning = conversation?.isReturningComposerFromPush == true
        let isPresented = !isReturning && conversation?.isConversationVisible == true
        let isDrafting = !isReturning && conversation?.isDrafting == true
        let showsDockedComposer = !isReturning && usesChatTabSwap && conversation?.navigationMode == .composer
        // Drafts now share one screen-level curtain, including docked composers.
        controller.inlinePresentation.backdrop = nil
        if isPresented {
            controller.inlinePresentation.finish(keepingBackdropVisible: conversation?.usesPushedPresentation != true)
        }
        controller.inlinePresentation.source = conversation?.inlineComposerContainer
        controller.inlinePresentation.accessoryContainer = nil
        let inlineContainer = isPresented || isDrafting || showsDockedComposer ? nil : conversation?.inlineComposerContainer
        let swapsDock = usesChatTabSwap && inlineContainer == nil
        if usesChatTabSwap {
            chrome.setComposerDockPresentation(
                showsComposer: showsDockedComposer,
                compactComposerContentView: swapsDock ? controller.dockSurfaceContentView : nil
            )
        }
        // The chrome owns the compact tab toggle and Cart in both exclusive modes.
        // Its root is transparent outside those controls, so keeping it above the
        // full-screen composer host prevents the composer from covering either one.
        view.bringSubviewToFront(chrome)
        if !swapsDock {
            controller.resetDockVisibility()
            if isPresented || isDrafting { controller.view.isHidden = false }
        }
        controller.overrideUserInterfaceStyle = overrideUserInterfaceStyle
        composer.configure(
            controller,
            navigationDockInset: standalone ? nil : ShopTabBarMetrics.composerHorizontalInset,
            navigationDockTrailingInset: standalone ? nil : chrome.composerTrailingInset,
            allowsFocus: usesChatTabSwap ? showsDockedComposer : (isPresented || isDrafting || conversation?.prefersDockedComposer == true),
            // A compact surface may not accept first responder until it is
            // revealed. Keep the tap's intent through interim source updates.
            focusOverride: focusOverride ?? (pendingDockFocus ? true : nil),
            inlineContainer: inlineContainer
        )
        if swapsDock {
            controller.setDockVisible(
                showsDockedComposer,
                compactView: chrome.compactComposerAnchor,
                compactPrompt: chrome.compactComposerPrompt,
                animated: true,
                navigationStyle: navigationStyle
            )
        } else {
            controller.view.isHidden = !isPresented && !isDrafting && !controller.isReturningToInline && conversation?.prefersDockedComposer != true
        }
        updateDockedAccessory()
    }

    @objc private func didRegisterFirstAppInteraction() {
        updateComposer()
    }

    func updateDockedAccessory() {
        // The SwiftUI accessory producer can mount before the input producer.
        // Don't record it as installed until there is a composer to anchor it to.
        let accessory = composerController == nil ? nil : conversation?.dockedAccessorySource?.contentContainer
        if dockedAccessory !== accessory {
            NSLayoutConstraint.deactivate(accessoryConstraints)
            accessoryConstraints = []
            accessoryHeight = nil
            dockedAccessory?.removeFromSuperview()
            dockedAccessory = accessory
            if let accessory, let composerController {
                accessory.translatesAutoresizingMaskIntoConstraints = false
                // Share the composer's layout/animation root. Cross-controller
                // constraints settle correctly, but miss its keyboard/height animation.
                let host = composerController.view!
                composerController.placeAccessoryBehindComposer(accessory)
                let height = accessory.heightAnchor.constraint(equalToConstant: 0)
                height.identifier = "AgentComposer.accessoryHeight"
                accessoryHeight = height
                accessoryConstraints = [
                    height,
                    accessory.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: GravitySpacing.space12),
                    accessory.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -GravitySpacing.space12),
                    accessory.bottomAnchor.constraint(equalTo: composerController.accessoryBottomAnchor, constant: -GravitySpacing.space12),
                ]
                NSLayoutConstraint.activate(accessoryConstraints)
            }
        }
        let source = conversation?.dockedAccessorySource
        let showsStarters = source?.isAccessoryVisible == true
            && conversation?.isDraftPresented == true
            && conversation?.composerSource?.composer?.hasText == false
        source?.setStartersVisible(showsStarters)
        updateDockedAccessoryHeight()
        draftPresentation.update(navigation: conversation)
    }

    private func updateDockedAccessoryHeight() {
        guard let dockedAccessory, let accessoryHeight else { return }
        let width = view.bounds.width - 2 * GravitySpacing.space12
        guard width > 0 else { return }
        // Hosting configurations are self-sizing in cells, but this one lives in
        // navigation chrome. Give its full measured stack height to Auto Layout.
        let height = dockedAccessory.fittingSize(width: width).height
        if abs(accessoryHeight.constant - height) > 0.5 {
            accessoryHeight.constant = height
        }
    }

    func disconnect() {
        if conversation?.controller === self { conversation?.controller = nil }
        conversation = nil
        removeComposer()
        chrome.onBack = nil
        chrome.onOpenCart = nil
        chrome.onTabPressed = nil
        chrome.prepareForRemoval()
    }

    private func removeComposer() {
        NSLayoutConstraint.deactivate(accessoryConstraints)
        accessoryConstraints = []
        accessoryHeight = nil
        dockedAccessory?.removeFromSuperview()
        dockedAccessory = nil
        draftPresentation.update(navigation: nil)
        guard let controller = composerController else { return }
        controller.setInlineContainer(nil)
        controller.inlinePresentation.finish()
        controller.view.endEditing(true)
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
        composerController = nil
    }
}

private final class ShopBottomNavigationPassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}
