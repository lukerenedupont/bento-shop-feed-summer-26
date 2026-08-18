import SwiftUI

/// Full-screen commerce-content card. A story can mix products and merchants;
/// the stable formats keep interaction familiar while the content supplies the novelty.
struct StoryFeedCard: View {
    let story: FeedStory
    let merchants: [SampleMerchant]
    let width: CGFloat
    let height: CGFloat
    var titleOverride: String? = nil
    var isActive = true
    var showsBackground = true
    var showsForegroundContent = true
    var showsFooterArrow = true
    var titleAtTopLeading = false
    var productLayout: FeedCardProductLayout? = nil
    var foregroundBottomPadding: CGFloat = GravitySpacing.space20
    var backgroundBlurRadius: CGFloat = 0
    var backgroundPlaybackEnabled = true
    /// Lets the feed establish a restrained motion rhythm. When a generated
    /// film is unavailable, the card continues to use its lifestyle still.
    var prefersVideoBackground = false
    var cornerRadius: CGFloat = GravityRadius.r28
    var freezesParallax = false
    /// Enables scroll-relative movement for the ambient film without moving
    /// any foreground commerce content. Nil outside a paginated feed.
    var scrollViewportHeight: CGFloat? = nil
    var onTap: (() -> Void)? = nil

    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mediaIsMoving = false
    @State private var selectedProductIndex = 0
    @State private var productDragOffset: CGFloat = 0
    @State private var productPromotionProgress: CGFloat = 0
    @State private var productDeckDirection = 1
    @State private var productDeckIsSettling = false

    private var items: [ResolvedStoryProduct] {
        story.resolvedProducts(from: merchants)
    }

    /// Product references lead the assortment, then the same merchants fill
    /// it out with adjacent catalog items. A final catalog pass guarantees the
    /// dense 4/6/9-up variants never end with a visibly empty grid slot.
    private var productAssortment: [ResolvedStoryProduct] {
        var seen = Set<String>()
        var assortment: [ResolvedStoryProduct] = []

        func append(_ item: ResolvedStoryProduct) {
            guard seen.insert(item.id).inserted else { return }
            assortment.append(item)
        }

        items.forEach(append)
        for item in items {
            for product in item.merchant.products {
                append(ResolvedStoryProduct(merchant: item.merchant, product: product))
            }
        }
        if assortment.count < 10 {
            for merchant in merchants {
                for product in merchant.products {
                    append(ResolvedStoryProduct(merchant: merchant, product: product))
                    if assortment.count == 10 { break }
                }
                if assortment.count == 10 { break }
            }
        }
        return Array(assortment.prefix(10))
    }

    private var ambientFilmURLs: [URL] {
        guard !story.usesCatalogOnlyMedia else { return [] }
        guard story.coverImageName == nil else { return [] }
        return items.flatMap {
            $0.product.ambientFilmURLs(merchantID: $0.merchant.id)
        }
    }

    private var leadFilmURL: URL? {
        ambientFilmURLs.first
    }

    private var heroLifestyleImageURL: URL? {
        if prefersVideoBackground, leadFilmURL != nil {
            return nil
        }
        return story.lifestyleImageURL(
            from: merchants,
            format: .portrait,
            role: "feed-hero"
        )
    }

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            if let onTap {
                onTap()
            } else {
                coordinator.pushRoute(.story(storyId: story.id))
            }
        } label: {
            ZStack {
                if showsBackground {
                    atmosphericBackground
                        .frame(width: width, height: height)
                        .scaleEffect(backgroundBlurRadius > 0 ? 1.12 : 1)
                        .blur(radius: backgroundBlurRadius, opaque: true)
                    backgroundScrim
                        .frame(width: width, height: height)
                }

                if showsForegroundContent {
                    ZStack {
                        if productLayout == .compactGrid {
                            compactGridComposition
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .bottomLeading
                                )
                        } else {
                            storyHeader
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: titleAtTopLeading ? .topLeading : .bottomLeading
                                )
                        }
                        if showsFooterArrow {
                            footerArrow
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .bottomTrailing
                                )
                        }
                        if productLayout == .stackedDeck {
                            productCarousel
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .bottomLeading
                                )
                        }
                        if productLayout == .bottomCarousel {
                            bottomProductCarousel
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .bottomLeading
                                )
                        }
                    }
                    .padding(.horizontal, GravitySpacing.space20)
                    .padding(.top, GravitySpacing.space20)
                    .padding(.bottom, foregroundBottomPadding)
                    .opacity(isActive ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isActive)
                    .transition(.opacity)
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            }
            .gravityShadow(GravityShadows.medium)
        }
        .buttonStyle(PressScaleButtonStyle())
        .onAppear { mediaIsMoving = true }
        .accessibilityLabel("\(titleOverride ?? story.title). \(story.subtitle)")
        .accessibilityHint(story.destinationLabel)
    }

    // MARK: - Atmosphere

    private var atmosphericBackground: some View {
        ZStack {
            Color(hex: story.accentHex)

            if let heroLifestyleImageURL {
                Color.clear
                    .overlay {
                        CachedAsyncImage(url: heroLifestyleImageURL) { phase in
                            if case .success(let image) = phase {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .scaleEffect(mediaIsMoving ? 1.0 : 1.035)
                                    .animation(
                                        .easeInOut(duration: 8).repeatForever(autoreverses: true),
                                        value: mediaIsMoving
                                    )
                            } else if case .failure = phase,
                                      let first = items.first {
                                ProductImageView(product: first.product, merchant: first.merchant)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if let coverImageName = story.coverImageName {
                // Overlay-on-clear keeps the fill image from expanding the
                // ZStack beyond the card frame and breaking sibling layout.
                Color.clear
                    .overlay {
                        Image(coverImageName)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(mediaIsMoving ? 1.0 : 1.04)
                            .animation(
                                .easeInOut(duration: 8).repeatForever(autoreverses: true),
                                value: mediaIsMoving
                            )
                    }
                    .clipped()
            } else if let first = items.first, leadFilmURL != nil {
                parallaxFilm {
                    AmbientProductVideo(
                        videoURLs: ambientFilmURLs,
                        posterImageURL: first.product.imageURL,
                        playbackEnabled: backgroundPlaybackEnabled && isActive,
                        playbackGroupID: "story-card-\(story.id)"
                    )
                }
            } else if let first = items.first,
                      let imageURL = first.product.imageURL,
                      let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 22)
                            .scaleEffect(mediaIsMoving ? 1.08 : 1.22)
                            .opacity(0.42)
                            .animation(
                                .easeInOut(duration: 8).repeatForever(autoreverses: true),
                                value: mediaIsMoving
                            )
                    }
                }
            }

            if leadFilmURL == nil && heroLifestyleImageURL == nil {
                LinearGradient(
                    colors: [Color(hex: story.accentHex).opacity(0.08), Color(hex: story.accentHex).opacity(0.68)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipped()
    }

    /// The film travels at a fraction of the card's scroll velocity. A small
    /// overscan keeps the card edges covered while the media shifts underneath
    /// its stationary title, products, and scrims.
    @ViewBuilder
    private func parallaxFilm<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if let scrollViewportHeight, !reduceMotion {
            content()
                .scaleEffect(1.05)
                .visualEffect { film, proxy in
                    film.offset(
                        y: freezesParallax
                            ? 0
                            : max(
                                -14,
                                min(
                                    14,
                                    -(proxy.frame(in: .scrollView(axis: .vertical)).midY
                                        - scrollViewportHeight / 2) * 0.025
                                )
                            )
                    )
                }
        } else {
            content()
        }
    }

    private var backgroundScrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.36), location: 0),
                .init(color: .clear, location: 0.30),
                .init(color: .clear, location: 0.72),
                .init(color: .black.opacity(0.34), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Header

    private var storyHeader: some View {
        Text(titleOverride ?? story.title)
            .font(FeedEditorialTypography.titleFont)
            .tracking(FeedEditorialTypography.titleTracking)
            .lineSpacing(FeedEditorialTypography.titleLineSpacing)
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
    }

    // MARK: - Stable formats

    @ViewBuilder
    private var storyContent: some View {
        switch story.format {
        case .world:
            StoryWorldLayout(items: items, isActive: isActive)
        case .shortlist:
            StoryShortlistLayout(items: items, isActive: isActive)
        case .setup:
            StorySetupLayout(items: items, isActive: isActive)
        }
    }

    // MARK: - Footer

    private var footerArrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(.white.opacity(0.12), in: Circle())
    }

    /// Large native square cards keep the assortment useful over the media.
    /// The rail owns the full card width so the next product can peek through
    /// the rounded edge instead of being clipped by the foreground inset.
    private var bottomProductCarousel: some View {
        let tileWidth = max((width - 64) / 2, 144)

        return VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(productAssortment) { item in
                        compactProductTile(item)
                            .frame(width: tileWidth)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.leading, GravitySpacing.space20, for: .scrollContent)
            .padding(.horizontal, -GravitySpacing.space20)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))

            productFooter
        }
        .frame(height: tileWidth + 42)
    }

    /// Dense assortment treatment: the title stays fixed at the top while the
    /// products and edit footer form one anchored block at the bottom.
    private var compactGridComposition: some View {
        let count = compactGridItemCount
        let columns = count == 4 ? 2 : 3

        return VStack(alignment: .leading, spacing: 0) {
            storyHeader

            Spacer(minLength: 18)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns),
                spacing: 8
            ) {
                ForEach(Array(productAssortment.prefix(count))) { item in
                    compactProductTile(item)
                }
            }
            .padding(.bottom, 14)

            productFooter
        }
    }

    /// Dense cards alternate between a complete 3×2 and 3×3 rhythm. The
    /// carousel variant supplies the four-up treatment elsewhere in the feed.
    private var compactGridItemCount: Int {
        let stableSeed = story.id.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return stableSeed.isMultiple(of: 2) ? 6 : 9
    }

    private func compactProductTile(_ item: ResolvedStoryProduct) -> some View {
        ProductCard(
            image: nil,
            imageURL: item.product.imageURL,
            priceBadge: formatPrice(item.product.price),
            showFavoriteButton: true
        )
        // The whole story card is the destination at this level. Controls are
        // presented in their native form without creating nested tap targets.
        .allowsHitTesting(false)
    }

    private var productFooter: some View {
        HStack(spacing: 8) {
            Text("\(productAssortment.count) items added 8m ago")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Text("Shop all")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var productCarousel: some View {
        VStack(spacing: 14) {
            GeometryReader { geometry in
                if !items.isEmpty {
                    let safeIndex = min(selectedProductIndex, items.count - 1)
                    let item = items[safeIndex]
                    let nextItem = deckItem(from: safeIndex, offset: productDeckDirection)
                    let farItem = deckItem(from: safeIndex, offset: productDeckDirection * 2)

                    ZStack(alignment: .leading) {
                        productSummaryCard(farItem)
                            .frame(width: geometry.size.width - 16)
                            .scaleEffect(0.92 + 0.04 * productPromotionProgress, anchor: .leading)
                            .offset(x: 36 - 18 * productPromotionProgress)
                            .shadow(color: .black.opacity(0.12), radius: 5, y: 2)

                        productSummaryCard(nextItem)
                            .frame(width: geometry.size.width - 16)
                            .scaleEffect(0.96 + 0.04 * productPromotionProgress, anchor: .leading)
                            .offset(x: 18 * (1 - productPromotionProgress))
                            .shadow(color: .black.opacity(0.12), radius: 5, y: 2)

                        productSummaryCard(item)
                            .frame(width: geometry.size.width - 16)
                            .offset(x: productDragOffset)
                            .shadow(color: .black.opacity(0.16), radius: 7, y: 3)
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(productDeckGesture(width: geometry.size.width))
                }
            }
            .frame(height: 88)

            HStack(spacing: 8) {
                Text("\(items.count) items added 8m ago")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)

                Spacer()

                Text("Shop all")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(height: 126)
    }

    private func productSummaryCard(_ item: ResolvedStoryProduct) -> some View {
        HStack(spacing: 12) {
            ProductImageView(product: item.product, merchant: item.merchant)
                .frame(width: 72, height: 72)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.product.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(formatPrice(item.product.price))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 6)

            Image(systemName: "heart")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
        }
        .padding(8)
        .background(productStackColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        }
    }

    private var productStackColor: Color {
        items.first?.merchant.brandColor ?? Color(hex: story.accentHex)
    }

    private func deckItem(from index: Int, offset: Int) -> ResolvedStoryProduct {
        let resolvedIndex = (index + offset + items.count * 2) % items.count
        return items[resolvedIndex]
    }

    private func productDeckGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !productDeckIsSettling,
                      abs(value.translation.width) > abs(value.translation.height) else { return }
                productDeckDirection = value.translation.width < 0 ? 1 : -1
                productDragOffset = value.translation.width
                productPromotionProgress = min(abs(value.translation.width) / max(width, 1), 1)
            }
            .onEnded { value in
                guard !productDeckIsSettling,
                      items.count > 1,
                      abs(value.translation.width) > abs(value.translation.height),
                      abs(value.translation.width) > 42 else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        productDragOffset = 0
                        productPromotionProgress = 0
                    }
                    return
                }

                productDeckIsSettling = true
                let direction = value.translation.width < 0 ? 1 : -1
                let exitOffset = direction > 0 ? -width : width

                withAnimation(.easeOut(duration: 0.22)) {
                    productDragOffset = exitOffset
                    productPromotionProgress = 1
                }

                Task { @MainActor in
                    // Reset only after both the outgoing card and the already-
                    // rendered rear card have reached their final geometry.
                    try? await Task.sleep(for: .milliseconds(230))
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        selectedProductIndex = (selectedProductIndex + direction + items.count) % items.count
                        productDragOffset = 0
                        productPromotionProgress = 0
                    }
                    productDeckIsSettling = false
                    HapticFeedback.light.fire()
                }
            }
    }

}

#Preview("World story") {
    StoryFeedCard(
        story: FeedStory.previews.first(where: { $0.format == .world }) ?? FeedStory.preview,
        merchants: SampleMerchant.previews,
        width: 377,
        height: 645
    )
    .padding()
    .background(GravityColors.bg)
    .environment(NavigationCoordinator())
}

#Preview("Shortlist story") {
    StoryFeedCard(
        story: FeedStory.previews.first(where: { $0.format == .shortlist }) ?? FeedStory.preview,
        merchants: SampleMerchant.previews,
        width: 377,
        height: 645
    )
    .padding()
    .background(GravityColors.bg)
    .environment(NavigationCoordinator())
}

#Preview("Setup story") {
    StoryFeedCard(
        story: FeedStory.previews.first(where: { $0.format == .setup }) ?? FeedStory.preview,
        merchants: SampleMerchant.previews,
        width: 377,
        height: 645
    )
    .padding()
    .background(GravityColors.bg)
    .environment(NavigationCoordinator())
}
