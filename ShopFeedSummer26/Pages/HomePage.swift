import Combine
import SwiftUI
import UIKit

private struct FeedViewportLayout {
    let compactWidth: CGFloat
    let compactHeight: CGFloat
    let expandedWidth: CGFloat
    let expandedHeight: CGFloat
    let viewportHeight: CGFloat
    let expansionProgress: CGFloat
    let expandedForegroundTopPadding: CGFloat

    var cardWidth: CGFloat {
        compactWidth + ((expandedWidth - compactWidth) * expansionProgress)
    }

    var cardHeight: CGFloat {
        compactHeight + ((expandedHeight - compactHeight) * expansionProgress)
    }

    var foregroundTopPadding: CGFloat {
        GravitySpacing.space20
            + ((expandedForegroundTopPadding - GravitySpacing.space20) * expansionProgress)
    }
}

private struct FeedViewportMetrics {
    let containerSize: CGSize
    let safeAreaTop: CGFloat
    let isForYou: Bool
    let expansionProgress: CGFloat

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
        )
    }

    var layout: FeedViewportLayout {
        FeedViewportLayout(
            compactWidth: compactWidth,
            compactHeight: compactHeight,
            expandedWidth: containerSize.width,
            expandedHeight: fullBleedHeight,
            viewportHeight: containerSize.height,
            expansionProgress: expansionProgress,
            expandedForegroundTopPadding: safeAreaTop
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

/// Home feed — scrollable merchant feed cards with focused topic feeds.
struct HomePage: View {
    private enum FeedEntry: Identifiable {
        case story(FeedStory)
        case post(ShopPost)

        var id: String {
            switch self {
            case let .story(story): story.id
            case let .post(post): "shop-post-\(post.id)"
            }
        }
    }

    private enum ForYouUtilityPresentation {
        case carouselOnly
        case carouselAndFullHeight
    }

    /// Shared with `RootView` so a tapped feed card can zoom into the
    /// original full-screen topic content.
    var namespace: Namespace.ID

#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var merchantService = RemoteMerchantService.shared
    @ObservedObject private var feedService = RemoteFeedService.shared
    @State private var postService = ShopPostService.shared
    @State private var buyerPreview = BuyerPreviewStore.shared
    @Namespace private var heroNamespace
    @Namespace private var topicSelectionNamespace

    /// Buyer-profile-curated products bundled from official merchant catalogs.
    @State private var bundledMerchants: [SampleMerchant] = LocalMerchantService.loadMerchants()

    /// The generated assortment once the dossier-lab feed answers, else the
    /// bundled snapshot. Recomputes when the service publishes, so a feed that
    /// lands after first render swaps in without any manual refresh.
    private var merchants: [SampleMerchant] {
        LocalMerchantService.mergeMerchants([
            feedService.merchants,
            bundledMerchants,
            HypothesisShelfCatalog.merchants,
        ])
    }
    @State private var selectedTopicID = "for-you"
    /// A drilled-in subcategory story rendered inline so the top bar stays.
    @State private var focusedStoryID: String?
    @State private var visibleStoryID: String?
    @State private var expandingStoryID: String?
    @State private var categoryMoveDirection = 1
    @State private var topicRailOffset: CGFloat = 0
    @State private var topicRailContentWidth: CGFloat = 0
    @State private var showsBuyerSwitcher = false
    @GestureState private var topicRailDragOffset: CGFloat = 0

    private let retargetingCardHeight: CGFloat = 188
    private let utilityRailControlSize: CGFloat = 32
    private let utilityStoryID = "for-you-utility-hub"
    /// Keep the full-height exploration available without placing it in the
    /// live feed. Switching this recipe restores the prototype for comparison.
    private let forYouUtilityPresentation: ForYouUtilityPresentation = .carouselOnly

    private var topics: [FeedTopic] { PersonalizedFeedCatalog.current.topics }
    private var navigationTopics: [BuyerFeedTopic] {
        buyerPreview.navigationTopics
    }
    private var selectedTopic: BuyerFeedTopic {
        navigationTopics.first { $0.id == selectedTopicID } ?? navigationTopics[0]
    }
    private var selectedCategory: FeedCategory {
        FeedInformationArchitecture.categories.first {
            $0.id == selectedTopic.sourceCategoryID
        } ?? FeedInformationArchitecture.categories[0]
    }

    private var pageBackgroundColor: Color {
        .white
    }

    /// The feed intentionally ignores the top safe area so its card surface
    /// can draw behind system chrome. In that configuration GeometryProxy can
    /// report zero; the active window remains the authoritative device inset.
    private var windowSafeAreaTopInset: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let keyWindow = windowScene.windows.first(where: \.isKeyWindow) else {
            return 0
        }
        return keyWindow.safeAreaInsets.top
    }

    private var focusedStories: [FeedStory] {
        buyerPreview.stories(
            for: selectedTopic,
            in: PersonalizedFeedCatalog.current
        )
    }

    /// Luke's verified Shop Posts are interleaved into For You without
    /// replacing any of the authored flick-and-stick cards. Other buyer
    /// profiles remain byte-for-byte on their existing feeds for now.
    private var feedEntries: [FeedEntry] {
        guard buyerPreview.selected.id == "luke", selectedTopicID == "for-you" else {
            return focusedStories.map(FeedEntry.story)
        }

        let posts = Array(postService.lukePosts.prefix(4))
        guard !posts.isEmpty else { return focusedStories.map(FeedEntry.story) }

        var result: [FeedEntry] = []
        var nextPostIndex = 0
        for (index, story) in focusedStories.enumerated() {
            result.append(.story(story))
            if index.isMultiple(of: 2), posts.indices.contains(nextPostIndex) {
                result.append(.post(posts[nextPostIndex]))
                nextPostIndex += 1
            }
        }
        return result
    }

    private var activeFeedStory: FeedStory? {
        if visibleStoryID == utilityStoryID {
            // The first story is already fully visible beneath the utility
            // shelf, so keep its editorial content present at rest.
            return focusedStories.first
        }
        if let visibleStoryID,
           let visibleStory = focusedStories.first(where: { $0.id == visibleStoryID }) {
            return visibleStory
        }
        return focusedStories.first
    }

    /// Keep takeover state discrete. Driving width, height, clipping, header
    /// colors, and media from the raw scroll offset invalidated the entire
    /// feed on every drag frame. Native scrolling now does the movement; this
    /// value changes only when SwiftUI selects a new snap target.
    private var firstStoryExpansionProgress: CGFloat {
        guard let visibleStoryID else { return 0 }
        return visibleStoryID == utilityStoryID ? 0 : 1
    }

    private var usesLightUtilityShelf: Bool {
        selectedTopicID == "for-you"
    }

    private var utilityPrimaryColor: Color {
        usesLightUtilityShelf ? .black : .white
    }

    private var utilitySecondaryColor: Color {
        utilityPrimaryColor.opacity(0.62)
    }

    private var utilityControlFill: Color {
        utilityPrimaryColor.opacity(usesLightUtilityShelf ? 0.07 : 0.14)
    }

    private var utilitySurfaceFill: Color {
        usesLightUtilityShelf ? .white : .black.opacity(0.40)
    }

    private var utilitySurfaceBorder: Color {
        utilityPrimaryColor.opacity(usesLightUtilityShelf ? 0.08 : 0.18)
    }

    var body: some View {
        // This concrete container owns the persistent chrome. A transparent
        // `Group` forwards modifiers to its changing child, which caused the
        // safe-area bar to inherit the feed's horizontal replacement motion.
        ZStack {
            if let focusedStoryID {
                StoryTopicPage(
                    storyID: focusedStoryID,
                    namespace: namespace,
                    contextTopicID: selectedTopicID,
                    closeOnlyNavigation: buyerPreview.selected.id == "luke"
                )
                    .id(focusedStoryID)
            } else {
                storyFeed
                    // The selected tab often remains "for-you" while the
                    // buyer changes. Include profile identity so SwiftUI does
                    // not preserve the previous shopper's lazy-stack cells or
                    // scroll position under the new persistent header.
                    .id("\(buyerPreview.selected.id)-\(selectedTopicID)")
                    .transition(categoryFeedTransition)
            }
        }
        .background {
            ZStack {
                pageBackgroundColor
                if focusedStoryID == nil {
                    feedAmbientBackdrop
                }
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            if buyerPreview.selected.id != "luke" || focusedStoryID == nil {
                topBar
            }
        }
        .overlay {
            if showsBuyerSwitcher {
                Color.black.opacity(0.10)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        // Luke's resting For You surface is white; restore light system chrome
        // until the first card has substantially taken over the viewport.
        .environment(
            \.colorScheme,
            usesLightUtilityShelf && firstStoryExpansionProgress < 0.999
                ? .light
                : .dark
        )
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            // Keep the curated assortment authoritative for this prototype and
            // expose it to PDP/store lookups through SampleMerchant.all.
            merchantService.merchants = merchants
            merchantService.usingFallbackData = !feedService.isLive
            coordinator.navBarBlurTint = pageBackgroundColor
#if DEBUG
            let buyerFixtureIssues = BuyerPreviewStore.validationIssues(
                in: PersonalizedFeedCatalog.current,
                merchants: merchants
            )
            assert(
                buyerFixtureIssues.isEmpty,
                "Invalid buyer feed fixtures:\n\(buyerFixtureIssues.joined(separator: "\n"))"
            )
#endif
        }
        .onChange(of: feedService.revision) { _, _ in
            // The feed usually lands after first render; re-publish so PDP and
            // store lookups going through SampleMerchant.all see the same
            // assortment the stories reference.
            merchantService.merchants = merchants
            merchantService.usingFallbackData = !feedService.isLive
        }
        .onChange(of: selectedTopicID) { _, newTopicID in
            if newTopicID != "for-you",
               let topic = navigationTopics.first(where: { $0.id == newTopicID }) {
                visibleStoryID = buyerPreview.stories(
                    for: topic,
                    in: PersonalizedFeedCatalog.current
                ).first?.id
            } else {
                // `nil` leaves SwiftUI free to preserve the outgoing tab's
                // scroll position. Target the resting utility row explicitly
                // so returning to For You always restores the top state.
                visibleStoryID = buyerPreview.selected.showsUtilityShelf
                    ? utilityStoryID
                    : focusedStories.first?.id
            }
            expandingStoryID = nil
            withAnimation(.easeOut(duration: 0.22)) {
                coordinator.navBarBlurTint = pageBackgroundColor
            }
            syncTopicBackAction()
        }
        .onChange(of: focusedStoryID) { _, _ in
            syncTopicBackAction()
        }
        .onAppear {
            expandingStoryID = nil
            syncTopicBackAction()
            coordinator.inlineStoryHandler = { storyID in
                coordinator.resetScrollState()
                HapticFeedback.light.fire()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    focusedStoryID = storyID
                }
                return true
            }
        }
        .purlInjectable()
    }

    private var storyFeed: some View {
        GeometryReader { geo in
            let isForYou = selectedTopicID == "for-you"
            let firstStoryID = focusedStories.first?.id
            let metrics = FeedViewportMetrics(
                containerSize: geo.size,
                safeAreaTop: max(geo.safeAreaInsets.top, windowSafeAreaTopInset),
                isForYou: isForYou,
                expansionProgress: firstStoryExpansionProgress
            )
            let layout = metrics.layout

            ZStack {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: FeedCardStyle.cardSpacing) {
                        if selectedTopicID == "for-you", buyerPreview.selected.showsUtilityShelf {
                            VStack(spacing: 0) {
                                Color.clear
                                    .frame(height: metrics.utilityLaunchInset)
                                    .accessibilityHidden(true)

                                feedUtilityShelf(containerWidth: geo.size.width)
                            }
                            // The launch clearance belongs to the utility
                            // target alone. Feed cards remain true top-aligned
                            // snap targets instead of inheriting this inset.
                            .opacity(metrics.expansionProgress < 0.5 ? 1 : 0)
                            .allowsHitTesting(metrics.expansionProgress < 0.5)
                            .id(utilityStoryID)
                            if forYouUtilityPresentation == .carouselAndFullHeight {
                                fullHeightUtilityCard(
                                    width: metrics.compactWidth,
                                    height: metrics.compactHeight
                                )
                                    .id(utilityStoryID)
                            }
                        }

                        ForEach(feedEntries) { entry in
                            feedEntryCard(
                                entry,
                                layout: layout,
                                firstEntryID: firstStoryID
                            )
                            .frame(
                                width: layout.expandedWidth,
                                height: metrics.fullBleedHeight,
                                alignment: .top
                            )
                            .animation(
                                reduceMotion ? nil : .easeOut(duration: 0.18),
                                value: layout.expansionProgress
                            )
                            .id(entry.id)
                        }
                    }
                    .scrollTargetLayout()
                    // The header floats above the feed instead of reserving a
                    // safe-area bar. Initial utility content still clears it,
                    // while a snapped viewport card can extend behind it.
                    .padding(.bottom, metrics.bottomContentPadding)
                }
                // The NavigationStack proposes a viewport below the status
                // bar even though this feed draws under system chrome. Shift
                // the viewport to the physical top. Keep only the system inset
                // as a content margin so snap targets align with the physical
                // top instead of leaving the outgoing card behind the header.
                // The extra launch padding above keeps the utility shelf in
                // its original resting position below navigation.
                .contentMargins(
                    .top,
                    metrics.safeAreaTop,
                    for: .scrollContent
                )
                .frame(height: metrics.extendedViewportHeight)
                .offset(y: -metrics.safeAreaTop)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(id: $visibleStoryID, anchor: .top)
                .onScrollGeometryChange(for: CGFloat.self) {
                    max(0, $0.contentOffset.y + $0.contentInsets.top)
                } action: { _, offset in
                    coordinator.updateScrollOffset(offset)
                }
            }
            .onChange(of: feedEntries.map(\.id)) { _, entryIDs in
                // Keep both the utility/resting target and live feed entries
                // stable as remote content arrives or the assortment changes.
                guard let visibleStoryID else { return }
                guard visibleStoryID == utilityStoryID
                    || entryIDs.contains(visibleStoryID) else {
                    self.visibleStoryID = nil
                    return
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private var categoryFeedTransition: AnyTransition {
        let incoming: Edge = categoryMoveDirection > 0 ? .trailing : .leading
        let outgoing: Edge = categoryMoveDirection > 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: incoming),
            removal: .move(edge: outgoing)
        )
    }

    private var defaultUtilityProducts: [ResolvedStoryProduct] {
        var seen = Set<String>()
        return focusedStories
            .flatMap { $0.resolvedProducts(from: merchants) }
            .filter { seen.insert($0.id).inserted }
    }

    private func utilityProducts(for storyID: String?) -> [ResolvedStoryProduct] {
        guard let storyID, !storyID.isEmpty,
              let story = PersonalizedFeedCatalog.current.stories.first(where: { $0.id == storyID }) else {
            return defaultUtilityProducts
        }
        return story.resolvedProducts(from: merchants)
    }

    private func feedUtilityShelf(containerWidth: CGFloat) -> some View {
        retargetingRailCarousel(containerWidth: containerWidth)
        .padding(.top, 18)
        .frame(width: containerWidth)
    }

    private func retargetingRailCarousel(containerWidth: CGFloat) -> some View {
        let railWidth = min(max(containerWidth - 64, 300), 360)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if let storyID = buyerPreview.selected.utility.buyAgainStoryID {
                    let products = utilityProducts(for: storyID).filter {
                        $0.product.tags.contains("buyer-buy-again")
                    }
                    utilityProductRail(
                        title: "Buy again",
                        products: Array(products.prefix(3)),
                        width: railWidth
                    )
                }

                if buyerPreview.selected.utility.showsCart, let cartItem = cartSyncItem {
                    cartSyncCard(item: cartItem, width: railWidth)
                }

                if buyerPreview.selected.utility.showsOrders {
                    orderTrackingRailCard(width: railWidth)
                }

                if let storyID = buyerPreview.selected.utility.recentlyViewedStoryID {
                    let products = utilityProducts(for: storyID).filter {
                        $0.product.tags.contains("buyer-saved")
                    }
                    utilityProductRail(
                        title: "Your saves",
                        products: Array(products.prefix(3)),
                        width: railWidth
                    )
                }

                if let storyID = buyerPreview.selected.utility.ownedAdjacencyStoryID {
                    let products = utilityProducts(for: storyID).filter {
                        $0.product.tags.contains("buyer-open-loop")
                    }
                    utilityProductRail(
                        title: "Pick up where you left off",
                        products: Array(products.prefix(3)),
                        width: railWidth
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
    }

    private var cartSyncItem: ResolvedStoryProduct? {
        defaultUtilityProducts
            .filter { numericPrice($0.product.price) > 0 }
            .min { lhs, rhs in
            numericPrice(lhs.product.price) < numericPrice(rhs.product.price)
        }
    }

    private func numericPrice(_ price: String) -> Double {
        Double(price.filter { $0.isNumber || $0 == "." }) ?? .greatestFiniteMagnitude
    }

    private func cartSyncCard(item: ResolvedStoryProduct, width: CGFloat) -> some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.navigateToPage(4)
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Text(item.merchant.displayName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(utilityPrimaryColor)
                        .frame(width: 38, height: 38)
                        .background(utilityControlFill, in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.merchant.displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(utilityPrimaryColor)
                            .lineLimit(1)
                        Text("Subtotal \(formatPrice(item.product.price))")
                            .font(.system(size: 14))
                            .foregroundStyle(utilitySecondaryColor)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    ProductImageView(product: item.product, merchant: item.merchant)
                        .frame(width: 60, height: 60)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            Text("1")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(utilityPrimaryColor)
                                .frame(width: 18, height: 18)
                                .background(utilityControlFill, in: Circle())
                                .offset(x: -6, y: -6)
                        }
                }

                Spacer(minLength: 10)

                Text("Continue to checkout")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(utilityPrimaryColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(utilityControlFill, in: Capsule())
            }
            .padding(16)
            .frame(width: width, height: retargetingCardHeight)
            .retargetingSurface(
                fill: utilitySurfaceFill,
                border: utilitySurfaceBorder
            )
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var deliveryMerchants: [SampleMerchant] {
        var seen = Set<String>()
        return defaultUtilityProducts
            .map(\.merchant)
            .filter { seen.insert($0.id).inserted && !$0.products.isEmpty }
    }

    @ViewBuilder
    private func orderTrackingRailCard(width: CGFloat) -> some View {
        if let merchant = deliveryMerchants.first {
            let deliveryProducts = Array(merchant.products.prefix(2))
            Button {
                HapticFeedback.light.fire()
                coordinator.navigateToPage(1)
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Your orders")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(utilityPrimaryColor)
                            .tracking(-0.6)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(utilityPrimaryColor)
                            .frame(width: utilityRailControlSize, height: utilityRailControlSize)
                            .background(utilityControlFill, in: Circle())
                    }

                    HStack(spacing: 10) {
                        MerchantLogoImage(merchant: merchant, size: 48)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(merchant.displayName)
                                .font(.system(size: 14))
                                .foregroundStyle(utilitySecondaryColor)
                            Text("Arriving today 3–6pm")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(utilityPrimaryColor)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                        Spacer(minLength: 2)

                        HStack(spacing: 6) {
                            ForEach(deliveryProducts) { product in
                                ProductImageView(product: product, merchant: merchant)
                                    .frame(width: 48, height: 48)
                                    .background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
                .padding(16)
                .frame(width: width, height: retargetingCardHeight, alignment: .top)
                .retargetingSurface(
                    fill: utilitySurfaceFill,
                    border: utilitySurfaceBorder
                )
            }
            .buttonStyle(PressScaleButtonStyle())
        }
    }

    /// A second prototype of the same utility information at feed-card scale.
    /// It deliberately reuses the order, cart, and product primitives from the
    /// compact rail so the two treatments can be compared without data drift.
    private func fullHeightUtilityCard(width: CGFloat, height: CGFloat) -> some View {
        let buyAgain = Array(defaultUtilityProducts.dropFirst(3).prefix(3))
        let recentlyViewed = Array(defaultUtilityProducts.prefix(4))
        let isActive = visibleStoryID == nil || visibleStoryID == utilityStoryID

        return ZStack {
            LinearGradient(
                colors: [
                    deliveryMerchants.first?.brandColor.opacity(0.24) ?? Color.black.opacity(0.06),
                    Color(hex: 0xF2F1ED),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 14) {
                Text("Your Shop right now")
                    .feedCardTitleStyle()
                    .foregroundStyle(.black)
                    .lineLimit(2)

                if let merchant = deliveryMerchants.first {
                    fullHeightOrderSummary(merchant: merchant)
                }

                if let cartItem = cartSyncItem {
                    fullHeightCartSummary(item: cartItem)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Buy again")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)

                    HStack(spacing: 8) {
                        ForEach(buyAgain) { item in
                            Button {
                                HapticFeedback.light.fire()
                                coordinator.pushRoute(
                                    .product(merchantId: item.merchant.id, productId: item.product.id)
                                )
                            } label: {
                                ProductCard(
                                    image: nil,
                                    imageURL: item.product.imageURL,
                                    priceBadge: formatPrice(item.product.price),
                                    showFavoriteButton: true
                                )
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recently viewed")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)

                    HStack(spacing: 8) {
                        ForEach(recentlyViewed) { item in
                            Button {
                                HapticFeedback.light.fire()
                                coordinator.pushRoute(
                                    .product(merchantId: item.merchant.id, productId: item.product.id)
                                )
                            } label: {
                                ProductImageView(product: item.product, merchant: item.merchant)
                                    .frame(width: 58, height: 58)
                                    .background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
                                    }
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                }
            }
            .padding(20)
            .opacity(isActive ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isActive)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                .strokeBorder(.white.opacity(0.24), lineWidth: 0.5)
        }
        .gravityShadow(GravityShadows.medium)
    }

    private func fullHeightOrderSummary(merchant: SampleMerchant) -> some View {
        let deliveryProducts = Array(merchant.products.prefix(2))

        return Button {
            HapticFeedback.light.fire()
            coordinator.navigateToPage(1)
        } label: {
            HStack(spacing: 10) {
                MerchantLogoImage(merchant: merchant, size: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(merchant.displayName)
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.58))
                    Text("Arriving today 3–6pm")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.78)

                Spacer(minLength: 2)

                HStack(spacing: 5) {
                    ForEach(deliveryProducts) { product in
                        ProductImageView(product: product, merchant: merchant)
                            .frame(width: 44, height: 44)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }
            }
            .padding(12)
            .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func fullHeightCartSummary(item: ResolvedStoryProduct) -> some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.navigateToPage(4)
        } label: {
            HStack(spacing: 12) {
                ProductImageView(product: item.product, merchant: item.merchant)
                    .frame(width: 64, height: 64)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cart ready")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("Subtotal \(formatPrice(item.product.price))")
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.58))
                }

                Spacer(minLength: 4)

                Text("Checkout")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .frame(height: 36)
                    .background(.black, in: Capsule())
            }
            .padding(12)
            .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func utilityProductRail(
        title: String,
        products: [ResolvedStoryProduct],
        width: CGFloat
    ) -> some View {
        let tileWidth = (width - 52) / 3

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(utilityPrimaryColor)
                    .tracking(-0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(utilityPrimaryColor)
                    .frame(width: utilityRailControlSize, height: utilityRailControlSize)
                    .background(utilityControlFill, in: Circle())
            }

            HStack(spacing: 10) {
                ForEach(products) { item in
                    Button {
                        HapticFeedback.light.fire()
                        coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
                    } label: {
                        utilityProductTile(item, size: tileWidth)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
        .padding(16)
        .frame(width: width, height: retargetingCardHeight, alignment: .top)
        .retargetingSurface(
            fill: utilitySurfaceFill,
            border: utilitySurfaceBorder
        )
    }

    private func utilityProductTile(
        _ item: ResolvedStoryProduct,
        size: CGFloat
    ) -> some View {
        ProductImageView(product: item.product, merchant: item.merchant)
            .frame(width: size, height: size)
            .background(Color.black.opacity(0.025))
            .overlay { Color.black.opacity(0.025) }
            .overlay(alignment: .topLeading) {
                Text(formatPrice(item.product.price))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.48), in: Capsule())
                    .padding(8)
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "heart")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                    .padding(9)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.035), lineWidth: 0.5)
            }
            .gravityShadow(GravityShadows.small)
    }

    /// Every entry owns an identical snap slot. Its surface grows inside that
    /// stable slot during the initial takeover, so later cards inherit the
    /// same full-bleed alignment without changing scroll geometry mid-gesture.
    @ViewBuilder
    private func feedEntryCard(
        _ entry: FeedEntry,
        layout: FeedViewportLayout,
        firstEntryID: String?
    ) -> some View {
        let isFirstEntry = entry.id == firstEntryID
        let isSnappedEntry = visibleStoryID == entry.id
        let hasEnteredFullBleedFeed = layout.expansionProgress >= 0.999
        let takeoverProgress: CGFloat = {
            if isFirstEntry { return layout.expansionProgress }
            // Every card keeps the same full-width slot, but only the card
            // locked at the top loses its top radii. The incoming card stays
            // rounded so its peek reads clearly against the white canvas.
            return hasEnteredFullBleedFeed && isSnappedEntry ? 1 : 0
        }()
        let feedCornerRadius = FeedCardStyle.cornerRadius
        let topCornerRadius = feedCornerRadius * (1 - takeoverProgress)
        let chromeOpacity = Double(1 - takeoverProgress)

        switch entry {
        case let .story(story):
            paginatedFeedCard(
                story,
                width: layout.cardWidth,
                height: layout.cardHeight,
                viewportHeight: layout.viewportHeight,
                cornerRadius: topCornerRadius,
                bottomCornerRadius: feedCornerRadius,
                topScrimOpacity: 0.36 * chromeOpacity,
                borderOpacity: 0.12 * chromeOpacity,
                shadowOpacity: chromeOpacity,
                foregroundTopPadding: layout.foregroundTopPadding,
                scrollMotionEnabled: false
            )

        case let .post(post):
            paginatedPostCard(
                post,
                width: layout.cardWidth,
                height: layout.cardHeight,
                cornerRadius: topCornerRadius,
                bottomCornerRadius: feedCornerRadius,
                foregroundTopPadding: layout.foregroundTopPadding,
                borderOpacity: 0.16 * chromeOpacity,
                shadowOpacity: chromeOpacity,
                scrollMotionEnabled: false
            )
        }
    }

    /// Pulls each card gently back toward the viewport center while it moves.
    /// Native snapping releases that resistance at the end, creating a short,
    /// interruptible rubber catch-up rather than delaying gesture response.
    @ViewBuilder
    private func paginatedFeedCard(
        _ story: FeedStory,
        width: CGFloat,
        height: CGFloat,
        viewportHeight: CGFloat,
        cornerRadius: CGFloat = GravityRadius.r28,
        bottomCornerRadius: CGFloat? = nil,
        topScrimOpacity: Double = 0.36,
        borderOpacity: Double = 0.12,
        shadowOpacity: Double = 1,
        foregroundTopPadding: CGFloat = GravitySpacing.space20,
        scrollMotionEnabled: Bool = true
    ) -> some View {
        let motionIsReduced = reduceMotion
        let appliesScrollMotion = !motionIsReduced && scrollMotionEnabled
        let storyIndex = focusedStories.firstIndex(where: { $0.id == story.id })

        Group {
            if let collection = MerchantCollectionCatalog.presentation(for: story.id) {
                MerchantCollectionFeedCard(
                    story: story,
                    presentation: collection,
                    merchants: merchants,
                    width: width,
                    height: height,
                    isActive: story.id == activeFeedStory?.id,
                    cornerRadius: cornerRadius,
                    bottomCornerRadius: bottomCornerRadius,
                    foregroundTopPadding: foregroundTopPadding,
                    borderOpacity: borderOpacity,
                    shadowOpacity: shadowOpacity
                )
            } else {
                StoryFeedCard(
                    story: story,
                    merchants: merchants,
                    width: width,
                    height: height,
                    titleOverride: nil,
                    isActive: story.id == activeFeedStory?.id,
                    showsFooterArrow: false,
                    titleAtTopLeading: true,
                    productLayout: FeedInformationArchitecture.productLayout(
                        for: story,
                        in: selectedCategory,
                        visibleStoryIndex: storyIndex
                    ),
                    foregroundTopPadding: foregroundTopPadding,
                    // Resizing an active AV layer on every drag frame is the
                    // largest source of hitching. Hold its poster while the
                    // scroll is moving, then resume playback once locked.
                    backgroundPlaybackEnabled: expandingStoryID != story.id,
                    prefersVideoBackground: storyIndex?.isMultiple(of: 5) == true,
                    cornerRadius: cornerRadius,
                    bottomCornerRadius: bottomCornerRadius,
                    topScrimOpacity: topScrimOpacity,
                    borderOpacity: borderOpacity,
                    shadowOpacity: shadowOpacity,
                    freezesParallax: expandingStoryID == story.id,
                    // The takeover already supplies the spatial motion for
                    // The full-bleed takeover already supplies the spatial
                    // motion. Avoid stacking film parallax on top of it.
                    scrollViewportHeight: scrollMotionEnabled ? viewportHeight : nil,
                    onTap: story.topicKeys.contains("merchant-card")
                        ? nil
                        : { openTopic(for: story) }
                )
            }
        }
        .scrollTransition(
            appliesScrollMotion ? .interactive(timingCurve: .circularEaseOut) : .identity,
            axis: .vertical
        ) { card, phase in
            card
                .offset(y: appliesScrollMotion ? -CGFloat(phase.value) * 18 : 0)
                .scaleEffect(
                    appliesScrollMotion
                        ? 1 - CGFloat(min(abs(phase.value), 1)) * 0.015
                        : 1
                )
        }
        .scaleEffect(
            !appliesScrollMotion || story.id == activeFeedStory?.id ? 1 : 0.992
        )
        .animation(
            appliesScrollMotion ? SpringPreset.responsive : nil,
            value: activeFeedStory?.id
        )
        .matchedTransitionSource(id: story.id, in: namespace) { source in
            source
                .shadow(
                    color: .black.opacity(0.18 * shadowOpacity),
                    radius: 18,
                    y: 10
                )
        }
    }

    private func paginatedPostCard(
        _ post: ShopPost,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat = GravityRadius.r28,
        bottomCornerRadius: CGFloat? = nil,
        foregroundTopPadding: CGFloat = GravitySpacing.space20,
        borderOpacity: Double = 0.16,
        shadowOpacity: Double = 1,
        scrollMotionEnabled: Bool = true
    ) -> some View {
        let id = "shop-post-\(post.id)"
        let motionIsReduced = reduceMotion
        let appliesScrollMotion = !motionIsReduced && scrollMotionEnabled
        return ShopPostFeedCard(
            post: post,
            width: width,
            height: height,
            isActive: visibleStoryID == id,
            cornerRadius: cornerRadius,
            bottomCornerRadius: bottomCornerRadius,
            foregroundTopPadding: foregroundTopPadding,
            borderOpacity: borderOpacity,
            shadowOpacity: shadowOpacity
        )
        .scrollTransition(
            appliesScrollMotion ? .interactive(timingCurve: .circularEaseOut) : .identity,
            axis: .vertical
        ) { card, phase in
            card
                .offset(y: appliesScrollMotion ? -CGFloat(phase.value) * 18 : 0)
                .scaleEffect(
                    appliesScrollMotion
                        ? 1 - CGFloat(min(abs(phase.value), 1)) * 0.015
                        : 1
                )
        }
        .scaleEffect(!appliesScrollMotion || visibleStoryID == id ? 1 : 0.992)
        .animation(
            appliesScrollMotion ? SpringPreset.responsive : nil,
            value: visibleStoryID
        )
    }

    @ViewBuilder
    private var feedAmbientBackdrop: some View {
        Color.white
            .allowsHitTesting(false)
    }

    /// Resolves a For You story to its canonical topic. An exact lead-story
    /// match wins over secondary membership so cards such as New York graphics
    /// can own a destination even when they also appear in Type & transit.
    private func openTopic(for story: FeedStory) {
        // Luke's Hypothesis shelves are authored directly into his buyer
        // topics, rather than the legacy shared topic catalog below. Keep the
        // drill-in inside Home so the selected topic and its sibling shelves
        // remain available around the real shelf content.
        if buyerPreview.selected.id == "luke",
           selectedTopic.storyIDs.contains(story.id) {
            coordinator.resetScrollState()
            withAnimation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.32, dampingFraction: 0.82)
            ) {
                focusedStoryID = story.id
            }
            return
        }

        let destinations = topics.filter { $0.id != "for-you" }
        let destination = destinations.first { $0.storyIDs?.first == story.id }
            ?? destinations.first { $0.storyIDs?.contains(story.id) == true }
            ?? destinations.first { topic in
                guard let key = topic.storyTopicKey else { return false }
                return story.topicKeys.contains(key)
            }

        guard let destination else {
            // This is still a home-card drill-in. Name the card explicitly so
            // NavigationCoordinator does not turn it into an inline content
            // swap and StoryTopicPage can perform the same system zoom as an
            // expanded topic.
            expandingStoryID = story.id
            Task { @MainActor in
                await Task.yield()
                coordinator.pushRoute(
                    .story(storyId: story.id, sourceId: story.id)
                )
            }
            return
        }

        coordinator.resetScrollState()
        expandingStoryID = story.id

        // Commit the frozen media geometry before navigation captures the
        // matched source. Otherwise parallax reacts to the zoom's changing
        // coordinate space and the film appears to slide out of the card.
        Task { @MainActor in
            await Task.yield()
            coordinator.pushRoute(
                .topicExpanded(topicId: destination.id, sourceStoryId: story.id)
            )
        }
    }

    // MARK: - Top Bar (Quick Links)

    private var topBar: some View {
        ZStack(alignment: .leading) {
            topicRail
            avatar
                .zIndex(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, GravitySpacing.space16)
        .padding(.vertical, PurlTune.token("Pages/HomePage.swift:padding:_:165:29", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
        // Deliberately no bar background: the active feed film or topic cover
        // continues through both the topic rail and the status-bar safe area.
    }

    /// Registers the bottom nav's back behavior for the active topic. Topic
    /// selection is inline state, so the shared back button needs this hook.
    private func syncTopicBackAction() {
        if focusedStoryID != nil {
            // Back from a subcategory returns to its parent topic in place.
            coordinator.topicBackAction = {
                coordinator.resetScrollState()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    focusedStoryID = nil
                }
            }
        } else if selectedTopicID == "for-you" {
            coordinator.topicBackAction = nil
        } else {
            coordinator.topicBackAction = {
                coordinator.resetScrollState()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    selectedTopicID = "for-you"
                }
            }
        }
    }

    private var avatar: some View {
        Button {
            HapticFeedback.light.fire()
            withAnimation(.easeOut(duration: 0.18)) {
                showsBuyerSwitcher = true
            }
        } label: {
            BuyerPreviewAvatar(
                profile: buyerPreview.selected,
                size: FeedNavigationStyle.avatarSize
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Switch preview buyer")
        .fullScreenCover(isPresented: $showsBuyerSwitcher) {
            ZStack(alignment: .bottom) {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissBuyerSwitcher() }

                VStack(spacing: 4) {
                    ForEach(BuyerPreviewStore.profiles) { profile in
                        Button {
                            selectBuyer(profile)
                        } label: {
                            HStack(spacing: 14) {
                                BuyerPreviewAvatar(profile: profile, size: 44)

                                Text(profile.name.split(separator: " ").first.map(String.init) ?? profile.name)
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(.primary)

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 58)
                            .background(
                                buyerPreview.selected.id == profile.id
                                    ? Color.primary.opacity(0.07)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: 40, style: .continuous)
                )
                .shadow(color: .black.opacity(0.14), radius: 24, y: 8)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .ignoresSafeArea()
            .presentationBackground(.clear)
            .environment(\.colorScheme, .light)
            .accessibilityAction(.escape) { dismissBuyerSwitcher() }
        }
        .zIndex(1)
    }

    private func selectBuyer(_ profile: BuyerPreviewProfile) {
        buyerPreview.select(profile)
        dismissBuyerSwitcher()
        coordinator.resetScrollState()
        visibleStoryID = nil
        expandingStoryID = nil
        focusedStoryID = nil
        selectedTopicID = "for-you"
        topicRailOffset = 0
    }

    private func dismissBuyerSwitcher() {
        withAnimation(.easeOut(duration: 0.16)) {
            showsBuyerSwitcher = false
        }
    }

    private var topicRail: some View {
        GeometryReader { geometry in
            let leadingInset = FeedNavigationStyle.avatarSize + GravitySpacing.space8
            let effectiveOffset = clampedTopicRailOffset(
                proposed: topicRailOffset + topicRailDragOffset,
                viewportWidth: geometry.size.width,
                leadingInset: leadingInset
            )

            ZStack(alignment: .leading) {
                Color.clear

                HStack(spacing: FeedNavigationStyle.itemSpacing) {
                    ForEach(navigationTopics) { topic in
                        topicButton(topic)
                            .id(topic.id)
                    }

                    Color.clear
                        .frame(width: GravitySpacing.space16, height: 1)
                        .accessibilityHidden(true)
                }
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: leadingInset + effectiveOffset)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { _, width in
                    topicRailContentWidth = width
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .updating($topicRailDragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let proposed = topicRailOffset + value.predictedEndTranslation.width
                        withAnimation(.easeOut(duration: 0.18)) {
                            topicRailOffset = clampedTopicRailOffset(
                                proposed: proposed,
                                viewportWidth: geometry.size.width,
                                leadingInset: leadingInset
                            )
                        }
                    }
            )
            .mask {
                HStack(spacing: 0) {
                    // The strip can pass behind the avatar when explicitly
                    // dragged, but selection never changes its offset.
                    Color.clear.frame(width: 20)
                    Color.black
                }
            }
        }
        .frame(height: FeedNavigationStyle.controlSize)
    }

    private func clampedTopicRailOffset(
        proposed: CGFloat,
        viewportWidth: CGFloat,
        leadingInset: CGFloat
    ) -> CGFloat {
        let minimum = min(
            0,
            viewportWidth - leadingInset - topicRailContentWidth
        )
        return min(0, max(minimum, proposed))
    }

    private func topicButton(_ topic: BuyerFeedTopic) -> some View {
        return Button {
            guard selectedTopicID != topic.id || focusedStoryID != nil else { return }
            HapticFeedback.light.fire()
            coordinator.resetScrollState()
            let currentIndex = navigationTopics.firstIndex { $0.id == selectedTopicID } ?? 0
            let nextIndex = navigationTopics.firstIndex { $0.id == topic.id } ?? currentIndex
            categoryMoveDirection = nextIndex >= currentIndex ? 1 : -1
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
                focusedStoryID = nil
                selectedTopicID = topic.id
            }
        } label: {
            topicLabel(topic)
                .background {
                    if selectedTopicID == topic.id {
                        Capsule()
                            .fill(Color.white.opacity(0.92))
                            .overlay {
                                Capsule()
                                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                            }
                            .shadow(
                                color: .black.opacity(0.10),
                                radius: 12,
                                y: 4
                            )
                            .matchedGeometryEffect(id: "selected-topic", in: topicSelectionNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTopicID == topic.id ? .isSelected : [])
    }

    private func topicLabel(_ topic: BuyerFeedTopic) -> some View {
        Text(topic.label)
            .font(FeedNavigationStyle.labelFont)
            .foregroundStyle(topicLabelColor(topic))
            .padding(.horizontal, FeedNavigationStyle.pillHorizontalPadding)
            .frame(height: FeedNavigationStyle.controlSize)
            .contentShape(Capsule())
    }

    private func topicLabelColor(_ topic: BuyerFeedTopic) -> Color {
        if selectedTopicID == topic.id {
            return GravityColors.textFixedDark
        }
        return GravityColors.textTertiary
    }

}

private extension View {
    func retargetingSurface(
        fill: Color,
        border: Color
    ) -> some View {
        background(
            fill,
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(border, lineWidth: 0.5)
        }
        .gravityShadow(GravityShadows.large)
    }
}

#Preview {
    @Previewable @Namespace var namespace
    NavigationStack {
        HomePage(namespace: namespace)
    }
    .environment(NavigationCoordinator())
}
