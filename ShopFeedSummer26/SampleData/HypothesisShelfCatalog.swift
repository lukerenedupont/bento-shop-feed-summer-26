import SwiftUI

/// Exact public shelves exported from the authenticated Hypothesis Shelves
/// prototype. The bundled dataset deliberately excludes buyer activity,
/// prompts, hypotheses, queries, and provenance.
enum HypothesisShelfCatalog {
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
            FeedStory(
                id: shelf.id,
                eyebrow: "",
                title: shelf.title,
                subtitle: shelf.subtitle,
                format: .world,
                topicKeys: [shelf.topic, "catalog-only-media"],
                accentHex: topicAccents[shelf.topic] ?? "#706B66",
                coverImageName: nil,
                destinationLabel: "Explore",
                products: shelf.items.map {
                    .init(merchantID: $0.merchantID, productID: $0.productID)
                }
            )
        }
    }

    /// The strongest repeated shops in each buyer's source shelves become
    /// honest single-merchant cards. Products are never borrowed from another
    /// profile, and a shop must occur at least twice to qualify.
    private static let merchantRecommendations: [MerchantRecommendation] = payload.users.flatMap { user in
        var merchantOrder: [String] = []
        var itemsByMerchant: [String: [Item]] = [:]

        for item in user.shelves.flatMap(\.items) {
            if itemsByMerchant[item.merchantID] == nil {
                merchantOrder.append(item.merchantID)
            }
            itemsByMerchant[item.merchantID, default: []].append(item)
        }

        let candidates = merchantOrder
            .filter { (itemsByMerchant[$0]?.count ?? 0) >= 2 }
            .sorted { lhs, rhs in
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
                    productCount: min(items.count, 4),
                    coverProductID: lead.productID,
                    coverImageIndex: 0,
                    usesImageCover: false
                )
            )
        }
    }

    static let stories: [FeedStory] = shelfStories + merchantRecommendations.map(\.story)

    static let merchantCollectionPresentations: [MerchantCollectionPresentation] =
        merchantRecommendations.map(\.presentation)

    static let profiles: [BuyerPreviewProfile] = payload.users.map { user in
        let merchantStoryIDs = merchantRecommendations
            .filter { $0.userID == user.id }
            .map { $0.story.id }
        var forYouStoryIDs: [String] = []
        for (index, shelf) in user.shelves.enumerated() {
            forYouStoryIDs.append(shelf.id)
            if index == 1, let first = merchantStoryIDs.first {
                forYouStoryIDs.append(first)
            }
            if index == 5, merchantStoryIDs.indices.contains(1) {
                forYouStoryIDs.append(merchantStoryIDs[1])
            }
        }
        if user.shelves.count <= 5, merchantStoryIDs.indices.contains(1) {
            forYouStoryIDs.append(merchantStoryIDs[1])
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
                showsOrders: false
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

        return order.compactMap { merchantID in
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
    }()

    private static func avatarAssetName(for userID: String) -> String? {
        switch userID {
        case "luke", "mikhail", "tobi", "kenny", "archie":
            return "\(userID)-avatar"
        case "katrina":
            return "katarina-avatar"
        default:
            return nil
        }
    }
}
