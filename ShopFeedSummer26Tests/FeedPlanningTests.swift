import XCTest
import SwiftUI
import AVFoundation
@testable import ShopFeedSummer26

final class FeedPlanningTests: XCTestCase {
    @MainActor
    func testLibraryForYouPromotesPriceResearchWithoutChangingItsProductOrder() throws {
        guard ShopCanvasLibrary.isEnabled else { throw XCTSkip("Library-only editorial opening") }
        let buyer = ShopCanvasLibrary.profile
        let topic = try XCTUnwrap(buyer.topics.first { $0.id == "for-you" })
        let input = HomeFeedPlanner.Input(
            buyer: buyer,
            topic: topic,
            catalog: ShopCanvasLibrary.catalog,
            merchants: ShopCanvasLibrary.merchants,
            followedMerchants: [],
            posts: [],
            enabledWorldIDs: [],
            enabledContentKinds: Set(FeedContentKind.allCases),
            seasonalPlacement: .off
        )
        let plan = HomeFeedPlanner.plan(input)
        let promoted = try XCTUnwrap(plan.stories.first)
        XCTAssertEqual(promoted.id, "library-edit-norda-price-research")
        XCTAssertEqual(
            promoted.products.map(\.productID),
            ShopCanvasLibrary.stories.first { $0.id == "library-edit-norda-price-research" }?.products.map(\.productID)
        )
    }

    @MainActor
    func testDemoForYouOpensWithFiveVideoStoriesBeforeMixedCards() throws {
        let request = try demoInput(
            seasonalPlacement: .feedCard,
            worldIDs: [WorldPrototypeCatalog.tryOnID, WorldPrototypeCatalog.tryFavesID]
        )
        let plan = HomeFeedPlanner.plan(request)
        let expected = [
            "kyle-argizari-lighting",
            "shelf-luke-9-streetwear-caps-and-tees",
            "shelf-luke-2-sculptural-living-room-pieces",
            "shelf-luke-10-performance-sneakers-edit",
            "shelf-luke-7-stylish-travel-essentials",
        ]
        XCTAssertEqual(Array(plan.entries.prefix(5).map(\.id)), expected)
        XCTAssertEqual(Array(plan.stories.prefix(5).map(\.id)), expected,
            "Media prefetch must follow the same story order as the visible feed")
        for entry in plan.entries.prefix(5) {
            guard case let .story(story) = entry else {
                XCTFail("The opening must not be interrupted by mixed card formats")
                continue
            }
            XCTAssertFalse(story.rendersAsMerchantCard)
            XCTAssertNotNil(FeedCoverCatalog.presentation(for: story)?.source.videoURL)
        }
        let remainderIDs = Set(plan.entries.dropFirst(5).map(\.id))
        XCTAssertTrue(remainderIDs.contains("suggested-collections"))
        XCTAssertTrue(remainderIDs.contains("shop-post-demo-post"))
        XCTAssertTrue(remainderIDs.contains(TryOnExperience.cardID))
        XCTAssertTrue(remainderIDs.contains(TryFavesExperience.cardID))
        XCTAssertTrue(remainderIDs.contains("seasonal-savings"))
        XCTAssertEqual(Set(plan.entries.map(\.id)).count, plan.entries.count)
    }

    @MainActor
    func testDemoOpeningLeavesOtherBuyersAndTopicFeedsInTheirAuthoredOrder() throws {
        for (buyerID, topicID) in [("mikhail", "for-you"), ("luke", "living")] {
            let request = try demoInput(buyerID: buyerID, topicID: topicID)
            XCTAssertEqual(HomeFeedPlanner.plan(request).stories.map(\.id), request.topic.storyIDs)
        }
    }

    @MainActor
    func testDemoOpeningDoesNotForceDisabledRecommendationsBackIntoTheFeed() throws {
        let request = try demoInput(contentKinds: [.posts])
        XCTAssertEqual(HomeFeedPlanner.plan(request).entries.map(\.id), ["shop-post-demo-post"])
    }

    @MainActor
    private func demoInput(
        buyerID: String = "luke",
        topicID: String = "for-you",
        seasonalPlacement: SeasonalPlacement = .off,
        worldIDs: Set<String> = [],
        contentKinds: Set<FeedContentKind> = Set(FeedContentKind.allCases)
    ) throws -> HomeFeedPlanner.Input {
        if ShopCanvasLibrary.isEnabled { throw XCTSkip("Legacy buyer-opening fixtures belong to the preserved demo app") }
        let buyer = try XCTUnwrap(BuyerPreviewStore.profiles.first { $0.id == buyerID })
        let topic = try XCTUnwrap(buyer.topics.first { $0.id == topicID })
        let merchants = LocalMerchantService.mergeMerchants([
            LocalMerchantService.loadMerchants(),
            HypothesisShelfCatalog.merchants,
            BuyerPersonalizationCatalog.merchants,
        ])
        let post = ShopPost(id: "demo-post", title: "A merchant post", caption: nil, subtitle: nil,
            media: .image(url: URL(string: "https://example.invalid/post.jpg")!, width: nil, height: nil),
            merchant: .init(id: "demo-merchant", name: "Example", logoURL: nil, websiteURL: nil),
            actionURL: nil)
        return HomeFeedPlanner.Input(buyer: buyer, topic: topic,
            catalog: PersonalizedFeedCatalog.current, merchants: merchants,
            followedMerchants: [], posts: [post], enabledWorldIDs: worldIDs,
            enabledContentKinds: contentKinds, seasonalPlacement: seasonalPlacement)
    }

    @MainActor
    func testRefreshUpdatesStoryContentWithoutChangingIDsOrVersion() {
        let original = input(stories: [story(title: "Original edit")])
        XCTAssertEqual(HomeFeedPlanner.plan(original).stories.first?.title, "Original edit")

        let refreshed = input(stories: [story(title: "Updated edit")])
        XCTAssertEqual(HomeFeedPlanner.plan(refreshed).stories.first?.title, "Updated edit")
    }

    @MainActor
    func testRefreshReevaluatesCustomIntentWhenProductCountIsUnchanged() {
        let original = input(merchants: [merchant(products: [product(1, "Trail cap")])], intent: "hats")
        XCTAssertEqual(HomeFeedPlanner.plan(original).stories.first?.products.map(\.productID), [1])

        // Same merchant, product ID, and inventory size; different content.
        let refreshed = input(merchants: [merchant(products: [product(1, "Table lamp")])], intent: "hats")
        XCTAssertTrue(HomeFeedPlanner.plan(refreshed).stories.isEmpty)
    }

    @MainActor
    func testCompositionToggleHidesCardsWithoutLosingAvailableCounts() {
        let original = input(stories: [story(title: "An edit")])
        let hidden = HomeFeedPlanner.Input(
            buyer: original.buyer, topic: original.topic, catalog: original.catalog,
            merchants: [], followedMerchants: [], posts: [], enabledWorldIDs: [],
            enabledContentKinds: [], seasonalPlacement: .off
        )
        let plan = HomeFeedPlanner.plan(hidden)
        XCTAssertTrue(plan.entries.isEmpty)
        XCTAssertEqual(plan.availableContentCounts[.recommendations], 1)
    }

    @MainActor
    func testHatSynonymsDoNotAdmitUnrelatedProducts() {
        let assortment = [merchant(products: [
            product(1, "Trail cap"), product(2, "Running shoes"), product(3, "Wool beanie"),
        ])]
        let request = input(merchants: assortment, intent: "Hats I like")
        let stories = HomeFeedPlanner.plan(request).stories
        XCTAssertEqual(stories.flatMap(\.products).map(\.productID), [1, 3])
        XCTAssertEqual(stories.flatMap(\.products).map(\.merchantID), ["test-merchant", "test-merchant"])
    }

    @MainActor
    func testReturningToAFeedKeepsItsOwnAssortment() {
        let assortment = [merchant(products: [product(1, "Trail cap"), product(2, "Table lamp")])]
        let hats = input(merchants: assortment, intent: "hats")
        let lamps = input(merchants: assortment, intent: "lamps")
        XCTAssertEqual(HomeFeedPlanner.plan(hats).stories.flatMap(\.products).map(\.productID), [1])
        XCTAssertEqual(HomeFeedPlanner.plan(lamps).stories.flatMap(\.products).map(\.productID), [2])
        XCTAssertEqual(HomeFeedPlanner.plan(hats).stories.flatMap(\.products).map(\.productID), [1])
    }

    @MainActor
    func testCurrentCatalogInvalidatesItsSupplementalMergeOnReplacement() {
        let previous = PersonalizedFeedCatalog.remote
        defer { PersonalizedFeedCatalog.remote = previous }
        PersonalizedFeedCatalog.remote = input(stories: [story(title: "Before refresh")]).catalog
        XCTAssertEqual(PersonalizedFeedCatalog.current.stories.first { $0.id == "test-story" }?.title, "Before refresh")
        PersonalizedFeedCatalog.remote = input(stories: [story(title: "After refresh")]).catalog
        XCTAssertEqual(PersonalizedFeedCatalog.current.stories.first { $0.id == "test-story" }?.title, "After refresh")
    }

    func testMediaPlaybackPolicyRequiresVisibilityAndRespectsUserAndSystemConstraints() {
        XCTAssertTrue(MediaPlaybackPolicy.shouldPlay(
            requested: true, visible: true, reduceMotion: false,
            lowPowerMode: false, sceneIsActive: true
        ))
        XCTAssertFalse(MediaPlaybackPolicy.shouldPlay(
            requested: true, visible: false, reduceMotion: false,
            lowPowerMode: false, sceneIsActive: true
        ))
        XCTAssertFalse(MediaPlaybackPolicy.shouldPlay(
            requested: true, visible: true, reduceMotion: true,
            lowPowerMode: false, sceneIsActive: true
        ))
        XCTAssertFalse(MediaPlaybackPolicy.shouldPlay(
            requested: true, visible: true, reduceMotion: false,
            lowPowerMode: true, sceneIsActive: true
        ))
        XCTAssertFalse(MediaPlaybackPolicy.shouldPlay(
            requested: true, visible: true, reduceMotion: false,
            lowPowerMode: false, sceneIsActive: false
        ))
    }

    @MainActor
    func testCoverSurfacesShareMutedPlaybackAndLoopOnlyTheirSelectedExcerpt() async throws {
        let url = try XCTUnwrap(NikeSkimsWorldMedia.coverFilmURL)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        let surfaces = (0..<2).map { _ in
            LoopingVideoPlayer.PlayerUIView(urls: [url], loops: true, loopDuration: 0.5,
                playbackEnabled: false, playbackGroupID: "test-cover-handoff", videoGravity: .resizeAspectFill)
        }
        surfaces.forEach {
            $0.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            window.rootViewController?.view.addSubview($0)
        }
        window.isHidden = false
        defer { surfaces.forEach { $0.removeFromSuperview() }; window.isHidden = true }
        let players = surfaces.compactMap { surface in
            surface.layer.sublayers?.compactMap { ($0 as? AVPlayerLayer)?.player }.first
        }
        XCTAssertEqual(players.count, 2)
        let player = try XCTUnwrap(players.first)
        XCTAssertTrue(player === players.last)
        XCTAssertTrue(player.isMuted)
        let looped = expectation(description: "Short excerpt loops twice, not the full source film")
        looped.expectedFulfillmentCount = 2
        let observer = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
            object: nil, queue: .main) { notification in
                guard let item = notification.object as? AVPlayerItem,
                      (item.asset as? AVURLAsset)?.url == url else { return }
                XCTAssertLessThanOrEqual(item.currentTime().seconds, 0.55)
                looped.fulfill()
            }
        defer { NotificationCenter.default.removeObserver(observer) }
        surfaces[0].setPlaybackEnabled(true)
        await fulfillment(of: [looped], timeout: 5)
        surfaces[1].setPlaybackEnabled(true)
        surfaces[0].setPlaybackEnabled(false)
        XCTAssertEqual(player.rate, 1)
        surfaces[1].setPlaybackEnabled(false)
        XCTAssertEqual(player.rate, 0)
    }

    @MainActor
    func testMediaRuntimeRefreshesLowPowerModeForActivePlayers() {
        var lowPowerMode = false
        let runtime = MediaPlaybackRuntime { lowPowerMode }
        XCTAssertFalse(runtime.isLowPowerModeEnabled)

        lowPowerMode = true
        runtime.refreshSystemState()

        XCTAssertTrue(runtime.isLowPowerModeEnabled)
    }

    func testExplicitLocalWorldContextOverridesSubjectAndBuyerContext() {
        var context = WorldContext()
        context.set(.init(key: "budget", value: "500", source: .inferred, scope: .buyer))
        context.set(.init(key: "budget", value: "200", source: .observed, scope: .subject))
        context.set(.init(key: "budget", value: "75", source: .stated, scope: .local))
        XCTAssertEqual(context.value(for: "budget"), "75")
        XCTAssertEqual(context.resolvedFacts.count, 1)
    }

    func testWorldSaveAndRejectRemainMutuallyExclusive() {
        let definition = WorldDefinition(id: "test-world", title: "A trip", purpose: .intent,
            subject: "Buyer", primaryExperience: .merchandised,
            availableExperiences: [.merchandised], lifetime: .session, paths: [])
        let session = WorldSession(definition: definition)
        session.send(.saveProduct("merchant-1"))
        session.send(.rejectProduct("merchant-1"))
        XCTAssertTrue(session.state.savedProductIDs.isEmpty)
        XCTAssertEqual(session.state.rejectedProductIDs, ["merchant-1"])
        session.send(.saveProduct("merchant-1"))
        XCTAssertEqual(session.state.savedProductIDs, ["merchant-1"])
        XCTAssertTrue(session.state.rejectedProductIDs.isEmpty)
    }

    @MainActor
    private func input(stories: [FeedStory] = [], merchants: [SampleMerchant] = [], intent: String? = nil) -> HomeFeedPlanner.Input {
        let topic = BuyerFeedTopic(id: "test-feed", label: "Test feed", sourceCategoryID: "for-you",
            storyIDs: stories.map(\.id), evidence: .discovery, customIntent: intent)
        let buyer = BuyerPreviewProfile(id: "test-buyer", name: "Test buyer", symbol: "person",
            accentHex: "#333333", avatarAssetName: nil, topics: [topic], utility: .none)
        return HomeFeedPlanner.Input(buyer: buyer, topic: topic,
            catalog: .init(version: 1, topics: [], stories: stories),
            merchants: merchants, followedMerchants: [], posts: [], enabledWorldIDs: [],
            enabledContentKinds: Set(FeedContentKind.allCases), seasonalPlacement: .off)
    }

    private func story(title: String) -> FeedStory {
        FeedStory(id: "test-story", eyebrow: "An edit", title: title, subtitle: "A shortlist",
            format: .shortlist, topicKeys: [], accentHex: "#333333", coverImageName: nil,
            destinationLabel: "Explore", products: [])
    }

    private func product(_ id: Int, _ title: String) -> SampleMerchant.Product {
        .init(id: id, title: title, price: "50.00", handle: "product-\(id)", productType: nil,
            vendor: "Example", imageURL: "https://example.invalid/product-\(id).jpg", shopURL: nil, tags: [])
    }

    private func merchant(products: [SampleMerchant.Product]) -> SampleMerchant {
        .init(id: "test-merchant", name: "Example", description: "", rating: 0,
            totalRatings: 0, totalReviews: 0, primaryColor: .black, secondaryColor: .white,
            collections: [], products: products, featuredImageURLs: [], logoImageURL: nil,
            wordmarkImageURL: nil, coverImageURL: nil, videoURL: nil, coverDominantColor: nil,
            productCategory: nil)
    }
}
