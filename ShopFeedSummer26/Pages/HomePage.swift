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
        case seasonalSavings
        case story(FeedStory)
        case post(ShopPost)

        var id: String {
            switch self {
            case .seasonalSavings: "seasonal-savings"
            case let .story(story): story.id
            case let .post(post): "shop-post-\(post.id)"
            }
        }
    }

    private enum SeasonalPlacement: String, CaseIterable, Identifiable {
        case off
        case header
        case feedCard

        var id: String { rawValue }

        var label: String {
            switch self {
            case .off: "Off"
            case .header: "Header"
            case .feedCard: "Feed card"
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
    @AppStorage("holidayHeaderEnabled") private var legacyHolidayHeaderEnabled = false
    @AppStorage("seasonalPlacement") private var seasonalPlacementRawValue = ""

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

    private var isHolidayHeaderPresented: Bool {
        seasonalPlacement == .header
            && selectedTopicID == "for-you"
            && focusedStoryID == nil
            && visibleStoryID == utilityStoryID
    }

    /// An empty new value migrates the original on/off prototype preference.
    private var seasonalPlacement: SeasonalPlacement {
        SeasonalPlacement(rawValue: seasonalPlacementRawValue)
            ?? (legacyHolidayHeaderEnabled ? .header : .off)
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

    /// Verified buyer posts are interleaved into For You without replacing
    /// any of the authored flick-and-stick cards.
    private var feedEntries: [FeedEntry] {
        guard selectedTopicID == "for-you" else {
            return focusedStories.map(FeedEntry.story)
        }

        let posts = Array(postService.posts(for: buyerPreview.selected).prefix(4))
        var result: [FeedEntry] = []
        var nextPostIndex = 0
        for (index, story) in focusedStories.enumerated() {
            result.append(.story(story))
            if index.isMultiple(of: 2), posts.indices.contains(nextPostIndex) {
                result.append(.post(posts[nextPostIndex]))
                nextPostIndex += 1
            }
        }
        if seasonalPlacement == .feedCard {
            result.insert(.seasonalSavings, at: 0)
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
                    closeOnlyNavigation: buyerPreview.selected.usesInlineTopicNavigation
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
            if !buyerPreview.selected.usesInlineTopicNavigation || focusedStoryID == nil {
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
                && !isHolidayHeaderPresented
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
            resetFeedPosition(for: newTopicID)
            withAnimation(.easeOut(duration: 0.22)) {
                coordinator.navBarBlurTint = pageBackgroundColor
            }
            syncTopicBackAction()
        }
        .onChange(of: focusedStoryID) { _, _ in
            syncTopicBackAction()
        }
        .onAppear {
            if visibleStoryID == nil {
                resetFeedPosition(for: selectedTopicID)
            } else {
                expandingStoryID = nil
            }
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
            let renderedTopicID = selectedTopicID
            let isForYou = selectedTopicID == "for-you"
            let firstEntryID = feedEntries.first?.id
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
                            utilityFeedEntry(
                                containerWidth: geo.size.width,
                                launchInset: metrics.utilityLaunchInset
                            )
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
                                firstEntryID: firstEntryID
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
                .scrollPosition(
                    id: Binding(
                        get: { visibleStoryID },
                        set: { newValue in
                            // Both feeds exist briefly during the horizontal
                            // replacement transition. Ignore late position
                            // writes from the outgoing topic.
                            guard selectedTopicID == renderedTopicID else { return }
                            visibleStoryID = newValue
                        }
                    ),
                    anchor: .top
                )
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

    /// Real products from the active buyer's For You assortment, biased
    /// toward the campaign's $50 threshold while retaining a full carousel.
    private var seasonalSavingsProducts: [ResolvedStoryProduct] {
        let qualifying = defaultUtilityProducts.filter {
            numericPrice($0.product.price) >= 50
        }
        let source = qualifying.count >= 4 ? qualifying : defaultUtilityProducts
        return Array(source.prefix(8))
    }

    /// Every product supported by the selected buyer's authored shelves.
    /// Utility cards use this only to complete a known activity type across
    /// stories; an item is never presented as purchased/saved without its
    /// corresponding buyer tag.
    private var allBuyerUtilityProducts: [ResolvedStoryProduct] {
        var seenStories = Set<String>()
        var seenProducts = Set<String>()
        let storyIDs = navigationTopics
            .flatMap(\.storyIDs)
            .filter { seenStories.insert($0).inserted }

        return storyIDs
            .compactMap { storyID in
                PersonalizedFeedCatalog.current.stories.first { $0.id == storyID }
            }
            .flatMap { $0.resolvedProducts(from: merchants) }
            .filter { seenProducts.insert($0.id).inserted }
    }

    private func utilityProducts(for storyID: String?) -> [ResolvedStoryProduct] {
        guard let storyID, !storyID.isEmpty,
              let story = PersonalizedFeedCatalog.current.stories.first(where: { $0.id == storyID }) else {
            return defaultUtilityProducts
        }
        return story.resolvedProducts(from: merchants)
    }

    /// Prefer the configured story, then complete the row with other products
    /// carrying the same verified buyer signal elsewhere in that buyer's feed.
    private func utilityProducts(
        for storyID: String?,
        matchingTag tag: String,
        limit: Int = 3
    ) -> [ResolvedStoryProduct] {
        var seen = Set<String>()
        let primary = utilityProducts(for: storyID)
        return (primary + allBuyerUtilityProducts)
            .filter { $0.product.tags.contains(tag) }
            .filter { seen.insert($0.id).inserted }
            .prefix(limit)
            .map { $0 }
    }

    private func feedUtilityShelf(containerWidth: CGFloat) -> some View {
        retargetingRailCarousel(containerWidth: containerWidth)
        .padding(.top, 18)
        .frame(width: containerWidth)
    }

    @ViewBuilder
    private func utilityFeedEntry(
        containerWidth: CGFloat,
        launchInset: CGFloat
    ) -> some View {
        if seasonalPlacement == .header {
            VStack(spacing: -70) {
                HolidayFeedHeader(
                    width: containerWidth,
                    height: containerWidth * (428 / 402)
                ) {
                    // This is an interaction hook for the prototype variant;
                    // commerce routing can be attached once the campaign has
                    // a canonical collection destination.
                }

                feedUtilityShelf(containerWidth: containerWidth)
                    .environment(\.colorScheme, .light)
                    .zIndex(1)
            }
        } else {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: launchInset)
                    .accessibilityHidden(true)

                feedUtilityShelf(containerWidth: containerWidth)
            }
        }
    }

    private func retargetingRailCarousel(containerWidth: CGFloat) -> some View {
        let railWidth = min(max(containerWidth - 48, 300), 320)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GravitySpacing.space10) {
                if buyerPreview.selected.utility.showsOrders {
                    orderTrackingRailCard(width: railWidth)
                }

                if let storyID = buyerPreview.selected.utility.buyAgainStoryID {
                    let products = utilityProducts(
                        for: storyID,
                        matchingTag: "buyer-buy-again"
                    )
                    if !products.isEmpty {
                        utilityProductRail(
                            title: "Buy again",
                            products: products,
                            maximumWidth: railWidth
                        )
                    }
                }

                if buyerPreview.selected.utility.showsCart, let cartItem = cartSyncItem {
                    cartSyncCard(item: cartItem, width: railWidth)
                }

                if let storyID = buyerPreview.selected.utility.recentlyViewedStoryID {
                    let products = utilityProducts(
                        for: storyID,
                        matchingTag: "buyer-saved"
                    )
                    if !products.isEmpty {
                        utilityProductRail(
                            title: "Your saves",
                            products: products,
                            maximumWidth: railWidth
                        )
                    }
                }

                if let storyID = buyerPreview.selected.utility.ownedAdjacencyStoryID {
                    let products = utilityProducts(
                        for: storyID,
                        matchingTag: "buyer-open-loop"
                    )
                    if !products.isEmpty {
                        utilityProductRail(
                            title: "Keep shopping",
                            products: products,
                            maximumWidth: railWidth
                        )
                    }
                }
            }
            .padding(.horizontal, GravitySpacing.space12)
            .padding(.vertical, 8)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
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
            .frame(width: width, height: UtilityRailMetrics.cardHeight)
            .utilityRailSurface(
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
            OrderTrackingUtilityCard(
                merchant: merchant,
                products: Array(merchant.products.prefix(2)),
                width: width
            ) {
                coordinator.navigateToPage(1)
            }
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
        maximumWidth: CGFloat
    ) -> some View {
        UtilityProductRailCard(
            title: title,
            products: products,
            maximumWidth: maximumWidth,
            fill: utilitySurfaceFill,
            border: utilitySurfaceBorder,
            onSelectProduct: { item in
                coordinator.pushRoute(
                    .product(
                        merchantId: item.merchant.id,
                        productId: item.product.id
                    )
                )
            }
        )
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
        case .seasonalSavings:
            HolidayFeedCard(
                width: layout.cardWidth,
                height: layout.cardHeight,
                products: seasonalSavingsProducts,
                topCornerRadius: topCornerRadius,
                bottomCornerRadius: feedCornerRadius,
                foregroundTopPadding: layout.foregroundTopPadding,
                expansionProgress: layout.expansionProgress,
                borderOpacity: 0.12 * chromeOpacity,
                shadowOpacity: chromeOpacity
            ) {
                // Campaign routing remains intentionally detached from the
                // placement prototype until it has a canonical collection.
            } onSelectProduct: { item in
                coordinator.pushRoute(
                    .product(
                        merchantId: item.merchant.id,
                        productId: item.product.id
                    )
                )
            }

        case let .story(story):
            paginatedFeedCard(
                story,
                width: layout.cardWidth,
                height: layout.cardHeight,
                viewportHeight: layout.viewportHeight,
                cornerRadius: topCornerRadius,
                bottomCornerRadius: feedCornerRadius,
                // Navigation and white titles still need contrast after the
                // card becomes full bleed; only borders and card shadows fade.
                topScrimOpacity: 0.36,
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
        // Authored buyer shelves stay inside Home so the selected topic and
        // its sibling shelves remain available around the real shelf content.
        if buyerPreview.selected.usesInlineTopicNavigation,
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
        BuyerFeedNavigationBar(
            profile: buyerPreview.selected,
            topics: navigationTopics,
            selectedTopicID: selectedTopicID,
            feedExpansionProgress: firstStoryExpansionProgress,
            usesInverseStyle: isHolidayHeaderPresented,
            selectionNamespace: topicSelectionNamespace,
            railOffset: $topicRailOffset,
            railContentWidth: $topicRailContentWidth,
            onSelectTopic: selectTopic,
            onSelectBuyer: {
                withAnimation(.easeOut(duration: 0.18)) {
                    showsBuyerSwitcher = true
                }
            }
        )
        .fullScreenCover(isPresented: $showsBuyerSwitcher) {
            buyerSwitcher
        }
        // Deliberately no bar background: the active feed film or topic cover
        // continues through both the topic rail and the status-bar safe area.
    }

    private var buyerSwitcher: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissBuyerSwitcher() }

            VStack(spacing: 4) {
                seasonalPlacementPicker

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

    private var seasonalPlacementPicker: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            Text("Holiday banner")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            Picker("Holiday banner", selection: seasonalPlacementBinding) {
                ForEach(SeasonalPlacement.allCases) { placement in
                    Text(placement.label).tag(placement)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(GravitySpacing.space12)
        .frame(height: 86)
        .background(
            Color.primary.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .onChange(of: seasonalPlacementRawValue) { _, _ in
            guard selectedTopicID == "for-you" else { return }
            resetFeedPosition(for: "for-you")
        }
    }

    private var seasonalPlacementBinding: Binding<SeasonalPlacement> {
        Binding(
            get: { seasonalPlacement },
            set: { placement in
                seasonalPlacementRawValue = placement.rawValue
                legacyHolidayHeaderEnabled = placement == .header
            }
        )
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

    private func selectBuyer(_ profile: BuyerPreviewProfile) {
        buyerPreview.select(profile)
        dismissBuyerSwitcher()
        coordinator.resetScrollState()
        focusedStoryID = nil
        selectedTopicID = "for-you"
        topicRailOffset = 0
        resetFeedPosition(for: "for-you")
    }

    private func dismissBuyerSwitcher() {
        withAnimation(.easeOut(duration: 0.16)) {
            showsBuyerSwitcher = false
        }
    }

    private func selectTopic(_ topic: BuyerFeedTopic) {
        guard selectedTopicID != topic.id || focusedStoryID != nil else { return }
        HapticFeedback.light.fire()
        coordinator.resetScrollState()
        let currentIndex = navigationTopics.firstIndex { $0.id == selectedTopicID } ?? 0
        let nextIndex = navigationTopics.firstIndex { $0.id == topic.id } ?? currentIndex
        categoryMoveDirection = nextIndex >= currentIndex ? 1 : -1

        // Selecting For You from an inline story does not change the tab
        // identifier, so `onChange` will not run. Reset it explicitly.
        if topic.id == selectedTopicID {
            resetFeedPosition(for: topic.id)
        }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
            focusedStoryID = nil
            selectedTopicID = topic.id
        }
    }

    /// Establishes the canonical entry position for every top-level feed.
    /// For You always begins on the utility shelf; topic feeds begin on their
    /// first authored story. No caller should use `nil` as a reset signal,
    /// because SwiftUI interprets that as permission to restore an old offset.
    private func resetFeedPosition(for topicID: String) {
        expandingStoryID = nil

        if topicID == "for-you" {
            visibleStoryID = buyerPreview.selected.showsUtilityShelf
                ? utilityStoryID
                : feedEntries.first?.id
        } else if let topic = navigationTopics.first(where: { $0.id == topicID }) {
            visibleStoryID = buyerPreview.stories(
                for: topic,
                in: PersonalizedFeedCatalog.current
            ).first?.id
        } else {
            visibleStoryID = nil
        }

    }

}

#Preview {
    @Previewable @Namespace var namespace
    NavigationStack {
        HomePage(namespace: namespace)
    }
    .environment(NavigationCoordinator())
}
