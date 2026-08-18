import Combine
import SwiftUI

/// Home feed — scrollable merchant feed cards with focused topic feeds.
struct HomePage: View {
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
    @State private var isFeedScrolling = false
    @State private var expandingStoryID: String?
    @State private var categoryMoveDirection = 1
    @State private var topicRailOffset: CGFloat = 0
    @State private var topicRailContentWidth: CGFloat = 0
    @State private var showsBuyerSwitcher = false
    @GestureState private var topicRailDragOffset: CGFloat = 0

    private let retargetingCardHeight: CGFloat = 177
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
        guard selectedTopicID != "for-you", let leadStory = focusedStories.first else {
            return .white
        }
        return Color(hex: leadStory.accentHex)
    }

    private var focusedStories: [FeedStory] {
        buyerPreview.stories(
            for: selectedTopic,
            in: PersonalizedFeedCatalog.current
        )
    }

    private var activeFeedStory: FeedStory? {
        if visibleStoryID == utilityStoryID {
            return nil
        }
        if let visibleStoryID,
           let visibleStory = focusedStories.first(where: { $0.id == visibleStoryID }) {
            return visibleStory
        }
        return focusedStories.first
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
        .safeAreaBar(edge: .top) {
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
        // Every Home surface now sits on imagery. Keep status-bar chrome light
        // so the transparent top rail remains legible over the moving backdrop.
        .environment(\.colorScheme, .dark)
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
        .onChange(of: selectedTopicID) { _, _ in
            visibleStoryID = nil
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
            let cardWidth = min(geo.size.width - 32, 377)
            let cardHeight = cardWidth * 1.71

            ZStack {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        if selectedTopicID == "for-you", buyerPreview.selected.showsUtilityShelf {
                            feedUtilityShelf(containerWidth: geo.size.width)
                            if forYouUtilityPresentation == .carouselAndFullHeight {
                                fullHeightUtilityCard(width: cardWidth, height: cardHeight)
                                    .id(utilityStoryID)
                            }
                        }

                        ForEach(focusedStories) { story in
                            paginatedFeedCard(
                                story,
                                width: cardWidth,
                                height: cardHeight,
                                viewportHeight: geo.size.height
                            )
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.top, 8)
                    .padding(.bottom, max((geo.size.height - cardHeight) / 2, 8))
                }
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(id: $visibleStoryID, anchor: .center)
                .onScrollPhaseChange { _, phase in
                    isFeedScrolling = phase != .idle
                }
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, offset in
                    coordinator.updateScrollOffset(offset)
                }
            }
            .onChange(of: focusedStories.map(\.id)) { _, storyIDs in
                // A nil position means the shopper is still in the utility
                // shelf above the flick-and-stick feed. Never jump them past it.
                guard let visibleStoryID else { return }
                guard storyIDs.contains(visibleStoryID) else {
                    self.visibleStoryID = nil
                    return
                }
            }
        }
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
        .padding(.bottom, 12)
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
                        title: "Saved",
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
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.16), in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.merchant.displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("Subtotal \(formatPrice(item.product.price))")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.64))
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
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Color.white.opacity(0.18), in: Circle())
                                .offset(x: -6, y: -6)
                        }
                }

                Spacer(minLength: 10)

                Text("Continue to checkout")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.white.opacity(0.14), in: Capsule())
            }
            .padding(16)
            .frame(width: width, height: retargetingCardHeight)
            .retargetingSurface()
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
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.14), in: Circle())
                    }

                    HStack(spacing: 10) {
                        MerchantLogoImage(merchant: merchant, size: 48)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(merchant.displayName)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.64))
                            Text("Arriving today 3–6pm")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
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
                .retargetingSurface()
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
                    .font(FeedEditorialTypography.homeCardTitleFont)
                    .tracking(FeedEditorialTypography.homeCardTitleTracking)
                    .lineSpacing(FeedEditorialTypography.homeCardTitleLineSpacing)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.14), in: Circle())
            }

            HStack(spacing: 10) {
                ForEach(products) { item in
                    Button {
                        HapticFeedback.light.fire()
                        coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
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
        .padding(16)
        .frame(width: width, height: retargetingCardHeight, alignment: .top)
        .retargetingSurface()
    }

    /// Pulls each card gently back toward the viewport center while it moves.
    /// Native snapping releases that resistance at the end, creating a short,
    /// interruptible rubber catch-up rather than delaying gesture response.
    @ViewBuilder
    private func paginatedFeedCard(
        _ story: FeedStory,
        width: CGFloat,
        height: CGFloat,
        viewportHeight: CGFloat
    ) -> some View {
        let motionIsReduced = reduceMotion
        let storyIndex = focusedStories.firstIndex(where: { $0.id == story.id })

        Group {
            if let collection = MerchantCollectionCatalog.presentation(for: story.id) {
                MerchantCollectionFeedCard(
                    story: story,
                    presentation: collection,
                    merchants: merchants,
                    width: width,
                    height: height,
                    isActive: story.id == activeFeedStory?.id
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
                    backgroundPlaybackEnabled: expandingStoryID != story.id,
                    prefersVideoBackground: storyIndex?.isMultiple(of: 5) == true,
                    freezesParallax: expandingStoryID == story.id,
                    scrollViewportHeight: viewportHeight,
                    onTap: story.topicKeys.contains("merchant-card")
                        ? nil
                        : { openTopic(for: story) }
                )
            }
        }
        .scrollTransition(
            motionIsReduced ? .identity : .interactive(timingCurve: .circularEaseOut),
            axis: .vertical
        ) { card, phase in
            card
                .offset(y: motionIsReduced ? 0 : -CGFloat(phase.value) * 18)
                .scaleEffect(
                    motionIsReduced
                        ? 1
                        : 1 - CGFloat(min(abs(phase.value), 1)) * 0.015
                )
        }
        .scaleEffect(motionIsReduced || story.id == activeFeedStory?.id ? 1 : 0.992)
        .animation(motionIsReduced ? nil : SpringPreset.responsive, value: activeFeedStory?.id)
        .matchedTransitionSource(id: story.id, in: namespace) { source in
            source
                .background(.black)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: GravityRadius.r28,
                        style: .continuous
                    )
                )
                .shadow(
                    color: .black.opacity(0.24),
                    radius: 18,
                    y: 10
                )
        }
        .id(story.id)
    }

    private var feedAmbientBackdrop: some View {
        ZStack {
            if let story = activeFeedStory ?? focusedStories.first {
                let accent = Color(hex: story.accentHex)
                let lead = story.resolvedProducts(from: merchants).first
                (lead?.merchant.secondaryColor ?? accent)

                if let lead {
                    let collectionBackdropURL = MerchantCollectionCatalog
                        .presentation(for: story.id)?
                        .coverURL(from: merchants)
                    let backdropURL = collectionBackdropURL ?? story.lifestyleImageURL(
                        from: merchants,
                        format: .landscape,
                        role: "feed-backdrop"
                    )

                    if let backdropURL {
                        CachedAsyncImage(url: backdropURL) { phase in
                            if case .success(let image) = phase {
                                image
                                    .resizable()
                                    .scaledToFill()
                            } else if case .failure = phase {
                                ProductImageView(product: lead.product, merchant: lead.merchant)
                            } else {
                                accent
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(story.id)
                        .scaleEffect(1.32)
                        .blur(radius: 46, opaque: true)
                        .saturation(1.28)
                        .contrast(1.08)
                        .opacity(isFeedScrolling ? 0.94 : 0.88)
                        .transition(.opacity)
                    } else {
                        AmbientProductVideo(
                            videoURLs: backdropFilmURLs(for: story),
                            posterImageURL: lead.product.imageURL,
                            playbackEnabled: isFeedScrolling
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(story.id)
                        .scaleEffect(1.22)
                        .blur(radius: 38, opaque: true)
                        .opacity(isFeedScrolling ? 0.74 : 0.62)
                        .transition(.opacity)
                    }
                }

                LinearGradient(
                    colors: [.black.opacity(0.10), .clear, .black.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                pageBackgroundColor
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: isFeedScrolling ? 0.18 : 0.24), value: isFeedScrolling)
        .animation(.easeInOut(duration: 0.24), value: activeFeedStory?.id)
    }

    /// Rotates the story playlist by one item so the blurred backdrop never
    /// mirrors the clip currently beginning inside the foreground card.
    private func backdropFilmURLs(for story: FeedStory) -> [URL] {
        guard !story.usesCatalogOnlyMedia else { return [] }
        let urls = story.resolvedProducts(from: merchants).flatMap {
            $0.product.ambientFilmURLs(merchantID: $0.merchant.id)
        }
        guard urls.count > 1 else { return urls }
        return Array(urls.dropFirst()) + [urls[0]]
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
        Button {
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
                            .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
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
        selectedTopicID == topic.id ? GravityColors.textFixedDark : GravityColors.textFixedLight
    }

}

private extension View {
    /// A dark wash keeps utility chrome legible while letting the feed color
    /// remain visible beneath the card.
    func retargetingSurface() -> some View {
        background(
            Color.black.opacity(0.40),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.035), radius: 14, y: 7)
    }
}

#Preview {
    @Previewable @Namespace var namespace
    NavigationStack {
        HomePage(namespace: namespace)
    }
    .environment(NavigationCoordinator())
}
