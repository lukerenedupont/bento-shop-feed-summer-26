import Foundation
import SwiftUI

@MainActor
@Observable
final class ShopAddToCartAnimationCoordinator {
    private(set) var isCartButtonOptimisticallyVisible = false
    /// Mini controls follow RN's image-animation lifecycle, not persistent shell cart contents.
    /// This becomes true only while a valid-image Mini animation is active.
    private(set) var isMiniCartControlVisible = false
    private(set) var activeAnimations: [ShopAddToCartAnimation] = []
    private(set) var cartButtonBounceTrigger = 0
    private(set) var animationsCompleteTrigger = 0

    private var nextAnimationID = 0
    private var nextBatchID = 0
    private var optimisticVisibilityClearTask: Task<Void, Never>?
    private(set) var animationsEnabled = true
    @ObservationIgnored private var cartTargetReadiness: [ShopAddToCartAnimationSource: [UUID: Bool]] = [:]
    @ObservationIgnored private let legacyCartTargetID = UUID()
    @ObservationIgnored private var pendingAnimations: [ShopPendingAddToCartAnimation] = []
    @ObservationIgnored private var ordinaryAddToCartSource: ShopAddToCartAnimationSource = .standard
    @ObservationIgnored private var loadedAnimationIDs: Set<Int> = []
    private let compactRotationProvider: () -> Double

    /// - Parameter compactRotationProvider: supplies the stable per-image start rotation for the
    ///   `.compact` (synced-cart) variant. RN randomizes rotation in `±MAX_ROTATION_DEG (20°)`;
    ///   tests inject a deterministic provider.
    init(compactRotationProvider: @escaping () -> Double = { Double.random(in: -20 ... 20) }) {
        self.compactRotationProvider = compactRotationProvider
    }

    func setAnimationsEnabled(_ enabled: Bool) {
        animationsEnabled = enabled
        if enabled == false {
            cancelAnimationsForPresentationChange()
        } else {
            flushPendingAnimationsIfPossible()
        }
    }

    /// A Mini may close before its cart target lays out, or while an image is in flight. Do not
    /// replay that Mini-specific work into tab chrome after the presentation has ended.
    ///
    /// A generic unavailable surface keeps the optimistic cart control visible until normal cart
    /// state resolves. A Mini closure opts into clearing it because the root tab chrome resumes.
    func cancelAnimationsForPresentationChange(shouldClearOptimisticVisibility: Bool = false) {
        let hadQueuedAnimations = activeAnimations.isEmpty == false || pendingAnimations.isEmpty == false
        activeAnimations.removeAll()
        pendingAnimations.removeAll()
        loadedAnimationIDs.removeAll()
        refreshMiniCartControlVisibility()
        if hadQueuedAnimations {
            animationsCompleteTrigger += 1
        }
        if shouldClearOptimisticVisibility {
            clearOptimisticVisibility()
        }
    }

    /// Removes only Mini-owned image work when the Mini control opens cart. This prevents an
    /// in-flight image from replaying over the lifted foreground while the commerce task continues.
    func cancelMiniCartVisuals() {
        let removedAnimationIDs = Set(
            activeAnimations
                .filter { $0.source == .mini }
                .map(\.id)
        )
        let hadMiniVisualWork = removedAnimationIDs.isEmpty == false ||
            pendingAnimations.contains { $0.source == .mini }

        activeAnimations.removeAll { $0.source == .mini }
        pendingAnimations.removeAll { $0.source == .mini }
        loadedAnimationIDs.subtract(removedAnimationIDs)
        refreshMiniCartControlVisibility()

        if hadMiniVisualWork {
            animationsCompleteTrigger += 1
        }
    }

    /// Mini exit or replacement must not leak Mini feedback into restored tab chrome. This keeps
    /// the previous root-chrome optimistic cleanup while limiting visual-work removal to Mini work.
    func cancelMiniCartPresentation() {
        cancelMiniCartVisuals()
        clearOptimisticVisibility()
    }

    /// Native equivalent of RN `cartButtonLayout`: image animations are queued until a visible
    /// cart target has mounted and laid out, so they never start before they have a landing point.
    ///
    /// Multiple hosts can exist during the tab-chrome to Mini-cart transition. Each host owns a
    /// stable ID and source so only work rendered by that host can use its ready target.
    func updateCartTarget(
        id: UUID,
        source: ShopAddToCartAnimationSource,
        isReady: Bool
    ) {
        cartTargetReadiness[source, default: [:]][id] = isReady
        flushPendingAnimationsIfPossible()
    }

    func removeCartTarget(id: UUID, source: ShopAddToCartAnimationSource) {
        cartTargetReadiness[source]?.removeValue(forKey: id)
        if cartTargetReadiness[source]?.isEmpty == true {
            cartTargetReadiness.removeValue(forKey: source)
        }
    }

    /// Compatibility seam for existing focused coordinator tests. Production cart hosts must use
    /// stable target IDs and explicit sources through `updateCartTarget` and `removeCartTarget`.
    func setCartTargetReady(
        _ ready: Bool,
        source: ShopAddToCartAnimationSource = .standard
    ) {
        updateCartTarget(id: legacyCartTargetID, source: source, isReady: ready)
    }

    /// Native surfaces presented above a Mini still use the ordinary add API, but their feedback
    /// belongs to the cart host that owns the visible presentation.
    func setCartPresentationOwner(_ owner: ShopCartPresentationOwner) {
        ordinaryAddToCartSource = owner.animationSource
    }

    func beginAddToCart(
        variantImageURL: String?,
        disableAnimation: Bool = false,
        animationVariant: ShopAddToCartAnimationVariant = .default
    ) {
        beginAddToCart(
            variantImageURL: variantImageURL,
            disableAnimation: disableAnimation,
            animationVariant: animationVariant,
            source: ordinaryAddToCartSource
        )
    }

    /// Starts a Mini-specific animation. Unlike normal tab chrome optimism, Mini visibility is
    /// granted only after the image is known to be valid and animation is enabled.
    func beginMiniAddToCart(
        variantImageURL: String?,
        disableAnimation: Bool = false
    ) {
        beginAddToCart(
            variantImageURL: variantImageURL,
            disableAnimation: disableAnimation,
            animationVariant: .default,
            source: .mini
        )
    }

    private func beginAddToCart(
        variantImageURL: String?,
        disableAnimation: Bool,
        animationVariant: ShopAddToCartAnimationVariant,
        source: ShopAddToCartAnimationSource
    ) {
        optimisticVisibilityClearTask?.cancel()
        isCartButtonOptimisticallyVisible = true

        guard animationsEnabled,
              disableAnimation == false,
              let variantImageURL = requestableImageURLString(variantImageURL) else {
            scheduleOptimisticVisibilityClear()
            return
        }

        enqueueAnimation(
            ShopPendingAddToCartAnimation(
                imageURL: variantImageURL,
                variant: animationVariant,
                source: source,
                batchID: nil
            )
        )
    }

    /// Queues a single visual batch whose members all wait for image load before the existing
    /// RN-style stagger begins (0ms, 400ms, 800ms...). Used by synced-cart compact animations so a
    /// slower first image does not visually overlap later images that loaded earlier.
    @discardableResult
    func beginAddToCartBatch(
        variantImageURLs: [String],
        disableAnimation: Bool = false,
        animationVariant: ShopAddToCartAnimationVariant = .compact
    ) -> Bool {
        optimisticVisibilityClearTask?.cancel()
        isCartButtonOptimisticallyVisible = true

        guard animationsEnabled, disableAnimation == false else {
            scheduleOptimisticVisibilityClear()
            return false
        }

        let imageURLs = variantImageURLs.compactMap(requestableImageURLString)
        guard imageURLs.isEmpty == false else {
            scheduleOptimisticVisibilityClear()
            return false
        }

        let batchID = nextBatchID
        nextBatchID += 1
        for imageURL in imageURLs {
            enqueueAnimation(
                ShopPendingAddToCartAnimation(
                    imageURL: imageURL,
                    variant: animationVariant,
                    source: .standard,
                    batchID: batchID
                )
            )
        }
        return true
    }

    func completeAddToCart(succeeded: Bool) {
        guard succeeded == false else { return }

        if activeAnimations.isEmpty {
            pendingAnimations.removeAll()
            loadedAnimationIDs.removeAll()
            refreshMiniCartControlVisibility()
            clearOptimisticVisibility()
        } else {
            scheduleOptimisticVisibilityClear()
        }
    }

    func cartContentDidBecomeVisible() {
        clearOptimisticVisibility()
    }

    func animationReachedCart(id: Int) {
        // RN only passes the cart-bounce callback to the last active image in
        // `AddToCartAnimation`, while `cart_animations_complete` still waits for all images to
        // drain. Keep that visual behavior here while letting views report every image reaching the
        // target.
        guard activeAnimations.last?.id == id else { return }
        cartButtonBounceTrigger += 1
    }

    func animationDidComplete(id: Int) {
        let previousCount = activeAnimations.count
        activeAnimations.removeAll { $0.id == id }
        loadedAnimationIDs.remove(id)
        refreshMiniCartControlVisibility()

        if previousCount > 0, activeAnimations.isEmpty {
            animationsCompleteTrigger += 1
            scheduleOptimisticVisibilityClear()
        }
    }

    func clearOptimisticVisibility() {
        optimisticVisibilityClearTask?.cancel()
        optimisticVisibilityClearTask = nil
        isCartButtonOptimisticallyVisible = false
    }

    func animationImageLoadEnded(id: Int) {
        guard let animation = activeAnimations.first(where: { $0.id == id }) else {
            return
        }

        loadedAnimationIDs.insert(id)

        guard let batchID = animation.batchID else {
            markAnimationsReady(ids: [id])
            return
        }

        let batchAnimationIDs = activeAnimations
            .filter { $0.batchID == batchID }
            .map(\.id)
        guard batchAnimationIDs.isEmpty == false,
              batchAnimationIDs.allSatisfy({ loadedAnimationIDs.contains($0) }) else {
            return
        }
        markAnimationsReady(ids: batchAnimationIDs)
    }

    private func requestableImageURLString(_ rawValue: String?) -> String? {
        guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isEmpty == false,
              let url = URL(string: value),
              url.scheme?.isEmpty == false,
              url.host?.isEmpty == false else {
            return nil
        }
        return value
    }

    private func hasReadyCartTarget(for source: ShopAddToCartAnimationSource) -> Bool {
        cartTargetReadiness[source]?.values.contains(true) == true
    }

    private func enqueueAnimation(_ pendingAnimation: ShopPendingAddToCartAnimation) {
        if hasReadyCartTarget(for: pendingAnimation.source) {
            appendAnimation(pendingAnimation)
        } else {
            pendingAnimations.append(pendingAnimation)
        }
        refreshMiniCartControlVisibility()
    }

    private func flushPendingAnimationsIfPossible() {
        guard animationsEnabled, pendingAnimations.isEmpty == false else {
            return
        }

        let animationsToAppend = pendingAnimations.filter { hasReadyCartTarget(for: $0.source) }
        guard animationsToAppend.isEmpty == false else { return }

        pendingAnimations.removeAll { hasReadyCartTarget(for: $0.source) }
        for animation in animationsToAppend {
            appendAnimation(animation)
        }
        refreshMiniCartControlVisibility()
    }

    private func appendAnimation(_ pendingAnimation: ShopPendingAddToCartAnimation) {
        let animation = ShopAddToCartAnimation(
            id: nextAnimationID,
            imageURL: pendingAnimation.imageURL,
            variant: pendingAnimation.variant,
            source: pendingAnimation.source,
            staggerIndex: activeAnimations.count,
            rotationDegrees: pendingAnimation.variant == .compact ? compactRotationProvider() : 0,
            batchID: pendingAnimation.batchID
        )
        nextAnimationID += 1
        activeAnimations.append(animation)
    }

    private func markAnimationsReady(ids: [Int]) {
        var updatedAnimations = activeAnimations
        for id in ids {
            guard let index = updatedAnimations.firstIndex(where: { $0.id == id }) else {
                continue
            }
            updatedAnimations[index].isReadyToStart = true
        }
        activeAnimations = updatedAnimations
    }

    private func refreshMiniCartControlVisibility() {
        isMiniCartControlVisible = activeAnimations.contains { $0.source == .mini }
    }

    private func scheduleOptimisticVisibilityClear() {
        optimisticVisibilityClearTask?.cancel()
        optimisticVisibilityClearTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard Task.isCancelled == false else { return }
            isCartButtonOptimisticallyVisible = false
        }
    }
}

enum ShopAddToCartAnimationVariant: Equatable, Sendable {
    case `default`
    case compact
}

enum ShopAddToCartAnimationSource: Hashable, Sendable {
    case standard
    case mini
}

private struct ShopPendingAddToCartAnimation: Equatable, Sendable {
    let imageURL: String
    let variant: ShopAddToCartAnimationVariant
    let source: ShopAddToCartAnimationSource
    let batchID: Int?
}

struct ShopAddToCartAnimation: Identifiable, Equatable, Sendable {
    let id: Int
    let imageURL: String
    let variant: ShopAddToCartAnimationVariant
    let source: ShopAddToCartAnimationSource
    let staggerIndex: Int
    /// Stable start rotation (degrees) held for the animation lifecycle. `0` for `.default`;
    /// the `.compact` synced-cart variant uses a value in `±MAX_ROTATION_DEG (20°)`.
    var rotationDegrees: Double
    let batchID: Int?
    var isReadyToStart: Bool

    init(
        id: Int,
        imageURL: String,
        variant: ShopAddToCartAnimationVariant,
        source: ShopAddToCartAnimationSource = .standard,
        staggerIndex: Int,
        rotationDegrees: Double = 0,
        batchID: Int? = nil,
        isReadyToStart: Bool = false
    ) {
        self.id = id
        self.imageURL = imageURL
        self.variant = variant
        self.source = source
        self.staggerIndex = staggerIndex
        self.rotationDegrees = rotationDegrees
        self.batchID = batchID
        self.isReadyToStart = isReadyToStart
    }
}

private struct ShopAddToCartAnimationCoordinatorKey: EnvironmentKey {
    static let defaultValue: ShopAddToCartAnimationCoordinator? = nil
}

extension EnvironmentValues {
    var shopAddToCartAnimationCoordinator: ShopAddToCartAnimationCoordinator? {
        get { self[ShopAddToCartAnimationCoordinatorKey.self] }
        set { self[ShopAddToCartAnimationCoordinatorKey.self] = newValue }
    }
}

extension View {
    func shopAddToCartAnimationCoordinator(_ coordinator: ShopAddToCartAnimationCoordinator?) -> some View {
        environment(\.shopAddToCartAnimationCoordinator, coordinator)
    }
}
