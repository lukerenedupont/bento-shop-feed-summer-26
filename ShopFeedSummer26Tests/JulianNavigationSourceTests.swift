// Source: Shopify/shop-client @ 79849f634b495df011aeefc0c4ef04a7180e633d. Only the test import changes.
import Gravity
import SwiftUI
import Testing
import UIKit
@testable import JulianAgentUI

@Suite(.serialized)
@MainActor
struct ShopTabBarChromeConversationTests {
    @Test
    func contextualBuyingQuestionOpensAsAnUnsentDraft() {
        let state = JulianShellState()
        let context = JulianShellState.Context(id: "world:norda", title: "Norda edit")
        state.activate(context)
        var submissionCount = 0
        state.onInitialAgentSubmit = { _, _ in submissionCount += 1 }
        state.openAsk(prompt: "Should I buy Norda 003 now or wait?")
        #expect(state.context == context)
        #expect(state.draft.query == "Should I buy Norda 003 now or wait?")
        #expect(state.draft.isFocused)
        #expect(state.draft.navigation.isAskPagePresented)
        #expect(submissionCount == 0)
        #expect(!state.isConversationPresented)
    }

    @Test
    func dockDepthDipsTheRecedingSurfaceAndBumpsTheComposer() throws {
        let layer = CALayer()
        #expect(ShopTabBarMetrics.dockSwapBounce == 0)
        #expect(ShopTabBarMetrics.dockExpansionBounce == 0.14)
        #expect(ShopAgentUIKitComposerMetrics.focusTransitionBounce == 0.04)
        #expect(ShopTabBarMetrics.dockChatIconFadeOutDuration == 0.12)
        #expect(ShopTabBarMetrics.dockChatIconFadeOutDuration < ShopTabBarMetrics.dockSwapDuration / 2)
        let duration = ShopTabBarMetrics.dockSwapDuration
        ShopDockSwapDepthAnimation.animate(on: layer, recedes: false, duration: duration, animated: true)
        #expect(layer.animation(forKey: ShopDockSwapDepthAnimation.animationKey) == nil)

        ShopDockSwapDepthAnimation.animate(
            on: layer,
            recedes: false,
            bumps: true,
            duration: duration,
            animated: true
        )
        let bump = try #require(layer.animation(forKey: ShopDockSwapDepthAnimation.animationKey) as? CAKeyframeAnimation)
        #expect(bump.values?.compactMap { ($0 as? NSNumber)?.doubleValue } == [1, 1.12, 1])
        #expect(bump.keyTimes == [0, 0.5, 1])
        layer.removeAnimation(forKey: ShopDockSwapDepthAnimation.animationKey)

        ShopDockSwapDepthAnimation.animate(on: layer, recedes: true, duration: duration, animated: true)
        let dip = try #require(layer.animation(forKey: ShopDockSwapDepthAnimation.animationKey) as? CAKeyframeAnimation)
        #expect(dip.values?.compactMap { ($0 as? NSNumber)?.doubleValue } == [1, 0.90, 1])
        #expect(dip.keyTimes == [0, 0.5, 1])
        #expect(dip.duration == duration)
        #expect(CATransform3DIsIdentity(layer.transform))

        ShopDockSwapDepthAnimation.animate(
            on: layer,
            recedes: true,
            recedingScale: ShopDockSwapDepthAnimation.subtleMinimumScale,
            duration: duration,
            animated: true
        )
        let subtleDip = try #require(
            layer.animation(forKey: ShopDockSwapDepthAnimation.animationKey) as? CAKeyframeAnimation
        )
        #expect(subtleDip.values?.compactMap { ($0 as? NSNumber)?.doubleValue } == [1, 0.96, 1])

        // Reversing the swap restores the newly foreground surface, without a second dip.
        ShopDockSwapDepthAnimation.animate(on: layer, recedes: false, duration: duration, animated: true)
        let restore = try #require(layer.animation(forKey: ShopDockSwapDepthAnimation.animationKey) as? CAKeyframeAnimation)
        #expect(restore.values?.count == 2)
        #expect((restore.values?.last as? NSNumber)?.doubleValue == 1)

        // Nonanimated/reduced-motion paths remove only our depth animation.
        let unrelated = CABasicAnimation(keyPath: "opacity")
        unrelated.duration = 1
        layer.add(unrelated, forKey: "unrelated")
        ShopDockSwapDepthAnimation.animate(on: layer, recedes: true, duration: duration, animated: false)
        #expect(layer.animation(forKey: ShopDockSwapDepthAnimation.animationKey) == nil)
        #expect(layer.animation(forKey: "unrelated") != nil)
        #expect(CATransform3DIsIdentity(layer.transform))
    }

    @Test
    func navigationVisibilityChangesDoNotPulseTheTabMaterial() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let controller = UIViewController()
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        let chrome = ShopUIKitTabBarChromeView(frame: CGRect(x: 0, y: 740, width: 393, height: 112))
        controller.view.addSubview(chrome)
        update(chrome, coordinator: ShopAddToCartAnimationCoordinator(), hidesTabs: false)
        let surface = try #require(findView("navigation-tab-surface", in: chrome))
        // Initial Back/Cart visibility used to add a squash/stretch keyframe,
        // even for nonanimated updates. Native glass interaction is unchanged.
        #expect(surface.transform == .identity)
        #expect(surface.layer.animationKeys()?.isEmpty != false)
        chrome.prepareForRemoval()
    }

    @Test
    func tabSurfaceInstallsNavigationStyleLongPressWithoutCancellingTabTaps() throws {
        let chrome = ShopUIKitTabBarChromeView(frame: CGRect(x: 0, y: 740, width: 393, height: 112))
        let surface = try #require(findView("navigation-tab-surface", in: chrome))
        let longPress = try #require(
            surface.gestureRecognizers?.compactMap { $0 as? UILongPressGestureRecognizer }.first
        )

        #expect(longPress.minimumPressDuration == 0.6)
        #expect(!longPress.cancelsTouchesInView)
        #expect(longPress.delegate === chrome)
    }

    @Test(arguments: [ShopBottomNavigationStyle.rodeo, .pistons])
    func `bottom protection stays visible when tabs swap with the composer`(style: ShopBottomNavigationStyle) throws {
        let owner = ShopBottomNavigationViewController()
        owner.loadViewIfNeeded()
        owner.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        defer { owner.disconnect() }
        let coordinator = ShopAddToCartAnimationCoordinator()
        let backdrop = try #require(findView("navigation-bottom-protection", in: owner.view))

        for showsComposer in [true, false, true, false] {
            update(owner.chrome, coordinator: coordinator, hidesTabs: showsComposer,
                   swapsComposer: true, navigationStyle: style)
            #expect(backdrop.alpha == 1)
            #expect(!backdrop.isHidden)
            #expect(owner.view.subviews.first === backdrop)

            // Direct dock toggles must agree before SwiftUI republishes the mode.
            owner.chrome.setComposerDockPresentation(showsComposer: !showsComposer, compactComposerContentView: nil)
            #expect(backdrop.alpha == 1)
        }

        // Preserve the non-swapping conversation's existing hide/restore behavior.
        update(owner.chrome, coordinator: coordinator, hidesTabs: true)
        #expect(backdrop.alpha == 0)
        update(owner.chrome, coordinator: coordinator, hidesTabs: false)
        #expect(backdrop.alpha == 1)
    }

    // This single test requires Shop's production route/history owner, not the UI package.
    #if JULIAN_PRODUCTION_ROUTING
    @Test(arguments: [false, true])
    func detailPreviewKeepsItsConversationThroughNativeZoomReturn(docksComposer: Bool) throws {
        let conversation = ShopInlineConversation(docksComposer: docksComposer, usesPushedPresentation: true)
        conversation.summary = ShopAgentConversationSummary(
            firstQuery: "trail shoes",
            updatedAt: .now,
            conversationID: "search-preview"
        )

        conversation.open()
        let params = try #require(conversation.consumeRouteRequest())
        // The routed Agent screen marks the shared navigation as presented when it appears.
        conversation.navigation.isPresented = true
        #expect(conversation.navigation.usesPushedPresentation)
        #expect(conversation.navigation.isPresented)
        #expect(conversation.navigation.showsDockedComposer)

        conversation.navigation.isPresented = false
        // Keep the outgoing conversation/composer alive until the native pop completes.
        #expect(conversation.navigation.isConversationVisible)
        conversation.navigation.finishPushedConversationReturn()
        #expect(!conversation.navigation.isConversationVisible)
        // Orders restore their docked composer; search restores its tab-centered navigation.
        #expect(conversation.navigation.showsDockedComposer == docksComposer)
        #expect(conversation.summary?.conversationID == "search-preview")

        conversation.open()
        #expect(conversation.consumeRouteRequest()?.id == params.id)
        #expect(!ShopInlineConversation().navigation.usesPushedPresentation)
    }

    #endif

    @Test
    func toolbarChevronHasStableIntrinsicSizeAndAdaptiveTint() {
        let image = ShopToolbarBackControl.chevronImage
        #expect(image.size == CGSize(width: 20, height: 20))
        #expect(image.renderingMode == .alwaysTemplate)
        #expect(image.flipsForRightToLeftLayoutDirection)
        #expect(image.cgImage != nil)
    }

    @Test
    func draftPresentationEndsWhenConversationOpens() {
        let navigation = ShopBottomNavigationConversation(prefersDockedComposer: true)
        #expect(!navigation.isDraftPresented)
        navigation.isDrafting = true
        #expect(navigation.isDraftPresented)
        navigation.isPresented = true
        #expect(!navigation.isDraftPresented)
        #expect(navigation.showsDockedComposer)
        navigation.showNavigationMode(.tabs)
        #expect(!navigation.showsDockedComposer)
        #expect(navigation.isConversationVisible)
    }

    @Test
    func closingDraftRestoresTheSourcesDefaultDock() {
        for detail in [false, true] {
            let navigation = ShopBottomNavigationConversation(prefersDockedComposer: detail, opensAskPage: !detail)
            navigation.isDrafting = detail
            navigation.isAskPagePresented = !detail
            navigation.showNavigationMode(.composer)
            #expect(navigation.isDraftPresented)
            navigation.closeAskPage()
            #expect(!navigation.isDraftPresented)
            #expect(navigation.showsDockedComposer == detail)
        }
    }

    @Test
    func `page interaction restores a page's preferred composer without opening it`() {
        let navigation = ShopBottomNavigationConversation(prefersDockedComposer: true)

        navigation.showNavigationMode(.tabs)

        #expect(navigation.navigationMode == .tabs)
        navigation.restorePreferredComposerAfterPageInteraction()
        #expect(navigation.navigationMode == .composer)
        #expect(!navigation.isDraftPresented)
        navigation.restorePreferredComposerAfterPageInteraction()
        #expect(navigation.navigationMode == .composer)
    }

    @Test
    func `page interaction does not change a tab-first navigation`() {
        let navigation = ShopBottomNavigationConversation(prefersDockedComposer: false)

        navigation.restorePreferredComposerAfterPageInteraction()
        #expect(navigation.navigationMode == .tabs)
    }

    @Test
    func dockedComposerWaitsForEditableConfigurationBeforeFocusing() throws {
        let controller = ShopAgentUIKitComposerViewController(ownsNavigationButtons: false)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            controller.disconnect()
            window.isHidden = true
        }
        var isComposing = false
        var didOpen = false
        var didDismiss = false
        let composer = ShopAgentUIKitComposer(
            query: .constant(""),
            isComposing: Binding(get: { isComposing }, set: { isComposing = $0 }),
            context: .init(kind: .product, title: "Running shoe", fallbackIcon: .noImage),
            imageAttachments: [], canSubmit: false, isStreaming: false, showsBackButton: false,
            restingBottomInset: 0, bottomSpacing: 0, preservesNavigationBackTapRegion: false,
            onOpen: { didOpen = true }, onDismiss: { didDismiss = true },
            onBack: {}, onClose: {}, onAddContext: { _ in },
            onRemoveImageAttachment: { _ in }, onSubmit: {}, onStop: {}
        )
        composer.configure(controller, navigationDockInset: 92)
        window.layoutIfNeeded()
        let input = try #require(findView("agent-follow-up-text-input", in: controller.view) as? UITextView)
        let surface = try #require(findView("agent-composer-surface", in: controller.view))
        let composerView = try #require(surface.superview)
        #expect(!input.isEditable)

        // Exercise the tap action before SwiftUI publishes the expanded configuration,
        // as happens while the PDP's retained conversation is parked offscreen.
        composerView.perform(NSSelectorFromString("focusOrOpenComposer"))
        #expect(didOpen)
        #expect(isComposing)
        #expect(!input.isFirstResponder)

        composer.configure(controller, navigationDockInset: 92)
        #expect(input.isEditable)
        #expect(input.isFirstResponder)
        #expect(!didDismiss)
    }

    @Test
    func closingDraftEndsNativeEditingBeforeTheSourceRefreshes() throws {
        let navigation = ShopBottomNavigationConversation(prefersDockedComposer: true)
        let owner = ShopBottomNavigationViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = owner
        window.makeKeyAndVisible()
        defer {
            owner.disconnect()
            window.isHidden = true
        }
        let source = ShopBottomNavigationComposerSourceView()
        navigation.composerSource = source
        // Model a source that hasn't received SwiftUI's unfocused snapshot yet.
        var reportedFocus = true
        source.composer = ShopAgentUIKitComposer(
            query: .constant("My draft"),
            isComposing: Binding(get: { reportedFocus }, set: { _ in }),
            context: nil, imageAttachments: [], canSubmit: true,
            isStreaming: false, showsBackButton: false,
            restingBottomInset: 0, bottomSpacing: 0,
            preservesNavigationBackTapRegion: false,
            onOpen: {}, onDismiss: {}, onBack: {}, onClose: {},
            onAddContext: { _ in }, onRemoveImageAttachment: { _ in },
            onSubmit: {}, onStop: {}
        )
        navigation.isDrafting = true
        owner.update(conversation: navigation, bottomInset: 34)
        let controller = try #require(owner.composerController)
        let input = try #require(findView("agent-follow-up-text-input", in: controller.view) as? UITextView)
        #expect(input.isFirstResponder)

        navigation.closeAskPage()
        #expect(!input.isFirstResponder)
        #expect(!navigation.isDraftPresented)
        #expect(navigation.showsDockedComposer)
        #expect(input.text == "My draft")
        // The same focus reconciliation is also called by dock completions.
        controller.endHostChange()
        #expect(!input.isFirstResponder)

        // Opening must also survive an interim source update that still reports
        // the closed state, even if UIKit already accepted first responder.
        reportedFocus = false
        owner.update(conversation: navigation, bottomInset: 34, usesChatTabSwap: true)
        owner.toggleComposerDock()
        owner.toggleComposerDock()
        owner.updateComposer()
        #expect(input.isFirstResponder)
    }

    @Test
    func inlineComposerTargetsFinalKeyboardFrameAndReturnsToPlaceholder() throws {
        let controller = ShopAgentUIKitComposerViewController(ownsNavigationButtons: false)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = controller
        window.isHidden = false
        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer {
            controller.disconnect()
            window.isHidden = true
            UIView.setAnimationsEnabled(animationsWereEnabled)
        }
        window.layoutIfNeeded()
        let inline = UIView(frame: CGRect(x: 20, y: 360, width: 353, height: 56))
        controller.view.addSubview(inline)
        func composer(focused: Bool) -> ShopAgentUIKitComposer {
            ShopAgentUIKitComposer(
                query: .constant(""), isComposing: .constant(focused),
                context: .init(kind: .product, title: "Running shoe", fallbackIcon: .noImage),
                imageAttachments: [], canSubmit: false, isStreaming: false, showsBackButton: true,
                restingBottomInset: 0, bottomSpacing: 0, preservesNavigationBackTapRegion: false,
                onOpen: {}, onDismiss: {}, onBack: {}, onClose: {}, onAddContext: { _ in },
                onRemoveImageAttachment: { _ in }, onSubmit: {}, onStop: {}
            )
        }
        composer(focused: false).configure(controller, allowsFocus: false, inlineContainer: inline)
        inline.layoutIfNeeded()
        let input = try #require(findView("agent-follow-up-text-input", in: inline))
        let surface = try #require(findView("agent-composer-surface", in: inline))
        composer(focused: true).configure(controller)

        // The target comes from the notification, not the guide's current layout frame.
        let keyboardFrame = CGRect(x: 0, y: 550, width: 393, height: 302)
        let screenFrame = controller.view.convert(keyboardFrame, to: window.screen.coordinateSpace)
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil, userInfo: [
            UIResponder.keyboardFrameEndUserInfoKey: screenFrame,
            UIResponder.keyboardAnimationDurationUserInfoKey: 0.0,
        ])
        controller.view.layoutIfNeeded()
        let openedFrame = surface.convert(surface.bounds, to: controller.view)
        #expect(abs(openedFrame.maxY - 538) < 0.5)
        #expect(abs(openedFrame.minX - 12) < 0.5)
        #expect(abs(openedFrame.width - 369) < 0.5)
        #expect(surface.bounds.height > ShopAgentUIKitComposerMetrics.barHeight)
        #expect(findView("agent-follow-up-context-summary", in: surface) != nil)

        // Returning uses the placeholder's current position, not the captured starting one.
        inline.frame.origin.y = 300
        composer(focused: false).configure(controller, allowsFocus: false, inlineContainer: inline)
        inline.layoutIfNeeded()
        #expect(findView("agent-follow-up-text-input", in: inline) === input)
        #expect(abs(surface.convert(surface.bounds, to: controller.view).minY - 300) < 0.5)
        #expect(abs(surface.bounds.height - 56) < 0.5)
    }

    @Test
    func inlineProductComposerReusesItsInputWhenDraftingAndOpeningChat() throws {
        let navigation = ShopBottomNavigationConversation()
        let owner = ShopBottomNavigationViewController()
        owner.loadViewIfNeeded()
        owner.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let inline = UIView(frame: CGRect(x: 20, y: 350, width: 353, height: 56))
        owner.view.addSubview(inline)
        navigation.inlineComposerContainer = inline
        let source = ShopBottomNavigationComposerSourceView()
        navigation.composerSource = source
        source.composer = ShopAgentUIKitComposer(
            query: .constant("Does this run true to size?"), isComposing: .constant(false),
            context: .init(kind: .product, title: "Running shoe", fallbackIcon: .noImage),
            imageAttachments: [], canSubmit: true, isStreaming: false, showsBackButton: true,
            restingBottomInset: 0, bottomSpacing: 0, preservesNavigationBackTapRegion: false,
            onOpen: { navigation.isDrafting = true }, onDismiss: { navigation.isDrafting = false },
            onBack: {}, onClose: {}, onAddContext: { _ in }, onRemoveImageAttachment: { _ in },
            onSubmit: {}, onStop: {}
        )
        owner.update(conversation: navigation, bottomInset: 34)
        owner.view.layoutIfNeeded()
        inline.layoutIfNeeded()
        let input = try #require(findView("agent-follow-up-text-input", in: inline))
        let surface = try #require(findView("agent-composer-surface", in: inline))
        #expect(abs(surface.bounds.height - 56) < 0.5)
        let camera = try #require(findView("agent-follow-up-add-context-button", in: inline) as? UIButton)
        camera.sendActions(for: .touchUpInside)
        #expect(navigation.isDrafting)
        #expect(!navigation.isPresented)
        let controller = try #require(owner.composerController)
        let inlineFrame = surface.convert(surface.bounds, to: owner.view)
        controller.setInlineContainer(nil)
        let liftedFrame = surface.convert(surface.bounds, to: owner.view)
        #expect(abs(liftedFrame.minY - inlineFrame.minY) < 0.5)
        #expect(abs(liftedFrame.minX - inlineFrame.minX) < 0.5)
        #expect(abs(liftedFrame.width - inlineFrame.width) < 0.5)
        owner.updateComposer()
        #expect(findView("agent-follow-up-text-input", in: controller.view) === input)
        #expect(findView("agent-follow-up-text-input", in: inline) == nil)
        navigation.isPresented = true
        navigation.isDrafting = false
        owner.updateComposer()
        #expect(findView("agent-follow-up-text-input", in: controller.view) === input)
        navigation.isPresented = false
        owner.updateComposer()
        #expect(findView("agent-follow-up-text-input", in: inline) === input)
        owner.disconnect()
        #expect(inline.subviews.isEmpty)
    }

    @Test
    func firstFocusExpandsDockedComposerWithoutASecondConfigurationUpdate() throws {
        let controller = ShopAgentUIKitComposerViewController(ownsNavigationButtons: false)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()

        for isComposing in [false, true, false, true] {
            let composer = ShopAgentUIKitComposer(
                query: .constant(""), isComposing: .constant(isComposing),
                context: nil, imageAttachments: [], canSubmit: false,
                isStreaming: false, showsBackButton: true,
                restingBottomInset: 0, bottomSpacing: 0,
                preservesNavigationBackTapRegion: false,
                onOpen: {}, onDismiss: {}, onBack: {}, onClose: {},
                onAddContext: { _ in }, onRemoveImageAttachment: { _ in },
                onSubmit: {}, onStop: {}
            )
            composer.configure(controller, navigationDockInset: ShopTabBarMetrics.composerHorizontalInset)
            controller.view.layoutIfNeeded()
            let surface = try #require(findView("agent-composer-surface", in: controller.view))
            let frame = surface.convert(surface.bounds, to: controller.view)
            let expectedInset = isComposing ? 12 : ShopTabBarMetrics.composerHorizontalInset
            let expectedWidth = controller.view.bounds.width - 2 * expectedInset
            #expect(abs(frame.width - expectedWidth) < 0.5)
            #expect(abs(frame.minX - expectedInset) < 0.5)
            if !isComposing {
                #expect(abs(frame.minX - (24 + 56) - 12) < 0.5)
            }
        }
    }

    @Test
    func dockedComposerKeepsItsHeightAndSymmetricCameraInsets() throws {
        let controller = ShopAgentUIKitComposerViewController(ownsNavigationButtons: false)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        controller.additionalSafeAreaInsets.bottom = 34

        for query in ["", "A longer draft that would wrap across several lines in the docked composer"] {
            let composer = ShopAgentUIKitComposer(
                query: .constant(query), isComposing: .constant(false),
                context: nil, imageAttachments: [], canSubmit: false,
                isStreaming: false, showsBackButton: true,
                restingBottomInset: 0, bottomSpacing: 0,
                preservesNavigationBackTapRegion: false,
                onOpen: {}, onDismiss: {}, onBack: {}, onClose: {},
                onAddContext: { _ in }, onRemoveImageAttachment: { _ in },
                onSubmit: {}, onStop: {}
            )
            composer.configure(controller, navigationDockInset: ShopTabBarMetrics.composerHorizontalInset, allowsFocus: false)
            controller.view.layoutIfNeeded()

            let surface = try #require(findView("agent-composer-surface", in: controller.view))
            let camera = try #require(findView("agent-follow-up-add-context-button", in: controller.view))
            let glass = try #require(surface as? ShopUIKitGlassSurfaceView)
            #expect(camera.isHidden)
            if #available(iOS 26.0, *) {
                let container = try #require(glass.subviews.compactMap { $0 as? UIVisualEffectView }.first)
                let material = try #require(container.contentView.subviews.compactMap { $0 as? UIVisualEffectView }.first)
                #expect(material.cornerConfiguration == .uniformCorners(radius: .fixed(28)))
            }
            #expect(abs(surface.bounds.height - 56) < 0.5)
            #expect(surface.layer.cornerRadius == 28)
        }

        let expanded = ShopAgentUIKitComposer(
            query: .constant(""), isComposing: .constant(true),
            context: nil, imageAttachments: [], canSubmit: false,
            isStreaming: false, showsBackButton: true,
            restingBottomInset: 0, bottomSpacing: 0,
            preservesNavigationBackTapRegion: false,
            onOpen: {}, onDismiss: {}, onBack: {}, onClose: {},
            onAddContext: { _ in }, onRemoveImageAttachment: { _ in },
            onSubmit: {}, onStop: {}
        )
        expanded.configure(
            controller,
            navigationDockInset: ShopTabBarMetrics.composerHorizontalInset,
            allowsFocus: true
        )
        controller.view.layoutIfNeeded()
        let expandedSurface = try #require(findView("agent-composer-surface", in: controller.view))
        let expandedCamera = try #require(findView("agent-follow-up-add-context-button", in: controller.view))
        let cameraFrame = expandedCamera.convert(expandedCamera.bounds, to: expandedSurface)
        #expect(!expandedCamera.isHidden)
        #expect(abs(cameraFrame.minX - 8) < 0.5)
        #expect(abs(cameraFrame.minY - 8) < 0.5)
        #expect(abs(expandedSurface.bounds.maxY - cameraFrame.maxY - 8) < 0.5)
    }

    @Test
    func expandedDockKeepsStopButtonVisibleWhileStreaming() throws {
        let controller = ShopAgentUIKitComposerViewController(ownsNavigationButtons: false)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        var didStop = false
        let composer = ShopAgentUIKitComposer(
            query: .constant(""), isComposing: .constant(false),
            context: nil, imageAttachments: [], canSubmit: false,
            isStreaming: true, showsBackButton: false,
            restingBottomInset: 0, bottomSpacing: 0,
            preservesNavigationBackTapRegion: false,
            onOpen: {}, onDismiss: {}, onBack: {}, onClose: {},
            onAddContext: { _ in }, onRemoveImageAttachment: { _ in },
            onSubmit: {}, onStop: { didStop = true }
        )

        composer.configure(
            controller,
            navigationDockInset: ShopTabBarMetrics.composerHorizontalInset,
            allowsFocus: true
        )
        controller.view.layoutIfNeeded()

        let stop = try #require(findView("agent-follow-up-stop-button", in: controller.view) as? UIButton)
        #expect(!stop.isHidden)
        stop.sendActions(for: .touchUpInside)
        #expect(didStop)
    }

    @Test
    func dockedProductPreviewStaysSquareWhenAWideImageLoads() throws {
        let controller = ShopAgentUIKitComposerViewController(ownsNavigationButtons: false)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        defer { controller.disconnect() }
        let composer = ShopAgentUIKitComposer(
            query: .constant(""), isComposing: .constant(false),
            context: .init(kind: .product, title: "Pillowcases", fallbackIcon: .noImage),
            imageAttachments: [], canSubmit: false, isStreaming: false, showsBackButton: false,
            restingBottomInset: 0, bottomSpacing: 0, preservesNavigationBackTapRegion: false,
            onOpen: {}, onDismiss: {}, onBack: {}, onClose: {}, onAddContext: { _ in },
            onRemoveImageAttachment: { _ in }, onSubmit: {}, onStop: {}
        )
        composer.configure(controller, navigationDockInset: ShopTabBarMetrics.composerHorizontalInset)
        let preview = try #require(findView("agent-follow-up-add-context-button", in: controller.view) as? UIButton)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 40)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 160, height: 40))
        }
        preview.setImage(image, for: .normal)
        controller.view.layoutIfNeeded()
        #expect(abs(preview.bounds.width - preview.bounds.height) < 0.5)
        #expect(abs(preview.bounds.width - ShopAgentUIKitComposerMetrics.buttonSize) < 0.5)
    }

    @Test
    func glassButtonsAndTabSurfaceShareUnclippedShadows() {
        let button = ShopUIKitGlassButton()
        let tabs = ShopUIKitGlassSurfaceView(interactive: true, hasFloatingShadow: true)
        button.frame = CGRect(x: 0, y: 0, width: 56, height: 56)
        tabs.frame = CGRect(x: 0, y: 0, width: 208, height: 56)
        button.layoutIfNeeded()
        tabs.layoutIfNeeded()

        #expect(button.layer.shadowColor == tabs.layer.shadowColor)
        #expect(button.layer.shadowOpacity == tabs.layer.shadowOpacity)
        #expect(button.layer.shadowRadius == tabs.layer.shadowRadius)
        #expect(button.layer.shadowOffset == tabs.layer.shadowOffset)
        #expect(button.layer.shadowPath?.boundingBoxOfPath == button.bounds)
        #expect(tabs.layer.shadowPath?.boundingBoxOfPath == tabs.bounds)
        #expect(!button.clipsToBounds)
        #expect(!tabs.clipsToBounds)
        #expect(tabs.subviews.compactMap { $0 as? UIVisualEffectView }.first?.clipsToBounds == true)
    }

    @Test
    func navigationOwnsOneInputControllerAcrossConversationTransitions() throws {
        let navigation = ShopBottomNavigationViewController()
        navigation.loadViewIfNeeded()
        navigation.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let conversation = ShopBottomNavigationConversation()
        let source = ShopBottomNavigationComposerSourceView()
        source.composer = ShopAgentUIKitComposer(
            query: .constant(""),
            isComposing: .constant(false),
            context: nil,
            imageAttachments: [],
            canSubmit: false,
            isStreaming: false,
            showsBackButton: true,
            restingBottomInset: 0,
            bottomSpacing: 0,
            preservesNavigationBackTapRegion: false,
            onOpen: {}, onDismiss: {}, onBack: {}, onClose: {},
            onAddContext: { _ in }, onRemoveImageAttachment: { _ in },
            onSubmit: {}, onStop: {}
        )
        source.navigation = conversation
        conversation.composerSource = source
        navigation.update(conversation: conversation, bottomInset: 34)
        let inputController = try #require(navigation.composerController)

        for isPresented in [true, false, true, false] {
            conversation.isPresented = isPresented
            navigation.update(conversation: conversation, bottomInset: 34)
            navigation.view.layoutIfNeeded()
            #expect(navigation.children.compactMap { $0 as? ShopAgentUIKitComposerViewController }.count == 1)
            #expect(navigation.composerController === inputController)
            #expect(inputController.parent === navigation)
            #expect(inputController.view.isHidden == !isPresented)
            #expect(findView("agent-modal-back-button", in: inputController.view) == nil)
            #expect(findView("agent-close-button", in: inputController.view) == nil)
        }

        source.disconnect()
        #expect(navigation.children.compactMap { $0 as? ShopAgentUIKitComposerViewController }.count == 1)
        #expect(navigation.composerController === inputController)
        #expect(inputController.view.isHidden)
        #expect(conversation.composerSource == nil)
        navigation.disconnect()
        #expect(navigation.children.compactMap { $0 as? ShopAgentUIKitComposerViewController }.isEmpty)
        #expect(navigation.composerController == nil)
        #expect(conversation.controller == nil)
    }

    @Test
    func productDockSwapBeginsBeforeItsComposerSourceMounts() throws {
        let owner = ShopBottomNavigationViewController()
        owner.loadViewIfNeeded()
        owner.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        defer { owner.disconnect() }

        let landing = ShopBottomNavigationConversation(opensAskPage: true)
        update(
            owner.chrome,
            coordinator: ShopAddToCartAnimationCoordinator(),
            hidesTabs: false,
            swapsComposer: true
        )
        let source = ShopBottomNavigationComposerSourceView()
        source.composer = ShopAgentUIKitComposer(
            query: .constant(""), isComposing: .constant(false), context: nil,
            imageAttachments: [], canSubmit: false, isStreaming: false,
            showsBackButton: false, restingBottomInset: 0, bottomSpacing: 0,
            preservesNavigationBackTapRegion: false,
            onOpen: {}, onDismiss: {}, onBack: {}, onClose: {},
            onAddContext: { _ in }, onRemoveImageAttachment: { _ in },
            onSubmit: {}, onStop: {}
        )
        landing.composerSource = source
        owner.update(conversation: landing, bottomInset: 34, usesChatTabSwap: true)
        let composerController = try #require(owner.composerController)

        // The PDP preference is published before product loading creates its
        // product-bound source. The same surface should already occupy the dock.
        let product = ShopBottomNavigationConversation(prefersDockedComposer: true)
        owner.update(conversation: product, bottomInset: 34, usesChatTabSwap: true)
        owner.view.layoutIfNeeded()

        #expect(owner.composerController === composerController)
        #expect(!composerController.view.isHidden)
        let toggle = try #require(findView("navigation-composer-toggle", in: owner.chrome) as? UIButton)
        #expect(toggle.accessibilityLabel?.hasPrefix("Show tabs") == true)
    }

    @Test
    func tabModeKeepsCollapsedComposerVisibleWhileItsSourceRehosts() throws {
        let owner = ShopBottomNavigationViewController()
        owner.loadViewIfNeeded()
        owner.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        defer { owner.disconnect() }

        let navigation = ShopBottomNavigationConversation(opensAskPage: true)
        let source = ShopBottomNavigationComposerSourceView()
        source.composer = ShopAgentUIKitComposer(
            query: .constant(""), isComposing: .constant(false), context: nil,
            imageAttachments: [], canSubmit: false, isStreaming: false,
            showsBackButton: false, restingBottomInset: 0, bottomSpacing: 0,
            preservesNavigationBackTapRegion: false,
            onOpen: {}, onDismiss: {}, onBack: {}, onClose: {},
            onAddContext: { _ in }, onRemoveImageAttachment: { _ in },
            onSubmit: {}, onStop: {}
        )
        source.navigation = navigation
        navigation.composerSource = source
        owner.update(conversation: navigation, bottomInset: 34, usesChatTabSwap: true)
        owner.view.layoutIfNeeded()
        let composerController = try #require(owner.composerController)
        #expect(!composerController.view.isHidden)

        // Loading can replace the nonvisual SwiftUI source. The navigation owns
        // the actual surface, so the compact chat affordance must remain visible.
        source.disconnect()
        owner.view.layoutIfNeeded()

        #expect(owner.composerController === composerController)
        #expect(!composerController.view.isHidden)
        let surface = try #require(findView("agent-composer-surface", in: composerController.view))
        let prompt = try #require(owner.chrome.compactComposerPrompt)
        #expect(surface.alpha > 0.99)
        #expect(abs(surface.bounds.width - expectedCompactComposerWidth(for: prompt)) < 0.5)
        #expect(abs(surface.bounds.height - ShopTabBarMetrics.contentHeight) < 0.5)
    }

    @Test
    func conversationKeepsTheSameNavigationButtonsAndFrames() throws {
        let chrome = ShopUIKitTabBarChromeView(frame: CGRect(x: 0, y: 0, width: 393, height: 112))
        let coordinator = ShopAddToCartAnimationCoordinator()
        update(chrome, coordinator: coordinator, hidesTabs: false)
        let back = try #require(findView("floating-back-button", in: chrome))
        let cart = try #require(findView("rolling-cart-button", in: chrome))
        let backFrame = back.convert(back.bounds, to: chrome)
        let cartFrame = cart.convert(cart.bounds, to: chrome)
        #expect(abs(backFrame.minX - 24) < 0.5)
        #expect(abs(chrome.bounds.maxX - cartFrame.maxX - 24) < 0.5)
        let row = try #require(back.superview?.superview as? UIStackView)
        #expect(row.spacing == 12)
        let tabSlot = row.arrangedSubviews[1]
        let tabFrame = tabSlot.convert(tabSlot.bounds, to: chrome)
        #expect(abs(tabFrame.midX - chrome.bounds.midX) < 0.5)
        #expect(tabFrame.minX - backFrame.maxX >= 12)
        #expect(cartFrame.minX - tabFrame.maxX >= 12)

        for hidesTabs in [true, false, true, false] {
            update(chrome, coordinator: coordinator, hidesTabs: hidesTabs)
            #expect(findView("floating-back-button", in: chrome) === back)
            #expect(findView("rolling-cart-button", in: chrome) === cart)
            #expect(back.convert(back.bounds, to: chrome) == backFrame)
            #expect(cart.convert(cart.bounds, to: chrome) == cartFrame)
            #expect(!back.isHidden)
            #expect(!cart.isHidden)
        }
    }

    @Test
    func initialCartRevealWaitsThenTransitionsTheComposerAndCartTogether() async throws {
        let chrome = ShopUIKitTabBarChromeView(frame: CGRect(x: 0, y: 0, width: 393, height: 112))
        let host = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = host
        host.view.addSubview(chrome)
        window.isHidden = false
        defer {
            chrome.prepareForRemoval()
            window.isHidden = true
        }

        let coordinator = ShopAddToCartAnimationCoordinator()
        var presentationChanges = 0
        chrome.onCartPresentationChanged = { presentationChanges += 1 }
        update(
            chrome,
            coordinator: coordinator,
            hidesTabs: false,
            swapsComposer: true,
            cartVisible: true,
            animated: true
        )

        let cart = try #require(findView("rolling-cart-button", in: chrome))
        #expect(cart.isHidden)
        #expect(chrome.compactComposerPrompt == .tryAsking)

        try await Task.sleep(for: ShopTabBarMetrics.initialCartRevealDelay + .milliseconds(100))

        #expect(!cart.isHidden)
        #expect(chrome.compactComposerPrompt == nil)
        #expect(presentationChanges == 1)
    }

    @Test(arguments: [CGFloat(393), 440, 600])
    func rodeoAndPistonsReuseTheDockSurfaces(width: CGFloat) throws {
        let owner = ShopBottomNavigationViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 852))
        window.rootViewController = owner
        window.isHidden = false
        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer {
            owner.disconnect()
            window.isHidden = true
            UIView.setAnimationsEnabled(animationsWereEnabled)
        }
        let navigation = ShopBottomNavigationConversation()
        let source = ShopBottomNavigationComposerSourceView()
        source.composer = ShopAgentUIKitComposer(
            query: .constant(""), isComposing: .constant(false), context: nil,
            imageAttachments: [], canSubmit: false, isStreaming: false,
            showsBackButton: false, restingBottomInset: 0, bottomSpacing: 0,
            preservesNavigationBackTapRegion: false,
            onOpen: {}, onDismiss: {}, onBack: {}, onClose: {},
            onAddContext: { _ in }, onRemoveImageAttachment: { _ in },
            onSubmit: {}, onStop: {}
        )
        navigation.composerSource = source
        let coordinator = ShopAddToCartAnimationCoordinator()
        window.layoutIfNeeded()
        var originalSurface: UIView?

        // Toggle both layouts, cart visibility, and dock states without replacing the glass.
        for navigationStyle in [
            ShopBottomNavigationStyle.rodeo,
            .pistons,
            .rodeo,
            .pistons,
        ] {
            for (expanded, cartVisible) in [
                (false, true), (false, false), (false, true),
                (true, true), (true, false), (true, true), (true, false), (false, false), (false, true),
            ] {
                navigation.showNavigationMode(expanded ? .composer : .tabs)
                update(owner.chrome, coordinator: coordinator, hidesTabs: expanded,
                       swapsComposer: true, navigationStyle: navigationStyle, cartVisible: cartVisible)
                owner.update(
                    conversation: navigation,
                    bottomInset: 34,
                    usesChatTabSwap: true,
                    navigationStyle: navigationStyle
                )
                window.layoutIfNeeded()
                let controller = try #require(owner.composerController)
                #expect(owner.view.subviews.last === owner.chrome)
                let surface = try #require(findView("agent-composer-surface", in: controller.view))
                if let originalSurface { #expect(surface === originalSurface) }
                originalSurface = surface
                let tabs = try #require(findView("navigation-tab-surface", in: owner.chrome))
                let cart = try #require(findView("rolling-cart-button", in: owner.chrome))
                let cartSlot = try #require(cart.superview)
                let tabFrame = tabs.convert(tabs.bounds, to: owner.view)
                let cartFrame = cartSlot.convert(cartSlot.bounds, to: owner.view)
                let composerFrame = surface.convert(surface.bounds, to: owner.view)
                #expect(abs(cartFrame.maxX - (width - 24)) < 0.5)
                #expect(cart.isUserInteractionEnabled == cartVisible)
                if expanded {
                    #expect(abs(tabFrame.minX - 24) < 0.5)
                    #expect(abs(tabFrame.width - 56) < 0.5)
                    #expect(abs(composerFrame.minX - tabFrame.maxX - 12) < 0.5)
                    let expectedTrailingEdge = cartVisible ? cartFrame.minX - 12 : cartFrame.maxX
                    #expect(abs(composerFrame.maxX - expectedTrailingEdge) < 0.5)
                    let trailingPoint = CGPoint(x: composerFrame.maxX - 20, y: composerFrame.midY)
                    let trailingHit = owner.view.hitTest(trailingPoint, with: nil)
                    #expect(trailingHit?.isDescendant(of: surface) == true)
                    let point = CGPoint(x: tabFrame.midX, y: tabFrame.midY)
                    #expect(owner.view.hitTest(point, with: nil)?.accessibilityIdentifier == "navigation-composer-toggle")
                } else {
                    let expectedComposerWidth: CGFloat
                    if cartVisible {
                        expectedComposerWidth = ShopTabBarMetrics.contentHeight
                    } else {
                        let prompt = try #require(owner.chrome.compactComposerPrompt)
                        expectedComposerWidth = expectedCompactComposerWidth(for: prompt)
                    }
                    #expect(abs(composerFrame.width - expectedComposerWidth) < 0.5)
                    if navigationStyle == .pistons {
                        #expect(abs(tabFrame.minX - 24) < 0.5)
                        if cartVisible {
                            #expect(abs(cartFrame.minX - composerFrame.maxX - 12) < 0.5)
                            #expect(composerFrame.minX - tabFrame.maxX >= 11.5)
                        } else {
                            #expect(abs(composerFrame.maxX - cartFrame.maxX) < 0.5)
                        }
                    } else {
                        #expect(abs(tabFrame.midX - width / 2) < 0.5)
                        #expect(abs(composerFrame.minX - 24) < 0.5)
                    }
                    let exposedComposerX = navigationStyle == .pistons
                        ? composerFrame.maxX - 20
                        : composerFrame.minX + 20
                    let point = CGPoint(x: exposedComposerX, y: composerFrame.midY)
                    #expect(owner.view.hitTest(point, with: nil)?.accessibilityIdentifier == "navigation-composer-toggle")
                }
            }
        }
    }

    @Test
    func `fallback chat fills the empty cart slot and remains tappable`() throws {
        let chrome = ShopUIKitTabBarChromeView(frame: CGRect(x: 0, y: 0, width: 393, height: 112))
        let host = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = host
        host.view.addSubview(chrome)
        window.isHidden = false
        defer { window.isHidden = true }
        let coordinator = ShopAddToCartAnimationCoordinator()
        for cartVisible in [false, true, false] {
            update(chrome, coordinator: coordinator, hidesTabs: false, swapsComposer: true,
                   navigationStyle: .pistons, cartVisible: cartVisible)
            window.layoutIfNeeded()
            let chat = try #require(findView("floating-back-button", in: chrome))
            let frame = chat.convert(chat.bounds, to: chrome)
            let trailingInset = cartVisible ? CGFloat(24 + 56 + 12) : 24
            #expect(abs(frame.maxX - (chrome.bounds.maxX - trailingInset)) < 0.5,
                    "Cart visible: \(cartVisible), chat frame: \(frame), chrome bounds: \(chrome.bounds)")
            let hit = chrome.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
            #expect(hit === chat || hit?.isDescendant(of: chat) == true)
        }
    }

    @Test
    func onlyRodeoUsesTheDockDepthDip() {
        #expect(ShopBottomNavigationStyle.rodeo.usesDepthDip)
        #expect(!ShopBottomNavigationStyle.pistons.usesDepthDip)
    }

    private func update(_ chrome: ShopUIKitTabBarChromeView, coordinator: ShopAddToCartAnimationCoordinator,
                        hidesTabs: Bool, swapsComposer: Bool = false,
                        navigationStyle: ShopBottomNavigationStyle = .rodeo, cartVisible: Bool = true,
                        animated: Bool = false) {
        chrome.update(
            selectedTab: .home,
            tabs: ShopRootTab.visibleTabs(isNativeAgentEnabled: true),
            isNativeAgentEnabled: true,
            showsBackButton: true,
            cartTotalItemCount: 3,
            cartButtonVisible: cartVisible,
            cartButtonMode: .activeCart,
            coordinator: coordinator,
            cartAnimations: [],
            cartButtonBounceTrigger: 0,
            bottomInset: 34,
            backdropColor: UIColor(GravityColor.bgFill),
            hidesTabSection: hidesTabs,
            animated: animated,
            swapsComposer: swapsComposer,
            navigationStyle: navigationStyle
        )
        chrome.layoutIfNeeded()
    }

    private func findView(_ identifier: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == identifier { return view }
        return view.subviews.lazy.compactMap { findView(identifier, in: $0) }.first
    }

    private func expectedCompactComposerWidth(for prompt: ShopCompactComposerPrompt) -> CGFloat {
        let textWidth = ceil((prompt.title as NSString).size(withAttributes: [
            .font: GravityTextStyle.buttonLarge.scaledUIFont,
        ]).width)
        return max(
            ShopTabBarMetrics.contentHeight,
            24 + GravitySpacing.space6 + textWidth + GravitySpacing.space16 * 2
        )
    }
}
