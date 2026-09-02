import SwiftUI

/// PROTOTYPE: lightweight, local-only feedback actions for evaluating how
/// buyer signals and jump-off mechanics feel on feed cards and topic heroes.
struct PrototypeFeedbackActions: View {
    enum Layout {
        case vertical
        case horizontal
    }

    private enum Action: String, Hashable {
        case more = "More"
        case volume = "Volume"
        case like = "Like"
        case thread = "Thread"
        case share = "Share"

        var symbol: String {
            switch self {
            case .more: "ellipsis"
            case .volume: "speaker.wave.2"
            case .like: "heart"
            case .thread: "bubble.left.and.bubble.right"
            case .share: "square.and.arrow.up"
            }
        }

        var selectedSymbol: String {
            switch self {
            case .more: "ellipsis"
            case .volume: "speaker.slash"
            case .like: "heart.fill"
            case .thread: "bubble.left.and.bubble.right.fill"
            case .share: "square.and.arrow.up"
            }
        }

        var figmaAssetName: String? {
            switch self {
            case .more: "feedback-overflow"
            case .volume: "feedback-volume"
            case .like: "feedback-heart"
            case .share: "feedback-share"
            case .thread: nil
            }
        }
    }

    let layout: Layout
    var foregroundColor: Color = .white
    var appliesShadow = true
    var includesOverflow = false
    var includesVolume = false
    var includesThread = true
    var onOverflowTap: (() -> Void)?
    @State private var selectedActions: Set<Action> = []

    var body: some View {
        Group {
            if layout == .vertical {
                VStack(spacing: includesVolume ? GravitySpacing.space12 : GravitySpacing.space20) {
                    actionButtons
                }
            } else {
                HStack(spacing: GravitySpacing.space20) {
                    actionButtons
                }
            }
        }
    }

    private var actions: [Action] {
        var actions: [Action] = []
        if includesOverflow { actions.append(.more) }
        if includesVolume { actions.append(.volume) }
        actions.append(.like)
        if includesThread { actions.append(.thread) }
        actions.append(.share)
        return actions
    }

    @ViewBuilder
    private var actionButtons: some View {
        ForEach(actions, id: \.self) { action in
            Button {
                HapticFeedback.light.fire()
                if action == .more {
                    onOverflowTap?()
                    return
                }
                withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                    if selectedActions.contains(action) {
                        selectedActions.remove(action)
                    } else {
                        selectedActions.insert(action)
                    }
                }
            } label: {
                if layout == .vertical {
                    verticalLabel(for: action)
                } else {
                    horizontalLabel(for: action)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(action.rawValue)
            .accessibilityAddTraits(selectedActions.contains(action) ? .isSelected : [])
        }
    }

    private func verticalLabel(for action: Action) -> some View {
        let isSelected = selectedActions.contains(action)

        return actionImage(for: action, isSelected: isSelected)
            .foregroundStyle(foregroundColor)
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
            .shadow(
                color: appliesShadow ? .black.opacity(0.24) : .clear,
                radius: appliesShadow ? 4 : 0,
                y: appliesShadow ? 2 : 0
            )
            .scaleEffect(isSelected ? 1.12 : 1)
    }

    private func horizontalLabel(for action: Action) -> some View {
        let isSelected = selectedActions.contains(action)

        return actionImage(for: action, isSelected: isSelected)
            .foregroundStyle(foregroundColor)
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
            .opacity(isSelected ? 1 : 0.88)
            .scaleEffect(isSelected ? 1.1 : 1)
    }

    @ViewBuilder
    private func actionImage(for action: Action, isSelected: Bool) -> some View {
        if !isSelected, let assetName = action.figmaAssetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: isSelected ? action.selectedSymbol : action.symbol)
                .font(.system(size: 18, weight: .semibold))
        }
    }
}

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
    var foregroundTopPadding: CGFloat = GravitySpacing.space20
    var titleTrailingPadding: CGFloat = 0
    /// Pins a top-leading title under persistent navigation using a
    /// compositor-only offset. This avoids invalidating the card hierarchy
    /// while a vertical scroll gesture is in flight.
    var scrollPinnedTitleTop: CGFloat? = nil
    /// World cards anchor their title and products as one bottom composition
    /// that stays pinned above the bottom navigation while the card travels.
    var usesWorldCardComposition = false
    var foregroundBottomPadding: CGFloat = FeedCardStyle.foregroundBottomPadding
    var backgroundBlurRadius: CGFloat = 0
    var backgroundPlaybackEnabled = true
    /// Lets the feed establish a restrained motion rhythm. When a generated
    /// film is unavailable, the card continues to use its lifestyle still.
    var prefersVideoBackground = false
    var cornerRadius: CGFloat = GravityRadius.r28
    var bottomCornerRadius: CGFloat? = nil
    var topScrimOpacity: Double = 0.36
    var borderOpacity: Double = 0.12
    var shadowOpacity: Double = 1
    var freezesParallax = false
    /// Enables scroll-relative movement for the ambient film without moving
    /// any foreground commerce content. Nil outside a paginated feed.
    var scrollViewportHeight: CGFloat? = nil
    var onTap: (() -> Void)? = nil

    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        // Hypothesis shelves are exact authored assortments. Do not pad them
        // with products from another shelf just to fill a larger card layout.
        if story.id.hasPrefix("shelf-") {
            return items
        }

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

    private var authoredCover: FeedCoverPresentation? {
        FeedCoverCatalog.presentation(for: story)
    }

    private var authoredCoverURL: URL? {
        authoredCover?.coverURL(from: merchants)
    }

    private var authoredCoverAssetName: String? {
        authoredCover?.source.bundledAssetName
    }

    private var authoredCoverVideoURL: URL? {
        authoredCover?.source.videoURL
    }

    private var fallbackEditorialCoverImageName: String {
        FeedCoverCatalog.fallbackImageName(for: story)
    }

    private var resolvedBottomCornerRadius: CGFloat {
        bottomCornerRadius ?? cornerRadius
    }

    private var cardShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: cornerRadius,
            bottomLeadingRadius: resolvedBottomCornerRadius,
            bottomTrailingRadius: resolvedBottomCornerRadius,
            topTrailingRadius: cornerRadius,
            style: .continuous
        )
    }

    private var heroLifestyleImageURL: URL? {
        if story.coverImageName != nil { return nil }
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
                    let pinsBottomChrome = usesWorldCardComposition
                    let pinnedChromeRestingTop = foregroundTopPadding
                    Group {
                        if usesWorldCardComposition {
                            worldCardForeground
                        } else {
                            standardForeground
                        }
                    }
                    .padding(.horizontal, GravitySpacing.space20)
                    .padding(.top, foregroundTopPadding)
                    // 76pt keeps the pinned rail clear of the floating bottom
                    // navigation, matching the geometry the removed explore
                    // affordance used to reserve beneath the products.
                    .padding(.bottom, usesWorldCardComposition ? GravitySpacing.space64 + GravitySpacing.space12 : foregroundBottomPadding)
                    // While the card travels toward its snap slot its bottom
                    // edge is still below the viewport, which hides the
                    // bottom-anchored title and products behind the bottom
                    // navigation. Lifting the composition by the card's top
                    // offset holds it at its final on-screen position, the
                    // same trick the top-pinned title uses in reverse.
                    .visualEffect { content, proxy in
                        content.offset(
                            y: pinsBottomChrome
                                ? -max(
                                    0,
                                    proxy.frame(in: .scrollView(axis: .vertical)).minY
                                        - pinnedChromeRestingTop
                                )
                                : 0
                        )
                    }
                }
            }
            .frame(width: width, height: height)
            .clipShape(cardShape)
            .overlay {
                cardShape
                    .strokeBorder(
                        .white.opacity(borderOpacity),
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: .black.opacity(0.07 * shadowOpacity),
                radius: 16,
                x: 0,
                y: 3
            )
        }
        // A scroll drag begins as a press. Scaling the full card here made
        // its title spring on release just as the feed snap completed.
        .buttonStyle(.plain)
        .accessibilityLabel("\(titleOverride ?? story.title). \(story.subtitle)")
        .accessibilityHint(story.destinationLabel)
    }

    private var standardForeground: some View {
        ZStack {
            if productLayout == .compactGrid {
                compactGridComposition
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            } else {
                scrollAwareStoryHeader
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: titleAtTopLeading ? .topLeading : .bottomLeading
                    )
            }
            if showsFooterArrow {
                footerArrow
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            if productLayout == .stackedDeck {
                productCarousel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            if productLayout == .bottomCarousel {
                bottomProductCarousel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
    }

    private var worldCardForeground: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            Spacer(minLength: 80)
            storyHeader
            worldCardProducts
        }
        .frame(
            width: max(width - (GravitySpacing.space20 * 2), 0),
            alignment: .leading
        )
    }

    @ViewBuilder
    private var worldCardProducts: some View {
        switch productLayout {
        case .compactGrid:
            compactProductGrid
        case .stackedDeck:
            productCarousel
        case .bottomCarousel:
            bottomProductCarousel
        case nil:
            EmptyView()
        }
    }

    // MARK: - Atmosphere

    private var atmosphericBackground: some View {
        ZStack {
            Color(hex: story.accentHex)

            if story.id == WorldPrototypeCatalog.canvasID {
                CanvasAgentFeedCover(
                    products: CanvasAgentProductAdapter.products(from: items)
                )
            } else if let authoredCoverVideoURL {
                parallaxFilm {
                    AmbientProductVideo(
                        videoURLs: [authoredCoverVideoURL],
                        posterImageURL: authoredCoverURL?.absoluteString,
                        playbackEnabled: backgroundPlaybackEnabled && isActive,
                        playbackGroupID: "story-cover-\(story.id)"
                    )
                }
            } else if let authoredCover, let authoredCoverAssetName {
                Color.clear
                    .overlay {
                        Image(authoredCoverAssetName)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(authoredCover.scale)
                            .offset(y: authoredCover.yOffset)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: authoredCover.alignment
                            )
                    }
                    .clipped()
            } else if let authoredCover, let authoredCoverURL {
                Color.clear
                    .overlay {
                        CachedAsyncImage(url: authoredCoverURL) { phase in
                            if case .success(let image) = phase {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .scaleEffect(authoredCover.scale)
                                    .offset(y: authoredCover.yOffset)
                                    .frame(
                                        maxWidth: .infinity,
                                        maxHeight: .infinity,
                                        alignment: authoredCover.alignment
                                    )
                            } else {
                                loadingBackdrop
                            }
                        }
                    }
                    .clipped()
            } else if let heroLifestyleImageURL {
                Color.clear
                    .overlay {
                        CachedAsyncImage(url: heroLifestyleImageURL) { phase in
                            if case .success(let image) = phase {
                                image
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                loadingBackdrop
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
                    }
                    .clipped()
            } else if !items.isEmpty, leadFilmURL != nil {
                parallaxFilm {
                    AmbientProductVideo(
                        videoURLs: ambientFilmURLs,
                        // A PDP thumbnail is not a valid lifestyle poster.
                        // The tonal card surface remains visible while the
                        // approved ambient film prepares its first frame.
                        posterImageURL: nil,
                        playbackEnabled: backgroundPlaybackEnabled && isActive,
                        playbackGroupID: "story-card-\(story.id)"
                    )
                }
            } else {
                Image(fallbackEditorialCoverImageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipped()
    }

    /// Remote lifestyle media can take a beat on a cold launch. Keep the
    /// card atmospheric and product-specific while it resolves instead of
    /// exposing a flat black surface for dark stories.
    @ViewBuilder
    private var loadingBackdrop: some View {
        Image(fallbackEditorialCoverImageName)
            .resizable()
            .scaledToFill()
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
        let bottomOpacity = max(authoredCover?.textScrimOpacity ?? 0.34, 0.46)

        return LinearGradient(
            stops: [
                .init(color: .black.opacity(topScrimOpacity), location: 0),
                .init(color: .black.opacity(topScrimOpacity * 0.62), location: 0.14),
                .init(color: .black.opacity(topScrimOpacity * 0.18), location: 0.30),
                .init(color: .clear, location: 0.42),
                .init(color: .clear, location: 0.62),
                .init(color: .black.opacity(bottomOpacity * 0.22), location: 0.78),
                .init(color: .black.opacity(bottomOpacity), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Header

    private var storyHeader: some View {
        Text(titleOverride ?? story.title)
            .feedCardTitleStyle()
            .foregroundStyle(.white)
            .gravityShadow(GravityShadows.feedText)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .padding(.trailing, titleTrailingPadding)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
    }

    private var scrollAwareStoryHeader: some View {
        storyHeader
            .visualEffect { title, proxy in
                title.offset(
                    y: max(
                        0,
                        (scrollPinnedTitleTop
                            ?? proxy.frame(in: .scrollView(axis: .vertical)).minY)
                            - proxy.frame(in: .scrollView(axis: .vertical)).minY
                    )
                )
            }
    }

    // MARK: - Stable formats

    @ViewBuilder
    private var storyContent: some View {
        switch story.format {
        case .world:
            StoryWorldLayout(items: items)
        case .shortlist:
            StoryShortlistLayout(items: items)
        case .setup:
            StorySetupLayout(items: items)
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

        return ScrollView(.horizontal, showsIndicators: false) {
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
        .frame(height: tileWidth)
    }

    /// Dense assortment treatment: the title stays fixed at the top while the
    /// products and edit footer form one anchored block at the bottom.
    private var compactGridComposition: some View {
        VStack(alignment: .leading, spacing: 0) {
            scrollAwareStoryHeader

            Spacer(minLength: 18)

            compactProductGrid
        }
    }

    private var compactProductGrid: some View {
        let count = compactGridItemCount
        let columns = count == 4 ? 2 : 3

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns),
            spacing: 8
        ) {
            ForEach(Array(productAssortment.prefix(count))) { item in
                compactProductTile(item)
            }
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

    private var productCarousel: some View {
        GeometryReader { geometry in
            if !items.isEmpty {
                let safeIndex = min(selectedProductIndex, items.count - 1)
                let item = items[safeIndex]
                let nextItem = deckItem(from: safeIndex, offset: productDeckDirection)
                let farItem = deckItem(from: safeIndex, offset: productDeckDirection * 2)

                ZStack(alignment: .leading) {
                    productSummaryCard(
                        farItem,
                        surfaceTone: -0.16 + (0.08 * productPromotionProgress)
                    )
                        .frame(width: geometry.size.width - 16)
                        .scaleEffect(0.92 + 0.04 * productPromotionProgress, anchor: .leading)
                        .offset(x: 36 - 18 * productPromotionProgress)
                        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)

                    productSummaryCard(
                        nextItem,
                        surfaceTone: -0.08 + (0.24 * productPromotionProgress)
                    )
                        .frame(width: geometry.size.width - 16)
                        .scaleEffect(0.96 + 0.04 * productPromotionProgress, anchor: .leading)
                        .offset(x: 18 * (1 - productPromotionProgress))
                        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)

                    productSummaryCard(item, surfaceTone: 0.16)
                        .frame(width: geometry.size.width - 16)
                        .offset(x: productDragOffset)
                        .shadow(color: .black.opacity(0.16), radius: 7, y: 3)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(productDeckGesture(width: geometry.size.width))
            }
        }
        .frame(height: 88)
    }

    private func productSummaryCard(
        _ item: ResolvedStoryProduct,
        surfaceTone: Double = 0
    ) -> some View {
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

            ProductFavoriteIcon(color: .white)
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(productStackColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            (surfaceTone >= 0 ? Color.white : Color.black)
                                .opacity(abs(surfaceTone))
                        )
                }
        }
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
