import SwiftUI
import UIKit
import AVFoundation

/// The page is assembled from these finite merchandising primitives. Adding a
/// topic should mean authoring a recipe, not adding another view hierarchy.
private struct TopicPageRecipe {
    let sectionSpacing: CGFloat
    let blocks: [TopicPageBlock]
}

private enum TopicPageBlock {
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
}

private struct TopicProductQuery {
    var matching: [String] = []
    var excluding: [String] = []
    var fallbackOffset = 0
    var count = 8
}

private struct TopicCategoryDefinition {
    let title: String
    let query: TopicProductQuery
}

private struct TopicProductFilter: Identifiable, Equatable {
    let title: String
    let terms: [String]
    var id: String { title }

    static let all = TopicProductFilter(title: "All", terms: [])
}

private enum TopicCuratedLookStyle {
    case green
    case oxblood
}

private struct TopicCuratedLookDefinition {
    let title: String
    let style: TopicCuratedLookStyle
    let query: TopicProductQuery
}

private struct TopicPresentedAssortment: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let products: [ResolvedStoryProduct]
}

/// Immersive destination for a tapped feed story. The Figma-derived header
/// and first commerce rails resolve from the story, so every buyer and topic
/// shares one presentation instead of branching into profile-specific views.
struct TopicDetailPage: View {
    let story: FeedStory
    let merchants: [SampleMerchant]
    /// Resolve the authored assortment once when navigation creates the
    /// destination. This used to scan the full merchant catalog every time
    /// SwiftUI evaluated any rail on the page.
    private let products: [ResolvedStoryProduct]
    /// The long rails share one stable assortment instead of rebuilding it
    /// independently for every `productWindow` call.
    private let exploreProducts: [ResolvedStoryProduct]

    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @State private var showsControls = false
    @State private var isFollowingTopic = false
    @State private var focusedDealID: String?
    @State private var postService = ShopPostService.shared
    @State private var sampledSurfaceColor: DominantVideoColor?
    @State private var selectedExploreFilter = "All"
    @State private var presentedAssortment: TopicPresentedAssortment?

    init(
        story: FeedStory,
        merchants: [SampleMerchant],
        enrichmentProducts: [ResolvedStoryProduct] = []
    ) {
        self.story = story
        self.merchants = merchants

        var seenResolvedIDs = Set<String>()
        let resolved = (story.resolvedProducts(from: merchants) + enrichmentProducts)
            .filter { seenResolvedIDs.insert($0.id).inserted }
        products = resolved

        var initialMerchantIDs: [String] = []
        var initialSeenMerchantIDs = Set<String>()
        for item in resolved where initialSeenMerchantIDs.insert(item.merchant.id).inserted {
            initialMerchantIDs.append(item.merchant.id)
        }
        if let firstMerchantID = initialMerchantIDs.first {
            _focusedDealID = State(
                initialValue: "\(initialMerchantIDs.count > 1 ? 1 : 0)-\(firstMerchantID)"
            )
        }

        var seen = Set<String>()
        var expanded: [ResolvedStoryProduct] = []
        for item in resolved where seen.insert(item.id).inserted {
            expanded.append(item)
        }
        var seenMerchantIDs = Set<String>()
        for item in resolved where seenMerchantIDs.insert(item.merchant.id).inserted {
            for product in item.merchant.products {
                let adjacent = ResolvedStoryProduct(merchant: item.merchant, product: product)
                guard seen.insert(adjacent.id).inserted else { continue }
                expanded.append(adjacent)
            }
        }
        exploreProducts = expanded
    }

    private var relatedMerchants: [SampleMerchant] {
        var seen = Set<String>()
        return products.map(\.merchant).filter { seen.insert($0.id).inserted }
    }

    private var relatedDeals: [RelatedDeal] {
        // A deal is brand-led: keep the topic merchants first, but only show
        // stores whose real wordmark can render. Fill any remaining slots with
        // relevant catalog merchants instead of falling back to styled text.
        var seen = Set<String>()
        let dealMerchants = (relatedMerchants + featuredMerchants).filter {
            hasRenderableDealWordmark($0) && seen.insert($0.id).inserted
        }
        return dealMerchants.prefix(6).map { merchant in
            var seen = Set<Int>()
            let topicProducts = products
                .filter { $0.merchant.id == merchant.id }
                .map(\.product)
            let resolvedProducts = (topicProducts + merchant.products)
                .filter { seen.insert($0.id).inserted }

            return RelatedDeal(
                merchant: merchant,
                products: Array(resolvedProducts.prefix(3))
            )
        }
    }

    /// Repeat the authored deals around a stable middle cycle so the rail can
    /// recenter after each swipe without exposing a first or last card.
    private var loopingDeals: [LoopingDealItem] {
        guard relatedDeals.count > 1 else {
            return relatedDeals.map { LoopingDealItem(deal: $0, cycle: 0) }
        }

        return (0..<3).flatMap { cycle in
            relatedDeals.map { LoopingDealItem(deal: $0, cycle: cycle) }
        }
    }

    private var initialFocusedDealID: String? {
        guard let firstDeal = relatedDeals.first else { return nil }
        return LoopingDealItem(
            deal: firstDeal,
            cycle: relatedDeals.count > 1 ? 1 : 0
        ).id
    }

    private var bentoColumnCount: Int {
        max(1, Int(ceil(Double(exploreProducts.count) / 3.0)))
    }

    private var newProducts: [ResolvedStoryProduct] {
        Array(products.prefix(6))
    }

    private var bestSellerProducts: [ResolvedStoryProduct] {
        let offset = min(3, max(0, products.count - 1))
        let shifted = Array(products.dropFirst(offset).prefix(6))
        return shifted.count >= 3 ? shifted : Array(products.reversed().prefix(6))
    }

    /// Prefer posts from merchants already represented in this topic. The
    /// authenticated Shop feed remains the source of truth; we never invent a
    /// social tile from catalog photography.
    private var recentPosts: [ShopPost] {
        let merchantNames = Set(relatedMerchants.map { normalizedMerchantName($0.displayName) })
        let verified = postService.posts(for: BuyerPreviewStore.shared.selected)
            .filter { $0.media.previewURL != nil }
        let topicMatches = verified.filter {
            merchantNames.contains(normalizedMerchantName($0.merchant.name))
        }
        return Array((topicMatches.isEmpty ? verified : topicMatches).prefix(6))
    }

    private func normalizedMerchantName(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Deal cards are brand-led, so they only render when we have a real
    /// merchant wordmark rather than manufacturing a text approximation.
    private func hasRenderableDealWordmark(_ merchant: SampleMerchant) -> Bool {
        if UIImage(named: MerchantBrandAssets.wordmarkName(for: merchant.id)) != nil {
            return true
        }
        guard let rawURL = merchant.bestWordmarkURL,
              let url = URL(string: rawURL) else { return false }
        return url.pathExtension.lowercased() != "svg"
    }

    private var specificTopicTerms: Set<String> {
        let genericTerms: Set<String> = [
            "best", "black", "brass", "cream", "design", "designed", "designs", "featured", "high",
            "hardware", "lighting", "living", "modern", "pieces", "products",
            "mount", "mounted", "nickel", "shop", "style", "wall", "white",
        ]
        let copyTerms = Set(
            "\(story.title) \(story.subtitle)"
                .lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count > 3 && !genericTerms.contains($0) }
        )
        let productTerms = products
            .flatMap { item in
                item.product.title.lowercased()
                    .split { !$0.isLetter && !$0.isNumber }
                    .map(String.init)
            }
            .filter { $0.count > 3 && !genericTerms.contains($0) }
        let recurringProductTerms = Dictionary(grouping: productTerms, by: { $0 })
            .compactMap { term, occurrences in occurrences.count >= 2 ? term : nil }
        return copyTerms.union(recurringProductTerms)
    }

    private func relevance(of merchant: SampleMerchant) -> Int {
        let merchantText = "\(merchant.name) \(merchant.description) \(merchant.productCategory ?? "") \(merchant.products.map(\.title).joined(separator: " "))"
            .lowercased()
        return specificTopicTerms.reduce(0) { score, term in
            score + (merchantText.contains(term) ? 1 : 0)
        }
    }

    private func hasPriceFit(_ merchant: SampleMerchant) -> Bool {
        guard let band = HypothesisShelfCatalog.priceBandUSD(for: story.id) else {
            return true
        }
        let expandedBand = (band.lowerBound * 0.75)...(band.upperBound * 1.25)
        return merchant.products.lazy.compactMap { Double($0.price) }
            .filter { expandedBand.contains($0) }
            .prefix(2)
            .count >= 2
    }

    private var featuredCollections: [FeedStory] {
        let curatedIDs = HypothesisShelfCatalog.relatedStoryIDs(for: story.id)
        if !curatedIDs.isEmpty {
            let storiesByID = Dictionary(
                uniqueKeysWithValues: PersonalizedFeedStories.all.map { ($0.id, $0) }
            )
            return curatedIDs.compactMap { storiesByID[$0] }
        }

        let topicKeys = Set(story.topicKeys.filter { $0 != "catalog-only-media" })
        let currentMerchantIDs = Set(products.map(\.merchant.id))
        return PersonalizedFeedStories.all
            .filter { candidate in
                guard candidate.id != story.id,
                      candidate.topicKeys.contains("merchant-card") == false else { return false }
                let sharesTopic = !topicKeys.isDisjoint(with: candidate.topicKeys)
                let sharesMerchant = candidate.resolvedProducts(from: merchants).contains {
                    currentMerchantIDs.contains($0.merchant.id)
                }
                return sharesTopic || sharesMerchant
            }
            .prefix(6)
            .map { $0 }
    }

    private var featuredMerchants: [SampleMerchant] {
        var seen = Set<String>()
        var result: [SampleMerchant] = []

        for merchant in relatedMerchants {
            guard merchant.products.count >= 3,
                  hasRenderableDealWordmark(merchant),
                  seen.insert(merchant.id).inserted else { continue }
            result.append(merchant)
        }

        let canonicalCandidates = merchants
            .filter {
                $0.coverImageURL != nil
                    && $0.products.count >= 3
                    && hasRenderableDealWordmark($0)
                    && relevance(of: $0) >= 2
                    && hasPriceFit($0)
            }
            .sorted { relevance(of: $0) > relevance(of: $1) }

        for merchant in canonicalCandidates {
            guard seen.insert(merchant.id).inserted else { continue }
            result.append(merchant)
        }
        return Array(result.prefix(6))
    }

    private var showcaseMerchants: [SampleMerchant] {
        var seen = Set<String>()
        let candidates = relatedMerchants + featuredMerchants + merchants
            .filter { $0.products.count >= 3 && $0.coverImageURL != nil && relevance(of: $0) > 0 }
            .sorted { relevance(of: $0) > relevance(of: $1) }
        return Array(candidates.filter { seen.insert($0.id).inserted }.prefix(6))
    }

    private func productWindow(offset: Int, count: Int) -> [ResolvedStoryProduct] {
        guard !exploreProducts.isEmpty else { return [] }
        return (0..<min(count, exploreProducts.count)).map {
            exploreProducts[(offset + $0) % exploreProducts.count]
        }
    }

    private var surfaceColor: Color {
        // The Figma art direction is a stable lilac surface. Sampling the
        // sneaker film produced a late brown color jump on navigation and
        // made the destination feel as if it loaded twice.
        if usesHypebeastHierarchy { return Color(hex: "#9B76B4") }
        guard let sampledSurfaceColor else { return Color(hex: story.accentHex) }
        return Color(
            red: sampledSurfaceColor.red,
            green: sampledSurfaceColor.green,
            blue: sampledSurfaceColor.blue
        )
    }

    private var heroVideoURL: URL? {
        FeedCoverCatalog.presentation(for: story)?.source.videoURL
            ?? products.lazy.flatMap {
                $0.product.ambientFilmURLs(merchantID: $0.merchant.id)
            }.first
    }

    private var usesCuratedSculpturalHierarchy: Bool {
        story.id == "shelf-luke-2-sculptural-living-room-pieces"
    }

    private var usesHypebeastHierarchy: Bool {
        story.id == HypothesisShelfCatalog.hypebeastStoryID
    }

    private var pageRecipe: TopicPageRecipe {
        if usesCuratedSculpturalHierarchy {
            return TopicPageRecipe(sectionSpacing: 28, blocks: [
                .productRail(title: "Just dropped", query: .init(fallbackOffset: 0), cardWidth: 116),
                .featuredDeals(title: "Featured deals"),
                .productRail(title: "Best sellers in lighting", query: .init(fallbackOffset: 3), cardWidth: 116),
                .relatedCollections(title: "Related collections", cardHeight: 200),
                .productRail(title: "New arrivals from your brands", query: .init(fallbackOffset: 7), cardWidth: 116),
                .brandGrid(title: "Brands worth the hype"),
                .productRail(title: "Unique finds", query: .init(fallbackOffset: 11), cardWidth: 116),
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
        }

        if usesHypebeastHierarchy {
            return TopicPageRecipe(sectionSpacing: GravitySpacing.space32, blocks: [
                .productRail(title: "Just dropped", query: .init(fallbackOffset: 0), cardWidth: 116),
                .featuredDeals(title: "Featured deals"),
                .productRail(title: "New arrivals from your brands", query: .init(fallbackOffset: 6), cardWidth: 116),
                .relatedCollections(title: "Related collections", cardHeight: 220),
                .productRail(
                    title: "Best sellers in sneakers",
                    query: .init(matching: ["sneaker", "shoe", "dunk", "samba", "nike", "new balance"], fallbackOffset: 8),
                    cardWidth: 116
                ),
                .brandGrid(title: "Brands worth the hype"),
                .productRail(title: "Unique finds", query: .init(fallbackOffset: 14), cardWidth: 116),
                .curatedLooks(title: "Curated looks", looks: [
                    .init(title: "The green edit", style: .green, query: .init(fallbackOffset: 2, count: 6)),
                    .init(title: "The oxblood edit", style: .oxblood, query: .init(fallbackOffset: 9, count: 6)),
                ]),
                .categories(
                    title: "Browse apparel by category",
                    items: [
                        .init(title: "T-shirts", query: .init(matching: ["shirt", "tee", "jersey"], fallbackOffset: 0, count: 5)),
                        .init(title: "Hats", query: .init(matching: ["hat", "cap", "snapback", "beanie"], fallbackOffset: 5, count: 5)),
                        .init(title: "Sneakers", query: .init(matching: ["sneaker", "shoe", "dunk", "samba"], fallbackOffset: 10, count: 5)),
                    ],
                    snaps: false
                ),
                .recentContent(title: "Recent posts", allowsCatalogFallback: true),
                .bento(title: "Complete the look"),
                .explore(title: "Explore more", filters: [
                    .all,
                    .init(title: "Apparel", terms: ["shirt", "tee", "jacket", "pant", "hoodie"]),
                    .init(title: "Sneakers", terms: ["sneaker", "shoe", "dunk", "samba"]),
                    .init(title: "Accessories", terms: ["hat", "cap", "bag", "accessory"]),
                ]),
            ])
        }

        if story.topicKeys.contains("merchant-card") {
            return TopicPageRecipe(sectionSpacing: 28, blocks: [
                .productRail(title: "New and noteworthy", query: .init(fallbackOffset: 0, count: 8), cardWidth: 116),
                .featuredDeals(title: "Current offers"),
                .productRail(title: "Best sellers", query: .init(fallbackOffset: 3, count: 8), cardWidth: 116),
                .recentContent(title: "Recent posts", allowsCatalogFallback: true),
                .bento(title: "Shop the collection"),
                .explore(title: "Explore more", filters: automaticExploreFilters),
            ])
        }

        return TopicPageRecipe(sectionSpacing: 28, blocks: [
            .productRail(title: "New this week", query: .init(fallbackOffset: 0, count: 6), cardWidth: 132),
            .featuredDeals(title: "Featured deals"),
            .productRail(title: "Best sellers", query: .init(fallbackOffset: 3, count: 6), cardWidth: 132),
            .relatedCollections(title: "Related collections", cardHeight: 220),
            .productRail(title: "More from your brands", query: .init(fallbackOffset: 6, count: 8), cardWidth: 116),
            .topMerchants(title: "Top merchants"),
            .recentContent(title: "Recent posts", allowsCatalogFallback: true),
            .bento(title: contextualBentoTitle),
            .explore(title: "Explore more", filters: automaticExploreFilters),
        ])
    }

    private var contextualBentoTitle: String {
        let context = "\(story.title) \(story.topicKeys.joined(separator: " "))".lowercased()
        if ["apparel", "fashion", "sneaker", "streetwear", "style"]
            .contains(where: context.contains) {
            return "Complete the look"
        }
        if ["design", "decor", "furniture", "home", "lighting"]
            .contains(where: context.contains) {
            return "Complete the space"
        }
        if ["beauty", "grooming", "scalp", "skin", "wellness"]
            .contains(where: context.contains) {
            return "Build your routine"
        }
        if ["camp", "hiking", "outdoor", "trail", "travel"]
            .contains(where: context.contains) {
            return "Complete the kit"
        }
        if ["coffee", "desk", "morning", "setup"]
            .contains(where: context.contains) {
            return "Finish the setup"
        }
        return "More to explore"
    }

    private var automaticExploreFilters: [TopicProductFilter] {
        let ignored: Set<String> = ["and", "for", "from", "into", "the", "with"]
        let terms = "\(story.title) \(story.topicKeys.joined(separator: " "))"
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 3 && !ignored.contains($0) }
        var seen = Set<String>()
        let uniqueTerms = terms
            .filter { seen.insert($0).inserted }
            .filter { term in
                exploreProducts.contains { searchableText(for: $0).contains(term) }
            }
            .prefix(3)
        return [.all] + uniqueTerms.map {
            TopicProductFilter(title: $0.capitalized, terms: [$0])
        }
    }

    private var heroHeight: CGFloat {
        560
    }

    private var windowSafeAreaTopInset: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let keyWindow = windowScene.windows.first(where: \.isKeyWindow) else {
            return 0
        }
        return keyWindow.safeAreaInsets.top
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                surfaceColor
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        hero(width: geometry.size.width)
                        merchandising(containerWidth: geometry.size.width)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)

                HStack {
                    closeButton
                    Spacer()
                    followButton
                }
                    .frame(width: geometry.size.width)
                    .padding(.top, windowSafeAreaTopInset + GravitySpacing.space4)
                    .opacity(showsControls ? 1 : 0)
                    .zIndex(10)
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .dark)
        .sheet(item: $presentedAssortment) { assortment in
            TopicProductCollectionSheet(assortment: assortment, accentColor: surfaceColor)
                .environment(\.colorScheme, .light)
        }
        .task(id: story.id) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                focusedDealID = initialFocusedDealID
                // Navigation controls are part of the first useful frame.
                // Delaying them made an otherwise-rendered topic feel as if
                // it were still loading.
                showsControls = true
            }
        }
        .task(id: heroVideoURL) {
            sampledSurfaceColor = nil
            guard !usesHypebeastHierarchy else { return }
            guard let heroVideoURL,
                  let color = await DominantVideoColorSampler.sample(from: heroVideoURL),
                  !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.24)) {
                sampledSurfaceColor = color
            }
        }
        .onAppear { coordinator.showNavBar = false }
        .onDisappear {
            coordinator.resetScrollState()
            coordinator.showNavBar = true
        }
    }

    private func hero(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            surfaceColor

            StoryFeedCard(
                story: story,
                merchants: merchants,
                width: width,
                height: heroHeight,
                isActive: true,
                showsForegroundContent: false,
                showsFooterArrow: false,
                backgroundPlaybackEnabled: true,
                cornerRadius: 0,
                freezesParallax: true
            )
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.60),
                        .init(color: .white.opacity(0.72), location: 0.76),
                        .init(color: .white.opacity(0.22), location: 0.90),
                        .init(color: .clear, location: 0.98),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.28), location: 0),
                    .init(color: .clear, location: 0.26),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer()

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: surfaceColor.opacity(0.36), location: 0.34),
                        .init(color: surfaceColor.opacity(0.86), location: 0.70),
                        .init(color: surfaceColor, location: 0.92),
                        .init(color: surfaceColor, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 190)

                // A solid overlap prevents a one-pixel compositing seam where
                // the hero hands off to the page surface.
                surfaceColor.frame(height: 12)
            }

            VStack(alignment: .leading, spacing: GravitySpacing.space10) {
                Text(story.title)
                    .font(FeedEditorialTypography.titleFont)
                    .tracking(FeedEditorialTypography.titleTracking)
                    .lineSpacing(FeedEditorialTypography.titleLineSpacing)
                    .tightMultilineLeading(FeedEditorialTypography.titleLineTightening)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if !story.subtitle.isEmpty {
                    Text(story.subtitle)
                        .font(GravityFont.medium.fixedFont(size: 17))
                        .tracking(-0.2)
                        .lineSpacing(1)
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)
                        .frame(maxWidth: min(width - 48, 340), alignment: .leading)
                }
            }
            .foregroundStyle(.white)
            .gravityShadow(GravityShadows.feedText)
            .frame(
                maxWidth: width - 32,
                maxHeight: .infinity,
                alignment: .bottomLeading
            )
            .padding(.horizontal, GravitySpacing.space16)
            .padding(.bottom, GravitySpacing.space20)
        }
        .frame(width: width, height: heroHeight)
        .clipped()
    }

    private func productRail(
        title: String,
        items: [ResolvedStoryProduct],
        cardWidth: CGFloat = 132
    ) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionTitle(title)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: GravitySpacing.space8) {
                    ForEach(items) { item in
                        Button {
                            HapticFeedback.light.fire()
                            coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
                        } label: {
                            ProductCard(
                                image: nil,
                                imageURL: item.product.imageURL,
                                merchantName: item.merchant.displayName,
                                productName: item.product.title,
                                price: formatPrice(item.product.price),
                                showFavoriteButton: true
                            )
                            .frame(width: cardWidth)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private func merchandising(containerWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: pageRecipe.sectionSpacing) {
            ForEach(Array(pageRecipe.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block, containerWidth: containerWidth)
            }
        }
        .padding(.bottom, 120)
    }

    @ViewBuilder
    private func blockView(_ block: TopicPageBlock, containerWidth: CGFloat) -> some View {
        switch block {
        case .productRail(let title, let query, let cardWidth):
            productRail(title: title, items: products(for: query), cardWidth: cardWidth)

        case .featuredDeals(let title):
            if !relatedDeals.isEmpty {
                dealRail(title: title, containerWidth: containerWidth)
            }

        case .relatedCollections(let title, let cardHeight):
            if !featuredCollections.isEmpty {
                collectionRail(title: title, cardHeight: cardHeight)
            }

        case .topMerchants(let title):
            if !featuredMerchants.isEmpty {
                featuredMerchantRail(title: title)
            }

        case .brandGrid(let title):
            if !showcaseMerchants.isEmpty {
                brandGridRail(title: title)
            }

        case .categories(let title, let items, let snaps):
            categoryRail(title: title, definitions: items, snaps: snaps)

        case .curatedLooks(let title, let looks):
            curatedLooksRail(title: title, looks: looks)

        case .recentContent(let title, let allowsCatalogFallback):
            if allowsCatalogFallback || !recentPosts.isEmpty {
                recentContentRail(title: title, allowsCatalogFallback: allowsCatalogFallback)
            }

        case .bento(let title):
            completeLookRail(title: title, containerWidth: containerWidth)

        case .explore(let title, let filters):
            exploreMore(title: title, filters: filters, containerWidth: containerWidth)
        }
    }

    private func products(for query: TopicProductQuery) -> [ResolvedStoryProduct] {
        let matches = exploreProducts.filter { item in
            let searchable = ([
                item.product.title,
                item.product.productType ?? "",
                item.product.productDescription ?? "",
            ] + item.product.tags)
                .joined(separator: " ")
                .lowercased()
            return !query.matching.isEmpty
                && query.matching.contains(where: searchable.contains)
                && !query.excluding.contains(where: searchable.contains)
        }
        let fallbacks = productWindow(offset: query.fallbackOffset, count: query.count)
        var seen = Set<String>()
        let candidates = query.matching.isEmpty ? fallbacks : matches + fallbacks
        return Array(candidates.filter { seen.insert($0.id).inserted }.prefix(query.count))
    }

    private func dealRail(title: String, containerWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionTitle(title)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .center, spacing: GravitySpacing.space10) {
                    ForEach(loopingDeals) { item in
                        RelatedDealCard(deal: item.deal)
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(
                .horizontal,
                max(GravitySpacing.space12, (containerWidth - 266) / 2),
                for: .scrollContent
            )
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $focusedDealID, anchor: .center)
            .onScrollPhaseChange { _, phase in
                guard phase == .idle,
                      relatedDeals.count > 1,
                      let focusedDealID,
                      let focusedItem = loopingDeals.first(where: { $0.id == focusedDealID }),
                      focusedItem.cycle != 1 else { return }

                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    self.focusedDealID = LoopingDealItem(
                        deal: focusedItem.deal,
                        cycle: 1
                    ).id
                }
            }
        }
    }

    private func collectionRail(title: String, cardHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionTitle(title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space10) {
                    ForEach(featuredCollections) { collection in
                        TopicCollectionCard(
                            story: collection,
                            merchants: merchants,
                            height: cardHeight
                        )
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private func featuredMerchantRail(title: String) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionTitle(title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space10) {
                    ForEach(featuredMerchants) { merchant in
                        TopicMerchantShowcaseCard(merchant: merchant)
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private func recentContentRail(title: String, allowsCatalogFallback: Bool) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            sectionTitle(title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: GravitySpacing.space8) {
                    if recentPosts.isEmpty && allowsCatalogFallback {
                        ForEach(productWindow(offset: 8, count: 6)) { item in
                            TopicMerchantMediaCard(item: item)
                        }
                    } else {
                        ForEach(Array(recentPosts.enumerated()), id: \.element.id) { index, post in
                            TopicRecentPostCard(post: post, ageLabel: index.isMultiple(of: 2) ? "4m ago" : "6m ago")
                        }
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private func brandGridRail(title: String) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionTitle(title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space10) {
                    ForEach(showcaseMerchants) { merchant in
                        TopicBrandGridCard(merchant: merchant)
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private func categoryRail(
        title: String,
        definitions: [TopicCategoryDefinition],
        snaps: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            sectionTitle(title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: snaps ? GravitySpacing.space10 : GravitySpacing.space8) {
                    ForEach(definitions, id: \.title) { definition in
                        let items = products(for: definition.query)
                        TopicCategoryClusterCard(
                            title: definition.title,
                            products: items,
                            onBrowse: {
                                presentedAssortment = TopicPresentedAssortment(
                                    title: definition.title,
                                    subtitle: story.title,
                                    products: items
                                )
                            }
                        )
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
                .scrollTargetLayout()
            }
            .topicSnapping(enabled: snaps)
        }
    }

    private func curatedLooksRail(
        title: String,
        looks: [TopicCuratedLookDefinition]
    ) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            sectionTitle(title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space8) {
                    ForEach(Array(looks.enumerated()), id: \.offset) { _, look in
                        let items = products(for: look.query)
                        TopicCuratedLookCard(
                            style: look.style,
                            products: items,
                            onOpenLook: {
                                presentedAssortment = TopicPresentedAssortment(
                                    title: look.title,
                                    subtitle: "Shop the complete look",
                                    products: items
                                )
                            }
                        )
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
            }
        }
    }

    private func completeLookRail(
        title: String = "Pairs well with warm lighting",
        containerWidth: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            sectionTitle(title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space8) {
                    ForEach(0..<bentoColumnCount, id: \.self) { index in
                        TopicProductBentoColumn(
                            products: productWindow(offset: index * 3, count: 3),
                            largeTileFirst: index.isMultiple(of: 2)
                        )
                    }
                }
            }
            .contentMargins(.leading, GravitySpacing.space12, for: .scrollContent)
            // Leave enough terminal runway for the final 240pt column to
            // finish at the same left inset as the first column.
            .contentMargins(
                .trailing,
                max(GravitySpacing.space12, containerWidth - 252),
                for: .scrollContent
            )
        }
    }

    private func exploreMore(
        title: String,
        filters: [TopicProductFilter],
        containerWidth: CGFloat
    ) -> some View {
        let padding = GravitySpacing.space12
        let columnGap = GravitySpacing.space8
        let cardWidth = (containerWidth - padding * 2 - columnGap) / 2
        let activeFilter = filters.first { $0.title == selectedExploreFilter } ?? filters.first ?? .all
        let filteredProducts = products(matching: activeFilter)
        let indexedProducts = Array(filteredProducts.enumerated())
        let leftColumn = indexedProducts.filter { $0.offset.isMultiple(of: 2) }
        let rightColumn = indexedProducts.filter { !$0.offset.isMultiple(of: 2) }

        return VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionTitle(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GravitySpacing.space8) {
                    ForEach(filters) { filter in
                        Button {
                            HapticFeedback.light.fire()
                            withAnimation(.easeOut(duration: 0.18)) {
                                selectedExploreFilter = filter.title
                            }
                        } label: {
                            Text(filter.title)
                                .font(GravityFont.semiBold.fixedFont(size: 14))
                                .foregroundStyle(filter.title == activeFilter.title ? surfaceColor : .white)
                                .padding(.horizontal, GravitySpacing.space16)
                                .frame(height: 36)
                                .background(
                                    filter.title == activeFilter.title ? Color.white : Color.white.opacity(0.14),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(PressScaleButtonStyle())
                        .accessibilityAddTraits(filter.title == activeFilter.title ? .isSelected : [])
                    }
                }
                .padding(.horizontal, padding)
            }

            HStack(alignment: .top, spacing: columnGap) {
                VStack(spacing: GravitySpacing.space16) {
                    ForEach(leftColumn, id: \.element.id) { index, item in
                        TopicExploreProductCard(
                            item: item,
                            cardWidth: cardWidth,
                            mediaHeight: index.isMultiple(of: 4) ? cardWidth + 36 : cardWidth
                        )
                    }
                }
                VStack(spacing: GravitySpacing.space16) {
                    ForEach(rightColumn, id: \.element.id) { index, item in
                        TopicExploreProductCard(
                            item: item,
                            cardWidth: cardWidth,
                            mediaHeight: index.isMultiple(of: 3) ? cardWidth + 36 : cardWidth
                        )
                    }
                }
            }
            .padding(.horizontal, padding)
            .id(activeFilter.id)
            .transition(.opacity)
        }
    }

    private func products(matching filter: TopicProductFilter) -> [ResolvedStoryProduct] {
        guard !filter.terms.isEmpty else { return exploreProducts }
        let matches = exploreProducts.filter { item in
            filter.terms.contains(where: searchableText(for: item).contains)
        }
        return matches
    }

    private func searchableText(for item: ResolvedStoryProduct) -> String {
        ([
            item.product.title,
            item.product.productType ?? "",
            item.product.productDescription ?? "",
        ] + item.product.tags)
            .joined(separator: " ")
            .lowercased()
    }

    private func sectionTitle(_ title: String) -> some View {
        HStack(spacing: GravitySpacing.space8) {
            Text(title)
            Image(systemName: "chevron.right")
                .font(.system(size: 17, weight: .bold))
        }
        .font(GravityFont.expressiveBold.fixedFont(size: 20))
        .tracking(-0.45)
        .foregroundStyle(.white)
        .gravityShadow(GravityShadows.feedText)
        .padding(.horizontal, GravitySpacing.space12)
    }

    private var closeButton: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.showNavBar = true
            if coordinator.homePath.isEmpty, coordinator.topicBackAction != nil {
                coordinator.popCurrentPage()
            } else {
                dismiss()
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.leading, GravitySpacing.space16)
        .accessibilityLabel("Close")
    }

    private var followButton: some View {
        Button {
            HapticFeedback.light.fire()
            withAnimation(.easeInOut(duration: 0.18)) {
                isFollowingTopic.toggle()
            }
        } label: {
            Text(isFollowingTopic ? "Following" : "Follow")
                .font(GravityFont.semiBold.fixedFont(size: 14))
                .foregroundStyle(.white)
                .padding(.horizontal, GravitySpacing.space16)
                .frame(height: 40)
                .background(.ultraThinMaterial, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.trailing, GravitySpacing.space16)
        .accessibilityLabel(isFollowingTopic ? "Unfollow this topic" : "Follow this topic")
        .accessibilityAddTraits(isFollowingTopic ? .isSelected : [])
    }

}

private struct DominantVideoColor: Sendable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
}

/// Samples one representative video frame into a tiny quantized histogram.
/// The work runs off the main actor once per topic and stores only three color
/// channels, so scrolling and video playback never pay for the analysis.
private enum DominantVideoColorSampler {
    private struct Bucket {
        var count = 0
        var red = 0
        var green = 0
        var blue = 0
    }

    static func sample(from url: URL) async -> DominantVideoColor? {
        await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 96, height: 96)

            let frame: CGImage
            do {
                frame = try await generator.image(
                    at: CMTime(seconds: 1, preferredTimescale: 600)
                ).image
            } catch {
                return nil
            }
            return dominantColor(in: frame)
        }.value
    }

    private static func dominantColor(in image: CGImage) -> DominantVideoColor? {
        let width = 48
        let height = 48
        let bytesPerPixel = 4
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var buckets: [Int: Bucket] = [:]
        for offset in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = Int(pixels[offset])
            let green = Int(pixels[offset + 1])
            let blue = Int(pixels[offset + 2])
            let alpha = Int(pixels[offset + 3])
            let luminance = (red * 3 + green * 6 + blue) / 10
            guard alpha > 160, luminance > 22, luminance < 238 else { continue }

            let key = (red / 32 << 6) | (green / 32 << 3) | (blue / 32)
            var bucket = buckets[key, default: Bucket()]
            bucket.count += 1
            bucket.red += red
            bucket.green += green
            bucket.blue += blue
            buckets[key] = bucket
        }

        guard let winner = buckets.values.max(by: { $0.count < $1.count }),
              winner.count > 0 else { return nil }
        return DominantVideoColor(
            red: Double(winner.red) / Double(winner.count) / 255,
            green: Double(winner.green) / Double(winner.count) / 255,
            blue: Double(winner.blue) / Double(winner.count) / 255
        )
    }
}

private struct RelatedDeal: Identifiable {
    let merchant: SampleMerchant
    let products: [SampleMerchant.Product]

    var id: String { merchant.id }
}

private struct LoopingDealItem: Identifiable {
    let deal: RelatedDeal
    let cycle: Int

    var id: String { "\(cycle)-\(deal.id)" }
}

private struct RelatedDealCard: View {
    let deal: RelatedDeal
    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.store(merchantId: deal.merchant.id))
        } label: {
            ZStack {
                MerchantCoverImage(merchant: deal.merchant)
                    .frame(width: 266, height: 263)
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.18), location: 0),
                        .init(color: .clear, location: 0.34),
                        .init(color: .clear, location: 0.52),
                        .init(color: .black.opacity(0.08), location: 0.68),
                        .init(color: .black.opacity(0.30), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: GravitySpacing.space12) {
                    merchantIdentity.frame(height: 100)
                    productRow

                    Text("Save $10 on orders over $50")
                        .gravityTextStyle(GravityTypography.buttonSmall)
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(.white.opacity(0.64), in: Capsule())
                }
                .padding(GravitySpacing.space12)
            }
            .frame(width: 266, height: 263)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shop all from \(deal.merchant.displayName)")
    }

    private var merchantIdentity: some View {
        VStack(spacing: GravitySpacing.space8) {
            if MerchantBrandAssets.hasVerifiedBundledWordmark(for: deal.merchant.id)
                || hasUsableRemoteWordmark {
                MerchantWordmarkImage(
                    merchant: deal.merchant,
                    maxHeight: 40,
                    maxWidth: 120,
                    bundledAssetName: MerchantBrandAssets.wordmarkName(for: deal.merchant.id)
                )
            } else {
                Text(deal.merchant.displayName)
                    .font(GravityFont.expressiveBold.fixedFont(size: 24))
                    .tracking(-0.5)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)
            }

            if deal.merchant.totalRatings > 0 {
                HStack(spacing: GravitySpacing.space2) {
                    Text(String(format: "%.1f", deal.merchant.rating))
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .medium))
                    Text("(\(compactRatingCount(deal.merchant.totalRatings)))")
                }
                .gravityTextStyle(GravityTypography.captionMedium)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.22), radius: 8, y: 2)
        .frame(maxWidth: .infinity)
    }

    private var hasUsableRemoteWordmark: Bool {
        guard let source = deal.merchant.bestWordmarkURL,
              let url = URL(string: source) else { return false }
        return url.pathExtension.lowercased() != "svg"
    }

    private var productRow: some View {
        HStack(spacing: GravitySpacing.space8) {
            ForEach(deal.products) { product in
                ProductImageView(product: product, merchant: deal.merchant)
                    .frame(width: 75, height: 75)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                            .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
                    }
            }
        }
        .frame(width: 241, height: 75)
    }

    private func compactRatingCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return String(count)
    }
}

private struct TopicCollectionCard: View {
    let story: FeedStory
    let merchants: [SampleMerchant]
    var height: CGFloat = 220

    @Environment(NavigationCoordinator.self) private var coordinator

    private var lifestyleURL: URL? {
        if let presentation = FeedCoverCatalog.presentation(for: story) {
            return presentation.coverURL(from: merchants)
        }
        return story.lifestyleImageURL(
            from: merchants,
            format: .landscape,
            role: "topic-featured-collection"
        )
    }

    private var fallbackProduct: ResolvedStoryProduct? {
        story.resolvedProducts(from: merchants).first
    }

    private var bundledCoverName: String? {
        if let presentation = FeedCoverCatalog.presentation(for: story),
           let name = presentation.source.bundledAssetName {
            return name
        }
        return FeedCoverCatalog.fallbackImageName(for: story)
    }

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.story(storyId: story.id))
        } label: {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let lifestyleURL {
                        CachedAsyncImage(url: lifestyleURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else if let fallbackProduct {
                                ProductImageView(product: fallbackProduct.product, merchant: fallbackProduct.merchant)
                            } else {
                                Color(hex: story.accentHex)
                            }
                        }
                    } else if let bundledCoverName {
                        Image(bundledCoverName)
                            .resizable()
                            .scaledToFill()
                    } else if let fallbackProduct {
                        ProductImageView(product: fallbackProduct.product, merchant: fallbackProduct.merchant)
                    } else {
                        Color(hex: story.accentHex)
                    }
                }
                .frame(width: 364, height: height)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: GravitySpacing.space12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(story.title)
                            .font(GravityFont.expressiveBold.fixedFont(size: 23))
                            .tracking(-0.5)
                            .lineLimit(2)
                        if !story.subtitle.isEmpty {
                            Text(story.subtitle)
                                .font(GravityFont.medium.fixedFont(size: 13))
                                .lineLimit(1)
                                .foregroundStyle(.white.opacity(0.86))
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.18), in: Circle())
                }
                .foregroundStyle(.white)
                .padding(GravitySpacing.space16)
            }
            .frame(width: 364, height: height)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

private struct TopicCuratedLookCard: View {
    let style: TopicCuratedLookStyle
    let products: [ResolvedStoryProduct]
    let onOpenLook: () -> Void

    private let width: CGFloat = 364
    private let height: CGFloat = 473

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                switch style {
                case .green:
                    greenCollage
                case .oxblood:
                    oxbloodCollage
                }
            }
            .frame(width: width, height: height)
            .clipped()

            if style == .green {
                // The Figma export contains a flattened control. Reconstruct
                // the artwork's vertical green ramp so the live CTA does not
                // sit on a visible rectangular color patch.
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 17 / 255, green: 192 / 255, blue: 75 / 255), location: 0),
                        .init(color: Color(red: 18 / 255, green: 217 / 255, blue: 85 / 255), location: 0.76),
                        .init(color: Color(red: 16 / 255, green: 198 / 255, blue: 84 / 255), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 174, height: 54)
            }

            Button {
                openLook()
            } label: {
                shopTheLookPill
            }
            .buttonStyle(PressScaleButtonStyle())
            .padding(GravitySpacing.space12)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        }
        .gravityShadow(GravityShadows.medium)
        .accessibilityLabel("Shop the curated look")
    }

    /// Crops the 400×521 Figma export to its exact 364×473 green artwork.
    /// This removes the navy presentation frame without stretching or
    /// regenerating any of the product collage.
    private var greenCollage: some View {
        ZStack(alignment: .topLeading) {
            Image("hype-curated-look-green")
                .resizable()
                .frame(width: 400, height: 521)
                .offset(x: -12, y: -20)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .clipped()
    }

    private var oxbloodCollage: some View {
        ZStack(alignment: .bottomLeading) {
            Color(red: 141 / 255, green: 63 / 255, blue: 57 / 255)

            collageImage("hype-look-red-1", width: 215, height: 220)
                .rotationEffect(.degrees(-11.79))
                .position(x: 55, y: 82)

            collageImage("hype-look-red-2", width: 230, height: 294)
                .rotationEffect(.degrees(8.83))
                .position(x: 42, y: 247)

            collageImage("hype-look-red-3", width: 223, height: 161)
                .rotationEffect(.degrees(-11.45))
                .position(x: 136, y: 208)

            collageImage("hype-look-red-4", width: 227, height: 268)
                .rotationEffect(.degrees(8.67))
                .position(x: 292, y: 99)

            collageImage("hype-look-red-5", width: 252, height: 320)
                .rotationEffect(.degrees(-1.56))
                .position(x: 250, y: 348)

        }
    }

    private func openLook() {
        HapticFeedback.light.fire()
        guard !products.isEmpty else { return }
        onOpenLook()
    }

    private func collageImage(_ name: String, width: CGFloat, height: CGFloat) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
            .shadow(color: .black.opacity(0.24), radius: 20, y: 8)
    }

    private var shopTheLookPill: some View {
        HStack(spacing: GravitySpacing.space6) {
            Text("Shop the look")
                .font(GravityFont.semiBold.fixedFont(size: 14))
                .foregroundStyle(GravityColors.textFixedLight)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(.horizontal, GravitySpacing.space12)
        .frame(height: 38)
        .background(.black.opacity(0.58), in: Capsule())
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
        .contentShape(Capsule())
    }
}

private struct TopicRecentPostCard: View {
    let post: ShopPost
    var ageLabel = "4m ago"

    private var previewURL: URL? { post.media.previewURL }

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            guard let actionURL = post.actionURL else { return }
            UIApplication.shared.open(actionURL)
        } label: {
            Group {
                if let previewURL {
                    CachedAsyncImage(url: previewURL) { phase in
                        if case let .success(image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Color.white.opacity(0.08)
                        }
                    }
                } else {
                    Color.white.opacity(0.08)
                }
            }
            .frame(width: 148, height: 219)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: GravitySpacing.space8) {
                    MerchantAvatarView(
                        logoURL: post.merchant.logoURL,
                        name: post.merchant.name,
                        size: 32,
                        fallbackColor: GravityColors.bgFillFixedDusk
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text(post.merchant.name)
                            .gravityTextStyle(GravityTypography.captionBold)
                            .lineLimit(1)
                        Text(ageLabel)
                            .gravityTextStyle(GravityTypography.caption)
                            .foregroundStyle(GravityColors.textFixedLight.opacity(0.75))
                            .lineLimit(1)
                    }
                    .frame(width: 84, alignment: .leading)
                }
                .frame(width: 124, alignment: .leading)
                .foregroundStyle(GravityColors.textFixedLight)
                .padding(GravitySpacing.space12)
            }
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            }
            .gravityShadow(GravityShadows.medium)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Recent post from \(post.merchant.name)")
    }
}

/// Keeps the Figma post rail visible before the authenticated PostCard feed
/// arrives. The media and merchant identity are real catalog data, and the
/// supporting label explicitly avoids presenting it as a fabricated post age.
private struct TopicMerchantMediaCard: View {
    let item: ResolvedStoryProduct

    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
        } label: {
            ProductImageView(product: item.product, merchant: item.merchant, fallbackIndex: 1)
                .frame(width: 148, height: 219)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: GravitySpacing.space8) {
                        MerchantAvatarView(merchant: item.merchant, size: 32)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.merchant.displayName)
                                .gravityTextStyle(GravityTypography.captionBold)
                                .lineLimit(1)
                            Text("Recently added")
                                .gravityTextStyle(GravityTypography.caption)
                                .foregroundStyle(GravityColors.textFixedLight.opacity(0.75))
                                .lineLimit(1)
                        }
                        .frame(width: 84, alignment: .leading)
                    }
                    .frame(width: 124, alignment: .leading)
                    .foregroundStyle(GravityColors.textFixedLight)
                    .padding(GravitySpacing.space12)
                }
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            }
            .gravityShadow(GravityShadows.medium)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Recently added by \(item.merchant.displayName)")
    }
}

private struct TopicMerchantShowcaseCard: View {
    let merchant: SampleMerchant

    @Environment(NavigationCoordinator.self) private var coordinator

    private var products: [SampleMerchant.Product] {
        Array(merchant.products.prefix(3))
    }

    /// Merchant cover art frequently arrives as a baked campaign collage.
    /// Use one product's authored alternate frame instead so the card always
    /// has a single clean photographic background.
    private var backgroundImageURL: String? {
        merchant.products.lazy.compactMap { product in
            product.allImageURLs.dropFirst().first
        }.first
            ?? merchant.products.first?.imageURL
            ?? merchant.featuredImageURLs.first
    }

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.store(merchantId: merchant.id))
        } label: {
            ZStack {
                MerchantImage(merchant: merchant, urlString: backgroundImageURL)
                    .frame(width: 344, height: 382)
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.28), .clear, .black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 0) {
                    HStack {
                        MerchantWordmarkImage(
                            merchant: merchant,
                            maxHeight: 34,
                            maxWidth: 150,
                            bundledAssetName: MerchantBrandAssets.wordmarkName(for: merchant.id)
                        )
                        Spacer()
                        if merchant.totalRatings > 0 {
                            Label(String(format: "%.1f", merchant.rating), systemImage: "star.fill")
                                .font(GravityFont.medium.fixedFont(size: 12))
                        }
                    }
                    .frame(height: 46)

                    Spacer(minLength: GravitySpacing.space16)

                    HStack(spacing: GravitySpacing.space8) {
                        ForEach(products) { product in
                            ProductImageView(product: product, merchant: merchant)
                                .frame(width: 101, height: 101)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
                                .gravityShadow(GravityShadows.small)
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding(GravitySpacing.space12)
            }
            .frame(width: 344, height: 382)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Shop \(merchant.displayName)")
    }
}

/// Figma's topic-only merchant module: one lifestyle photograph, six square
/// products, and a compact store action. Feed merchant cards keep their
/// separate three-product treatment.
private struct TopicBrandGridCard: View {
    let merchant: SampleMerchant

    @Environment(NavigationCoordinator.self) private var coordinator
    @AppStorage("topicFollowedMerchantIDs") private var followedMerchantIDs = ""

    private var products: [SampleMerchant.Product] {
        guard !merchant.products.isEmpty else { return [] }
        return (0..<6).map { merchant.products[$0 % merchant.products.count] }
    }

    private var backgroundImageURL: String? {
        merchant.products.lazy.compactMap { $0.allImageURLs.dropFirst().first }.first
            ?? merchant.featuredImageURLs.first
            ?? merchant.products.first?.imageURL
    }

    private var isFollowing: Bool {
        followedMerchantIDSet.contains(merchant.id)
    }

    private var followedMerchantIDSet: Set<String> {
        Set(followedMerchantIDs.split(separator: ",").map(String.init))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                HapticFeedback.light.fire()
                coordinator.pushRoute(.store(merchantId: merchant.id))
            } label: {
                ZStack {
                    MerchantImage(merchant: merchant, urlString: backgroundImageURL)
                        .frame(width: 364, height: 370)
                        .clipped()

                    LinearGradient(
                        colors: [.black.opacity(0.34), .black.opacity(0.18), .black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(spacing: GravitySpacing.space10) {
                        MerchantWordmarkImage(
                            merchant: merchant,
                            maxHeight: 42,
                            maxWidth: 146,
                            bundledAssetName: MerchantBrandAssets.wordmarkName(for: merchant.id)
                        )
                            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.fixed(98), spacing: 8), count: 3),
                            spacing: 8
                        ) {
                            ForEach(Array(products.enumerated()), id: \.offset) { _, product in
                                ProductImageView(product: product, merchant: merchant)
                                    .frame(width: 98, height: 98)
                                    .background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
                            }
                        }

                        HStack(spacing: 5) {
                            Text("Shop all")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .font(GravityFont.semiBold.fixedFont(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundStyle(.white)
                    .gravityShadow(GravityShadows.feedText)
                    .padding(GravitySpacing.space12)
                }
                .frame(width: 364, height: 370)
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Shop all from \(merchant.displayName)")

            VStack(alignment: .trailing, spacing: 7) {
                Button {
                    toggleFollow()
                } label: {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(GravityFont.semiBold.fixedFont(size: 13))
                        .padding(.horizontal, 13)
                        .frame(height: 34)
                        .foregroundStyle(.white)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityAddTraits(isFollowing ? .isSelected : [])

                if merchant.totalRatings > 0 {
                    Label(String(format: "%.1f", merchant.rating), systemImage: "star.fill")
                        .font(GravityFont.medium.fixedFont(size: 11))
                        .foregroundStyle(.white)
                        .gravityShadow(GravityShadows.feedText)
                }
            }
            .padding(GravitySpacing.space12)
        }
        .frame(width: 364, height: 370)
    }

    private func toggleFollow() {
        HapticFeedback.light.fire()
        var ids = followedMerchantIDSet
        if isFollowing {
            ids.remove(merchant.id)
        } else {
            ids.insert(merchant.id)
        }
        followedMerchantIDs = ids.sorted().joined(separator: ",")
    }
}

private struct TopicCategoryClusterCard: View {
    let title: String
    let products: [ResolvedStoryProduct]
    let onBrowse: () -> Void

    @Environment(NavigationCoordinator.self) private var coordinator

    private let cardWidth: CGFloat = 304
    private let tileGap = GravitySpacing.space8

    private var displayedProducts: [ResolvedStoryProduct] {
        guard !products.isEmpty else { return [] }
        return (0..<5).map { products[$0 % products.count] }
    }

    var body: some View {
        if displayedProducts.count == 5 {
            VStack(alignment: .leading, spacing: GravitySpacing.space10) {
                VStack(spacing: tileGap) {
                    HStack(spacing: tileGap) {
                        ForEach(Array(displayedProducts.prefix(2).enumerated()), id: \.offset) { _, item in
                            productTile(item, size: 136)
                        }
                    }

                    HStack(spacing: tileGap) {
                        ForEach(Array(displayedProducts.dropFirst(2).enumerated()), id: \.offset) { _, item in
                            productTile(item, size: 88)
                        }
                    }
                }

                Button {
                    HapticFeedback.light.fire()
                    onBrowse()
                } label: {
                    HStack(spacing: GravitySpacing.space4) {
                        Text(title)
                            .font(GravityFont.bold.fixedFont(size: 20))
                            .tracking(-1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(GravityColors.textFixedLight)
                    .frame(height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Browse \(title)")
            }
            .padding(GravitySpacing.space12)
            .frame(width: cardWidth, height: 288, alignment: .topLeading)
            .background(
                Color(red: 108 / 255, green: 74 / 255, blue: 61 / 255).opacity(0.7),
                in: RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
            )
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        }
    }

    private func productTile(_ item: ResolvedStoryProduct, size: CGFloat) -> some View {
        Button {
            open(item)
        } label: {
            ZStack(alignment: .topLeading) {
                ProductImageView(product: item.product, merchant: item.merchant)
                    .frame(width: size, height: size)
                    .background(GravityColors.bgFillFixedLight)
                    .clipped()

                Color.black.opacity(0.04)

                Text(formatPrice(item.product.price))
                    .gravityTextStyle(GravityTypography.badgeBold)
                    .foregroundStyle(GravityColors.textFixedLight)
                    .padding(.horizontal, GravitySpacing.space6)
                    .padding(.vertical, GravitySpacing.space2)
                    .background(GravityColors.bgOverlayFixedIcon, in: Capsule())
                    .padding(GravitySpacing.space10)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                ProductFavoriteIcon(color: GravityColors.textFixedLight)
                    .gravityShadow(GravityShadows.feedText)
                    .padding(5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(item.product.title), \(formatPrice(item.product.price))")
    }

    private func open(_ item: ResolvedStoryProduct) {
        HapticFeedback.light.fire()
        coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
    }
}

private struct TopicProductBentoColumn: View {
    let products: [ResolvedStoryProduct]
    let largeTileFirst: Bool

    var body: some View {
        VStack(spacing: GravitySpacing.space8) {
            if largeTileFirst {
                tile(at: 0, size: 240)
                compactRow(firstIndex: 1)
            } else {
                compactRow(firstIndex: 0)
                tile(at: 2, size: 240)
            }
        }
        .frame(width: 240, height: 365, alignment: .top)
    }

    private func compactRow(firstIndex: Int) -> some View {
        HStack(spacing: GravitySpacing.space6) {
            tile(at: firstIndex, size: 117)
            tile(at: firstIndex + 1, size: 117)
        }
    }

    @ViewBuilder
    private func tile(at index: Int, size: CGFloat) -> some View {
        if !products.isEmpty {
            TopicBentoProductTile(item: products[index % products.count], size: size)
        }
    }
}

private struct TopicBentoProductTile: View {
    let item: ResolvedStoryProduct
    let size: CGFloat

    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
        } label: {
            ZStack(alignment: .topLeading) {
                ProductImageView(product: item.product, merchant: item.merchant)
                    .frame(width: size, height: size)
                    .background(GravityColors.bgFillFixedLight)
                    .clipped()

                Color.black.opacity(0.04)

                Text(formatPrice(item.product.price))
                    .gravityTextStyle(GravityTypography.badgeBold)
                    .foregroundStyle(GravityColors.textFixedLight)
                    .padding(.horizontal, GravitySpacing.space6)
                    .padding(.vertical, GravitySpacing.space2)
                    .background(GravityColors.bgOverlayFixedIcon, in: Capsule())
                    .padding(GravitySpacing.space10)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                ProductFavoriteIcon(color: GravityColors.textFixedLight)
                    .frame(width: 48, height: 48)
                    .gravityShadow(GravityShadows.feedText)
            }
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                    .strokeBorder(GravityColors.border, lineWidth: 0.5)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(item.product.title), \(formatPrice(item.product.price))")
    }
}

private struct TopicExploreProductCard: View {
    let item: ResolvedStoryProduct
    let cardWidth: CGFloat
    let mediaHeight: CGFloat

    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
        } label: {
            VStack(alignment: .leading, spacing: GravitySpacing.space10) {
                ProductImageView(product: item.product, merchant: item.merchant)
                    .frame(width: cardWidth, height: mediaHeight)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        ProductFavoriteIcon(color: .white)
                            .gravityShadow(GravityShadows.feedText)
                            .padding(GravitySpacing.space6)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                            .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
                    }

                VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                    Text(item.merchant.displayName)
                        .font(GravityFont.regular.fixedFont(size: 12))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)

                    Text(item.product.title)
                        .font(GravityFont.semiBold.fixedFont(size: 14))
                        .tracking(-0.1)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(formatPrice(item.product.price))
                        .font(GravityFont.medium.fixedFont(size: 13))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .frame(height: 66, alignment: .topLeading)
                .padding(.horizontal, GravitySpacing.space2)
            }
            .frame(width: cardWidth, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(item.product.title), \(formatPrice(item.product.price))")
    }
}

/// Shared destination for category clusters and authored looks. Both now open
/// the complete assortment instead of routing to an arbitrary first product.
private struct TopicProductCollectionSheet: View {
    let assortment: TopicPresentedAssortment
    let accentColor: Color

    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: GravitySpacing.space8, alignment: .top),
        GridItem(.flexible(), spacing: GravitySpacing.space8, alignment: .top),
    ]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: GravitySpacing.space20) {
                    ForEach(assortment.products) { item in
                        Button {
                            HapticFeedback.light.fire()
                            dismiss()
                            coordinator.pushRoute(
                                .product(merchantId: item.merchant.id, productId: item.product.id)
                            )
                        } label: {
                            ProductCard(
                                image: nil,
                                imageURL: item.product.imageURL,
                                merchantName: item.merchant.displayName,
                                productName: item.product.title,
                                price: formatPrice(item.product.price),
                                showFavoriteButton: true
                            )
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
                .padding(.bottom, GravitySpacing.space32)
            }
            .background(GravityColors.bg)
            .navigationTitle(assortment.title)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                if !assortment.subtitle.isEmpty {
                    Text(assortment.subtitle)
                        .font(GravityFont.medium.fixedFont(size: 14))
                        .foregroundStyle(GravityColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, GravitySpacing.space16)
                        .padding(.vertical, GravitySpacing.space12)
                        .background(GravityColors.bg)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(accentColor, in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private extension View {
    @ViewBuilder
    func topicSnapping(enabled: Bool) -> some View {
        if enabled {
            scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        } else {
            self
        }
    }
}
