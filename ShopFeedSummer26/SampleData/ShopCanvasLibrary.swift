import Foundation
import SwiftUI

/// The alternate app uses the asset library through this native data adapter.
/// No Canvas UI, source-side edits, runtime localhost dependency, or implicit
/// branding-based editorial approval is involved.
enum ShopCanvasLibrary {
    static let isEnabled = true // This file exists only on ceo-library-preview.
    static let profileID = "shop-canvas-library"
    static let storyPrefix = "library-edit-"

    struct Product: Decodable {
        let id: String
        let nativeID: Int
        let curated: Bool
        let merchantIDs: [String]
        let title: String
        let brand: String
        let group: String
        let image: String?
        let originalImage: String?
        let url: String?
        let price: String
        let currency: String
        let description: String
        let commerceCheck: String
        let checkedAt: String?
        let images: [String]

        func restricted(to merchantIDs: Set<String>) -> Self? {
            let approvedIDs = self.merchantIDs.filter(merchantIDs.contains)
            guard !approvedIDs.isEmpty else { return nil }
            return .init(
                id: id, nativeID: nativeID, curated: curated,
                merchantIDs: approvedIDs, title: title, brand: brand,
                group: group, image: image, originalImage: originalImage,
                url: url, price: price, currency: currency,
                description: description, commerceCheck: commerceCheck,
                checkedAt: checkedAt, images: images
            )
        }
    }

    struct Merchant: Decodable {
        struct Colors: Decodable {
            let primary: String?
            let coverDominant: String?
        }
        let id: String
        let name: String
        let url: String?
        let status: String?
        let platformOutcome: String?
        let logo: String?
        let wordmark: String?
        let wordmarkWhite: String?
        let cover: String?
        let colors: Colors
    }

    struct Group: Decodable {
        let title: String
        let productIDs: [String]
    }

    struct Manifest: Decodable {
        let selectedIds: [String]
        let products: [Product]
        let merchants: [Merchant]
        let groups: [Group]
        let nativeAssets: [String: String]
    }

    static let rootURL: URL = {
        guard let url = Bundle.main.url(forResource: "LibraryAssets", withExtension: nil) else {
            preconditionFailure("LibraryAssets is missing from the native preview target")
        }
        return url
    }()

    static let manifest: Manifest = {
        do {
            return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: rootURL.appendingPathComponent("snapshot.json")))
        } catch {
            preconditionFailure("Cannot decode the curated library snapshot: \(error)")
        }
    }()

    static func resolve(_ value: String?, root: URL = rootURL) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        if value.hasPrefix("https://") || value.hasPrefix("http://") {
            guard let url = URL(string: value), !url.pathComponents.contains("merchant-review") else { return nil }
            return url
        }
        guard !value.contains("://") else { return nil }
        let relative = value.hasPrefix("./") ? String(value.dropFirst(2)) : value
        let parts = relative.split(separator: "/").map(String.init)
        guard let first = parts.first,
              ["catalog", "cosmos-brand-assets", "merchant-assets", "merchant-cover-assets"].contains(first),
              !parts.contains(".."), !parts.contains("merchant-review"), !relative.hasPrefix("/") else { return nil }
        return root.appendingPathComponent(relative).standardizedFileURL
    }

    static func nativeAsset(_ value: String?) -> URL? {
        guard let value else { return nil }
        return resolve(manifest.nativeAssets[value] ?? value)
    }

    private static let merchantRecords: [Merchant] = {
        var seen = Set<String>()
        return (manifest.merchants + ShoppingResearchCatalog.snapshot.merchants)
            .filter { seen.insert($0.id).inserted }
    }()
    static let selectedProductIDs = manifest.selectedIds + ShoppingResearchCatalog.snapshot.offers.map(\.id)
    static let confirmedMerchantRecords = merchantRecords.filter {
        $0.platformOutcome == "confirmed_shopify" && $0.id.hasPrefix("gid://shopify/Shop/")
    }
    private static let confirmedMerchantIDs = Set(confirmedMerchantRecords.map(\.id))
    private static let publishedProducts = (manifest.products + ShoppingResearchCatalog.snapshot.offers.map(\.libraryProduct)).compactMap {
        $0.restricted(to: confirmedMerchantIDs)
    }
    static let productsByID = Dictionary(uniqueKeysWithValues: publishedProducts.map { ($0.id, $0) })
    static let productsByNativeID = Dictionary(uniqueKeysWithValues: publishedProducts.map { ($0.nativeID, $0) })
    static let merchantsByID = Dictionary(uniqueKeysWithValues: confirmedMerchantRecords.map { ($0.id, $0) })
    static let curatedProducts = selectedProductIDs.compactMap { productsByID[$0] }.filter(\.curated)

    static let merchants: [SampleMerchant] = confirmedMerchantRecords.map { merchant in
        let products = publishedProducts.filter { $0.merchantIDs.contains(merchant.id) }.map { product in
            SampleMerchant.Product(
                id: product.nativeID, title: product.title, price: product.price,
                handle: "", productType: product.group, vendor: product.brand,
                imageURL: resolve(product.image)?.absoluteString, shopURL: product.url,
                tags: ["library-source", product.curated ? "editorially-curated" : "broader-inventory", product.group],
                allImageURLs: product.images.compactMap { resolve($0)?.absoluteString },
                currencyCode: product.currency, productDescription: product.description,
                sourceProductID: product.id, isCurated: product.curated,
                associatedMerchantIDs: product.merchantIDs
            )
        }
        return SampleMerchant(
            id: merchant.id, name: LibraryMerchantNames.name(for: merchant.id, fallback: merchant.name),
            description: merchant.status ?? "From the asset library",
            rating: 0, totalRatings: 0, totalReviews: 0,
            primaryColor: Color(hex: merchant.colors.primary ?? "#41463F"), secondaryColor: .white,
            collections: [], products: products, featuredImageURLs: [],
            logoImageURL: nativeAsset(merchant.logo)?.absoluteString,
            wordmarkImageURL: nativeAsset(merchant.wordmark ?? merchant.wordmarkWhite ?? merchant.logo)?.absoluteString,
            coverImageURL: resolve(merchant.cover)?.absoluteString, videoURL: nil,
            coverDominantColor: merchant.colors.coverDominant ?? "#41463F", productCategory: nil
        )
    }

    private static func hasPublishableCover(for group: String) -> Bool {
        guard let cover = LibraryArtDirection.cover(forGroup: group) else { return false }
        if let merchantID = cover.sourceMerchantID {
            return confirmedMerchantIDs.contains(merchantID)
        }
        if let productID = cover.sourceProductID {
            return productsByID[productID] != nil
        }
        return false
    }

    private static func references(_ ids: [String]) -> [FeedStory.ProductReference] {
        ids.compactMap { id in
            guard let product = productsByID[id], product.curated,
                  let merchantID = product.merchantIDs.first else { return nil }
            return .init(merchantID: merchantID, productID: product.nativeID)
        }
    }

    static let stories: [FeedStory] = {
        let accents = ["#4D6256", "#5B5350", "#58656B", "#65604F", "#615965", "#59614B"]
        let edits = manifest.groups.enumerated().compactMap { index, group -> FeedStory? in
            let productReferences = references(group.productIDs)
            guard productReferences.count >= 3, hasPublishableCover(for: group.title) else { return nil }
            return FeedStory(
                id: "\(storyPrefix)\(index)", eyebrow: "Curated library", title: LibraryArtDirection.title(for: group.title),
                subtitle: "", format: .world,
                topicKeys: ["library", "catalog-only-media", "library-group:\(group.title)"], accentHex: accents[index % accents.count],
                coverImageName: nil, destinationLabel: "Explore the edit", products: productReferences
            )
        }
        let all = FeedStory(id: "\(storyPrefix)all", eyebrow: "Curated library", title: "All curated finds",
            subtitle: "", format: .world,
            topicKeys: ["library", "catalog-only-media"], accentHex: "#4D6256", coverImageName: nil,
            destinationLabel: "Explore all \(curatedProducts.count)", products: references(selectedProductIDs))
        return ShoppingResearchCatalog.worlds.map(\.story) + edits + [all]
    }()

    static let profile: BuyerPreviewProfile = {
        let edits = stories.filter { $0.id != "\(storyPrefix)all" }
        let sections: [(String, String, Set<String>)] = [
            ("living", "Living", ["For the thoughtful host", "Nordic Knots", "objects", "lighting", "tableware", "Working from home", "books", "furniture", "home textiles", "The coziest corner", "Turn off the big light"]),
            ("style", "Style", ["Eckhaus Latta", "fashion", "Balenciaga", "Soft launching fall", "The best-dressed guest", "Jil Sander", "Dries Van Noten", "Lemaire", "All suited up", "JW Anderson", "Our Legacy", "accessories"]),
            ("travel", "Travel", ["Travelling light", "Snow Peak"]),
            ("wellness", "Wellness", ["For your self-care reset", "Big sports guy", "On"]),
        ]
        let topics = [BuyerFeedTopic(id: "for-you", label: "For you", storyIDs: edits.map(\.id), evidence: .discovery)]
            + sections.compactMap { id, title, groups -> BuyerFeedTopic? in
                let ids = edits.filter { story in
                    LibraryArtDirection.group(for: story).map(groups.contains) ?? false
                }.map(\.id)
                guard !ids.isEmpty else { return nil }
                return BuyerFeedTopic(id: "library-\(id)", label: title, storyIDs: ids, evidence: .discovery)
            }
            + [BuyerFeedTopic(id: "library-all", label: "All finds", storyIDs: ["\(storyPrefix)all"], evidence: .discovery)]
        return BuyerPreviewProfile(id: profileID, name: "Luke", symbol: "L",
            accentHex: "#4D6256", avatarAssetName: "luke-avatar", topics: topics,
            utility: .init(buyAgainStoryID: nil, recentlyViewedStoryID: nil,
                           ownedAdjacencyStoryID: nil, showsCart: false, showsOrders: true))
    }()

    static let catalog = PersonalizedFeedCatalog(version: 3, topics: profile.topics.map {
        FeedTopic(id: $0.id, label: $0.label, storyTopicKey: nil, storyIDs: $0.storyIDs,
                  subtopics: nil, relatedMerchantIDs: nil, merchandisingBlocks: nil)
    }, stories: stories)

    /// The existing gift brief flow can open a library-backed World without
    /// pulling in legacy buyer fixtures or inventing saved/purchased signals.
    static func giftGuide(for brief: GiftGuideBrief) -> FeedStory {
        let groupsByInterest: [GiftGuideInterest: Set<String>] = [
            .outdoors: ["Snow Peak", "Travelling light"],
            .travel: ["Travelling light", "Snow Peak"],
            .games: ["objects", "books"], .making: ["objects", "art", "books"],
            .sports: ["Big sports guy", "On"], .music: ["books", "objects"],
            .style: ["Soft launching fall", "Gifts for him", "accessories"],
            .food: ["For the thoughtful host", "tableware"],
            .books: ["books", "Working from home"], .animals: [],
            .home: ["The coziest corner", "objects", "lighting", "Nordic Knots"],
            .surprises: ["Gifts for him", "For the thoughtful host", "objects"],
        ]
        let requested = brief.interests.reduce(into: Set<String>()) { result, interest in
            result.formUnion(groupsByInterest[interest] ?? [])
        }
        let matching = curatedProducts.filter { requested.contains($0.group) }
        let selected = Array((matching.isEmpty ? curatedProducts : matching).prefix(24))
        let leadGroup = selected.first?.group ?? "For the thoughtful host"
        return FeedStory(id: "\(storyPrefix)gift-\(UUID().uuidString)", eyebrow: "",
            title: "Gifts for \(brief.recipientName)", subtitle: "", format: .world,
            topicKeys: ["library", "catalog-only-media", "library-group:\(leadGroup)"],
            accentHex: "#4D6256", coverImageName: nil, destinationLabel: "Explore",
            products: references(selected.map(\.id)))
    }

    static func isLibraryStory(_ story: FeedStory) -> Bool { story.id.hasPrefix(storyPrefix) }

    static func wordmarkSources(for merchantID: String, onDark: Bool) -> [URL] {
        guard let merchant = merchantsByID[merchantID] else { return [] }
        let values = onDark ? [merchant.wordmarkWhite, merchant.wordmark, merchant.logo]
                            : [merchant.wordmark, merchant.wordmarkWhite, merchant.logo]
        var seen = Set<URL>()
        let preferred = LibraryWordmarkCatalog.sources(forMerchantID: merchantID, onDark: onDark)
        return (preferred + values.compactMap(nativeAsset)).filter { seen.insert($0).inserted }
    }
}
