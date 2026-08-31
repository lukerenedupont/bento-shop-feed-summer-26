import CoreGraphics
import Foundation

/// The finite set of layouts supported by the shared topic renderer.
/// A topic selects a recipe; it never creates another view hierarchy.
enum TopicPageKind {
    case sculpturalLiving
    case warmDesignerLighting
    case hypebeast
    case performanceSneakers
    case giftGuidePrototype
    case merchant
    case standard
}

enum TopicBlockMetrics {
    static let sectionSpacing: CGFloat = 28
    static let relaxedSectionSpacing: CGFloat = 32
    static let compactProductWidth: CGFloat = 116
    static let mediumProductWidth: CGFloat = 132
    static let compactCollectionHeight: CGFloat = 200
    static let collectionHeight: CGFloat = 220
}

struct TopicPageRecipe {
    let sectionSpacing: CGFloat
    let blocks: [TopicPageBlock]

    var validationIssues: [String] {
        var issues: [String] = []
        if sectionSpacing <= 0 { issues.append("section spacing must be positive") }
        if blocks.isEmpty { issues.append("recipe must contain blocks") }

        var titles = Set<String>()
        for block in blocks {
            let title = block.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if title.isEmpty { issues.append("block title must not be empty") }
            if !titles.insert(title).inserted { issues.append("duplicate block title: \(title)") }
            issues.append(contentsOf: block.validationIssues.map { "\(title): \($0)" })
        }
        return issues
    }
}

enum TopicPageBlock {
    case productRail(title: String, query: TopicProductQuery, cardWidth: CGFloat)
    case featuredDeals(title: String)
    case relatedCollections(title: String, cardHeight: CGFloat)
    case topMerchants(title: String)
    case brandGrid(title: String)
    case categories(title: String, items: [TopicCategoryDefinition], snaps: Bool)
    case curatedLooks(title: String, looks: [TopicCuratedLookDefinition])
    case recentContent(title: String, allowsCatalogFallback: Bool)
    case bento(title: String)
    case explore(title: String, filters: [TopicProductFilter])

    var title: String {
        switch self {
        case .productRail(let title, _, _), .featuredDeals(let title),
             .relatedCollections(let title, _), .topMerchants(let title),
             .brandGrid(let title), .categories(let title, _, _),
             .curatedLooks(let title, _), .recentContent(let title, _),
             .bento(let title), .explore(let title, _):
            title
        }
    }

    var validationIssues: [String] {
        switch self {
        case .productRail(_, let query, let cardWidth):
            var issues = query.validationIssues
            if !(96...180).contains(cardWidth) { issues.append("card width must be 96–180pt") }
            return issues
        case .relatedCollections(_, let cardHeight):
            return (180...260).contains(cardHeight) ? [] : ["card height must be 180–260pt"]
        case .categories(_, let items, _):
            var issues = items.count >= 3 ? [] : ["needs at least 3 categories"]
            let names = items.map(\.title)
            if Set(names).count != names.count { issues.append("category names must be unique") }
            issues.append(contentsOf: items.flatMap { $0.query.validationIssues })
            return issues
        case .curatedLooks(_, let looks):
            return looks.count >= 2 ? [] : ["needs at least 2 looks"]
        case .explore(_, let filters):
            var issues = filters.first == .all ? [] : ["first filter must be All"]
            let names = filters.map(\.title)
            if Set(names).count != names.count { issues.append("filter names must be unique") }
            return issues
        case .featuredDeals, .topMerchants, .brandGrid, .recentContent, .bento:
            return []
        }
    }
}

struct TopicProductQuery {
    var matching: [String] = []
    var excluding: [String] = []
    var fallbackOffset = 0
    var count = 8

    var validationIssues: [String] {
        count >= 3 ? [] : ["product query needs at least 3 results"]
    }
}

struct TopicCategoryDefinition {
    let title: String
    let query: TopicProductQuery
}

struct TopicProductFilter: Identifiable, Equatable {
    let title: String
    let terms: [String]
    var id: String { title }

    static let all = TopicProductFilter(title: "All", terms: [])
}

enum TopicCuratedLookStyle {
    case green
    case oxblood
}

struct TopicCuratedLookDefinition {
    let title: String
    let style: TopicCuratedLookStyle
    let query: TopicProductQuery
}

enum TopicPageRecipeCatalog {
    static func recipe(
        for kind: TopicPageKind,
        contextualBentoTitle: String,
        automaticExploreFilters: [TopicProductFilter]
    ) -> TopicPageRecipe {
        let result = switch kind {
        case .sculpturalLiving:
            sculpturalLiving
        case .warmDesignerLighting:
            warmDesignerLighting
        case .hypebeast:
            hypebeast
        case .performanceSneakers:
            performanceSneakers
        case .giftGuidePrototype:
            standard(
                bentoTitle: contextualBentoTitle,
                filters: automaticExploreFilters
            )
        case .merchant:
            merchant(filters: automaticExploreFilters)
        case .standard:
            standard(
                bentoTitle: contextualBentoTitle,
                filters: automaticExploreFilters
            )
        }
#if DEBUG
        assert(
            result.validationIssues.isEmpty,
            "Invalid topic recipe: \(result.validationIssues.joined(separator: ", "))"
        )
#endif
        return result
    }

    private static let sculpturalLiving = TopicPageRecipe(sectionSpacing: TopicBlockMetrics.sectionSpacing, blocks: [
        .productRail(title: "Just dropped", query: .init(fallbackOffset: 0), cardWidth: TopicBlockMetrics.compactProductWidth),
        .featuredDeals(title: "Featured deals"),
        .productRail(title: "Best sellers in lighting", query: .init(fallbackOffset: 3), cardWidth: TopicBlockMetrics.compactProductWidth),
        .relatedCollections(title: "Related collections", cardHeight: TopicBlockMetrics.compactCollectionHeight),
        .productRail(title: "New arrivals from your brands", query: .init(fallbackOffset: 7), cardWidth: TopicBlockMetrics.compactProductWidth),
        .brandGrid(title: "Brands worth the hype"),
        .productRail(title: "Unique finds", query: .init(fallbackOffset: 11), cardWidth: TopicBlockMetrics.compactProductWidth),
        .categories(
            title: "Browse by type",
            items: [
                .init(title: "Pendants", query: .init(matching: ["pendant", "chandelier", "ceiling", "hanging"], fallbackOffset: 0, count: 5)),
                .init(title: "Table lamps", query: .init(matching: ["table lamp", "desk lamp", "portable lamp", "lamp"], excluding: ["floor", "pendant", "ceiling"], fallbackOffset: 5, count: 5)),
                .init(title: "Floor lamps", query: .init(matching: ["floor lamp", "standing lamp"], fallbackOffset: 10, count: 5)),
            ],
            snaps: true
        ),
        .recentContent(title: "Recent posts", allowsCatalogFallback: true),
        .bento(title: "Pairs well with warm lighting"),
        .explore(title: "Explore more", filters: [
            .all,
            .init(title: "Lighting", terms: ["lamp", "light", "pendant", "chandelier"]),
            .init(title: "Tables", terms: ["table", "stand", "console"]),
            .init(title: "Mirrors", terms: ["mirror"]),
        ]),
    ])

    private static let warmDesignerLighting = TopicPageRecipe(sectionSpacing: TopicBlockMetrics.sectionSpacing, blocks: [
        .productRail(title: "Just dropped", query: .init(fallbackOffset: 0), cardWidth: TopicBlockMetrics.compactProductWidth),
        .featuredDeals(title: "Featured deals"),
        .productRail(
            title: "Best sellers in table lamps",
            query: .init(matching: ["table lamp", "desk lamp", "portable lamp"], fallbackOffset: 1),
            cardWidth: TopicBlockMetrics.compactProductWidth
        ),
        .relatedCollections(title: "Related collections", cardHeight: TopicBlockMetrics.compactCollectionHeight),
        .brandGrid(title: "Top brands"),
        .categories(
            title: "Browse by type",
            items: [
                .init(title: "Pendants", query: .init(matching: ["pendant", "chandelier", "ceiling"], fallbackOffset: 3, count: 5)),
                .init(title: "Table lamps", query: .init(matching: ["table lamp", "desk lamp", "portable lamp"], fallbackOffset: 0, count: 5)),
                .init(title: "Floor lamps", query: .init(matching: ["floor lamp", "standing lamp"], fallbackOffset: 7, count: 5)),
            ],
            snaps: true
        ),
        .recentContent(title: "Recent posts", allowsCatalogFallback: true),
        .bento(title: "Pairs well with warm lighting"),
        .explore(title: "Explore more", filters: [
            .all,
            .init(title: "Table lamps", terms: ["table lamp", "desk lamp", "portable lamp"]),
            .init(title: "Pendants", terms: ["pendant", "chandelier", "ceiling"]),
            .init(title: "Floor lamps", terms: ["floor lamp", "standing lamp"]),
        ]),
    ])

    private static let hypebeast = TopicPageRecipe(sectionSpacing: TopicBlockMetrics.relaxedSectionSpacing, blocks: [
        .productRail(title: "Just dropped", query: .init(fallbackOffset: 0), cardWidth: TopicBlockMetrics.compactProductWidth),
        .featuredDeals(title: "Featured deals"),
        .productRail(title: "New arrivals from your brands", query: .init(fallbackOffset: 6), cardWidth: TopicBlockMetrics.compactProductWidth),
        .relatedCollections(title: "Related collections", cardHeight: TopicBlockMetrics.collectionHeight),
        .productRail(
            title: "Best sellers in caps",
            query: .init(matching: ["cap", "hat", "snapback", "fitted", "new era"], fallbackOffset: 8),
            cardWidth: TopicBlockMetrics.compactProductWidth
        ),
        .brandGrid(title: "Brands worth the hype"),
        .productRail(title: "Unique finds", query: .init(fallbackOffset: 14), cardWidth: TopicBlockMetrics.compactProductWidth),
        .curatedLooks(title: "Curated looks", looks: [
            .init(title: "The green edit", style: .green, query: .init(fallbackOffset: 2, count: 6)),
            .init(title: "The oxblood edit", style: .oxblood, query: .init(fallbackOffset: 9, count: 6)),
        ]),
        .categories(
            title: "Browse by apparel by category",
            items: [
                .init(title: "T-shirts", query: .init(matching: ["shirt", "tee", "jersey"], fallbackOffset: 0, count: 5)),
                .init(title: "Fitted caps", query: .init(matching: ["hat", "cap", "snapback", "fitted", "new era"], fallbackOffset: 5, count: 5)),
                .init(title: "Jackets", query: .init(matching: ["jacket", "outerwear", "coat"], fallbackOffset: 10, count: 5)),
            ],
            snaps: false
        ),
        .recentContent(title: "Recent posts", allowsCatalogFallback: true),
        .bento(title: "Complete the look"),
        .explore(title: "Explore more", filters: [
            .all,
            .init(title: "Apparel", terms: ["shirt", "tee", "jacket", "pant", "hoodie"]),
            .init(title: "Caps", terms: ["hat", "cap", "snapback", "fitted", "new era"]),
            .init(title: "Accessories", terms: ["bag", "watch", "sunglasses", "accessory"]),
        ]),
    ])

    private static let performanceSneakers = TopicPageRecipe(sectionSpacing: TopicBlockMetrics.sectionSpacing, blocks: [
        .productRail(title: "Just dropped", query: .init(fallbackOffset: 0), cardWidth: TopicBlockMetrics.compactProductWidth),
        .featuredDeals(title: "Featured deals"),
        .productRail(title: "New arrivals from your brands", query: .init(fallbackOffset: 5), cardWidth: TopicBlockMetrics.compactProductWidth),
        .relatedCollections(title: "Related collections", cardHeight: TopicBlockMetrics.compactCollectionHeight),
        .productRail(
            title: "Best sellers in training shoes",
            query: .init(matching: ["trainer", "training", "runner", "running", "performance"], fallbackOffset: 8),
            cardWidth: TopicBlockMetrics.compactProductWidth
        ),
        .brandGrid(title: "Brands worth the hype"),
        .recentContent(title: "Recent posts", allowsCatalogFallback: true),
        .categories(
            title: "Browse sneakers by category",
            items: [
                .init(title: "Running", query: .init(matching: ["running", "runner", "performance", "trainer"], fallbackOffset: 0, count: 5)),
                .init(title: "Hiking", query: .init(matching: ["hiking", "trail", "outdoor", "gore-tex"], fallbackOffset: 5, count: 5)),
                .init(title: "Training", query: .init(matching: ["training", "workout", "gym", "cross"], fallbackOffset: 10, count: 5)),
            ],
            snaps: true
        ),
        .bento(title: "Pairs well with sneakers"),
        .explore(title: "Explore more", filters: [
            .all,
            .init(title: "Running", terms: ["running", "runner", "performance", "trainer"]),
            .init(title: "New Balance", terms: ["new balance", "992", "993", "990"]),
            .init(title: "Nike", terms: ["nike", "dunk", "p-6000"]),
        ]),
    ])

    private static func merchant(filters: [TopicProductFilter]) -> TopicPageRecipe {
        TopicPageRecipe(sectionSpacing: TopicBlockMetrics.sectionSpacing, blocks: [
            .productRail(title: "New and noteworthy", query: .init(fallbackOffset: 0, count: 8), cardWidth: TopicBlockMetrics.compactProductWidth),
            .featuredDeals(title: "Current offers"),
            .productRail(title: "Best sellers", query: .init(fallbackOffset: 3, count: 8), cardWidth: TopicBlockMetrics.compactProductWidth),
            .recentContent(title: "Recent posts", allowsCatalogFallback: true),
            .bento(title: "Shop the collection"),
            .explore(title: "Explore more", filters: filters),
        ])
    }

    private static func standard(
        bentoTitle: String,
        filters: [TopicProductFilter]
    ) -> TopicPageRecipe {
        TopicPageRecipe(sectionSpacing: TopicBlockMetrics.sectionSpacing, blocks: [
            .productRail(title: "New this week", query: .init(fallbackOffset: 0, count: 6), cardWidth: TopicBlockMetrics.mediumProductWidth),
            .featuredDeals(title: "Featured deals"),
            .productRail(title: "Best sellers", query: .init(fallbackOffset: 3, count: 6), cardWidth: TopicBlockMetrics.mediumProductWidth),
            .relatedCollections(title: "Related collections", cardHeight: TopicBlockMetrics.collectionHeight),
            .productRail(title: "More from your brands", query: .init(fallbackOffset: 6, count: 8), cardWidth: TopicBlockMetrics.compactProductWidth),
            .topMerchants(title: "Top merchants"),
            .recentContent(title: "Recent posts", allowsCatalogFallback: true),
            .bento(title: bentoTitle),
            .explore(title: "Explore more", filters: filters),
        ])
    }
}
