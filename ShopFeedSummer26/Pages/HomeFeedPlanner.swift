import Foundation

/// A resolved, render-ready feed. HomePage owns viewport and navigation state;
/// this module owns assortment, ordering, and composition decisions.
struct HomeFeedPlan {
    let stories: [FeedStory]
    let entries: [FeedEntry]
    let availableContentCounts: [FeedContentKind: Int]
}

@MainActor
enum HomeFeedPlanner {
    struct Input {
        let buyer: BuyerPreviewProfile
        let topic: BuyerFeedTopic
        let catalog: PersonalizedFeedCatalog
        let merchants: [SampleMerchant]
        let followedMerchants: [SampleMerchant]
        let posts: [ShopPost]
        let enabledWorldIDs: Set<String>
        let enabledContentKinds: Set<FeedContentKind>
        let seasonalPlacement: SeasonalPlacement
    }

    private struct Key: Hashable {
        let buyerID: String
        let topicID: String
        let storyIDs: [String]
        let catalogVersion: Int
        let catalogStoryIDs: [String]
        let merchantInventory: [String]
        let followedMerchantIDs: [String]
        let postIDs: [String]
        let worldIDs: [String]
        let contentKinds: [String]
        let seasonalPlacement: String
    }

    private static var cached: (key: Key, plan: HomeFeedPlan)?

    static func plan(_ input: Input) -> HomeFeedPlan {
        let key = Key(
            buyerID: input.buyer.id,
            topicID: input.topic.id,
            storyIDs: input.topic.storyIDs,
            catalogVersion: input.catalog.version,
            catalogStoryIDs: input.catalog.stories.map(\.id),
            merchantInventory: input.merchants.map { "\($0.id):\($0.products.count)" },
            followedMerchantIDs: input.followedMerchants.map(\.id),
            postIDs: input.posts.map(\.id),
            worldIDs: input.enabledWorldIDs.sorted(),
            contentKinds: input.enabledContentKinds.map(\.rawValue).sorted(),
            seasonalPlacement: input.seasonalPlacement.rawValue
        )
        if let cached, cached.key == key { return cached.plan }

        let stories = stories(for: input)
        let posts = relevantPosts(input.posts, buyer: input.buyer, topic: input.topic, stories: stories, merchants: input.merchants)
        var entries = distribute(stories: stories, posts: posts, buyerID: input.buyer.id, topicID: input.topic.id)
        entries = WorldPrototypeFeedOrdering.prioritizeTryOn(in: entries, enabledWorldIDs: input.enabledWorldIDs)
        entries = WorldPrototypeFeedOrdering.insertTryFaves(in: entries, enabledWorldIDs: input.enabledWorldIDs)
        let availableContentCounts = contentCounts(in: entries, enabledWorldIDs: input.enabledWorldIDs)
        entries = FeedCompositionFilter.apply(to: entries, enabledKinds: input.enabledContentKinds, enabledWorldIDs: input.enabledWorldIDs)
        if input.seasonalPlacement == .feedCard {
            entries.insert(.seasonalSavings, at: min(1, entries.count))
        }

        let plan = HomeFeedPlan(
            stories: stories,
            entries: entries,
            availableContentCounts: availableContentCounts
        )
        cached = (key, plan)
        return plan
    }

    private static func contentCounts(
        in entries: [FeedEntry],
        enabledWorldIDs: Set<String>
    ) -> [FeedContentKind: Int] {
        entries.reduce(into: [:]) { counts, entry in
            let kind: FeedContentKind? = switch entry {
            case .post: .posts
            case .story(let story): enabledWorldIDs.contains(story.id)
                ? nil
                : (story.rendersAsMerchantCard ? .merchantCards : .recommendations)
            case .tryOn: enabledWorldIDs.contains(WorldPrototypeCatalog.tryOnID) ? nil : .recommendations
            case .tryFaves: nil
            case .seasonalSavings: nil
            }
            if let kind { counts[kind, default: 0] += 1 }
        }
    }

    private static func stories(for input: Input) -> [FeedStory] {
        let baseAuthored = authoredStories(topic: input.topic, catalog: input.catalog)
        let authored = WorldPrototypeCatalog.feedStories(
            from: baseAuthored,
            available: input.catalog.stories,
            enabledIDs: input.enabledWorldIDs
        )
        let authoredIDs = Set(authored.map(\.id))
        let authoredMerchantIDs = Set(authored.compactMap(FeedMerchantDiversity.merchantID))
        let relationshipStories = BuyerFollowedContentCatalog.stories(
            for: input.buyer.id,
            topic: input.topic,
            followedMerchants: input.followedMerchants
        )
        .filter { story in
            guard !authoredIDs.contains(story.id) else { return false }
            guard let merchantID = FeedMerchantDiversity.merchantID(for: story) else { return true }
            return !authoredMerchantIDs.contains(merchantID)
        }
        guard !relationshipStories.isEmpty else {
            return FeedMerchantDiversity.filtered(authored)
        }

        var result: [FeedStory] = []
        var relationshipIndex = 0
        for (index, story) in authored.enumerated() {
            result.append(story)
            let insertionStride = input.topic.id == "for-you" ? 3 : 1
            if (index + 1).isMultiple(of: insertionStride),
               relationshipStories.indices.contains(relationshipIndex) {
                result.append(relationshipStories[relationshipIndex])
                relationshipIndex += 1
            }
        }
        result.append(contentsOf: relationshipStories.dropFirst(relationshipIndex))
        return FeedMerchantDiversity.filtered(result)
    }

    private static func authoredStories(
        topic: BuyerFeedTopic,
        catalog: PersonalizedFeedCatalog
    ) -> [FeedStory] {
        let byID = Dictionary(uniqueKeysWithValues: catalog.stories.map { ($0.id, $0) })
        let resolved = topic.storyIDs.compactMap { byID[$0] }
        if !resolved.isEmpty { return resolved }
        let sourceCategory = FeedInformationArchitecture.categories.first {
            $0.id == topic.sourceCategoryID
        } ?? FeedInformationArchitecture.categories[0]
        return FeedInformationArchitecture.stories(for: sourceCategory, in: catalog)
    }

    private static func distribute(
        stories: [FeedStory],
        posts: [ShopPost],
        buyerID: String,
        topicID: String
    ) -> [FeedEntry] {
        var result: [FeedEntry] = []
        var nextPostIndex = 0
        if buyerID == "luke", topicID == "for-you" {
            let leadStoryCount = min(4, stories.count)
            result.append(contentsOf: stories.prefix(leadStoryCount).map(FeedEntry.story))
            if posts.indices.contains(nextPostIndex) {
                result.append(.post(posts[nextPostIndex]))
                nextPostIndex += 1
            }
            result.append(.tryOn)
            appendRemainingStories(stories.dropFirst(leadStoryCount), posts: posts, nextPostIndex: &nextPostIndex, to: &result)
        } else {
            appendRemainingStories(stories[...], posts: posts, nextPostIndex: &nextPostIndex, to: &result)
        }
        return result
    }

    private static func appendRemainingStories(
        _ stories: ArraySlice<FeedStory>,
        posts: [ShopPost],
        nextPostIndex: inout Int,
        to result: inout [FeedEntry]
    ) {
        for (index, story) in stories.enumerated() {
            result.append(.story(story))
            if (index + 1).isMultiple(of: 2), posts.indices.contains(nextPostIndex) {
                result.append(.post(posts[nextPostIndex]))
                nextPostIndex += 1
            }
        }
    }

    private static func relevantPosts(
        _ posts: [ShopPost],
        buyer: BuyerPreviewProfile,
        topic: BuyerFeedTopic,
        stories: [FeedStory],
        merchants: [SampleMerchant]
    ) -> [ShopPost] {
        let candidates = Array(posts.prefix(6))
        guard topic.id != "for-you" else { return candidates }
        let merchantNames = Set(
            stories
                .flatMap { $0.resolvedProducts(from: merchants) }
                .map { FeedMerchantIdentity.normalizedName($0.merchant.displayName) }
        )
        return candidates.filter {
            merchantNames.contains(FeedMerchantIdentity.normalizedName($0.merchant.name))
        }
    }
}
