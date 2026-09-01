import Combine
import SwiftUI
import UIKit
/// Home feed — scrollable merchant feed cards with focused topic feeds.
struct HomePage: View {
    private static let bundledMerchantSnapshot = LocalMerchantService.loadMerchants()
    private static let personalizedMerchantSnapshot = BuyerPersonalizationCatalog.merchants.filter {
        [
            "city-lights-sf",
            "kith",
            "pollen-robotics",
            "sneaker-politics",
            "tin-can-kids",
        ].contains($0.id)
    }
    private static let initialMerchantSnapshot = LocalMerchantService.mergeMerchants([
        bundledMerchantSnapshot,
        HypothesisShelfCatalog.merchants,
        personalizedMerchantSnapshot,
    ])
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
    /// Keep the merged catalog stable across body evaluations. Rebuilding the
    /// full merchant/product graph during a swipe or tab animation creates a
    /// large amount of avoidable main-thread work.
    @State private var merchants: [SampleMerchant] = HomePage.initialMerchantSnapshot
    @State private var selectedTopicID = "for-you"
    /// A drilled-in subcategory story rendered inline so the top bar stays.
    @State private var focusedStoryID: String?
    @State private var visibleStoryID: String?
    @State private var feedScrollState = FeedScrollState()
    @State private var feedBackdropState = FeedBackdropState()
    @State private var feedChromeTransition = FeedChromeTransitionState()
    @State private var utilityRailExpansion = UtilityRailExpansionState()
    @State private var utilityBelt = UtilityBeltPreferences.shared
    @State private var feedChromeIsInverted = false
    @State private var expandingStoryID: String?
    @State private var categoryMoveDirection = 1
    @State private var showsBuyerSwitcher = false
    @State private var holidayFiltersPinned = false
    @State private var dealsFiltersPinned = false
    @State private var selectedDealFilterBand: DealFilterBand = .all
    @AppStorage("holidayHeaderEnabled") private var legacyHolidayHeaderEnabled = false
    @AppStorage("seasonalPlacement") private var seasonalPlacementRawValue = ""
    @AppStorage("utilityBeltExtendoEnabled") private var utilityBeltExtendoEnabled = true

    private let utilityStoryID = "for-you-utility-hub"
    /// Keep the full-height exploration available without placing it in the
    /// live feed. Switching this recipe restores the prototype for comparison.
    private let forYouUtilityPresentation: ForYouUtilityPresentation = .carouselOnly

    private var destinationFiltersPinned: Bool {
        holidayFiltersPinned || dealsFiltersPinned
    }

    private var topics: [FeedTopic] { PersonalizedFeedCatalog.current.topics }
    private var baseNavigationTopics: [BuyerFeedTopic] {
        buyerPreview.navigationTopics
    }

    /// Campaign navigation changes the utility destinations at the front of
    /// the rail without disturbing the buyer's personalized topic order.
    private var navigationTopics: [BuyerFeedTopic] {
        guard let forYou = baseNavigationTopics.first else { return [] }
        let personalizedTopics = Array(baseNavigationTopics.dropFirst())
        let utilityTopics = seasonalPlacement == .header
            ? holidayNavigationTopics(from: forYou)
            : evergreenNavigationTopics(from: forYou)
        return [forYou] + utilityTopics + personalizedTopics
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

    private var isHolidayDestination: Bool {
        selectedTopicID == "holiday-sale" || selectedTopicID == "gift-guides"
    }

    private var isEvergreenUtilityDestination: Bool {
        selectedTopicID == "following" || selectedTopicID == "deals"
    }

    private var isStaticUtilityDestination: Bool {
        isHolidayDestination || isEvergreenUtilityDestination
    }

    /// An empty new value migrates the original on/off prototype preference.
    private var seasonalPlacement: SeasonalPlacement {
        SeasonalPlacement(rawValue: seasonalPlacementRawValue)
            ?? (legacyHolidayHeaderEnabled ? .header : .off)
    }

    private func holidayNavigationTopics(
        from forYou: BuyerFeedTopic
    ) -> [BuyerFeedTopic] {
        utilityNavigationTopics(
            labels: [
                (id: "holiday-sale", label: "Holiday sale"),
                (id: "gift-guides", label: "Gift guides"),
            ],
            from: forYou
        )
    }

    private func evergreenNavigationTopics(
        from forYou: BuyerFeedTopic
    ) -> [BuyerFeedTopic] {
        utilityNavigationTopics(
            labels: [
                (id: "following", label: "Following"),
                (id: "deals", label: "Deals"),
            ],
            from: forYou
        )
    }

    /// These first-pass destinations reuse the buyer's authored assortment so
    /// every new tab is navigable while its dedicated editorial feed is built.
    private func utilityNavigationTopics(
        labels: [(id: String, label: String)],
        from forYou: BuyerFeedTopic
    ) -> [BuyerFeedTopic] {
        labels.enumerated().map { index, item in
            let alternatingStories = forYou.storyIDs.enumerated().compactMap {
                storyIndex, storyID in
                storyIndex % labels.count == index
                    ? storyID
                    : nil
            }
            return BuyerFeedTopic(
                id: item.id,
                label: item.label,
                sourceCategoryID: forYou.sourceCategoryID,
                storyIDs: alternatingStories.isEmpty
                    ? forYou.storyIDs
                    : alternatingStories,
                evidence: forYou.evidence
            )
        }
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
        let baseAuthored = buyerPreview.stories(for: selectedTopic, in: PersonalizedFeedCatalog.current)
        let worldsEnabled = buyerPreview.selected.id == "luke" && selectedTopicID == "for-you"
        let enabledWorldIDs = worldsEnabled ? WorldPrototypePreferences.shared.enabledWorldIDs : []
        let authored = WorldPrototypeCatalog.feedStories(from: baseAuthored, available: PersonalizedFeedCatalog.current.stories, enabledIDs: enabledWorldIDs)
        let authoredIDs = Set(authored.map(\.id))
        let authoredMerchantIDs = Set(authored.compactMap(FeedMerchantDiversity.merchantID))
        let relationshipStories = BuyerFollowedContentCatalog.stories(
            for: buyerPreview.selected.id,
            topic: selectedTopic,
            followedMerchants: activeRelationshipMerchants
        )
        .filter { story in
            guard !authoredIDs.contains(story.id) else { return false }
            guard let merchantID = FeedMerchantDiversity.merchantID(for: story) else { return true }
            return !authoredMerchantIDs.contains(merchantID)
        }
        guard !relationshipStories.isEmpty else {
            return FeedMerchantDiversity.filtered(authored)
        }

        // Preserve the authored shelf order, then distribute followed-shop
        // edits through it instead of appending a separate branded section.
        // The first card always remains the buyer's strongest authored focus.
        var result: [FeedStory] = []
        var relationshipIndex = 0
        for (index, story) in authored.enumerated() {
            result.append(story)
            // Keep Luke's three authored Figma topics together before the
            // first followed-merchant card enters For You.
            let insertionStride = selectedTopicID == "for-you" ? 3 : 1
            if (index + 1).isMultiple(of: insertionStride),
               relationshipStories.indices.contains(relationshipIndex) {
                result.append(relationshipStories[relationshipIndex])
                relationshipIndex += 1
            }
        }
        result.append(contentsOf: relationshipStories.dropFirst(relationshipIndex))
        return FeedMerchantDiversity.filtered(result)
    }

    /// Real merchant-authored posts are distributed through the story stream.
    /// Topic feeds only accept posts from merchants already represented in the
    /// topic; For You can use the complete personalized post set.
    private var feedEntries: [FeedEntry] {
        let posts = relevantFeedPosts
        var result: [FeedEntry] = []
        var nextPostIndex = 0

        if buyerPreview.selected.id == "luke", selectedTopicID == "for-you" {
            // The prototype's opening sequence is intentional: three authored
            // topics, one followed-merchant card, one merchant post, then Try
            // It Live. Continue the normal story/post cadence after that lead.
            let leadStoryCount = min(4, focusedStories.count)
            result.append(contentsOf: focusedStories.prefix(leadStoryCount).map(FeedEntry.story))
            if posts.indices.contains(nextPostIndex) {
                result.append(.post(posts[nextPostIndex]))
                nextPostIndex += 1
            }
            result.append(.tryOn)

            for (index, story) in focusedStories.dropFirst(leadStoryCount).enumerated() {
                result.append(.story(story))
                if (index + 1).isMultiple(of: 2),
                   posts.indices.contains(nextPostIndex) {
                    result.append(.post(posts[nextPostIndex]))
                    nextPostIndex += 1
                }
            }
        } else {
            for (index, story) in focusedStories.enumerated() {
                result.append(.story(story))
                if (index + 1).isMultiple(of: 2),
                   posts.indices.contains(nextPostIndex) {
                    result.append(.post(posts[nextPostIndex]))
                    nextPostIndex += 1
                }
            }
        }

        let enabledTryOnWorlds = buyerPreview.selected.id == "luke" && selectedTopicID == "for-you" ? WorldPrototypePreferences.shared.enabledWorldIDs : []
        result = WorldPrototypeFeedOrdering.prioritizeTryOn(in: result, enabledWorldIDs: enabledTryOnWorlds)
        if seasonalPlacement == .feedCard {
            result.insert(.seasonalSavings, at: min(1, result.count))
        }
        return result
    }

    private var relevantFeedPosts: [ShopPost] {
        let posts = Array(postService.posts(for: buyerPreview.selected).prefix(6))
        guard selectedTopicID != "for-you" else { return posts }

        let topicMerchantNames = Set(
            focusedStories
                .flatMap { $0.resolvedProducts(from: merchants) }
                .map { normalizedMerchantName($0.merchant.displayName) }
        )
        return posts.filter {
            topicMerchantNames.contains(normalizedMerchantName($0.merchant.name))
        }
    }

    private func normalizedMerchantName(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .filter(\.isLetter)
    }

    private var tryOnProducts: [ResolvedStoryProduct] {
        TryOnExperience.products(stories: focusedStories, merchants: merchants)
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

    /// Expensive feed state stays discrete. Scroll-linked title and utility
    /// motion is handled inside the compositor with `visualEffect`, so this
    /// value never invalidates the feed on each drag frame.
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
                    storyOverride: focusedStories.first { $0.id == focusedStoryID },
                    merchantOverride: merchants,
                    enrichmentProducts: relationshipProducts(for: selectedTopic),
                    closeOnlyNavigation: buyerPreview.selected.usesInlineTopicNavigation
                )
                    .id(focusedStoryID)
            } else {
                selectedFeedContent
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
            ZStack(alignment: .top) {
                if !buyerPreview.selected.usesInlineTopicNavigation || focusedStoryID == nil {
                    topBar
                        .offset(
                            y: destinationFiltersPinned
                                ? -(FeedNavigationStyle.controlSize + GravitySpacing.space16)
                                : 0
                        )
                        .opacity(destinationFiltersPinned ? 0 : 1)
                }

                if selectedTopicID == "holiday-sale",
                   focusedStoryID == nil,
                   holidayFiltersPinned {
                    HolidayFilterRail(
                        labels: ["Women", "Beauty", "Men", "Food & drink"],
                        showsStickyBackdrop: true
                    )
                    .transition(.opacity)
                    .zIndex(2)
                } else if selectedTopicID == "deals",
                          focusedStoryID == nil,
                          dealsFiltersPinned {
                    DealFilterTrain(
                        selectedBand: $selectedDealFilterBand,
                        showsStickyBackdrop: true
                    )
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
            .animation(.easeOut(duration: 0.16), value: destinationFiltersPinned)
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
            isStaticUtilityDestination
                || (usesLightUtilityShelf && !feedChromeIsInverted
                    && !isHolidayHeaderPresented)
                ? .light
                : .dark
        )
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            refreshMerchantSnapshot()
            // Keep the curated assortment authoritative for this prototype and
            // expose it to PDP/store lookups through SampleMerchant.all.
            merchantService.publishLookupMerchants(merchants)
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
            refreshMerchantSnapshot()
            // The feed usually lands after first render; re-publish so PDP and
            // store lookups going through SampleMerchant.all see the same
            // assortment the stories reference.
            merchantService.publishLookupMerchants(merchants)
            merchantService.usingFallbackData = !feedService.isLive
        }
        .onChange(of: merchantService.revision) { _, _ in
            refreshMerchantSnapshot()
            // Preserve one merged lookup graph for PDP/store routing while
            // RemoteMerchantService.followedMerchants remains the clean,
            // relationship-backed source for Following and Deals.
            merchantService.publishLookupMerchants(merchants)
        }
        .onChange(of: visibleStoryID) { _, storyID in
            prefetchFeedMedia(around: storyID)
        }
        .onChange(of: utilityBeltExtendoEnabled) { _, isEnabled in
            if !isEnabled { utilityRailExpansion.reset() }
        }
        .onChange(of: seasonalPlacementRawValue) { oldValue, newValue in
            let wasHeader = SeasonalPlacement(rawValue: oldValue) == .header
            let isHeader = SeasonalPlacement(rawValue: newValue) == .header
            if wasHeader != isHeader {
                if !navigationTopics.contains(where: { $0.id == selectedTopicID }) {
                    selectedTopicID = "for-you"
                } else {
                    resetFeedPosition(for: selectedTopicID)
                }
            } else if selectedTopicID == "for-you" {
                resetFeedPosition(for: "for-you")
            }
        }
        .onChange(of: selectedTopicID) { _, newTopicID in
            holidayFiltersPinned = false
            dealsFiltersPinned = false
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

    @ViewBuilder
    private var selectedFeedContent: some View {
        let destinationTopInset = windowSafeAreaTopInset
            + FeedNavigationStyle.controlSize
            + GravitySpacing.space8

        if selectedTopicID == "holiday-sale" {
            HolidaySaleDestinationFeed(
                products: allBuyerUtilityProducts,
                topInset: destinationTopInset,
                onFilterPinned: { isPinned in
                    holidayFiltersPinned = isPinned
                }
            )
        } else if selectedTopicID == "gift-guides" {
            HolidayGiftGuidesDestinationFeed(
                products: allBuyerUtilityProducts,
                topInset: destinationTopInset
            )
        } else if selectedTopicID == "following" {
            FollowingDestinationFeed(
                products: evergreenRelationshipProducts,
                topInset: destinationTopInset
            )
        } else if selectedTopicID == "deals" {
            DealsDestinationFeed(
                products: evergreenRelationshipProducts,
                topInset: destinationTopInset,
                selectedBand: $selectedDealFilterBand,
                onFilterPinned: { isPinned in
                    dealsFiltersPinned = isPinned
                }
            )
        } else {
            storyFeed
        }
    }

    private var storyFeed: some View {
        GeometryReader { geo in
            let renderedTopicID = selectedTopicID
            let isForYou = selectedTopicID == "for-you"
            let firstEntryID = feedEntries.first?.id
            let utilityScaleRetreat: CGFloat = reduceMotion ? 0 : 0.05
            // The seasonal campaign is a fixed launch surface. Its banner and
            // utility belt stay parked while the first feed card travels over
            // them, avoiding a second fade/scale motion during the native snap.
            // Evergreen For You retains the belt's restrained retreat.
            let keepsLaunchSurfaceFullyVisible = seasonalPlacement == .header
                || utilityRailExpansion.keepsBeltFullyVisible
            let metrics = FeedViewportMetrics(
                containerSize: geo.size,
                safeAreaTop: max(geo.safeAreaInsets.top, windowSafeAreaTopInset),
                isForYou: isForYou
            )
            let layout = metrics.layout

            ZStack {
                FeedRefreshIndicator(
                    state: utilityRailExpansion,
                    reduceMotion: reduceMotion,
                    onAnimationFinished: {
                        utilityRailExpansion.completeRefreshAnimation(
                            reduceMotion: reduceMotion
                        )
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(
                    .top,
                    metrics.safeAreaTop
                        + FeedNavigationStyle.controlSize
                        + GravitySpacing.space16
                )
                .allowsHitTesting(false)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: FeedCardStyle.cardSpacing) {
                        if selectedTopicID == "for-you", buyerPreview.selected.showsUtilityShelf {
                            utilityFeedEntry(
                                containerWidth: geo.size.width,
                                launchInset: metrics.utilityLaunchInset
                            )
                            // The belt is a persistent light surface. Do not
                            // let the active full-bleed card's dark system
                            // chrome invert it while it is being uncovered.
                            .environment(\.colorScheme, .light)
                            // Keep the belt visually parked in its launch
                            // position. Its layout slot still supplies the
                            // native distance to the first snap target, while
                            // the higher feed-card layer scrolls over it. The
                            // evergreen retreat stays compositor-driven; the
                            // seasonal launch surface remains fully fixed.
                            .visualEffect { utility, proxy in
                                let minY = proxy.frame(
                                    in: .scrollView(axis: .vertical)
                                ).minY
                                let retreatProgress = keepsLaunchSurfaceFullyVisible
                                    ? 0
                                    : utilityRetreatProgress(for: minY)
                                return utility
                                    // Pin in both directions at the compositor
                                    // layer. Pulling no longer writes layout
                                    // state on every scroll callback.
                                    .offset(y: -minY)
                                    .scaleEffect(
                                        1 - retreatProgress * utilityScaleRetreat,
                                        anchor: .bottom
                                    )
                                    .opacity(1 - retreatProgress)
                            }
                            .zIndex(0)
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
                            UtilityRailFeedMotionHost(
                                state: utilityRailExpansion,
                                followsBelt: entry.id == firstEntryID
                            ) {
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
                                // Drive the navigation fade directly from the
                                // first card's travel. Only the navigation host
                                // observes this reference-backed progress.
                                .onGeometryChange(for: CGFloat.self) { proxy in
                                    proxy.frame(in: .global).minY
                                } action: { _, minY in
                                    guard entry.id == firstEntryID else { return }
                                    let progress = min(max(1 - max(minY, 0) / 240, 0), 1)
                                    feedChromeTransition.progress = progress

                                    let isAtTop = minY <= 1
                                    guard feedChromeIsInverted != isAtTop else { return }
                                    var transaction = Transaction()
                                    transaction.disablesAnimations = true
                                    withTransaction(transaction) {
                                        feedChromeIsInverted = isAtTop
                                    }
                                }
                                .zIndex(1)
                            }
                            .id(entry.id)
                        }
                    }
                    .scrollTargetLayout()
                    .background {
                        utilityRailPanBridge
                            .frame(width: 0, height: 0)
                    }
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
                // The feed provides its own media contrast beneath the
                // floating topic rail. Disable iOS's automatic scroll-edge
                // treatment so it cannot progressively blur the fixed banner.
                .scrollEdgeEffectHidden(for: .top)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(
                    id: Binding(
                        get: { feedScrollState.positionID ?? visibleStoryID },
                        set: { newValue in
                            // Both feeds exist briefly during the horizontal
                            // replacement transition. Ignore late position
                            // writes from the outgoing topic.
                            guard selectedTopicID == renderedTopicID else { return }
                            feedScrollState.positionID = newValue
                            if let newValue { feedBackdropState.entryID = newValue }
                            guard !feedScrollState.isScrolling else { return }
                            commitVisibleStoryID(newValue)
                        }
                    ),
                    anchor: .top
                )
                .onScrollPhaseChange { _, phase in
                    guard selectedTopicID == renderedTopicID else { return }
                    feedScrollState.isScrolling = phase.isScrolling
                    if phase == .idle {
                        commitVisibleStoryID(feedScrollState.positionID)
                    }
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

    /// Belt resizing and native feed scrolling are mutually exclusive. This
    /// removes the feedback loop that made both layers move during one drag.
    private var utilityRailPanBridge: some View {
        UtilityRailVerticalPanBridge(
            shouldBegin: { verticalVelocity in
                guard selectedTopicID == "for-you",
                      buyerPreview.selected.showsUtilityShelf,
                      !utilityRailExpansion.isRefreshing else { return false }

                if utilityRailExpansion.isExpanded {
                    return true
                }

                let isAtUtilityTarget = feedScrollState.positionID == utilityStoryID
                    || visibleStoryID == utilityStoryID
                return verticalVelocity > 0
                    && !feedChromeIsInverted
                    && isAtUtilityTarget
            },
            onChanged: { verticalTravel in
                if utilityBeltExtendoEnabled {
                    utilityRailExpansion.update(dragTranslation: verticalTravel)
                } else {
                    utilityRailExpansion.updateRefreshOnly(dragTranslation: verticalTravel)
                }
            },
            onEnded: {
                guard utilityRailExpansion.hasActiveInteraction else { return }

                // The native scroll never moved during a belt drag, so only
                // the endpoint height needs to settle here.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    feedScrollState.positionID = utilityStoryID
                    visibleStoryID = utilityStoryID
                }
                let result = utilityRailExpansion.settle(reduceMotion: reduceMotion)
                if result?.requestedRefresh == true {
                    Task { await reloadFeedAfterPull() }
                }
            }
        )
    }

    private func reloadFeedAfterPull() async {
        await feedService.load(force: true)
        if AuthService.shared.hasSession {
            await merchantService.loadMerchants(force: true)
        }
        await postService.loadLukePosts(force: true)
        // Preserve a readable completion beat when all sources are local or cached.
        try? await Task.sleep(for: .milliseconds(420))
        utilityRailExpansion.finishRefresh()
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
    /// Purchased and saved utilities still require their corresponding buyer
    /// tag. Keep shopping may use this assortment for related recommendations
    /// after its verified open-loop products.
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

    /// Luke's authenticated Shop relationship graph is the source of truth
    /// for evergreen Following and Deals. Other preview buyers—and signed-out
    /// development builds—use their explicit bundled relationship fixture,
    /// then retain authored shelves only as a final safe fallback.
    private var activeRelationshipMerchants: [SampleMerchant] {
        if buyerPreview.selected.id == "luke",
           !merchantService.followedMerchants.isEmpty {
            return merchantService.followedMerchants
        }
        return BuyerRelationshipCatalog.followedMerchants(
            for: buyerPreview.selected.id,
            in: merchants
        )
    }

    private func relationshipProducts(for topic: BuyerFeedTopic) -> [ResolvedStoryProduct] {
        BuyerFollowedContentCatalog.products(
            for: buyerPreview.selected.id,
            topic: topic,
            followedMerchants: activeRelationshipMerchants
        )
    }

    private var evergreenRelationshipProducts: [ResolvedStoryProduct] {
        let relationshipMerchants = activeRelationshipMerchants

        guard !relationshipMerchants.isEmpty else { return allBuyerUtilityProducts }

        return relationshipMerchants.flatMap { merchant in
            merchant.products.compactMap { product in
                guard product.imageURL != nil else { return nil }
                return ResolvedStoryProduct(merchant: merchant, product: product)
            }
        }
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
    /// Open-loop utilities can additionally fill their expanded grid with
    /// related real products from the same buyer assortment.
    private func utilityProducts(
        for storyID: String?,
        matchingTag tag: String,
        completesWithRelatedProducts: Bool = false,
        limit: Int = 6
    ) -> [ResolvedStoryProduct] {
        var seen = Set<String>()
        let primary = utilityProducts(for: storyID)
        let candidates = primary + allBuyerUtilityProducts
        let signaled = candidates.filter { $0.product.tags.contains(tag) }
        let source = completesWithRelatedProducts
            ? signaled + candidates
            : signaled

        return source
            .filter { seen.insert($0.id).inserted }
            .prefix(limit)
            .map { $0 }
    }

    private func feedUtilityShelf(containerWidth: CGFloat) -> some View {
        UtilityRailExpansionHost(state: utilityRailExpansion) { cardHeight in
            retargetingRailCarousel(
                containerWidth: containerWidth,
                cardHeight: cardHeight
            )
        }
        .padding(.top, holidayUtilityShelfTopPadding)
        .frame(width: containerWidth)
    }

    private var holidayUtilityShelfTopPadding: CGFloat { 18 }

    @ViewBuilder
    private func utilityFeedEntry(
        containerWidth: CGFloat,
        launchInset: CGFloat
    ) -> some View {
        if seasonalPlacement == .header {
            let baseHeaderHeight = containerWidth * (428 / 402)
            let utilityOverlap: CGFloat = 70
            // Carry the campaign surface behind the utility card and finish
            // its fade at the card's lower edge. Increasing the negative
            // stack spacing by the same amount preserves the belt position.
            let fadeExtension = UtilityRailMetrics.cardHeight
                + holidayUtilityShelfTopPadding
                - utilityOverlap

            VStack(spacing: -(utilityOverlap + fadeExtension)) {
                HolidayFeedHeader(
                    width: containerWidth,
                    height: baseHeaderHeight + fadeExtension,
                    playbackEnabled: visibleStoryID == nil
                        || visibleStoryID == utilityStoryID
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

    private func retargetingRailCarousel(
        containerWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        let railWidth = min(max(containerWidth - 48, 300), 320)

        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: GravitySpacing.space10) {
                if buyerPreview.selected.utility.showsOrders,
                   utilityBelt.isEnabled(.orders) {
                    orderTrackingRailCard(width: railWidth, height: cardHeight)
                }

                if utilityBelt.isEnabled(.buyAgain),
                   let storyID = buyerPreview.selected.utility.buyAgainStoryID {
                    let products = utilityProducts(
                        for: storyID,
                        matchingTag: "buyer-buy-again"
                    )
                    if !products.isEmpty {
                        utilityProductRail(
                            title: "Buy again",
                            products: products,
                            maximumWidth: railWidth,
                            height: cardHeight
                        )
                    }
                }

                if buyerPreview.selected.utility.showsCart,
                   utilityBelt.isEnabled(.cart), let cartItem = cartSyncItem {
                    cartSyncCard(item: cartItem, width: railWidth, height: cardHeight)
                }

                if utilityBelt.isEnabled(.saves),
                   let storyID = buyerPreview.selected.utility.recentlyViewedStoryID {
                    let products = utilityProducts(
                        for: storyID,
                        matchingTag: "buyer-saved"
                    )
                    if !products.isEmpty {
                        utilityProductRail(
                            title: "Your saves",
                            products: products,
                            maximumWidth: railWidth,
                            height: cardHeight
                        )
                    }
                }

                if utilityBelt.isEnabled(.keepShopping),
                   let storyID = buyerPreview.selected.utility.ownedAdjacencyStoryID {
                    let products = utilityProducts(
                        for: storyID,
                        matchingTag: "buyer-open-loop",
                        completesWithRelatedProducts: true
                    )
                    if !products.isEmpty {
                        utilityProductRail(
                            title: "Keep shopping",
                            products: products,
                            maximumWidth: railWidth,
                            height: cardHeight
                        )
                    }
                }

                ForEach(UtilityBeltPromotionCard.Kind.allCases, id: \.self) { kind in
                    if utilityBelt.isEnabled(kind.beltItem) {
                        UtilityBeltPromotionCard(kind: kind, width: railWidth, height: cardHeight)
                    }
                }
            }
            .padding(.horizontal, GravitySpacing.space12)
            .padding(.vertical, UtilityRailMetrics.carouselVerticalPadding)
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

    private func cartSyncCard(
        item: ResolvedStoryProduct,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
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
            .padding(GravitySpacing.space12)
            .frame(width: width, height: height)
            .utilityRailSurface(
                fill: utilitySurfaceFill,
                border: utilitySurfaceBorder
            )
        }
        .buttonStyle(.plain)
    }

    private var deliveryMerchants: [SampleMerchant] {
        var seen = Set<String>()
        return defaultUtilityProducts
            .map(\.merchant)
            .filter { seen.insert($0.id).inserted && !$0.products.isEmpty }
    }

    @ViewBuilder
    private func orderTrackingRailCard(width: CGFloat, height: CGFloat) -> some View {
        OrderTrackingUtilityCard(width: width, height: height) {
            coordinator.navigateToPage(1)
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
        maximumWidth: CGFloat,
        height: CGFloat
    ) -> some View {
        UtilityProductRailCard(
            title: title,
            products: products,
            maximumWidth: maximumWidth,
            height: height,
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

    /// Every entry owns the final full-bleed geometry from its resting state.
    /// Scrolling only translates the stable snap slots; it never resizes a
    /// card mid-gesture, so the first takeover and later cards behave alike.
    @ViewBuilder
    private func feedEntryCard(
        _ entry: FeedEntry,
        layout: FeedViewportLayout,
        firstEntryID: String?
    ) -> some View {
        let isFirstEntry = entry.id == firstEntryID
        let isSnappedEntry = visibleStoryID == entry.id
        let expansionProgress = firstStoryExpansionProgress
        let hasEnteredFullBleedFeed = expansionProgress >= 0.999
        let lockedTakeoverProgress: CGFloat = {
            if isFirstEntry { return expansionProgress }
            // Every card keeps the same full-width slot, but only the card
            // locked at the top loses its top radii. The incoming card stays
            // rounded so its peek reads clearly against the white canvas.
            return hasEnteredFullBleedFeed && isSnappedEntry ? 1 : 0
        }()
        let feedCornerRadius = FeedCardStyle.cornerRadius
        // Keep the card silhouette stable while dragging and snapping. A
        // Home-level scroll flag invalidated the entire page (including the
        // topic rail), which made the navigation visibly blink.
        let topCornerRadius = feedCornerRadius
        let chromeOpacity = Double(1 - lockedTakeoverProgress)
        let usesDarkFeedbackIcons: Bool = {
            if case .tryOn = entry { return true }
            return false
        }()
        let includesVolumeControl: Bool = {
            if case .post = entry { return true }
            return false
        }()
        let feedbackForegroundColor: Color = usesDarkFeedbackIcons ? .black : .white

        ZStack(alignment: .topTrailing) {
            switch entry {
        case .tryOn:
            TryOnFeedCard(
                products: tryOnProducts,
                width: layout.cardWidth,
                height: layout.cardHeight,
                foregroundTopPadding: layout.foregroundTopPadding,
                titleTrailingPadding: 64,
                scrollPinnedTitleTop: layout.pinnedTitleTop
            ) {
                coordinator.resetScrollState()
                coordinator.pushRoute(.tryOnStudio)
            }
            .matchedTransitionSource(id: TryOnExperience.cardID, in: namespace) { source in
                source
                    .background(.clear)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: feedCornerRadius,
                            style: .continuous
                        )
                    )
            }

        case .seasonalSavings:
            HolidayFeedCard(
                width: layout.cardWidth,
                height: layout.cardHeight,
                products: seasonalSavingsProducts,
                topCornerRadius: topCornerRadius,
                bottomCornerRadius: feedCornerRadius,
                foregroundTopPadding: layout.foregroundTopPadding,
                expansionProgress: expansionProgress,
                borderOpacity: 0.12 * chromeOpacity,
                shadowOpacity: chromeOpacity,
                playbackEnabled: isSnappedEntry
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
                scrollPinnedTitleTop: layout.pinnedTitleTop,
                scrollMotionEnabled: false
            )

        case let .post(post):
            paginatedPostCard(
                post,
                width: layout.cardWidth,
                height: layout.cardHeight,
                cornerRadius: topCornerRadius,
                bottomCornerRadius: feedCornerRadius,
                foregroundTopPadding: layout.pinnedTitleTop,
                borderOpacity: 0.16 * chromeOpacity,
                shadowOpacity: chromeOpacity,
                scrollMotionEnabled: false
            )
            }

            PrototypeFeedbackActions(
                layout: .vertical,
                foregroundColor: feedbackForegroundColor,
                appliesShadow: !usesDarkFeedbackIcons,
                includesOverflow: true,
                includesVolume: includesVolumeControl,
                onOverflowTap: { showsBuyerSwitcher = true }
            )
            .padding(.top, layout.pinnedTitleTop)
            .padding(.trailing, GravitySpacing.space12)
            .visualEffect { actions, proxy in
                let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
                let distance = max(minY - layout.pinnedTitleTop, 0)
                let progress = min(max(1 - distance / 100, 0), 1)
                return actions.opacity(progress)
            }
            .allowsHitTesting(hasEnteredFullBleedFeed)
            .zIndex(4)
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
        scrollPinnedTitleTop: CGFloat? = nil,
        scrollMotionEnabled: Bool = true
    ) -> some View {
        let motionIsReduced = reduceMotion
        let appliesScrollMotion = !motionIsReduced && scrollMotionEnabled
        let storyIndex = focusedStories.firstIndex(where: { $0.id == story.id })

        Group {
            if story.id != "kyle-argizari-lighting",
               let collection = MerchantCollectionCatalog.presentation(for: story.id) {
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
                    scrollPinnedHeaderTop: scrollPinnedTitleTop,
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
                    titleTrailingPadding: 64,
                    scrollPinnedTitleTop: scrollPinnedTitleTop,
                    showsDelayedExploreButton: story.format == .world,
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
                    color: .black.opacity(0.10 * shadowOpacity),
                    radius: 12,
                    y: 5
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
            merchants: merchants,
            width: width,
            height: height,
            isActive: visibleStoryID == id,
            cornerRadius: cornerRadius,
            bottomCornerRadius: bottomCornerRadius,
            foregroundTopPadding: foregroundTopPadding,
            headerTrailingPadding: 64,
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

    private var feedBackdropColors: [String: Color] {
        Dictionary(uniqueKeysWithValues: feedEntries.map { entry in
            let color: Color = switch entry {
            case let .story(story): Color(hex: story.accentHex)
            case let .post(post): merchants.first {
                normalizedMerchantName($0.displayName)
                    == normalizedMerchantName(post.merchant.name)
            }?.brandColor ?? Color(hex: "#343038")
            case .seasonalSavings: Color(hex: "#49308F")
            case .tryOn: Color(hex: "#4A4745")
            }
            return (entry.id, color)
        })
    }

    private var feedAmbientBackdrop: some View {
        FeedAmbientBackdrop(
            state: feedBackdropState,
            colorsByEntryID: feedBackdropColors,
            utilityEntryID: utilityStoryID
        )
    }

    /// Resolves a For You story to its canonical topic. An exact lead-story
    /// match wins over secondary membership so cards such as New York graphics
    /// can own a destination even when they also appear in Type & transit.
    private func openTopic(for story: FeedStory) {
        // Authored buyer shelves use the same explicit source ID as the feed
        // card so NavigationStack can perform the native shared-view zoom.
        if buyerPreview.selected.usesInlineTopicNavigation,
           selectedTopic.storyIDs.contains(story.id) {
            coordinator.resetScrollState()
            expandingStoryID = story.id
            // Route in the same interaction turn. Waiting for another main-
            // actor pass made a topic tap feel ignored on a physical device,
            // especially while the active card's video was decoding.
            coordinator.pushRoute(
                .story(storyId: story.id, sourceId: story.id)
            )
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
            coordinator.pushRoute(
                .story(storyId: story.id, sourceId: story.id)
            )
            return
        }

        coordinator.resetScrollState()
        expandingStoryID = story.id

        coordinator.pushRoute(
            .topicExpanded(topicId: destination.id, sourceStoryId: story.id)
        )
    }

    // MARK: - Top Bar (Quick Links)

    private var topBar: some View {
        BuyerFeedNavigationBar(
            profile: buyerPreview.selected,
            topics: navigationTopics,
            selectedTopicID: selectedTopicID,
            chromeTransitionState: feedChromeTransition,
            usesInverseStyle: isHolidayHeaderPresented
                || selectedTopicID == "holiday-sale"
                || selectedTopicID == "gift-guides",
            usesFeedBackdropStyle: !isStaticUtilityDestination
                && (selectedTopicID != "for-you" || feedChromeIsInverted),
            usesHolidayPillStyle: seasonalPlacement == .header,
            selectionNamespace: topicSelectionNamespace,
            onSelectTopic: selectTopic,
            onSelectBuyer: {
                withAnimation(.easeOut(duration: 0.18)) {
                    showsBuyerSwitcher = true
                }
            }
        )
        .background(alignment: .top) {
            if selectedTopicID == "following", focusedStoryID == nil {
                StickyFilterBackdrop(height: 164, opaqueStop: 0.60)
            }
        }
        .sheet(isPresented: $showsBuyerSwitcher) {
            buyerSwitcher
        }
        // Deliberately no bar background: the active feed film or topic cover
        // continues through both the topic rail and the status-bar safe area.
    }

    private var buyerSwitcher: some View {
        HomeFeedControlsSheet(
            profiles: BuyerPreviewStore.profiles,
            selectedProfileID: buyerPreview.selected.id,
            seasonalPlacement: seasonalPlacementBinding,
            extendoEnabled: $utilityBeltExtendoEnabled,
            beltPreferences: utilityBelt,
            worldPreferences: WorldPrototypePreferences.shared,
            onSelectProfile: selectBuyer
        )
        .environment(\.colorScheme, .light)
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
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.20)) {
            focusedStoryID = nil
            selectedTopicID = topic.id
        }
    }

    private func refreshMerchantSnapshot() {
        let refreshedMerchants = LocalMerchantService.mergeMerchants([
            merchantService.followedMerchants,
            feedService.merchants,
            HomePage.bundledMerchantSnapshot,
            HypothesisShelfCatalog.merchants,
            HomePage.personalizedMerchantSnapshot,
        ])
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            merchants = refreshedMerchants
        }
        prefetchFeedMedia(around: visibleStoryID)
    }

    private func prefetchFeedMedia(around storyID: String?) {
        let stories = focusedStories
        guard !stories.isEmpty else { return }
        let currentIndex = storyID.flatMap { id in
            stories.firstIndex(where: { $0.id == id })
        } ?? 0
        let urls = stories[currentIndex..<min(currentIndex + 3, stories.endIndex)]
            .compactMap {
                $0.lifestyleImageURL(
                    from: merchants,
                    format: .portrait,
                    role: "feed-hero"
                )
            }

        Task(priority: .utility) {
            await ImageURLCache.shared.prefetch(urls)
        }
    }

    /// Establishes the canonical entry position for every top-level feed.
    /// For You always begins on the utility shelf; topic feeds begin on their
    /// first authored story. No caller should use `nil` as a reset signal,
    /// because SwiftUI interprets that as permission to restore an old offset.
    private func resetFeedPosition(for topicID: String) {
        expandingStoryID = nil

        if topicID == "for-you" {
            feedChromeIsInverted = false
            utilityRailExpansion.reset()
            let targetID = buyerPreview.selected.showsUtilityShelf
                ? utilityStoryID
                : feedEntries.first?.id
            feedScrollState.positionID = targetID
            feedBackdropState.entryID = targetID
            feedChromeTransition.progress = targetID == utilityStoryID ? 0 : 1
            visibleStoryID = targetID
        } else if let topic = navigationTopics.first(where: { $0.id == topicID }) {
            let targetID = buyerPreview.stories(
                for: topic,
                in: PersonalizedFeedCatalog.current
            ).first?.id
            feedScrollState.positionID = targetID
            feedBackdropState.entryID = targetID
            feedChromeTransition.progress = 1
            visibleStoryID = targetID
        } else {
            feedScrollState.positionID = nil
            feedBackdropState.entryID = nil
            feedChromeTransition.progress = 0
            visibleStoryID = nil
        }

    }

    private func commitVisibleStoryID(_ newValue: String?) {
        guard visibleStoryID != newValue else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            visibleStoryID = newValue
        }
    }

    /// The first card travels roughly one utility-card height before it has
    /// visually taken over the belt. Mapping that distance linearly keeps the
    /// fade and recession attached to the drag instead of feeling animated.
    nonisolated private func utilityRetreatProgress(for minY: CGFloat) -> CGFloat {
        let retreatDistance = UtilityRailMetrics.cardHeight + GravitySpacing.space24
        return min(max(-minY / retreatDistance, 0), 1)
    }

}

#Preview {
    @Previewable @Namespace var namespace
    NavigationStack {
        HomePage(namespace: namespace)
    }
    .environment(NavigationCoordinator())
}
