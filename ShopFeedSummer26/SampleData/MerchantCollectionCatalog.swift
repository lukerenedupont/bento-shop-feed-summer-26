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
    case bundledAsset(name: String)

    var bundledAssetName: String? {
        guard case .bundledAsset(let name) = self else { return nil }
        return name
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
        case .bundledAsset:
            return nil
        }
    }

    var videoURL: URL? {
        guard case .remoteVideo(let url, _) = self else { return nil }
        return Self.normalizedURL(url)
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
            storyID: "shelf-luke-1-modern-bathroom-fixtures",
            merchantID: "shelf-shop-upton-ff049dd",
            productID: 3391803343539049754,
            mediaRole: .inContext,
            alignment: .center,
            textScrimOpacity: 0.56
        ),
        .init(
            storyID: "shelf-luke-2-sculptural-living-room-pieces",
            merchantID: "shelf-shop-a-e-bowery-lighting-29b49c3",
            productID: 1588130628707273584,
            mediaRole: .inContext,
            alignment: .center,
            textScrimOpacity: 0.42
        ),
        .init(
            storyID: "shelf-luke-3-playful-coffee-table",
            bundledAssetName: "cover-coffee-counter",
            textScrimOpacity: 0.42
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
            merchantID: "shelf-shop-comfrt-6d9274b",
            productID: 8836003514488376238,
            mediaRole: .wornOrUsed,
            alignment: .top,
            textScrimOpacity: 0.52
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
            merchantID: "shelf-shop-alo-yoga-561ac5f",
            productID: 5790741028039858671,
            mediaRole: .wornOrUsed,
            alignment: .top,
            textScrimOpacity: 0.5
        ),
        .init(
            storyID: "shelf-luke-16-artist-collab-tees-hoodies-prints",
            merchantID: "shelf-shop-classic-paris-249db76",
            productID: 4066842927228705409,
            mediaRole: .inContext,
            textScrimOpacity: 0.46
        ),
        .init(
            storyID: "shelf-luke-10-performance-sneakers-edit",
            bundledAssetName: "cover-trail-to-street",
            textScrimOpacity: 0.46
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
        guard let merchant = merchants.first(where: { $0.id == coverMerchantID }),
              let source = merchant.bestCoverImageURL else {
            return nil
        }
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
        presentations.first { $0.storyID == storyID }
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
    ]

    /// Storefront scraping can surface payment sprites or campaign art near
    /// the word "logo". These brands intentionally use a clean native text
    /// treatment until an official reusable wordmark is verified.
    private static let textFallbackOnly: Set<String> = [
        "standards-manual",
    ]

    static func hasVerifiedBundledWordmark(for merchantID: String) -> Bool {
        let assetID = aliases[merchantID] ?? merchantID
        return !merchantID.hasPrefix("shelf-shop-")
            && !textFallbackOnly.contains(assetID)
    }

    static func wordmarkName(for merchantID: String) -> String {
        let assetID = aliases[merchantID] ?? merchantID
        return "merchant-wordmark-\(assetID)"
    }
}
