import SwiftUI

/// Background media must declare why it qualifies as lifestyle content.
/// Catalog packshots, packaging, grids, and promotional composites have no
/// valid role and therefore cannot enter the full-bleed rendering path.
enum FeedBackgroundMediaRole: String, Hashable {
    case merchantPost
    case inContext
    case wornOrUsed
    case editorial
}

/// Keeps the origin of every approved cover explicit. This lets the feed mix
/// real shelf products, richer canonical merchant galleries, merchant posts,
/// and bundled editorial art without turning those sources into rendering
/// conditionals scattered through the card view.
enum FeedCoverSource: Hashable {
    case productGallery(merchantID: String, productID: Int, imageIndex: Int)
    case remoteImage(url: String)
    case remoteVideo(url: String, posterURL: String?)
    case bundledVideo(resource: String, fileExtension: String)
    case bundledAsset(name: String)

    var bundledAssetName: String? {
        if case .bundledAsset(let name) = self { return name }
        return nil
    }

    func remoteURL(from merchants: [SampleMerchant]) -> URL? {
        switch self {
        case let .productGallery(merchantID, productID, imageIndex):
            guard let merchant = merchants.first(where: { $0.id == merchantID }),
                  let product = merchant.products.first(where: { $0.id == productID }) else {
                return nil
            }
            let images = product.allImageURLs.isEmpty
                ? [product.imageURL].compactMap { $0 }
                : product.allImageURLs
            guard !images.isEmpty else { return nil }
            return Self.normalizedURL(images[min(imageIndex, images.count - 1)])
        case .remoteImage(let url):
            return Self.normalizedURL(url)
        case .remoteVideo(_, let posterURL):
            return posterURL.flatMap(Self.normalizedURL)
        case .bundledVideo, .bundledAsset:
            return nil
        }
    }

    var videoURL: URL? {
        switch self {
        case .remoteVideo(let url, _):
            return Self.normalizedURL(url)
        case .bundledVideo(let resource, let fileExtension):
            return Bundle.main.url(forResource: resource, withExtension: fileExtension)
        default:
            return nil
        }
    }

    private static func normalizedURL(_ source: String) -> URL? {
        URL(string: source.hasPrefix("//") ? "https:\(source)" : source)
    }
}

/// An explicit cover decision for an editorial feed story. Product inventory
/// remains sourced from the buyer's shelf; this layer only decides which of
/// those real images is strong enough to become full-bleed media.
struct FeedCoverPresentation {
    let storyID: String
    let source: FeedCoverSource
    let mediaRole: FeedBackgroundMediaRole
    let alignment: Alignment
    let yOffset: CGFloat
    let scale: CGFloat
    let textScrimOpacity: Double

    init(
        storyID: String,
        source: FeedCoverSource,
        mediaRole: FeedBackgroundMediaRole,
        alignment: Alignment = .center,
        yOffset: CGFloat = 0,
        scale: CGFloat = 1,
        textScrimOpacity: Double = 0.48
    ) {
        self.storyID = storyID
        self.source = source
        self.mediaRole = mediaRole
        self.alignment = alignment
        self.yOffset = yOffset
        self.scale = scale
        self.textScrimOpacity = textScrimOpacity
    }

    init(
        storyID: String,
        merchantID: String,
        productID: Int,
        imageIndex: Int = 0,
        mediaRole: FeedBackgroundMediaRole,
        alignment: Alignment = .center,
        yOffset: CGFloat = 0,
        scale: CGFloat = 1,
        textScrimOpacity: Double = 0.48
    ) {
        self.storyID = storyID
        source = .productGallery(
            merchantID: merchantID,
            productID: productID,
            imageIndex: imageIndex
        )
        self.mediaRole = mediaRole
        self.alignment = alignment
        self.yOffset = yOffset
        self.scale = scale
        self.textScrimOpacity = textScrimOpacity
    }

    init(
        storyID: String,
        bundledAssetName: String,
        mediaRole: FeedBackgroundMediaRole = .editorial,
        alignment: Alignment = .center,
        yOffset: CGFloat = 0,
        scale: CGFloat = 1,
        textScrimOpacity: Double = 0.48
    ) {
        self.storyID = storyID
        source = .bundledAsset(name: bundledAssetName)
        self.mediaRole = mediaRole
        self.alignment = alignment
        self.yOffset = yOffset
        self.scale = scale
        self.textScrimOpacity = textScrimOpacity
    }

    func coverURL(from merchants: [SampleMerchant]) -> URL? {
        source.remoteURL(from: merchants)
    }
}

enum FeedCoverCatalog {
    private static let fallbackImagesByTopic: [String: [String]] = [
        "living": [
            "cover-sculptural-mirrors",
            "cover-tabletop-objects",
            "cover-design-for-kids",
        ],
        "style": ["cover-trail-to-street", "cover-birding"],
        "wellness": ["cover-scalp-care", "cover-birding"],
        "morning": ["cover-coffee-counter", "cover-tabletop-objects"],
        "outdoors": ["cover-birding", "cover-trail-to-street"],
        "design": ["cover-material-study", "cover-sculptural-mirrors"],
    ]

    private static let universalFallbackImages = [
        "cover-sculptural-mirrors",
        "cover-coffee-counter",
        "cover-tabletop-objects",
        "cover-trail-to-street",
        "cover-scalp-care",
        "cover-birding",
        "cover-design-for-kids",
        "cover-material-study",
    ]

    /// Luke's first authored pass. Real shelf or canonical merchant media wins.
    /// Bundled editorial covers are only used when the exact shelf galleries
    /// contain packshots, and are assigned by story rather than topic hashing.
    private static let authoredPresentations: [FeedCoverPresentation] = [
        .init(
            storyID: "kyle-argizari-lighting",
            source: .bundledVideo(resource: "warm-designer-lighting", fileExtension: "mp4"),
            mediaRole: .inContext,
            alignment: .center,
            textScrimOpacity: 0.36
        ),
        // Canonical topic covers. Each source is merchant-owned media tied to
        // the exact product, collection, or editorial world behind the story.
        // Source page: nocsprovisions.com/blogs/digest/edge-clarity
        .init(
            storyID: "city-to-trail-birding",
            source: .remoteImage(
                url: "https://www.nocsprovisions.com/cdn/shop/articles/edge-b-hero_cd5db1cf-b51e-4da6-9e6b-61420b46ea37.jpg?v=1782774502&width=1600"
            ),
            mediaRole: .editorial,
            alignment: .center,
            textScrimOpacity: 0.46
        ),
        .init(
            storyID: "sculptural-mirror-hunt",
            merchantID: "forom",
            productID: 7914833051779,
            imageIndex: 0,
            mediaRole: .inContext,
            alignment: .center,
            textScrimOpacity: 0.46
        ),
        .init(
            storyID: "type-systems",
            merchantID: "draw-down",
            productID: 1591926554714,
            imageIndex: 2,
            mediaRole: .editorial,
            alignment: .center,
            textScrimOpacity: 0.48
        ),
        .init(
            storyID: "coffee-counter",
            // Source page: fellowproducts.com/products/aiden-precision-coffee-maker
            source: .remoteImage(
                url: "https://fellowproducts.com/cdn/shop/files/Web_HP-Module_AidenColdBrewBundle.jpg?v=1785966992"
            ),
            mediaRole: .editorial,
            alignment: .center,
            textScrimOpacity: 0.44
        ),
        .init(
            storyID: "table-stranger",
            merchantID: "doiy",
            productID: 8300748931228,
            imageIndex: 2,
            mediaRole: .inContext,
            alignment: .center,
            textScrimOpacity: 0.44
        ),
        .init(
            storyID: "nursery-grown-up-room",
            merchantID: "babyletto",
            productID: 7652167942198,
            imageIndex: 3,
            mediaRole: .inContext,
            alignment: .center,
            textScrimOpacity: 0.5
        ),
        .init(
            storyID: "trail-to-street",
            // Source page: extrabutterny.com/blogs/extra-butter/
            // salomon-fall-winter-2020-footwear-capsule
            source: .remoteImage(
                url: "https://cdn.shopify.com/s/files/1/0236/4333/files/Salomon_EB_Look3-3.jpg?v=1605817987"
            ),
            mediaRole: .editorial,
            alignment: .center,
            textScrimOpacity: 0.5
        ),
        .init(
            storyID: "new-york-graphics",
            merchantID: "lichen",
            productID: 11009838154046,
            imageIndex: 3,
            mediaRole: .wornOrUsed,
            alignment: .center,
            textScrimOpacity: 0.48
        ),
        .init(
            storyID: "scalp-reset",
            merchantID: "ceremonia",
            productID: 7219216580772,
            imageIndex: 4,
            mediaRole: .wornOrUsed,
            alignment: .top,
            textScrimOpacity: 0.5
        ),
        .init(
            storyID: "black-silver-signal",
            merchantID: "house-of-leon",
            productID: 7873592721581,
            imageIndex: 0,
            mediaRole: .inContext,
            alignment: .center,
            textScrimOpacity: 0.46
        ),
        .init(
            storyID: "shelf-luke-1-modern-bathroom-fixtures",
            merchantID: "shelf-shop-upton-ff049dd",
            productID: 3391803343539049754,
            mediaRole: .inContext,
            alignment: .center,
            textScrimOpacity: 0.56
        ),
        .init(
            storyID: "shelf-luke-2-sculptural-living-room-pieces",
            source: .bundledVideo(
                resource: "sculptural-living-room",
                fileExtension: "mp4"
            ),
            mediaRole: .inContext,
            alignment: .center,
            textScrimOpacity: 0.42
        ),
        .init(
            storyID: "shelf-luke-3-playful-coffee-table",
            source: .bundledVideo(resource: "caraway-feed", fileExtension: "mp4"),
            mediaRole: .wornOrUsed,
            alignment: .center,
            textScrimOpacity: 0.46
        ),
        .init(
            storyID: "shelf-luke-4-whimsical-sculptural-decor",
            merchantID: "shelf-shop-herb-living-ff3ff2c",
            productID: 2180918525698509762,
            mediaRole: .inContext,
            textScrimOpacity: 0.46
        ),
        .init(
            storyID: "shelf-luke-5-modernist-graphic-design-library",
            bundledAssetName: "cover-type-systems",
            alignment: .top,
            textScrimOpacity: 0.44
        ),
        .init(
            storyID: "shelf-luke-6-analog-watches-desk-clocks",
            merchantID: "shelf-shop-vhail-bcc39aa",
            productID: 2570243354690201607,
            mediaRole: .inContext,
            textScrimOpacity: 0.42
        ),
        .init(
            storyID: "shelf-luke-7-stylish-travel-essentials",
            source: .bundledVideo(resource: "olend-travel", fileExtension: "mp4"),
            mediaRole: .wornOrUsed,
            alignment: .center,
            textScrimOpacity: 0.48
        ),
        .init(
            storyID: "shelf-luke-8-ceremonia-hair-ritual",
            merchantID: "ceremonia",
            productID: 15369056321905,
            imageIndex: 3,
            mediaRole: .wornOrUsed,
            alignment: .top,
            textScrimOpacity: 0.5
        ),
        .init(
            storyID: "luke-gift-guide-for-son",
            source: .remoteImage(
                url: "https://tincan.kids/cdn/shop/files/2026-06-Website-Hero-Photo-mobile.jpg?v=1781018822&width=1200"
            ),
            mediaRole: .wornOrUsed,
            alignment: .center,
            textScrimOpacity: 0.36
        ),
        .init(
            storyID: "shelf-luke-9-streetwear-caps-and-tees",
            source: .bundledVideo(resource: "streetwear-staples", fileExtension: "mp4"),
            mediaRole: .editorial,
            alignment: .center,
            textScrimOpacity: 0.38
        ),
        .init(
            storyID: "shelf-luke-11-neutral-activewear-essentials",
            merchantID: "shelf-shop-alo-yoga-561ac5f",
            productID: 5072467516453192554,
            mediaRole: .wornOrUsed,
            alignment: .top,
            textScrimOpacity: 0.48
        ),
        .init(
            storyID: "shelf-luke-12-modern-kids-seating-tables",
            merchantID: "shelf-shop-kidkraft-com-fff90d2",
            productID: 6913395034556184462,
            mediaRole: .wornOrUsed,
            textScrimOpacity: 0.48
        ),
        .init(
            storyID: "shelf-luke-14-sculptural-bath-finishing-touches",
            merchantID: "shelf-shop-upton-ff049dd",
            productID: 1360197513559918501,
            mediaRole: .inContext,
            textScrimOpacity: 0.5
        ),
        .init(
            storyID: "shelf-luke-15-elevated-winter-knits",
            source: .bundledVideo(resource: "rcout-knit", fileExtension: "mp4"),
            mediaRole: .wornOrUsed,
            alignment: .center,
            textScrimOpacity: 0.48
        ),
        .init(
            storyID: "shelf-luke-16-artist-collab-tees-hoodies-prints",
            source: .bundledVideo(resource: "senvoler-collab", fileExtension: "mp4"),
            mediaRole: .wornOrUsed,
            alignment: .center,
            textScrimOpacity: 0.5
        ),
        .init(
            storyID: "shelf-luke-17-pro-level-painting-essentials",
            source: .bundledVideo(resource: "fuumuu-painting", fileExtension: "mp4"),
            mediaRole: .wornOrUsed,
            alignment: .center,
            textScrimOpacity: 0.48
        ),
        .init(
            storyID: "shelf-luke-10-performance-sneakers-edit",
            source: .bundledVideo(resource: "stadium-sneakers", fileExtension: "mp4"),
            mediaRole: .editorial,
            alignment: .center,
            textScrimOpacity: 0.48
        ),
        .init(
            storyID: "shelf-luke-19-race-day-and-daily-trainers",
            bundledAssetName: "cover-trail-to-street",
            scale: 1.08,
            textScrimOpacity: 0.5
        ),
    ]

    private static let presentationsByStoryID = Dictionary(
        uniqueKeysWithValues: authoredPresentations.map { ($0.storyID, $0) }
    )

    static func presentation(for story: FeedStory) -> FeedCoverPresentation? {
        presentationsByStoryID[story.id]
    }

    /// Guarantees a vetted lifestyle/editorial image behind every feed card.
    /// Product- and merchant-specific authored media still wins; this is the
    /// final visual fallback instead of a flat color or enlarged PDP image.
    static func fallbackImageName(for story: FeedStory) -> String {
        fallbackImageName(stableID: story.id, topicKeys: Array(story.topicKeys))
    }

    static func fallbackImageName(stableID: String, topicKeys: [String] = []) -> String {
        let topicPriority = ["living", "style", "wellness", "morning", "outdoors", "design"]
        let topic = topicPriority.first { topicKeys.contains($0) }
        let candidates = topic.flatMap { fallbackImagesByTopic[$0] } ?? universalFallbackImages
        let stableSeed = stableID.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return candidates[abs(stableSeed) % candidates.count]
    }
}

/// A collection-level merchant treatment is only authored when the story is
/// genuinely a coherent assortment from one shop. This keeps a visual card
/// variant from quietly turning a mixed editorial story into fake inventory.
struct MerchantCollectionPresentation: Hashable {
    /// Merchant-owned frames that have been visually checked as a single,
    /// clean lifestyle photograph. Product galleries can include contact
    /// sheets and campaign collages, so they must never be treated as a
    /// universally safe full-bleed source just because they are one URL.
    private static let approvedLifestyleCoversByMerchantID: [String: String] = [
        "lichen": "https://cdn.shopify.com/s/files/1/0026/8907/3221/files/2024_03_22_Lichen2201copy_05fe8826-36e0-41b1-8736-3ff26985200f.jpg?v=1713408513",
    ]

    let storyID: String
    /// Owns the exact buyer-profile assortment rendered in the product grid.
    let merchantID: String
    /// Optional canonical merchant record used only for verified identity,
    /// lifestyle media, and the store destination.
    let brandMerchantID: String?
    let productCount: Int
    let coverProductID: Int
    let coverImageIndex: Int
    let lifestyleCoverURL: String?
    let coverYOffset: CGFloat
    /// Only authored lifestyle media is allowed to fill the card. Generated
    /// catalog packshots often contain labels, banners, or baked-in copy.
    let usesImageCover: Bool

    init(
        storyID: String,
        merchantID: String,
        brandMerchantID: String? = nil,
        productCount: Int,
        coverProductID: Int,
        coverImageIndex: Int,
        lifestyleCoverURL: String? = nil,
        coverYOffset: CGFloat = 0,
        usesImageCover: Bool = true
    ) {
        self.storyID = storyID
        self.merchantID = merchantID
        self.brandMerchantID = brandMerchantID
        self.productCount = productCount
        self.coverProductID = coverProductID
        self.coverImageIndex = coverImageIndex
        self.lifestyleCoverURL = lifestyleCoverURL
        self.coverYOffset = coverYOffset
        self.usesImageCover = usesImageCover
    }

    func coverURL(from merchants: [SampleMerchant]) -> URL? {
        if let lifestyleCoverURL {
            let normalized = lifestyleCoverURL.hasPrefix("//")
                ? "https:\(lifestyleCoverURL)"
                : lifestyleCoverURL
            return URL(string: normalized)
        }
        let coverMerchantID = brandMerchantID ?? merchantID
        if let approvedLifestyleCover = Self.approvedLifestyleCoversByMerchantID[coverMerchantID] {
            return URL(string: approvedLifestyleCover)
        }
        guard let merchant = merchants.first(where: { $0.id == coverMerchantID }) else {
            return nil
        }
        // A single authored PDP alternate is a better full-bleed cover than a
        // merchant-level collection collage. Existing presentations already
        // identify the intended product and frame; relationship stories use
        // the same contract dynamically.
        let coverProduct = merchant.products.first { $0.id == coverProductID }
        let source = coverProduct.flatMap { product -> String? in
            guard product.allImageURLs.indices.contains(coverImageIndex) else {
                return product.allImageURLs.dropFirst().first ?? product.imageURL
            }
            return product.allImageURLs[coverImageIndex]
        } ?? merchant.bestCoverImageURL
        guard let source else { return nil }
        let normalized = source.hasPrefix("//") ? "https:\(source)" : source
        return URL(string: normalized)
    }
}

enum MerchantCollectionCatalog {
    /// High-confidence buyer matches backed by the canonical catalog fixtures.
    /// Four-up cards preserve more of the lifestyle cover; six-up is reserved
    /// for merchants with a genuinely broader assortment.
    private static let authoredPresentations: [MerchantCollectionPresentation] = [
        .init(
            storyID: "discovery-nocs-field-kit",
            merchantID: "nocs",
            productCount: 2,
            coverProductID: 10432692846871,
            coverImageIndex: 1
        ),
        .init(
            storyID: "discovery-fellow-coffee-workflow",
            merchantID: "fellow",
            productCount: 2,
            coverProductID: 2055410221171,
            coverImageIndex: 1
        ),
        .init(
            storyID: "discovery-house-of-leon-reading-room",
            merchantID: "house-of-leon",
            productCount: 2,
            coverProductID: 7873592721581,
            coverImageIndex: 1
        ),
        .init(
            storyID: "discovery-draw-down-type-books",
            merchantID: "draw-down",
            productCount: 3,
            coverProductID: 7804062892286,
            coverImageIndex: 1
        ),
        .init(
            storyID: "andreas-lange-routine",
            merchantID: "lange-hair",
            productCount: 4,
            coverProductID: 4804878434404,
            coverImageIndex: 1
        ),
        .init(
            storyID: "andreas-minimal-comfort",
            merchantID: "comfrt",
            productCount: 4,
            coverProductID: 7287683743788,
            coverImageIndex: 1
        ),
        .init(
            storyID: "kyle-1890-collabs",
            merchantID: "kith",
            productCount: 4,
            coverProductID: 8286509564032,
            coverImageIndex: 1
        ),
        .init(
            storyID: "kyle-braided-bostons",
            merchantID: "kith",
            productCount: 4,
            coverProductID: 8286022762624,
            coverImageIndex: 1
        ),
        .init(
            storyID: "kyle-argizari-lighting",
            merchantID: "city-lights-sf",
            productCount: 6,
            coverProductID: 8568483807399,
            coverImageIndex: 1
        ),
        .init(
            storyID: "tobi-xbloom-system",
            merchantID: "xbloom",
            productCount: 4,
            coverProductID: 8424667807968,
            coverImageIndex: 1
        ),
        .init(
            storyID: "tobi-manmade-basics",
            merchantID: "manmade",
            productCount: 4,
            coverProductID: 8829694050617,
            coverImageIndex: 1
        ),
        .init(
            storyID: "tobi-wet-shave",
            merchantID: "henson-shaving",
            productCount: 4,
            coverProductID: 7234770337872,
            coverImageIndex: 2
        ),
        .init(
            storyID: "tobi-sim-racing",
            merchantID: "moza-racing",
            productCount: 4,
            coverProductID: 10209094500672,
            coverImageIndex: 2,
            coverYOffset: -142
        ),
        .init(
            storyID: "katarina-rick-owens",
            merchantID: "svrn-rick-owens",
            productCount: 4,
            coverProductID: 15632596205641,
            coverImageIndex: 1
        ),
        .init(
            storyID: "katarina-silver",
            merchantID: "vitaly",
            productCount: 4,
            coverProductID: 4415294537803,
            coverImageIndex: 2
        ),
        .init(
            storyID: "katarina-black-swim",
            merchantID: "matteau",
            productCount: 4,
            coverProductID: 9025373044958,
            coverImageIndex: 1
        ),
        .init(
            storyID: "katarina-rhode-routine",
            merchantID: "rhode",
            productCount: 6,
            coverProductID: 8070391660782,
            // The first three entries are duplicate packshots. This is
            // Rhode's official mobile lifestyle still for Glazing Milk.
            coverImageIndex: 4
        ),
        .init(
            storyID: "edit-wash-day-reset",
            merchantID: "ceremonia",
            productCount: 4,
            coverProductID: 15369056321905,
            // Use the single-frame wash-day lifestyle still. Index 1 is a
            // four-panel campaign collage that competes with the card's own
            // product grid and creates an unintended grid-on-grid treatment.
            coverImageIndex: 3
        ),
    ]

    static var presentations: [MerchantCollectionPresentation] {
        authoredPresentations + HypothesisShelfCatalog.merchantCollectionPresentations
    }

    static func presentation(for storyID: String) -> MerchantCollectionPresentation? {
        if let authored = presentations.first(where: { $0.storyID == storyID }) {
            return authored
        }
        let parts = storyID.components(separatedBy: "::")
        guard parts.count == 4,
              parts[0] == "relcollection",
              let productID = Int(parts[2]) else { return nil }
        return MerchantCollectionPresentation(
            storyID: storyID,
            merchantID: parts[1],
            productCount: 4,
            coverProductID: productID,
            coverImageIndex: 2
        )
    }
}

/// Central mapping between Shop merchant identifiers and the official,
/// normalized white wordmarks bundled by `sync_merchant_wordmarks.py`.
enum MerchantBrandAssets {
    private static let aliases: [String: String] = [
        "nocs": "nocs-provisions",
        "moma": "moma-design-store",
        "svrn-rick-owens": "svrn",
        "feature-salomon": "feature",
        "extra-butter-salomon": "extra-butter",
        "shelf-shop-the-oblist-02fd47c": "the-oblist",
    ]

    /// Storefront scraping can surface payment sprites or campaign art near
    /// the word "logo". These brands intentionally use a clean native text
    /// treatment until an official reusable wordmark is verified.
    private static let textFallbackOnly: Set<String> = [
        "standards-manual",
    ]

    static func hasVerifiedBundledWordmark(for merchantID: String) -> Bool {
        let assetID = aliases[merchantID] ?? merchantID
        return (!merchantID.hasPrefix("shelf-shop-") || aliases[merchantID] != nil)
            && !textFallbackOnly.contains(assetID)
    }

    static func wordmarkName(for merchantID: String) -> String {
        let assetID = aliases[merchantID] ?? merchantID
        return "merchant-wordmark-\(assetID)"
    }
}
