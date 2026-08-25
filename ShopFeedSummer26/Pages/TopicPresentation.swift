import CoreGraphics
import Foundation
import UIKit

/// The single seam between authored topic art direction and the shared topic
/// renderer. Adding a topic changes this catalog; `TopicDetailPage` only knows
/// the presentation interface.
struct TopicPresentation {
    enum MerchantStyle {
        case standard
        case warmLighting
    }

    let kind: TopicPageKind
    let fixedSurfaceHex: String?
    let heroFallbackAsset: String?
    let heroTitleOverride: String?
    let merchantStyle: MerchantStyle
    let authoredBlocks: [String: AuthoredTopicBlock]

    var usesExactHeroLayout: Bool { heroFallbackAsset != nil }
    var softensLongPageSurface: Bool { !usesExactHeroLayout }
    var samplesVideoSurfaceColor: Bool { fixedSurfaceHex == nil }

    func recipe(
        contextualBentoTitle: String,
        automaticExploreFilters: [TopicProductFilter]
    ) -> TopicPageRecipe {
        TopicPageRecipeCatalog.recipe(
            for: kind,
            contextualBentoTitle: contextualBentoTitle,
            automaticExploreFilters: automaticExploreFilters
        )
    }

    func authoredBlock(for block: TopicPageBlock) -> AuthoredTopicBlock? {
        authoredBlocks[block.title]
    }

    var validationIssues: [String] {
        authoredBlocks.flatMap { title, block in
            block.validationIssues.map { "\(title): \($0)" }
        }
    }
}

struct AuthoredTopicProduct: Identifiable {
    let asset: String
    let merchant: String
    let title: String
    let price: String
    var id: String { asset }
}

struct AuthoredTopicCategory: Identifiable {
    let title: String
    let assets: [String]
    var id: String { title }
}

enum AuthoredTopicBlock {
    case products(title: String, products: [AuthoredTopicProduct])
    case cards(title: String, assetPrefix: String, count: Int, width: CGFloat, height: CGFloat)
    case categories(title: String, categories: [AuthoredTopicCategory])
    case mosaic(title: String, assetPrefix: String, largeHeight: CGFloat, smallHeight: CGFloat)
    case explore(title: String, filters: [String], products: [AuthoredTopicProduct])

    var validationIssues: [String] {
        let assets: [String]
        switch self {
        case .products(_, let products), .explore(_, _, let products):
            assets = products.map(\.asset)
        case .cards(_, let prefix, let count, let width, let height):
            if count <= 0 || width <= 0 || height <= 0 { return ["invalid card geometry"] }
            assets = (1...count).map { "\(prefix)-\($0)" }
        case .categories(_, let categories):
            if categories.isEmpty || categories.contains(where: { $0.assets.count != 5 }) {
                return ["categories require exactly five assets"]
            }
            assets = categories.flatMap(\.assets)
        case .mosaic(_, let prefix, let largeHeight, let smallHeight):
            if largeHeight <= 0 || smallHeight <= 0 { return ["invalid mosaic geometry"] }
            assets = (1...6).map { "\(prefix)-\($0)" }
        }
        if assets.isEmpty { return ["must contain authored assets"] }
        let missing = assets.filter { UIImage(named: $0) == nil }
        return missing.isEmpty ? [] : ["missing assets: \(missing.joined(separator: ", "))"]
    }
}

enum TopicPresentationCatalog {
    static func presentation(for story: FeedStory) -> TopicPresentation {
        let result: TopicPresentation
        switch story.id {
        case "kyle-argizari-lighting":
            result = TopicPresentation(
                kind: .warmDesignerLighting,
                fixedSurfaceHex: "#251705",
                heroFallbackAsset: "topic-warm-lighting-hero",
                heroTitleOverride: "Warm designer\nlighting",
                merchantStyle: .warmLighting,
                authoredBlocks: [:]
            )
        case HypothesisShelfCatalog.streetwearStoryID:
            result = streetwear
        case HypothesisShelfCatalog.performanceSneakerStoryID:
            result = performanceSneakers
        case "shelf-luke-2-sculptural-living-room-pieces":
            result = standard(kind: .sculpturalLiving)
        default:
            result = standard(kind: story.topicKeys.contains("merchant-card") ? .merchant : .standard)
        }
#if DEBUG
        if !result.validationIssues.isEmpty {
            print(
                "TopicPresentation validation failed for \(story.id): "
                    + result.validationIssues.joined(separator: ", ")
            )
        }
#endif
        return result
    }

    private static func standard(kind: TopicPageKind) -> TopicPresentation {
        TopicPresentation(
            kind: kind,
            fixedSurfaceHex: nil,
            heroFallbackAsset: nil,
            heroTitleOverride: nil,
            merchantStyle: .standard,
            authoredBlocks: [:]
        )
    }

    private static let streetwear: TopicPresentation = {
        let just = products("streetwear-just", merchants: ["S'Envoler", "Sports World NY", "HYPEDEPT", "Hat Club"], titles: ["Graphic tee", "New York Yankees cap", "Graphic tee", "New Era cap"], prices: ["$50.00", "$39.99", "$34.99", "$45.00"])
        let new = products("streetwear-new", merchants: ["Reigning Champ", "RC Outdoor Supply", "Reigning Champ", "CapsuleHats"], titles: ["Knit beanie", "Technical jacket", "Knit polo", "New Era cap"], prices: ["$65.00", "$198.00", "$150.00", "$38.00"])
        let caps = products("streetwear-caps", merchants: ["Nouveau", "Sports World NY", "Hat Club", "Bleacher Bum"], titles: ["Logo cap", "Los Angeles cap", "Embroidered cap", "New Era fitted"], prices: ["$55.00", "$39.99", "$45.00", "$42.00"])
        let unique = products("streetwear-unique", merchants: ["Culture Kings", "Cherry", "Nouveau", "Hat Club"], titles: ["Statement boots", "Graphic tee", "Red boots", "New Era cap"], prices: ["$180.00", "$65.00", "$220.00", "$45.00"])
        let explore = products("streetwear-explore", merchants: ["S'Envoler", "Reigning Champ", "Sports World NY", "Cherry", "RC Outdoor Supply", "HYPEDEPT"], titles: ["Oversized graphic tee", "Monogram cap", "New York Yankees cap", "Patterned knit", "Technical jacket", "Graphic tee"], prices: ["$88.00", "$60.00", "$39.99", "$145.00", "$198.00", "$34.99"])
        return TopicPresentation(
            kind: .hypebeast,
            fixedSurfaceHex: "#2D0C0C",
            heroFallbackAsset: "topic-streetwear-caps-hero",
            heroTitleOverride: nil,
            merchantStyle: .standard,
            authoredBlocks: [
                "Just dropped": .products(title: "Just dropped", products: just),
                "Featured deals": .cards(title: "Featured deals", assetPrefix: "streetwear-deal-card", count: 3, width: 266, height: 263),
                "New arrivals from your brands": .products(title: "New arrivals from your brands", products: new),
                "Related collections": .cards(title: "Related collections", assetPrefix: "streetwear-collection-card", count: 4, width: 364, height: 200),
                "Best sellers in caps": .products(title: "Best sellers in caps", products: caps),
                "Brands worth the hype": .cards(title: "Brands worth the hype", assetPrefix: "streetwear-brand-card", count: 2, width: 364, height: 370),
                "Unique finds": .products(title: "Unique finds", products: unique),
                "Browse by apparel by category": .categories(title: "Browse by apparel by category", categories: [
                    .init(title: "T-shirts", assets: assets("streetwear-category-tee", count: 5)),
                    .init(title: "Fitted caps", assets: assets("streetwear-category-cap", count: 5)),
                ]),
                "Complete the look": .mosaic(title: "Complete the look", assetPrefix: "streetwear-complete", largeHeight: 372, smallHeight: 182),
                "Explore more": .explore(title: "Explore more", filters: ["All", "Tees", "Caps", "Outerwear"], products: explore),
            ]
        )
    }()

    private static let performanceSneakers: TopicPresentation = {
        let just = products("sneaker-just", merchants: ["New Balance", "Nike", "ASICS", "Salomon"], titles: ["Performance runner", "Air Zoom trainer", "Gel running shoe", "Trail runner"], prices: Array(repeating: "$150.00", count: 4))
        let new = products("sneaker-new", merchants: ["Nike", "New Balance", "ASICS", "Salomon"], titles: ["Race day runner", "Fresh Foam runner", "Gel-Kayano", "XT trail shoe"], prices: Array(repeating: "$150.00", count: 4))
        let best = products("sneaker-best", merchants: ["Nike", "New Balance", "ASICS", "Salomon"], titles: ["Training shoe", "Performance trainer", "Gel trainer", "Technical runner"], prices: Array(repeating: "$150.00", count: 4))
        let explore = products("sneaker-explore", merchants: ["ASICS", "Salomon", "Nike", "New Balance", "HOKA", "Saucony", "Salomon", "ASICS"], titles: ["Gel performance runner", "XT trail runner", "Trail running shoe", "Fresh Foam runner", "Technical trail shoe", "Performance runner", "Advanced trail runner", "Gel terrain runner"], prices: ["$160.00", "$180.00", "$150.00", "$165.00", "$175.00", "$150.00", "$190.00", "$170.00"])
        return TopicPresentation(
            kind: .performanceSneakers,
            fixedSurfaceHex: "#0C0F2D",
            heroFallbackAsset: "topic-performance-sneaker-hero",
            heroTitleOverride: nil,
            merchantStyle: .standard,
            authoredBlocks: [
                "Just dropped": .products(title: "Just dropped", products: just),
                "Featured deals": .cards(title: "Featured deals", assetPrefix: "sneaker-deal-card", count: 2, width: 266, height: 263),
                "New arrivals from your brands": .products(title: "New arrivals from your brands", products: new),
                "Related collections": .cards(title: "Related collections", assetPrefix: "sneaker-collection-card", count: 4, width: 364, height: 200),
                "Best sellers in training shoes": .products(title: "Best sellers in training shoes", products: best),
                "Brands worth the hype": .cards(title: "Brands worth the hype", assetPrefix: "sneaker-brand-card", count: 2, width: 364, height: 370),
                "Browse sneakers by category": .cards(title: "Browse sneakers by category", assetPrefix: "sneaker-category-card", count: 2, width: 304, height: 288),
                "Pairs well with sneakers": .mosaic(title: "Pairs well with sneakers", assetPrefix: "sneaker-pair", largeHeight: 240, smallHeight: 117),
                "Explore more": .explore(title: "Explore more", filters: ["All", "Running", "Training", "Trail"], products: explore),
            ]
        )
    }()

    private static func products(_ prefix: String, merchants: [String], titles: [String], prices: [String]) -> [AuthoredTopicProduct] {
        merchants.indices.map {
            AuthoredTopicProduct(asset: "\(prefix)-\($0 + 1)", merchant: merchants[$0], title: titles[$0], price: prices[$0])
        }
    }

    private static func assets(_ prefix: String, count: Int) -> [String] {
        (1...count).map { "\(prefix)-\($0)" }
    }
}
