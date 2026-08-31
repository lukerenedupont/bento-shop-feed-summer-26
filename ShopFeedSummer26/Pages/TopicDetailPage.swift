import SwiftUI
import UIKit
import AVFoundation
struct TopicPresentedAssortment: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let products: [ResolvedStoryProduct]
}
@Observable
private final class TopicHeaderScrollState {
    var showsTitle = false
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
    private let topicPresentation: TopicPresentation
    /// The long rails share one stable assortment instead of rebuilding it
    /// independently for every `productWindow` call.
    private let exploreProducts: [ResolvedStoryProduct]
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @State private var showsControls = false
    @State private var closeMorphProgress: CGFloat = 0
    @State private var headerScrollState = TopicHeaderScrollState()
    @State private var postService = ShopPostService.shared
    @State private var sampledSurfaceColor: DominantVideoColor?
    @State private var selectedExploreFilter = "All"
    @State private var presentedAssortment: TopicPresentedAssortment?
    @State private var giftGuideState = GiftGuidePrototypeState()
    init(
        story: FeedStory,
        merchants: [SampleMerchant],
        enrichmentProducts: [ResolvedStoryProduct] = []
    ) {
        self.story = story
        self.merchants = merchants
        topicPresentation = TopicPresentationCatalog.presentation(for: story)
        var seenResolvedIDs = Set<String>()
        let resolved = (story.resolvedProducts(from: merchants) + enrichmentProducts)
            .filter { seenResolvedIDs.insert($0.id).inserted }
        products = resolved
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
            .filter { $0.media.isVideo || $0.media.previewURL != nil }
        let topicMatches = verified.filter {
            merchantNames.contains(normalizedMerchantName($0.merchant.name))
        }
        let topicMatchIDs = Set(topicMatches.map(\.id))
        let remainingPosts = verified.filter { !topicMatchIDs.contains($0.id) }
        return Array((topicMatches + remainingPosts).prefix(6))
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
        if let fixedSurfaceHex = topicPresentation.fixedSurfaceHex {
            return Color(hex: fixedSurfaceHex)
        }
        guard let sampledSurfaceColor else { return Color(hex: story.accentHex) }
        return Color(
            red: sampledSurfaceColor.red,
            green: sampledSurfaceColor.green,
            blue: sampledSurfaceColor.blue
        )
    }
    /// The hero keeps the authored topic color at full strength. Commerce
    /// content gradually washes that color toward white so long pages feel
    /// calmer without creating a hard color seam below the film.
    private var scrolledSurfaceBackground: some View {
        let softeningOpacity = topicPresentation.softensLongPageSurface ? 0.09 : 0
        return surfaceColor
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, .white.opacity(softeningOpacity)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 240)
                    Color.white.opacity(softeningOpacity)
                }
            }
    }
    private var heroVideoURL: URL? {
        FeedCoverCatalog.presentation(for: story)?.source.videoURL
            ?? products.lazy.flatMap {
                $0.product.ambientFilmURLs(merchantID: $0.merchant.id)
            }.first
    }
    private var heroTitle: String {
        topicPresentation.heroTitleOverride ?? story.title
    }
    private var pageRecipe: TopicPageRecipe {
        topicPresentation.recipe(
            contextualBentoTitle: contextualBentoTitle,
            automaticExploreFilters: automaticExploreFilters
        )
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
        topicPresentation.usesExactHeroLayout ? 526 : 560
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
                            .background { scrolledSurfaceBackground }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .onScrollGeometryChange(for: CGFloat.self) { scrollGeometry in
                    scrollGeometry.contentOffset.y
                } action: { _, offset in
                    let shouldShowTitle = offset > heroHeight - 96
                    guard shouldShowTitle != headerScrollState.showsTitle else { return }
                    headerScrollState.showsTitle = shouldShowTitle
                }
                compactNavigationHeader(width: geometry.size.width)
                    .opacity(showsControls ? 1 : 0)
                    .zIndex(10)
                if topicPresentation.usesGiftGuidePrototype {
                    GiftGuideSteeringDock(state: giftGuideState)
                        .padding(.bottom, 28)
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height,
                            alignment: .bottom
                        )
                        .zIndex(20)
                }
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
                // Start with the same avatar silhouette as the feed header.
                // The native card zoom then has no chrome discontinuity while
                // the avatar resolves into the destination's close control.
                showsControls = true
                closeMorphProgress = 0
            }
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                closeMorphProgress = 1
            }
            // Keep the bottom chrome stationary until the shared card has
            // finished settling; moving it during the zoom reads as a bump.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                coordinator.showNavBar = false
            }
        }
        .task(id: heroVideoURL) {
            sampledSurfaceColor = nil
            guard topicPresentation.samplesVideoSurfaceColor else { return }
            guard let heroVideoURL,
                  let color = await DominantVideoColorSampler.sample(from: heroVideoURL),
                  !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.24)) {
                sampledSurfaceColor = color
            }
        }
        .onAppear { coordinator.showNavBar = true }
        .onDisappear {
            coordinator.resetScrollState()
            coordinator.showNavBar = true
        }
    }
    private func hero(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            surfaceColor
            Group {
                if heroVideoURL != nil {
                    // Carry the authored feed film into the destination so the
                    // shared-card transition does not resolve into a frozen
                    // Figma export as soon as navigation completes.
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
                } else if let heroFallbackAsset = topicPresentation.heroFallbackAsset {
                    Image(heroFallbackAsset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: heroHeight)
                        .clipped()
                } else {
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
                }
            }
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
            heroFeedbackPill
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topTrailing
                )
                .padding(
                    .top,
                    windowSafeAreaTopInset
                        + FeedNavigationStyle.controlSize
                        + GravitySpacing.space12
                        + FeedCardStyle.titleHeaderGap
                )
                .padding(.trailing, GravitySpacing.space12)
                .offset(y: -GravitySpacing.space40)
            VStack(alignment: .leading, spacing: GravitySpacing.space10) {
                Text(heroTitle)
                    .font(FeedEditorialTypography.titleFont)
                    .tracking(FeedEditorialTypography.titleTracking)
                    .lineSpacing(FeedEditorialTypography.titleLineSpacing)
                    .tightMultilineLeading(FeedEditorialTypography.titleLineTightening)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if !topicPresentation.usesExactHeroLayout,
                   !topicPresentation.usesGiftGuidePrototype,
                   !story.subtitle.isEmpty {
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
            .frame(
                maxWidth: width - 32,
                maxHeight: .infinity,
                alignment: topicPresentation.usesExactHeroLayout ? .topLeading : .bottomLeading
            )
            .padding(.horizontal, GravitySpacing.space16)
            .padding(.top, topicPresentation.usesExactHeroLayout ? 120 : 0)
            .padding(.bottom, topicPresentation.usesExactHeroLayout ? 0 : GravitySpacing.space20)
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
                                showFavoriteButton: true,
                                favoriteIconHasContrastShadow: true
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
    @ViewBuilder
    private func merchandising(containerWidth: CGFloat) -> some View {
        if topicPresentation.usesGiftGuidePrototype {
            GiftGuidePrototypeContent(products: products, state: giftGuideState)
        } else {
            VStack(alignment: .leading, spacing: pageRecipe.sectionSpacing) {
                ForEach(Array(pageRecipe.blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block, containerWidth: containerWidth)
                }
            }
            .padding(.bottom, 120)
        }
    }
    @ViewBuilder
    private func blockView(_ block: TopicPageBlock, containerWidth: CGFloat) -> some View {
        if let authoredBlock = topicPresentation.authoredBlock(for: block) {
            TopicPresentationBlockView(block: authoredBlock, surfaceColor: surfaceColor)
        } else {
            defaultBlockView(block, containerWidth: containerWidth)
        }
    }
    @ViewBuilder
    private func defaultBlockView(_ block: TopicPageBlock, containerWidth: CGFloat) -> some View {
        switch block {
        case .productRail(let title, let query, let cardWidth):
            productRail(title: title, items: products(for: query), cardWidth: cardWidth)
        case .featuredDeals(let title):
            if !relatedDeals.isEmpty { dealRail(title: title, containerWidth: containerWidth) }
        case .relatedCollections(let title, let cardHeight):
            if !featuredCollections.isEmpty { collectionRail(title: title, cardHeight: cardHeight) }
        case .topMerchants(let title):
            if !featuredMerchants.isEmpty { featuredMerchantRail(title: title) }
        case .brandGrid(let title):
            if topicPresentation.merchantStyle == .warmLighting || !showcaseMerchants.isEmpty {
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
                    ForEach(relatedDeals) { deal in
                        RelatedDealCard(deal: deal)
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
                    if topicPresentation.merchantStyle == .warmLighting {
                        WarmLightingBluDotBrandCard()
                        ForEach(showcaseMerchants.prefix(5)) { merchant in
                            TopicBrandGridCard(merchant: merchant)
                        }
                    } else {
                        ForEach(showcaseMerchants) { merchant in
                            TopicBrandGridCard(merchant: merchant)
                        }
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
        HStack(spacing: GravitySpacing.space6) {
            Text(title)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
        }
        .font(GravityFont.expressiveBold.fixedFont(size: 20))
        .tracking(-0.45)
        .foregroundStyle(.white)
        .padding(.horizontal, GravitySpacing.space12)
    }
    private func compactNavigationHeader(width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            TopicCompactHeaderBackdrop(
                state: headerScrollState,
                title: topicPresentation.heroTitleOverride?.replacingOccurrences(of: "\n", with: " ") ?? story.title,
                surfaceColor: surfaceColor,
                width: width,
                topInset: windowSafeAreaTopInset
            )
            .allowsHitTesting(false)
            HStack {
                closeButton
                Spacer()
            }
            .frame(width: width)
            .padding(.top, windowSafeAreaTopInset + GravitySpacing.space4)
        }
        .frame(width: width, height: windowSafeAreaTopInset + 72, alignment: .top)
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
            ZStack {
                BuyerPreviewAvatar(
                    profile: BuyerPreviewStore.shared.selected,
                    size: FeedNavigationStyle.avatarSize
                )
                .opacity(1 - closeMorphProgress)
                .scaleEffect(1 - (0.08 * closeMorphProgress))

                Circle()
                    .fill(surfaceColor)
                    .overlay { Circle().fill(.black.opacity(0.26)) }
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
                    }
                    .opacity(closeMorphProgress)

                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .opacity(closeMorphProgress)
                    .scaleEffect(0.72 + (0.28 * closeMorphProgress))
            }
            .frame(width: FeedNavigationStyle.controlSize, height: FeedNavigationStyle.controlSize)
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.leading, GravitySpacing.space16)
        .accessibilityLabel("Close")
    }
    private var heroFeedbackPill: some View {
        PrototypeFeedbackActions(
            layout: .vertical,
            foregroundColor: .white,
            appliesShadow: true,
            includesOverflow: true,
            includesVolume: false
        )
    }
}
/// Owns the only scroll-responsive topic chrome. Keeping this in a separate
/// observation boundary prevents a title visibility change from rebuilding
/// the video hero and every merchandising rail on the page.
private struct TopicCompactHeaderBackdrop: View {
    let state: TopicHeaderScrollState
    let title: String
    let surfaceColor: Color
    let width: CGFloat
    let topInset: CGFloat
    var body: some View {
        ZStack(alignment: .top) {
            if state.showsTitle {
                // Resolve scrolling content into the authored topic color
                // instead of smearing it through a system material. This
                // keeps product photography crisp beneath a cleaner fade.
                LinearGradient(
                    stops: [
                        .init(color: surfaceColor.opacity(0.98), location: 0),
                        .init(color: surfaceColor.opacity(0.94), location: 0.56),
                        .init(color: surfaceColor.opacity(0.72), location: 0.78),
                        .init(color: surfaceColor.opacity(0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Text(title)
                    .font(GravityFont.semiBold.fixedFont(size: 15))
                    .tracking(-0.2)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: max(120, width - 140))
                    .padding(.top, topInset + 14)
                    .transition(.opacity)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .frame(width: width, height: topInset + 72, alignment: .top)
        .animation(.easeOut(duration: 0.14), value: state.showsTitle)
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
