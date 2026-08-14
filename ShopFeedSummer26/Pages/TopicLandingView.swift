import SwiftUI

/// Editorial topic destination based on the Topic Feeds Figma scaffold.
/// The sections are intentionally derived from feed data so visual treatments
/// can change without rebuilding the topic graph in Swift.
struct TopicLandingView: View {
    let topic: FeedTopic
    let stories: [FeedStory]
    let merchants: [SampleMerchant]
    /// Optional parent-topic theme inherited by drilled-in subtopic pages.
    var headerCoverImageName: String? = nil
    var surfaceAccentHex: String? = nil
    /// Wayfinding for drill-ins: the parent world's name, shown as an
    /// eyebrow above the title so a subcategory never reads as a new topic.
    var headerEyebrow: String? = nil
    /// Sub-topic pages use a shorter header — they are chapters, not covers.
    var compactHeader: Bool = false

    @Environment(NavigationCoordinator.self) private var coordinator

    private var backgroundColor: Color {
        Color(hex: surfaceAccentHex ?? stories.first?.accentHex ?? "#171717")
    }

    private var effectiveCoverImageName: String? {
        headerCoverImageName ?? stories.first?.coverImageName
    }

    private var resolvedProducts: [ResolvedStoryProduct] {
        var seen = Set<String>()
        return stories
            .flatMap { $0.resolvedProducts(from: merchants) }
            .filter { seen.insert($0.id).inserted }
    }

    private var relevantMerchants: [SampleMerchant] {
        var seen = Set<String>()
        // Merchants whose products appear in the topic come first, then
        // curated related merchants from the topic definition.
        var result = resolvedProducts.map(\.merchant).filter { seen.insert($0.id).inserted }
        for merchantID in topic.relatedMerchantIDs ?? [] {
            guard seen.insert(merchantID).inserted,
                  let merchant = merchants.first(where: { $0.id == merchantID }) else { continue }
            result.append(merchant)
        }
        return result
    }

    /// Full topical inventory for open-ended browsing: story-curated products
    /// lead, then the rest of each relevant merchant's catalog. Topic pages
    /// should feel as deep as the shops behind them, not just as deep as the
    /// handful of products their stories cite.
    private var deepProducts: [ResolvedStoryProduct] {
        var seen = Set<String>()
        var result = resolvedProducts.filter { seen.insert($0.id).inserted }
        for merchant in relevantMerchants {
            for product in merchant.products {
                let item = ResolvedStoryProduct(merchant: merchant, product: product)
                guard seen.insert(item.id).inserted else { continue }
                result.append(item)
            }
        }
        return result
    }

    /// Products already merchandised by explicit blocks above the masonry
    /// (bento compartments, product rails). The catch-all must not repeat
    /// them — seeing the same binoculars twice in one screen reads as broken.
    private var merchandisedProductIDs: Set<String> {
        Set(merchandisingBlocks.flatMap { block -> [String] in
            guard block.kind != .masonry else { return [] }
            return (block.items ?? []).compactMap { item in
                guard item.kind == .product,
                      let merchantID = item.merchantID,
                      let productID = item.productID else { return nil }
                return "\(merchantID)-\(productID)"
            }
        })
    }

    /// Mirrors the heterogeneous item stream accepted by Shop client's masonry
    /// renderer. Merchant, category/action, and post cards are interleaved with
    /// products rather than being presented as separate shelves.
    private var masonryItems: [TopicMasonryItem] {
        let products = deepProducts.filter { !merchandisedProductIDs.contains($0.id) }
        var items: [TopicMasonryItem] = []
        if products.indices.contains(0) { items.append(.product(products[0])) }
        if let merchant = relevantMerchants.first {
            items.append(.merchant(merchant, products.filter { $0.merchant.id == merchant.id }))
        }
        if products.indices.contains(1) { items.append(.product(products[1])) }
        if products.indices.contains(2) { items.append(.product(products[2])) }
        if stories.indices.contains(2) {
            items.append(.category(stories[2], stories[2].resolvedProducts(from: merchants)))
        }
        if products.indices.contains(3) { items.append(.product(products[3])) }
        if products.indices.contains(4), stories.indices.contains(1) {
            items.append(.post(stories[1], products[4]))
        }
        if products.indices.contains(5) { items.append(.product(products[5])) }
        if relevantMerchants.indices.contains(1) {
            let merchant = relevantMerchants[1]
            items.append(.merchant(merchant, products.filter { $0.merchant.id == merchant.id }))
        }
        if products.indices.contains(6) { items.append(.product(products[6])) }
        if products.indices.contains(7) { items.append(.product(products[7])) }
        if stories.indices.contains(3) {
            items.append(.category(stories[3], stories[3].resolvedProducts(from: merchants)))
        }
        items.append(contentsOf: products.dropFirst(8).map(TopicMasonryItem.product))
        return items
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    topicHeader
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(merchandisingBlocks) { block in
                            merchandisingBlock(block, containerWidth: geometry.size.width)
                                .id(block.id)
                        }
                    }
                    // The header already plays the lead hero's film; nothing
                    // below it may loop the same clip on this screen.
                    .environment(\.claimedFilmURL, headerFilm?.url)
                }
                // A vertical ScrollView proposes an unconstrained cross-axis.
                // Pinning its child prevents horizontal rails from making the
                // entire topic page wider than the device and clipping it.
                .frame(width: geometry.size.width, alignment: .leading)
                .padding(.bottom, 40)
            }
            // The cover header owns the top of the screen; the top-bar pills
            // float above it with a clear background.
            .ignoresSafeArea(edges: .top)
            // The default scroll-edge effect paints a heavy tinted wash under
            // the top bar (harsh in dark scheme); .soft is blur-based.
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, offset in
                coordinator.updateScrollOffset(offset)
            }
#if DEBUG
            // Fast-iteration hook: `-scrollTo <blockID>` jumps to a
            // merchandising block for screenshot loops. One-shot: the launch
            // arg lives for the whole process, so without consuming it every
            // topic opened in the session would auto-scroll.
            .onAppear {
                if let target = UserDefaults.standard.string(forKey: "scrollTo"),
                   !Self.didConsumeScrollTo {
                    Self.didConsumeScrollTo = true
                    // Delay past first layout + image decode so cold
                    // launches land correctly.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                }
            }
#endif
            }
        }
        .background(backgroundColor.ignoresSafeArea())
    }

#if DEBUG
    /// Whether the `-scrollTo` launch hook has already fired this process.
    @MainActor private static var didConsumeScrollTo = false
#endif

    /// The lead story's hero-product film — the same surface its feed card
    /// plays, so the zoom transition hands the motion off seamlessly.
    private var headerFilm: (url: URL, poster: String?)? {
        guard let hero = stories.first?.resolvedProducts(from: merchants).first,
              let url = DossierStore.ambientVideoURL(merchantID: hero.merchant.id, productID: hero.product.id) else { return nil }
        return (url, hero.product.imageURL)
    }

    private var topicHeader: some View {
        ZStack(alignment: .bottomLeading) {
            if let headerFilm {
                Color.clear
                    .overlay {
                        AmbientProductVideo(videoURL: headerFilm.url, posterImageURL: headerFilm.poster)
                    }
                    .clipped()
            } else if let coverImageName = effectiveCoverImageName {
                // Overlay-on-clear keeps the fill image from widening the
                // header beyond the container and displacing the page layout.
                Color.clear
                    .overlay {
                        Image(coverImageName)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            } else {
                backgroundColor
            }

            // Eased dissolve into the page background so the cover melts
            // into the feed instead of ending on a hard edge. Kept low and
            // light: the cover art stays clean and the ramp only builds in
            // the last stretch before the feed.
            LinearGradient(
                stops: [
                    .init(color: backgroundColor.opacity(0), location: 0),
                    .init(color: backgroundColor.opacity(0), location: 0.74),
                    .init(color: backgroundColor.opacity(0.06), location: 0.82),
                    .init(color: backgroundColor.opacity(0.24), location: 0.9),
                    .init(color: backgroundColor.opacity(0.58), location: 0.96),
                    .init(color: backgroundColor, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

        }
        // Cover topics get a tall editorial header; coverless landings and
        // drilled-in sub-topics stay compact instead of reserving atmosphere.
        .frame(height: {
            let hasCover = effectiveCoverImageName != nil || headerFilm != nil
            if compactHeader { return hasCover ? 300 : 180 }
            return hasCover ? 410 : 220
        }())
        // Display title sits a touch below center of the atmosphere — the
        // bottom edge is now free for the feed to pull up underneath.
        .overlay {
            VStack(spacing: 6) {
                if let headerEyebrow {
                    Text(headerEyebrow)
                        .font(.system(size: 12, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.72))
                }
                Text(topic.label)
                    .font(.system(size: compactHeader ? 30 : 40, weight: .heavy, design: .default))
                    .tracking(compactHeader ? -0.9 : -1.4)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .offset(y: compactHeader ? 40 : 50)
        }
    }

    private var merchandisingBlocks: [FeedTopic.MerchandisingBlock] {
        if let blocks = topic.merchandisingBlocks, !blocks.isEmpty { return blocks }
        return [
            .init(id: "merchants", kind: .merchantRail, title: "Related shops", items: nil),
            .init(id: "discover", kind: .masonry, title: "Discover more", items: nil),
        ]
    }

    @ViewBuilder
    private func merchandisingBlock(_ block: FeedTopic.MerchandisingBlock, containerWidth: CGFloat) -> some View {
        switch block.kind {
        case .bento:
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(block.title)
                BentoGrid(
                    compartments: bentoCompartments(block),
                    containerWidth: containerWidth - 32
                )
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)
        case .mediaCarousel:
            mediaCarousel(block)
        case .merchantRail:
            merchantRail(block)
        case .productRail:
            productRail(block)
        case .masonry:
            VStack(alignment: .leading, spacing: 0) {
                sectionTitle(block.title)
                productMasonry(containerWidth: containerWidth)
            }
        }
    }

    /// Wireframe section header: compact bold title with an inline circular
    /// chevron chip ("Gifts under $100  ›").
    private func sectionTitle(_ title: String?) -> some View {
        Group {
            if let title, !title.isEmpty {
                HStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.3)
                        .foregroundStyle(.white)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(.white.opacity(0.14), in: Circle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }
        }
    }

    private func mediaCarousel(_ block: FeedTopic.MerchandisingBlock) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(block.title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array((block.items ?? []).enumerated()), id: \.offset) { _, item in
                        mediaCarouselItem(item)
                    }
                }
                .padding(.horizontal, 16)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private func mediaCarouselItem(_ item: FeedTopic.MerchandisingBlock.Item) -> some View {
        switch item.kind {
        case .story:
            if let storyID = item.storyID, let story = stories.first(where: { $0.id == storyID }) {
                TopicFeatureCard(story: story, merchants: merchants) {
                    coordinator.pushRoute(.story(storyId: story.id))
                }
                .frame(width: 330)
            }
        case .merchant:
            if let merchantID = item.merchantID, let merchant = merchants.first(where: { $0.id == merchantID }) {
                TopicMerchantSpotlight(merchant: merchant) {
                    coordinator.pushRoute(.store(merchantId: merchant.id))
                }
                .frame(width: 270)
            }
        case .product:
            if let product = resolvedProduct(for: item) {
                TopicProductRailCard(item: product) {
                    coordinator.pushRoute(.product(merchantId: product.merchant.id, productId: product.product.id))
                }
                .frame(width: 190)
            }
        case .merchantSpotlight, .avatarCluster:
            // Bento-only kinds; a media carousel never authors them.
            EmptyView()
        }
    }

    private func merchantRail(_ block: FeedTopic.MerchandisingBlock) -> some View {
        let blockMerchants: [SampleMerchant] = (block.items ?? []).compactMap { item -> SampleMerchant? in
            guard let id = item.merchantID else { return nil }
            return merchants.first { $0.id == id }
        }
        let displayed = blockMerchants.isEmpty ? relevantMerchants : blockMerchants

        return VStack(alignment: .leading, spacing: 14) {
            sectionTitle(block.title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(displayed) { merchant in
                        Button {
                            coordinator.pushRoute(.store(merchantId: merchant.id))
                        } label: {
                            MerchantLogoImage(merchant: merchant, size: 68)
                                .overlay { Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5) }
                        }
                        .buttonStyle(PressScaleButtonStyle(scale: 0.9))
                        .accessibilityLabel(merchant.name)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func productRail(_ block: FeedTopic.MerchandisingBlock) -> some View {
        let products = (block.items ?? []).compactMap(resolvedProduct(for:))
        return VStack(alignment: .leading, spacing: 14) {
            sectionTitle(block.title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(products) { item in
                        TopicProductRailCard(item: item) {
                            coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
                        }
                        .frame(width: 164)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    /// Maps a bento block's items to compartments. Explicit sizes win;
    /// unsized cells resolve from signal strength and film coverage.
    private func bentoCompartments(_ block: FeedTopic.MerchandisingBlock) -> [BentoCompartment] {
        let signals = ShopperSignals.current
        return (block.items ?? []).enumerated().compactMap { index, item in
            let id = "\(block.id)-\(index)"
            let role = item.role ?? ""
            switch item.kind {
            case .product:
                guard let resolved = resolvedProduct(for: item) else { return nil }
                let hasFilm = DossierStore.ambientVideoURL(merchantID: resolved.merchant.id, productID: resolved.product.id) != nil
                let size = BentoCompartment.resolveSize(
                    explicit: item.size,
                    signal: signals.strength(merchantID: resolved.merchant.id, productID: resolved.product.id),
                    hasFilm: hasFilm
                )
                return BentoCompartment(id: id, role: role, size: size, surface: .product(resolved)) {
                    // Straight to the PDP unless a dossier with real content
                    // (payload or films) has landed — pre-seeded manifest
                    // entries alone must not earn an empty interstitial.
                    if let dossier = DossierStore.dossier(merchantID: resolved.merchant.id, productID: resolved.product.id),
                       dossier.payload != nil || dossier.hasAmbientVideo {
                        coordinator.pushRoute(.deepDive(merchantId: resolved.merchant.id, productId: resolved.product.id))
                    } else {
                        coordinator.pushRoute(.product(merchantId: resolved.merchant.id, productId: resolved.product.id))
                    }
                }
            case .merchant:
                guard let merchantID = item.merchantID,
                      let merchant = merchants.first(where: { $0.id == merchantID }) else { return nil }
                let size = BentoCompartment.resolveSize(explicit: item.size, signal: .none, hasFilm: false)
                return BentoCompartment(id: id, role: role, size: size, surface: .merchant(merchant)) {
                    coordinator.pushRoute(.store(merchantId: merchant.id))
                }
            case .merchantSpotlight:
                guard let merchantID = item.merchantID,
                      let merchant = merchants.first(where: { $0.id == merchantID }) else { return nil }
                let chips = (item.productIDs ?? []).compactMap { productID in
                    merchant.products.first(where: { $0.id == productID })
                        .map { ResolvedStoryProduct(merchant: merchant, product: $0) }
                }
                // Always standard: the spotlight earns its height by anchoring
                // a trio, not by claiming a full-width cell.
                return BentoCompartment(id: id, role: role, size: .standard, surface: .merchantSpotlight(merchant, chips)) {
                    coordinator.pushRoute(.store(merchantId: merchant.id))
                }
            case .avatarCluster:
                let clusterMerchants = (item.merchantIDs ?? []).compactMap { mid in
                    merchants.first(where: { $0.id == mid })
                }
                guard clusterMerchants.count >= 4 else { return nil }
                // The discs are their own buttons; the compartment action is
                // never reachable but the shape keeps the grammar uniform.
                return BentoCompartment(id: id, role: role, size: .standard, surface: .avatarCluster(clusterMerchants), action: {})
            case .story:
                guard let storyID = item.storyID,
                      let story = stories.first(where: { $0.id == storyID }) ?? PersonalizedFeedStories.all.first(where: { $0.id == storyID }) else { return nil }
                let hero = story.resolvedProducts(from: merchants).first
                let hasFilm = hero.map { DossierStore.ambientVideoURL(merchantID: $0.merchant.id, productID: $0.product.id) != nil } ?? false
                let size = BentoCompartment.resolveSize(explicit: item.size, signal: .none, hasFilm: hasFilm)
                return BentoCompartment(id: id, role: role, size: size, surface: .story(story, hero: hero)) {
                    coordinator.pushRoute(.story(storyId: story.id))
                }
            }
        }
    }

    private func resolvedProduct(for item: FeedTopic.MerchandisingBlock.Item) -> ResolvedStoryProduct? {
        guard let merchantID = item.merchantID,
              let productID = item.productID,
              let merchant = merchants.first(where: { $0.id == merchantID }),
              let product = merchant.products.first(where: { $0.id == productID }) else { return nil }
        return ResolvedStoryProduct(merchant: merchant, product: product)
    }

    private func productMasonry(containerWidth: CGFloat) -> some View {
        let columns = splitMasonryItems(masonryItems)
        let horizontalPadding: CGFloat = 16
        // Mirrors ShopProductDetailsMasonrySpacing.defaultItemGap.
        let columnSpacing: CGFloat = GravitySpacing.space16
        let columnWidth = (containerWidth - horizontalPadding * 2 - columnSpacing) / 2

        return HStack(alignment: .top, spacing: columnSpacing) {
            VStack(spacing: columnSpacing) {
                ForEach(columns.0) { item in
                    TopicMasonryCard(item: item, cardWidth: columnWidth)
                }
            }
            .frame(width: columnWidth)

            VStack(spacing: columnSpacing) {
                ForEach(columns.1) { item in
                    TopicMasonryCard(item: item, cardWidth: columnWidth)
                }
            }
            .frame(width: columnWidth)
        }
        .frame(width: containerWidth - horizontalPadding * 2, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 18)
    }

    private func splitMasonryItems(_ items: [TopicMasonryItem]) -> ([TopicMasonryItem], [TopicMasonryItem]) {
        var left: [TopicMasonryItem] = []
        var right: [TopicMasonryItem] = []
        for (index, item) in items.enumerated() {
            index.isMultiple(of: 2) ? left.append(item) : right.append(item)
        }
        return (left, right)
    }

}

private struct TopicFeatureCard: View {
    let story: FeedStory
    let merchants: [SampleMerchant]
    let action: () -> Void

    private static let cardHeight: CGFloat = 244

    /// The story's lifestyle cover is the preferred backdrop; the hero
    /// product photo is an honest fallback when no cover art exists.
    private var heroProduct: ResolvedStoryProduct? {
        story.resolvedProducts(from: merchants).first
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // One big, clean surface — no collage. The hero product's
                // ambient dossier film wins when it exists; cover art and
                // product photo are the fallbacks.
                Color.clear
                    .overlay {
                        if let hero = heroProduct,
                           let film = DossierStore.ambientVideoURL(merchantID: hero.merchant.id, productID: hero.product.id) {
                            AmbientProductVideo(videoURL: film, posterImageURL: hero.product.imageURL)
                        } else if let coverImageName = story.coverImageName {
                            Image(coverImageName)
                                .resizable()
                                .scaledToFill()
                        } else if let hero = heroProduct {
                            ProductImageView(product: hero.product, merchant: hero.merchant, fallbackIndex: 0)
                        } else {
                            Color(hex: story.accentHex)
                        }
                    }
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.45),
                        .init(color: .black.opacity(0.72), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 12) {
                    // Echoes the topic header's display type, scaled to the card.
                    Text(story.title)
                        .font(.system(size: 26, weight: .heavy))
                        .tracking(-0.9)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.16), in: Circle())
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

private struct TopicMerchantSpotlight: View {
    let merchant: SampleMerchant
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                MerchantCoverImage(merchant: merchant)
                    .frame(height: 244)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(spacing: 10) {
                    MerchantLogoImage(merchant: merchant, size: 46)
                    Text(merchant.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(16)
            }
            .frame(height: 244)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

/// Simplified rail card: the component-system `ProductCard` in image-only
/// mode with the standard price badge overlay. No metadata below the tile —
/// title/merchant live one tap away on the PDP.
private struct TopicProductRailCard: View {
    let item: ResolvedStoryProduct
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ProductCard(
                image: nil,
                imageURL: item.product.imageURL,
                priceBadge: formatPrice(item.product.price),
                showFavoriteButton: true
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(item.product.title), \(formatPrice(item.product.price)), \(item.merchant.displayName)")
    }
}

#Preview("Topic landing") {
    let topic = PersonalizedFeedCatalog.current.topics.first { $0.id == "coffee-counter" }!
    let ids = Set(topic.storyIDs ?? [])
    NavigationStack {
        TopicLandingView(
            topic: topic,
            stories: PersonalizedFeedStories.all.filter { ids.contains($0.id) },
            merchants: SampleMerchant.previews
        )
    }
    .environment(NavigationCoordinator())
}
