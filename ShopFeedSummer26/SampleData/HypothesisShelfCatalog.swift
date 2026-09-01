import SwiftUI

/// Exact public shelves exported from the authenticated Hypothesis Shelves
/// prototype. The bundled dataset deliberately excludes buyer activity,
/// prompts, hypotheses, queries, and provenance.
enum HypothesisShelfCatalog {
    static let giftGuideStoryID = "luke-gift-guide-for-son"
    static let streetwearStoryID = "shelf-luke-9-streetwear-caps-and-tees"
    static let performanceSneakerStoryID = "shelf-luke-10-performance-sneakers-edit"

    /// Canonical Kith collaborations lead the performance assortment; the
    /// exact Sneaker Politics and specialist-shop products follow from Luke's
    /// authenticated shelf export below.
    private static let hypebeastProductReferences: [FeedStory.ProductReference] = [
        .init(merchantID: "kith", productID: 8_286_509_564_032),
        .init(merchantID: "kith", productID: 8_286_188_830_848),
        .init(merchantID: "kith", productID: 8_286_188_863_616),
    ]

    private struct Payload: Decodable {
        let version: Int
        let users: [User]
    }

    private struct User: Decodable {
        let id: String
        let name: String
        let symbol: String
        let accent: String
        let shelves: [Shelf]
    }

    private struct Shelf: Decodable {
        let id: String
        let title: String
        let subtitle: String
        let topic: String
        let items: [Item]
        let signals: Signals?

        struct Signals: Decodable {
            let kind: String
            let persona: String
            let priceBandUSD: [Double]?
            let qualityScore: Int?
            let relatedShelfIDs: [String]
        }
    }

    private struct Item: Decodable {
        let merchantID: String
        let productID: Int
        let title: String
        let shop: String
        let price: String
        let image: String
        let buyAgain: Bool
        let saved: Bool
        let openLoop: Bool
    }

    private struct MerchantRecommendation {
        let userID: String
        let story: FeedStory
        let presentation: MerchantCollectionPresentation
    }

    private struct MerchantBrandPresentation {
        let merchantID: String
        let lifestyleCoverURL: String
    }

    /// Buyer-profile inventory keeps its source identifiers, while the few
    /// verified matches below can reuse canonical Shop identity and media.
    private static let merchantBrandPresentations: [String: MerchantBrandPresentation] = [
        "shelf-shop-forom-330c94c": MerchantBrandPresentation(
            merchantID: "forom",
            lifestyleCoverURL: "https://cdn.shopify.com/s/files/1/0356/2795/8403/files/gallerwallmirrorsandporcupine-beaunaySQ_1100x_66a7927f-7385-46bd-8697-ab807198137b.webp?v=1697392113"
        ),
    ]

    private static let preferredMerchantIDsByUser: [String: [String]] = [
        "luke": ["shelf-shop-forom-330c94c"],
    ]

    private static let topicPresentation: [(id: String, label: String)] = [
        ("living", "Living"),
        ("style", "Style"),
        ("wellness", "Wellness"),
        ("morning", "Food & drink"),
        ("outdoors", "Outdoors"),
        ("design", "Design & tech"),
    ]

    private static let topicAccents: [String: String] = [
        "living": "#8B7867",
        "style": "#5F5A61",
        "wellness": "#776D66",
        "morning": "#8A6F58",
        "outdoors": "#61705E",
        "design": "#626A70",
    ]

    private static let payload: Payload = {
        guard let asset = NSDataAsset(name: "hypothesis-shelves"),
              let value = try? JSONDecoder().decode(Payload.self, from: asset.data) else {
            assertionFailure("hypothesis-shelves.json is missing or invalid")
            return Payload(version: 1, users: [])
        }
        return value
    }()

    private static let shelfStories: [FeedStory] = payload.users.flatMap { user in
        user.shelves.map { shelf in
            let isStreetwearStory = shelf.id == streetwearStoryID
            let isPerformanceSneakerStory = shelf.id == performanceSneakerStoryID
            let isCanvasWatchStory = shelf.id == "shelf-luke-6-analog-watches-desk-clocks"
            let sourceItems: [Item]
            if isCanvasWatchStory {
                sourceItems = []
            } else if isStreetwearStory {
                let sourceShelfIDs = [
                    streetwearStoryID,
                    "shelf-luke-16-artist-collab-tees-hoodies-prints",
                    "shelf-luke-18-elevated-classics",
                ]
                sourceItems = sourceShelfIDs.flatMap { sourceShelfID in
                    user.shelves.first(where: { $0.id == sourceShelfID })?.items ?? []
                }
            } else if isPerformanceSneakerStory {
                let sourceShelfIDs = [
                    performanceSneakerStoryID,
                    "shelf-luke-19-race-day-and-daily-trainers",
                    "shelf-luke-18-elevated-classics",
                ]
                sourceItems = sourceShelfIDs.flatMap { sourceShelfID in
                    user.shelves.first(where: { $0.id == sourceShelfID })?.items ?? []
                }
            } else {
                sourceItems = shelf.items
            }

            let title = if isStreetwearStory {
                "Streetwear staples from caps to tees"
            } else if isPerformanceSneakerStory {
                "Your performance sneaker edit"
            } else {
                shelf.title
            }
            let subtitle = if isStreetwearStory {
                "Caps, graphic tees, and streetwear from the brands Luke follows"
            } else if isPerformanceSneakerStory {
                "Performance runners and everyday trainers from Luke's favorite sneaker shops"
            } else {
                shelf.subtitle
            }
            let coverImageName: String? = if isStreetwearStory {
                "topic-streetwear-caps-hero"
            } else if isPerformanceSneakerStory {
                "topic-performance-sneaker-hero"
            } else {
                nil
            }
            let canonicalProducts: [FeedStory.ProductReference] = if isCanvasWatchStory {
                VerySpecialWatchCatalog.productReferences
            } else if isPerformanceSneakerStory {
                hypebeastProductReferences
            } else {
                []
            }

            return FeedStory(
                id: shelf.id,
                eyebrow: "",
                title: title,
                subtitle: subtitle,
                format: .world,
                topicKeys: [shelf.topic, "catalog-only-media"],
                accentHex: topicAccents[shelf.topic] ?? "#706B66",
                coverImageName: coverImageName,
                destinationLabel: "Explore",
                products: canonicalProducts + sourceItems.map {
                    .init(merchantID: $0.merchantID, productID: $0.productID)
                }
            )
        }
    }

    /// A repeated shop only becomes a merchant card after its canonical Shop
    /// identity, official wordmark, and merchant-owned lifestyle cover have
    /// all been verified. Repetition alone is not a visual recommendation.
    private static let merchantRecommendations: [MerchantRecommendation] = payload.users.flatMap { user in
        var merchantOrder: [String] = []
        var itemsByMerchant: [String: [Item]] = [:]

        for item in user.shelves.flatMap(\.items) {
            if itemsByMerchant[item.merchantID] == nil {
                merchantOrder.append(item.merchantID)
            }
            itemsByMerchant[item.merchantID, default: []].append(item)
        }

        let preferredMerchantIDs = preferredMerchantIDsByUser[user.id] ?? []
        let candidates = merchantOrder
            .filter {
                guard (itemsByMerchant[$0]?.count ?? 0) >= 2,
                      let brand = merchantBrandPresentations[$0] else {
                    return false
                }
                return MerchantBrandAssets.hasVerifiedBundledWordmark(
                    for: brand.merchantID
                )
            }
            .sorted { lhs, rhs in
                let lhsPreference = preferredMerchantIDs.firstIndex(of: lhs) ?? Int.max
                let rhsPreference = preferredMerchantIDs.firstIndex(of: rhs) ?? Int.max
                if lhsPreference != rhsPreference { return lhsPreference < rhsPreference }
                let lhsCount = itemsByMerchant[lhs]?.count ?? 0
                let rhsCount = itemsByMerchant[rhs]?.count ?? 0
                guard lhsCount == rhsCount else { return lhsCount > rhsCount }
                return merchantOrder.firstIndex(of: lhs)! < merchantOrder.firstIndex(of: rhs)!
            }
            .prefix(2)

        return candidates.enumerated().compactMap { index, merchantID -> MerchantRecommendation? in
            guard let sourceItems = itemsByMerchant[merchantID],
                  let lead = sourceItems.first else { return nil }

            var seen = Set<Int>()
            let items = sourceItems.filter { seen.insert($0.productID).inserted }
            guard items.count >= 2 else { return nil }
            guard let brandPresentation = merchantBrandPresentations[merchantID] else {
                return nil
            }

            let storyID = "merchant-card-\(user.id)-\(index + 1)"
            let story = FeedStory(
                id: storyID,
                eyebrow: "",
                title: lead.shop,
                subtitle: "",
                format: .world,
                topicKeys: ["merchant-card", "catalog-only-media"],
                accentHex: user.accent,
                coverImageName: nil,
                destinationLabel: "Shop all",
                products: items.map {
                    .init(merchantID: $0.merchantID, productID: $0.productID)
                }
            )
            return MerchantRecommendation(
                userID: user.id,
                story: story,
                presentation: MerchantCollectionPresentation(
                    storyID: storyID,
                    merchantID: merchantID,
                    brandMerchantID: brandPresentation.merchantID,
                    productCount: min(items.count, 4),
                    coverProductID: lead.productID,
                    coverImageIndex: 0,
                    lifestyleCoverURL: brandPresentation.lifestyleCoverURL,
                    usesImageCover: true
                )
            )
        }
    }

    static let stories: [FeedStory] = shelfStories
        + merchantRecommendations.map(\.story)
        + BuyerPersonalizationCatalog.stories.filter {
            $0.id == "kyle-argizari-lighting" || $0.id == giftGuideStoryID
        }

    static let merchantCollectionPresentations: [MerchantCollectionPresentation] =
        merchantRecommendations.map(\.presentation)

    private static let shelvesByID: [String: Shelf] = Dictionary(
        uniqueKeysWithValues: payload.users
            .flatMap(\.shelves)
            .map { ($0.id, $0) }
    )

    static func relatedStoryIDs(for storyID: String) -> [String] {
        if storyID == performanceSneakerStoryID {
            return [
                "shelf-luke-19-race-day-and-daily-trainers",
                "shelf-luke-18-elevated-classics",
                "shelf-luke-11-neutral-activewear-essentials",
            ]
        }
        return shelvesByID[storyID]?.signals?.relatedShelfIDs ?? []
    }

    static func priceBandUSD(for storyID: String) -> ClosedRange<Double>? {
        guard let values = shelvesByID[storyID]?.signals?.priceBandUSD,
              values.count == 2,
              values[0] <= values[1] else { return nil }
        return values[0]...values[1]
    }

    static let profiles: [BuyerPreviewProfile] = payload.users.map { user in
        let merchantStoryIDs = merchantRecommendations
            .filter { $0.userID == user.id }
            .map { $0.story.id }

        // Lead Luke's feed with the two authored topic films while preserving
        // the relative order of every other shelf and all topic-specific feeds.
        var forYouShelves = user.shelves
        if user.id == "luke",
           let featuredIndex = forYouShelves.firstIndex(where: {
               $0.id == "shelf-luke-2-sculptural-living-room-pieces"
           }) {
            let featuredShelf = forYouShelves.remove(at: featuredIndex)
            forYouShelves.insert(featuredShelf, at: 0)
        }
        if user.id == "luke",
           let hypebeastIndex = forYouShelves.firstIndex(where: {
               $0.id == performanceSneakerStoryID
           }) {
            let hypebeastShelf = forYouShelves.remove(at: hypebeastIndex)
            forYouShelves.insert(hypebeastShelf, at: min(1, forYouShelves.count))
        }

        var forYouStoryIDs: [String] = []
        for (index, shelf) in forYouShelves.enumerated() {
            forYouStoryIDs.append(shelf.id)
            if index == 1, let first = merchantStoryIDs.first {
                forYouStoryIDs.append(first)
            }
            if index == 5, merchantStoryIDs.indices.contains(1) {
                forYouStoryIDs.append(merchantStoryIDs[1])
            }
        }
        if forYouShelves.count <= 5, merchantStoryIDs.indices.contains(1) {
            forYouStoryIDs.append(merchantStoryIDs[1])
        }
        if user.id == "luke" {
            forYouStoryIDs.removeAll { $0 == "kyle-argizari-lighting" }
            forYouStoryIDs.insert("kyle-argizari-lighting", at: 0)
            forYouStoryIDs.removeAll { $0 == giftGuideStoryID }
            forYouStoryIDs.insert(giftGuideStoryID, at: min(1, forYouStoryIDs.count))
            forYouStoryIDs.removeAll { $0 == streetwearStoryID }
            forYouStoryIDs.insert(streetwearStoryID, at: min(2, forYouStoryIDs.count))
            forYouStoryIDs.removeAll { $0 == performanceSneakerStoryID }
            forYouStoryIDs.insert(performanceSneakerStoryID, at: min(3, forYouStoryIDs.count))
        }

        let forYou = BuyerFeedTopic(
            id: "for-you",
            label: "For you",
            sourceCategoryID: "for-you",
            storyIDs: forYouStoryIDs,
            evidence: .observed
        )
        let topics = topicPresentation.compactMap { presentation -> BuyerFeedTopic? in
            let storyIDs = user.shelves
                .filter { $0.topic == presentation.id }
                .map(\.id)
            guard !storyIDs.isEmpty else { return nil }
            return BuyerFeedTopic(
                id: presentation.id,
                label: presentation.label,
                sourceCategoryID: presentation.id,
                storyIDs: storyIDs,
                evidence: .observed
            )
        }
        let items = user.shelves.flatMap(\.items)
        return BuyerPreviewProfile(
            id: user.id,
            name: user.name,
            symbol: avatarAssetName(for: user.id) == nil ? String(user.name.prefix(1)) : user.symbol,
            accentHex: user.accent,
            avatarAssetName: avatarAssetName(for: user.id),
            topics: [forYou] + topics,
            utility: BuyerUtilityConfiguration(
                buyAgainStoryID: items.contains(where: \.buyAgain) ? "" : nil,
                recentlyViewedStoryID: items.contains(where: \.saved) ? "" : nil,
                ownedAdjacencyStoryID: items.contains(where: \.openLoop) ? "" : nil,
                showsCart: false,
                showsOrders: user.id == "luke"
            )
        )
    }

    static let merchants: [SampleMerchant] = {
        var order: [String] = []
        var names: [String: String] = [:]
        var products: [String: [SampleMerchant.Product]] = [:]
        var productIDs: [String: Set<Int>] = [:]

        for item in payload.users.flatMap(\.shelves).flatMap(\.items) {
            if names[item.merchantID] == nil {
                order.append(item.merchantID)
                names[item.merchantID] = item.shop
            }
            guard productIDs[item.merchantID, default: []].insert(item.productID).inserted else {
                continue
            }
            var tags = ["canonical-catalog", "hypothesis-shelf"]
            if item.buyAgain { tags.append("buyer-buy-again") }
            if item.saved { tags.append("buyer-saved") }
            if item.openLoop { tags.append("buyer-open-loop") }
            products[item.merchantID, default: []].append(
                SampleMerchant.Product(
                    id: item.productID,
                    title: item.title,
                    price: item.price,
                    handle: "",
                    productType: nil,
                    vendor: item.shop,
                    imageURL: item.image,
                    shopURL: nil,
                    tags: tags,
                    allImageURLs: [item.image]
                )
            )
        }

        // The authenticated shelf contains two saved The Oblist lamps. Add a
        // current item from the same official storefront so merchant cards
        // can keep their fixed three-product treatment without duplicating a
        // product or borrowing inventory from another shop.
        let oblistID = "shelf-shop-the-oblist-02fd47c"
        if products[oblistID, default: []].count < 3 {
            products[oblistID, default: []].append(
                SampleMerchant.Product(
                    id: 8_254_326_407_433,
                    title: "Socorro Lamp",
                    price: "1527.00",
                    handle: "824410-socorro-lamp",
                    productType: "Table lamps",
                    vendor: "The Oblist",
                    imageURL: "https://cdn.shopify.com/s/files/1/0671/5290/4457/files/hi1bvskktqsnh1vhmuht.jpg?v=1769353096",
                    shopURL: "https://oblist.com/products/824410-socorro-lamp",
                    tags: ["canonical-catalog", "merchant-editorial"],
                    allImageURLs: [
                        "https://cdn.shopify.com/s/files/1/0671/5290/4457/files/hi1bvskktqsnh1vhmuht.jpg?v=1769353096"
                    ]
                )
            )
        }

        let shelfMerchants: [SampleMerchant] = order.compactMap { merchantID in
            guard let name = names[merchantID], let catalog = products[merchantID],
                  let cover = catalog.first?.imageURL else { return nil }
            return SampleMerchant(
                id: merchantID,
                name: name,
                description: "",
                rating: 0,
                totalRatings: 0,
                totalReviews: 0,
                primaryColor: Color(hex: "#706B66"),
                secondaryColor: Color(hex: "#706B66"),
                collections: [],
                products: catalog,
                featuredImageURLs: [cover],
                logoImageURL: nil,
                wordmarkImageURL: nil,
                coverImageURL: cover,
                videoURL: nil,
                coverDominantColor: "#706B66",
                productCategory: nil
            )
        }
        return shelfMerchants + hypebeastMerchants + [VerySpecialWatchCatalog.merchant]
    }()

    private static let hypebeastMerchants: [SampleMerchant] = [
        curatedMerchant(
            id: "kith",
            name: "Kith",
            domain: "kith.com",
            color: "#4B423B",
            products: [
                premiumProduct(
                    8_286_509_564_032,
                    "New Balance x Stone Island ABZORB 1890 – Deep Forest / Olive Green",
                    "250.00",
                    "nbu1890st",
                    "New Balance",
                    [
                        "https://cdn.shopify.com/s/files/1/0094/2252/files/5476753459_sd1.jpg?v=1780510881",
                        "https://cdn.shopify.com/s/files/1/0094/2252/files/20-05-2026-JW_U1890ST_2_1.jpg?v=1780510881",
                    ]
                ),
                premiumProduct(
                    8_286_188_830_848,
                    "New Balance x Action Bronson 1890 – Blue / Grey",
                    "200.00",
                    "nbu18908bn",
                    "New Balance",
                    [
                        "https://cdn.shopify.com/s/files/1/0094/2252/files/NBU18908BNNewBalanceActionBronson1890Blue_0381.jpg?v=1770835668",
                        "https://cdn.shopify.com/s/files/1/0094/2252/files/NBU18908BNNewBalanceActionBronson1890Blue_0382.jpg?v=1770835668",
                    ]
                ),
                premiumProduct(
                    8_286_188_863_616,
                    "New Balance x Action Bronson 1890 – Brown / Blue",
                    "200.00",
                    "nbu18901dp",
                    "New Balance",
                    [
                        "https://cdn.shopify.com/s/files/1/0094/2252/files/NBU18901DPNewBalanceActionBronson1890White_0388.jpg?v=1770835641",
                        "https://cdn.shopify.com/s/files/1/0094/2252/files/NBU18901DPNewBalanceActionBronson1890White_0390.jpg?v=1770835641",
                    ]
                ),
            ]
        ),
        curatedMerchant(
            id: "sneaker-politics",
            name: "Sneaker Politics",
            domain: "sneakerpolitics.com",
            color: "#272727",
            products: [
                premiumProduct(
                    9_405_655_777_468,
                    "Pharrell Williams x Adidas Adistar Jellyfish – Crystal Sand / Trace Brown",
                    "300.00",
                    "pharrell-williams-x-adidas-adistar-jellyfish-crystal-sand-trace-brown",
                    "Adidas",
                    [
                        "https://cdn.shopify.com/s/files/1/0214/7974/files/Sneaker-Politics-Adidas-PharrellWilliamsxAdidasAdistarJellyfish_CrystalSand_-KH6729-WB-1.jpg?v=1787263080",
                        "https://cdn.shopify.com/s/files/1/0214/7974/files/Sneaker-Politics-Adidas-AdistarJellyfish-IG-1.jpg?v=1787263172",
                    ]
                ),
                premiumProduct(
                    9_189_417_943_228,
                    "Willy Chavarria x Adidas Superstar – Core Black / Off White",
                    "88.00",
                    "willy-chavarria-x-adidas-superstar-core-black-off-white",
                    "Adidas",
                    [
                        "https://cdn.shopify.com/s/files/1/0214/7974/files/Sneaker-Politics-ADIDAS-WillyChavarriaxAdidasSuperstar-CoreBlack-OffWhite-KI5156-WB-1.jpg?v=1779939134",
                        "https://cdn.shopify.com/s/files/1/0214/7974/files/Sneaker-Politics-ADIDAS-WillyChavarriaxAdidasSuperstar-CoreBlack-OffWhite-KI5156-WB-5.jpg?v=1779939134",
                    ]
                ),
                premiumProduct(
                    9_410_290_516_156,
                    "Air Jordan 8 Retro ‘Chrome’ – Black / White",
                    "215.00",
                    "air-jordan-8-retro-black-white-1",
                    "Air Jordan",
                    [
                        "https://cdn.shopify.com/s/files/1/0214/7974/files/AURORA_305381-007_PHSLH000-2000.jpg?v=1787092878",
                        "https://cdn.shopify.com/s/files/1/0214/7974/files/AURORA_305381-007_PHCFH001-2000.jpg?v=1787092878",
                    ]
                ),
                premiumProduct(
                    9_346_461_434_044,
                    "Nike Kobe 10 Protro ‘Halo’ – White / Multi",
                    "190.00",
                    "nike-kobe-10-protro-halo-white-multi",
                    "Nike",
                    [
                        "https://cdn.shopify.com/s/files/1/0214/7974/files/AURORA_IO3415-100_PHSLH000-2000.jpg?v=1786745895",
                        "https://cdn.shopify.com/s/files/1/0214/7974/files/AURORA_IO3415-100_PHCFH001-2000.jpg?v=1786745895",
                    ]
                ),
            ]
        ),
    ]

    private static func curatedMerchant(
        id: String,
        name: String,
        domain: String,
        color: String,
        products: [SampleMerchant.Product]
    ) -> SampleMerchant {
        SampleMerchant(
            id: id,
            name: name,
            description: "",
            rating: 4.9,
            totalRatings: 0,
            totalReviews: 0,
            primaryColor: Color(hex: color),
            secondaryColor: Color(hex: color),
            collections: [],
            products: products.map { product in
                SampleMerchant.Product(
                    id: product.id,
                    title: product.title,
                    price: product.price,
                    handle: product.handle,
                    productType: product.productType,
                    vendor: product.vendor,
                    imageURL: product.imageURL,
                    shopURL: "https://\(domain)/products/\(product.handle)",
                    tags: product.tags,
                    allImageURLs: product.allImageURLs,
                    currencyCode: product.currencyCode
                )
            },
            featuredImageURLs: products.flatMap(\.allImageURLs),
            logoImageURL: nil,
            wordmarkImageURL: nil,
            coverImageURL: products.first?.allImageURLs.dropFirst().first,
            videoURL: nil,
            coverDominantColor: color,
            productCategory: "Sneakers",
            logoFitsInCircle: false
        )
    }

    private static func premiumProduct(
        _ id: Int,
        _ title: String,
        _ price: String,
        _ handle: String,
        _ vendor: String,
        _ images: [String]
    ) -> SampleMerchant.Product {
        SampleMerchant.Product(
            id: id,
            title: title,
            price: price,
            handle: handle,
            productType: "Sneakers",
            vendor: vendor,
            imageURL: images.first,
            shopURL: nil,
            tags: ["canonical-catalog", "premium-sneakers"],
            allImageURLs: images,
            currencyCode: "USD"
        )
    }

    private static func avatarAssetName(for userID: String) -> String? {
        "\(userID)-avatar"
    }
}
