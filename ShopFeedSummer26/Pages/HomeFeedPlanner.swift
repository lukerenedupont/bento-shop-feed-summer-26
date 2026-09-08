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
        let promotedStories: [FeedStory]
        let enabledWorldIDs: Set<String>
        let enabledContentKinds: Set<FeedContentKind>
        let seasonalPlacement: SeasonalPlacement
    }

    private struct Key: Hashable {
        let buyerID: String
        let topicID: String
        let topicLabel: String
        let customIntent: String?
        let storyIDs: [String]
        let catalogVersion: Int
        let catalogStoryIDs: [String]
        let merchantInventory: [String]
        let followedMerchantIDs: [String]
        let postIDs: [String]
        let promotedStoryIDs: [String]
        let worldIDs: [String]
        let contentKinds: [String]
        let seasonalPlacement: String
    }

    private static var cached: (key: Key, plan: HomeFeedPlan)?

    static func plan(_ input: Input) -> HomeFeedPlan {
        let key = Key(
            buyerID: input.buyer.id,
            topicID: input.topic.id,
            topicLabel: input.topic.label,
            customIntent: input.topic.customIntent,
            storyIDs: input.topic.storyIDs,
            catalogVersion: input.catalog.version,
            catalogStoryIDs: input.catalog.stories.map(\.id),
            merchantInventory: input.merchants.map { "\($0.id):\($0.products.count)" },
            followedMerchantIDs: input.followedMerchants.map(\.id),
            postIDs: input.posts.map(\.id),
            promotedStoryIDs: input.promotedStories.map(\.id),
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
        if let suggestedCollections = suggestedCollections(for: input) {
            entries.insert(
                .suggestedCollections(suggestedCollections),
                at: min(1, entries.count)
            )
        }
        let availableContentCounts = contentCounts(in: entries, enabledWorldIDs: input.enabledWorldIDs)
        entries = FeedCompositionFilter.apply(to: entries, enabledKinds: input.enabledContentKinds, enabledWorldIDs: input.enabledWorldIDs)
        if input.seasonalPlacement == .feedCard {
            entries.insert(.seasonalSavings, at: min(1, entries.count))
        }
        // Explicit occasion promotions own rank 2 even when optional cards or
        // composition filters are active. This keeps the authored demo order
        // stable instead of letting a utility campaign silently displace it.
        if let promotedStory = input.promotedStories.first {
            entries.removeAll { $0.id == promotedStory.id }
            entries.insert(.story(promotedStory), at: min(1, entries.count))
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
            case .suggestedCollections: .suggestedCollections
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

    private static func suggestedCollections(
        for input: Input
    ) -> SuggestedCollectionsPresentation? {
        guard input.buyer.id == "luke", input.topic.id == "for-you" else { return nil }

        let definitions: [(id: String, intent: String, title: String, subtitle: String, accent: String, hero: String)] = [
            (
                id: "caps-in-rotation",
                intent: "hats",
                title: "Caps in rotation",
                subtitle: "Headwear selected around your streetwear taste",
                accent: "#587F91",
                hero: "streetwear-new-1"
            ),
            (
                id: "warm-light-small-footprint",
                intent: "lamps",
                title: "Warm light, small footprint",
                subtitle: "Sculptural lighting for the spaces you’re finishing",
                accent: "#9B6B54",
                hero: "topic-warm-lighting-hero"
            ),
            (
                id: "trail-ready-runners",
                intent: "trail shoes",
                title: "Trail-ready runners",
                subtitle: "Technical pairs from shops already in your orbit",
                accent: "#586B5B",
                hero: "topic-performance-sneaker-hero"
            ),
        ]

        let collections = definitions.compactMap { definition -> SuggestedCollectionPresentation? in
            guard let source = CustomFeedRecommendationEngine.stories(
                intent: definition.intent,
                buyer: input.buyer,
                catalog: input.catalog,
                merchants: input.merchants,
                followedMerchants: input.followedMerchants
            ).first else { return nil }

            return SuggestedCollectionPresentation(
                story: FeedStory(
                    id: "custom-feed-suggested-\(definition.id)",
                    eyebrow: "Suggested collection",
                    title: definition.title,
                    subtitle: definition.subtitle,
                    format: .shortlist,
                    topicKeys: source.topicKeys,
                    accentHex: definition.accent,
                    coverImageName: nil,
                    destinationLabel: "Shop all",
                    products: source.products
                ),
                heroAssetName: definition.hero
            )
        }
        guard collections.count >= 2 else { return nil }
        return SuggestedCollectionsPresentation(
            id: "suggested-collections",
            title: "Suggested collections",
            collections: collections
        )
    }

    private static func stories(for input: Input) -> [FeedStory] {
        if let intent = input.topic.customIntent {
            return CustomFeedRecommendationEngine.stories(
                intent: intent,
                buyer: input.buyer,
                catalog: input.catalog,
                merchants: input.merchants,
                followedMerchants: input.followedMerchants
            )
        }

        var baseAuthored = authoredStories(topic: input.topic, catalog: input.catalog)
        let promotedIDs = Set(input.promotedStories.map(\.id))
        baseAuthored.removeAll { promotedIDs.contains($0.id) }
        for story in input.promotedStories.reversed() {
            baseAuthored.insert(story, at: min(1, baseAuthored.count))
        }
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

/// Resolves shopper-authored feed intent against the complete merchant
/// snapshot. Intent relevance is the hard gate; buyer history and followed
/// shops only rank relevant products, so personalization cannot turn a Hats
/// feed into a generic For You feed.
@MainActor
enum CustomFeedRecommendationEngine {
    private struct Candidate {
        let merchant: SampleMerchant
        let product: SampleMerchant.Product
        let relevance: Int
        let affinity: Int
    }

    private static let ignoredTerms: Set<String> = [
        "a", "an", "and", "for", "feed", "find", "i", "like", "me", "my",
        "of", "on", "please", "show", "some", "that", "the", "to", "want",
        "with",
    ]

    private static let synonymGroups: [Set<String>] = [
        ["hat", "cap", "beanie", "headwear", "balaclava", "trucker"],
        ["shoe", "sneaker", "footwear", "trainer", "boot", "loafer", "clog"],
        ["lamp", "light", "lighting", "sconce", "pendant", "chandelier"],
        ["sofa", "couch", "settee"],
        ["chair", "seating", "stool", "bench"],
        ["coffee", "espresso", "grinder", "kettle", "brewer"],
        ["bag", "backpack", "tote", "pouch", "luggage"],
        ["shirt", "tee", "tshirt", "top"],
        ["jacket", "coat", "outerwear", "parka"],
        ["pant", "trouser", "jean", "denim"],
        ["watch", "timepiece", "chronograph"],
        ["book", "publication", "magazine", "manual"],
        ["skincare", "skin", "serum", "cleanser", "moisturizer"],
        ["hair", "shampoo", "conditioner", "scalp"],
        ["outdoor", "trail", "hiking", "camping"],
    ]

    static func stories(
        intent: String,
        buyer: BuyerPreviewProfile,
        catalog: PersonalizedFeedCatalog,
        merchants: [SampleMerchant],
        followedMerchants: [SampleMerchant]
    ) -> [FeedStory] {
        let intentTerms = meaningfulTokens(in: intent)
        guard !intentTerms.isEmpty else { return [] }
        let expandedTerms = expanded(intentTerms)
        let followedIDs = Set(followedMerchants.map(\.id))
        let authoredReferences = Set(
            buyer.topics.flatMap(\.storyIDs)
                .compactMap { storyID in catalog.stories.first { $0.id == storyID } }
                .flatMap(\.products)
        )
        let authoredMerchantCounts = authoredReferences.reduce(into: [String: Int]()) {
            $0[$1.merchantID, default: 0] += 1
        }
        let authoredVocabulary = buyerAffinityVocabulary(
            references: authoredReferences,
            merchants: merchants
        )

        let ranked = merchants.flatMap { merchant in
            merchant.products.compactMap { product -> Candidate? in
                guard isUseful(product) else { return nil }
                let relevance = relevanceScore(
                    product: product,
                    merchant: merchant,
                    intentTerms: intentTerms,
                    expandedTerms: expandedTerms
                )
                guard relevance > 0 else { return nil }

                var affinity = authoredMerchantCounts[merchant.id, default: 0] * 3
                if followedIDs.contains(merchant.id) { affinity += 24 }
                if authoredReferences.contains(
                    FeedStory.ProductReference(merchantID: merchant.id, productID: product.id)
                ) {
                    affinity += 40
                }
                affinity += productTokens(product).intersection(authoredVocabulary).count
                if buyer.id == "luke", let signals = catalog.signals {
                    affinity += signals.strength(
                        merchantID: merchant.id,
                        productID: product.id
                    ).rawValue * 18
                }
                return Candidate(
                    merchant: merchant,
                    product: product,
                    relevance: relevance,
                    affinity: affinity
                )
            }
        }
        .sorted {
            if $0.relevance != $1.relevance { return $0.relevance > $1.relevance }
            if $0.affinity != $1.affinity { return $0.affinity > $1.affinity }
            if $0.merchant.id != $1.merchant.id { return $0.merchant.id < $1.merchant.id }
            return $0.product.id < $1.product.id
        }

        let diversified = diversify(ranked)
        if !diversified.isEmpty {
            return makeStories(
                from: diversified,
                intent: intent,
                buyer: buyer
            )
        }

        // Some authored topics carry useful editorial semantics that are not
        // repeated in product metadata. They are a safe fallback only when the
        // story itself matches the request; unrelated For You stories never
        // enter a custom feed.
        return catalog.stories
            .filter { storyRelevance($0, terms: expandedTerms) > 0 }
            .sorted {
                let lhs = storyRelevance($0, terms: expandedTerms)
                let rhs = storyRelevance($1, terms: expandedTerms)
                return lhs == rhs ? $0.id < $1.id : lhs > rhs
            }
    }

    static func validationIssues(
        buyer: BuyerPreviewProfile,
        catalog: PersonalizedFeedCatalog,
        merchants: [SampleMerchant],
        followedMerchants: [SampleMerchant]
    ) -> [String] {
        let intent = "Hats I like"
        let resolved = stories(
            intent: intent,
            buyer: buyer,
            catalog: catalog,
            merchants: merchants,
            followedMerchants: followedMerchants
        )
        if resolved.isEmpty { return ["Hats custom feed returned no cards"] }

        let merchantsByID = Dictionary(uniqueKeysWithValues: merchants.map { ($0.id, $0) })
        return resolved.flatMap { story in
            story.products.compactMap { reference in
                guard let merchant = merchantsByID[reference.merchantID],
                      let product = merchant.products.first(where: { $0.id == reference.productID }) else {
                    return "\(story.id): unresolved custom-feed product"
                }
                return productMatches(product, merchant: merchant, intent: intent)
                    ? nil
                    : "\(story.id): \(product.title) is unrelated to hats"
            }
        }
    }

    static func productMatches(
        _ product: SampleMerchant.Product,
        merchant: SampleMerchant,
        intent: String
    ) -> Bool {
        let terms = meaningfulTokens(in: intent)
        return relevanceScore(
            product: product,
            merchant: merchant,
            intentTerms: terms,
            expandedTerms: expanded(terms)
        ) > 0
    }

    private static func makeStories(
        from candidates: [Candidate],
        intent: String,
        buyer: BuyerPreviewProfile
    ) -> [FeedStory] {
        let slug = meaningfulTokens(in: intent).sorted().joined(separator: "-")
        let shopperName = buyer.name.split(separator: " ").first.map(String.init) ?? buyer.name
        let chunks = stride(from: 0, to: min(candidates.count, 30), by: 6).map {
            Array(candidates[$0..<min($0 + 6, candidates.count)])
        }

        return chunks.enumerated().map { index, candidates in
            let title = switch index {
            case 0: "\(intent), picked for you"
            case 1: "More \(intent.lowercased()) to consider"
            default: "A different take on \(intent.lowercased())"
            }
            return FeedStory(
                id: "custom-feed-\(buyer.id)-\(slug)-\(index)",
                eyebrow: "Made for \(shopperName)",
                title: title,
                subtitle: "Relevant finds, tuned to what you already like",
                format: .shortlist,
                topicKeys: Set(["custom-feed", "catalog-only-media"])
                    .union(meaningfulTokens(in: intent)),
                accentHex: candidates.first?.merchant.coverDominantColor ?? "#343434",
                coverImageName: nil,
                destinationLabel: "Explore \(intent)",
                products: candidates.map {
                    FeedStory.ProductReference(
                        merchantID: $0.merchant.id,
                        productID: $0.product.id
                    )
                }
            )
        }
    }

    private static func diversify(_ candidates: [Candidate]) -> [Candidate] {
        var buckets = Dictionary(grouping: candidates, by: { $0.merchant.id })
        let merchantOrder = buckets.keys.sorted {
            guard let lhs = buckets[$0]?.first, let rhs = buckets[$1]?.first else {
                return $0 < $1
            }
            if lhs.relevance != rhs.relevance { return lhs.relevance > rhs.relevance }
            if lhs.affinity != rhs.affinity { return lhs.affinity > rhs.affinity }
            return $0 < $1
        }
        var result: [Candidate] = []
        while result.count < candidates.count {
            var appended = false
            for merchantID in merchantOrder {
                guard var bucket = buckets[merchantID], !bucket.isEmpty else { continue }
                result.append(bucket.removeFirst())
                buckets[merchantID] = bucket
                appended = true
            }
            if !appended { break }
        }
        return result
    }

    private static func relevanceScore(
        product: SampleMerchant.Product,
        merchant: SampleMerchant,
        intentTerms: Set<String>,
        expandedTerms: Set<String>
    ) -> Int {
        guard !intentTerms.isEmpty else { return 0 }
        let title = tokens(in: product.title)
        let type = tokens(in: product.productType ?? "")
        let tags = tokens(in: product.tags.joined(separator: " "))
        let description = tokens(in: product.productDescription ?? "")
        let brand = tokens(in: "\(product.vendor) \(merchant.name)")
        let direct = intentTerms

        return title.intersection(direct).count * 30
            + type.intersection(direct).count * 26
            + tags.intersection(direct).count * 18
            + brand.intersection(direct).count * 16
            + description.intersection(direct).count * 5
            + title.intersection(expandedTerms.subtracting(direct)).count * 18
            + type.intersection(expandedTerms.subtracting(direct)).count * 16
            + tags.intersection(expandedTerms.subtracting(direct)).count * 12
            + brand.intersection(expandedTerms.subtracting(direct)).count * 10
            + description.intersection(expandedTerms.subtracting(direct)).count * 3
    }

    private static func storyRelevance(_ story: FeedStory, terms: Set<String>) -> Int {
        let searchable = tokens(in: "\(story.title) \(story.subtitle) \(story.topicKeys.joined(separator: " "))")
        return searchable.intersection(terms).count
    }

    private static func buyerAffinityVocabulary(
        references: Set<FeedStory.ProductReference>,
        merchants: [SampleMerchant]
    ) -> Set<String> {
        references.reduce(into: Set<String>()) { result, reference in
            guard let merchant = merchants.first(where: { $0.id == reference.merchantID }),
                  let product = merchant.products.first(where: { $0.id == reference.productID }) else {
                return
            }
            result.formUnion(productTokens(product))
        }
    }

    private static func productTokens(_ product: SampleMerchant.Product) -> Set<String> {
        tokens(in: ([
            product.title,
            product.productType ?? "",
            product.vendor,
            product.productDescription ?? "",
        ] + product.tags).joined(separator: " "))
    }

    private static func meaningfulTokens(in value: String) -> Set<String> {
        tokens(in: value).subtracting(ignoredTerms)
    }

    private static func expanded(_ terms: Set<String>) -> Set<String> {
        synonymGroups.reduce(into: terms) { result, group in
            if !group.isDisjoint(with: terms) { result.formUnion(group) }
        }
    }

    private static func tokens(in value: String) -> Set<String> {
        Set(
            value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map { canonicalToken(String($0)) }
                .filter { !$0.isEmpty }
        )
    }

    private static func canonicalToken(_ token: String) -> String {
        let irregular: [String: String] = [
            "hats": "hat", "caps": "cap", "beanies": "beanie",
            "shoes": "shoe", "sneakers": "sneaker", "boots": "boot",
            "bags": "bag", "books": "book", "chairs": "chair",
            "lamps": "lamp", "pants": "pant", "tees": "tee",
            "watches": "watch",
        ]
        return irregular[token] ?? token
    }

    private static func isUseful(_ product: SampleMerchant.Product) -> Bool {
        guard product.imageURL != nil || !product.allImageURLs.isEmpty else { return false }
        let title = product.title.lowercased()
        return !["gift card", "replacement", "spare part", "swatch", "sample", "shipping", "warranty", "deposit"]
            .contains { title.contains($0) }
    }
}
