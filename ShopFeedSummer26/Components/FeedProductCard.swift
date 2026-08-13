import SwiftUI

// MARK: - Feed Card Layout

enum FeedCardLayout: CaseIterable {
    case grid      // 2x2 product grid over hero image
    case single    // Hero bg + floating product info card
    case hScroll   // Hero bg + horizontal product rail
}

// MARK: - Feed Product Card

/// Merchant-focused feed card with multiple layout variants.
///
/// Matches the SuperFeed card system: full-bleed hero background,
/// merchant branding at top (wordmark or avatar+name+rating),
/// layout-specific product content using `ProductCard`, and "Shop all" CTA footer.
struct FeedProductCard: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let merchant: SampleMerchant
    let layout: FeedCardLayout
    let width: CGFloat
    let height: CGFloat
    let heroNamespace: Namespace.ID

    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.homePath.append(HomeRoute.store(merchantId: merchant.id))
        } label: {
            ZStack {
                heroBackground
                gradientScrims

                VStack(spacing: 0) {
                    cardHeader

                    if layout == .grid {
                        // Grid: vertically centered content
                        Spacer(minLength: GravitySpacing.space8)
                        cardContent
                        Spacer(minLength: GravitySpacing.space8)
                    } else {
                        Spacer(minLength: GravitySpacing.space8)
                        cardContent
                    }

                    cardFooter
                        .padding(.top, PurlTune.token("Components/FeedProductCard.swift:padding:_:50:40", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
                }
                .padding(PurlTune.token("Components/FeedProductCard.swift:padding:_:52:26", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                    .strokeBorder(Color.white.opacity(PurlTune.value("Components/FeedProductCard.swift:opacity:_:58:55", default: 0.08)), lineWidth: 0.5)
            )
            .gravityShadow(GravityShadows.medium)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: - Hero Background

    @ViewBuilder
    private var heroBackground: some View {
        switch layout {
        case .hScroll:
            // Video card — always has video
            if let url = merchant.bestVideoURL {
                LoopingVideoPlayer(url: url)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                // Shouldn't happen (hScroll only assigned to video merchants)
                // but fallback gracefully
                MerchantImage(merchant: merchant, index: 0)
                    .frame(width: width, height: height)
                    .clipped()
            }

        case .grid:
            // Cover image as background texture with brand color gradient overlay
            ZStack {
                // Cover/header image as subtle texture
                MerchantCoverImage(merchant: merchant)
                    .frame(width: width, height: height)
                    .clipped()

                // Brand color gradient: 60% → 100% opacity over the image
                LinearGradient(
                    stops: [
                        .init(color: merchant.brandColor.opacity(PurlTune.value("Components/FeedProductCard.swift:opacity:_:95:66", default: 0.6)), location: 0),
                        .init(color: merchant.brandColor, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

        case .single:
            // Featured image hero
            Color.clear
                .frame(width: width, height: height)
                .background {
                    MerchantImage(merchant: merchant, index: 0)
                        .frame(width: width, height: height)
                        .clipped()
                }
        }
    }

    // MARK: - Gradient Scrims

    private var gradientScrims: some View {
        Group {
            switch layout {
            case .grid:
                // Grid card uses brand color overlay, no additional scrim needed
                EmptyView()

            case .single, .hScroll:
                VStack(spacing: 0) {
                    // Top scrim
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(PurlTune.value("Components/FeedProductCard.swift:opacity:_:130:57", default: 0.24)), location: 0.8),
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: PurlTune.value("Components/FeedProductCard.swift:frame:height:135:36", default: 100))

                    Spacer()

                    // Bottom scrim
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(PurlTune.value("Components/FeedProductCard.swift:opacity:_:143:57", default: 0.32)), location: 0.8),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: height * 0.5)
                }
            }
        }
    }

    // MARK: - Card Header

    private var cardHeader: some View {
        HStack(alignment: .top, spacing: GravitySpacing.space8) {
            merchantBranding
                .frame(maxWidth: .infinity, alignment: .leading)
            headerActions
        }
    }

    @ViewBuilder
    private var merchantBranding: some View {
        if merchant.bestWordmarkURL != nil {
            MerchantWordmarkImage(merchant: merchant, maxHeight: 36, maxWidth: 150)
        } else {
            HStack(spacing: GravitySpacing.space8) {
                MerchantAvatarView(merchant: merchant, size: 32)

                VStack(alignment: .leading, spacing: 0) {
                    Text(merchant.name)
                        .gravityTextStyle(GravityTypography.bodyTitleSmall)
                        .foregroundStyle(.white)

                    if merchant.totalRatings > 0 {
                        HStack(spacing: 2) {
                            Text(String(format: "%.1f", merchant.rating))
                                .gravityTextStyle(GravityTypography.caption)
                                .foregroundStyle(.white.opacity(PurlTune.value("Components/FeedProductCard.swift:opacity:_:180:61", default: 0.7)))
                            GravityIcon.starFilled.image
                                .resizable()
                                .scaledToFit()
                                .frame(width: PurlTune.value("Components/FeedProductCard.swift:frame:width:184:43", default: 10), height: PurlTune.value("Components/FeedProductCard.swift:frame:height:184:135", default: 10))
                                .foregroundStyle(Color(hex: 0xFFB800))
                            Text("(\(merchant.totalRatings))")
                                .gravityTextStyle(GravityTypography.caption)
                                .foregroundStyle(.white.opacity(PurlTune.value("Components/FeedProductCard.swift:opacity:_:188:61", default: 0.7)))
                        }
                    }
                }
            }
        }
    }

    // Header actions: overflow icon (+ volume icon column, matching Figma)
    private var headerActions: some View {
        VStack(spacing: GravitySpacing.space16) {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: PurlTune.value("Components/FeedProductCard.swift:frame:width:201:31", default: 20), height: PurlTune.value("Components/FeedProductCard.swift:frame:height:201:123", default: 20))
        }
        .padding(.trailing, PurlTune.token("Components/FeedProductCard.swift:padding:_:203:29", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
    }

    // MARK: - Content

    @ViewBuilder
    private var cardContent: some View {
        if merchant.products.isEmpty {
            Spacer()
        } else {
            switch layout {
            case .grid:
                productGrid
            case .single:
                listProductCard
            case .hScroll:
                productRail
            }
        }
    }

    // MARK: - 2x2 Product Grid

    private var productGrid: some View {
        let products = Array(merchant.products.prefix(4))
        let spacing: CGFloat = GravitySpacing.space8
        let tileSize = (width - GravitySpacing.space16 * 2 - spacing) / 2

        return VStack(spacing: spacing) {
            if products.count >= 2 {
                HStack(spacing: spacing) {
                    feedProductCard(product: products[0], index: 0, size: tileSize)
                    feedProductCard(product: products[1], index: 1, size: tileSize)
                }
            }
            if products.count >= 4 {
                HStack(spacing: spacing) {
                    feedProductCard(product: products[2], index: 2, size: tileSize)
                    feedProductCard(product: products[3], index: 3, size: tileSize)
                }
            } else if products.count == 3 {
                HStack(spacing: spacing) {
                    feedProductCard(product: products[2], index: 2, size: tileSize)
                    Color.clear.frame(width: tileSize, height: tileSize)
                }
            }
        }
    }

    // MARK: - List Product Card (Single variant — Figma ListProductCard)

    @ViewBuilder
    private var listProductCard: some View {
        if let product = merchant.products.first {
            // Glass card navigates to PDP (not store)
            NavigationLink(value: HomeRoute.product(merchantId: merchant.id, productId: product.id)) {
                HStack(spacing: GravitySpacing.space8) {
                    // Product thumbnail using ProductCard in compact mode
                    ProductCard(
                        image: nil,
                        imageURL: product.imageURL,
                        showFavoriteButton: true
                    )
                    .frame(width: PurlTune.value("Components/FeedProductCard.swift:frame:width:266:35", default: 80))

                    // Meta info
                    VStack(alignment: .leading, spacing: 0) {
                        Text(product.title)
                            .gravityTextStyle(GravityTypography.captionBold)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if merchant.totalRatings > 0 {
                            HStack(spacing: GravitySpacing.space4) {
                                HStack(spacing: 2) {
                                    ForEach(0..<5) { i in
                                        GravityIcon.starFilled.image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: PurlTune.value("Components/FeedProductCard.swift:frame:width:282:55", default: 12), height: PurlTune.value("Components/FeedProductCard.swift:frame:height:282:147", default: 12))
                                            .foregroundStyle(
                                                Double(i) < merchant.rating
                                                    ? Color(hex: 0xFFB800)
                                                    : .white.opacity(PurlTune.value("Components/FeedProductCard.swift:opacity:_:286:66", default: 0.3))
                                            )
                                    }
                                }
                                Text("(\(merchant.totalRatings))")
                                    .gravityTextStyle(GravityTypography.caption)
                                    .foregroundStyle(.white.opacity(PurlTune.value("Components/FeedProductCard.swift:opacity:_:292:65", default: 0.7)))
                            }
                        }

                        Text(formatPrice(product.price))
                            .gravityTextStyle(GravityTypography.captionBold)
                            .foregroundStyle(.white)
                    }
                    .padding(.vertical, PurlTune.token("Components/FeedProductCard.swift:padding:_:299:41", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))

                    Spacer()
                }
                .padding(.leading, PurlTune.token("Components/FeedProductCard.swift:padding:_:303:36", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
                .padding(.trailing, PurlTune.token("Components/FeedProductCard.swift:padding:_:304:37", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
                .padding(.vertical, PurlTune.token("Components/FeedProductCard.swift:padding:_:305:37", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
                .glassEffect(.regular, in: .rect(cornerRadius: GravityRadius.r28))
                .matchedTransitionSource(id: product.id, in: heroNamespace)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Horizontal Product Rail

    private var productRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GravitySpacing.space8) {
                ForEach(Array(merchant.products.prefix(6).enumerated()), id: \.element.id) { index, product in
                    feedProductCard(product: product, index: index, size: 140)
                }
            }
            .padding(.horizontal, PurlTune.token("Components/FeedProductCard.swift:padding:_:322:35", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
            .padding(.vertical, PurlTune.token("Components/FeedProductCard.swift:padding:_:323:33", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
        }
        .scrollClipDisabled()
        .padding(.horizontal, -GravitySpacing.space16)
        .padding(.vertical, -GravitySpacing.space8)
    }

    // MARK: - Feed Product Card Tile (uses ProductCard with price badge)

    private func feedProductCard(product: SampleMerchant.Product, index: Int, size: CGFloat) -> some View {
        NavigationLink(value: HomeRoute.product(merchantId: merchant.id, productId: product.id)) {
            ProductCard(
                image: nil,
                imageURL: product.imageURL,
                priceBadge: formatPrice(product.price),
                showFavoriteButton: true
            )
            .frame(width: size)
            .shadow(color: .black.opacity(PurlTune.value("Components/FeedProductCard.swift:opacity:_:341:43", default: 0.28)), radius: PurlTune.value("Components/FeedProductCard.swift:shadow:radius:341:136", default: 20), x: PurlTune.value("Components/FeedProductCard.swift:shadow:x:341:226", default: 0), y: PurlTune.value("Components/FeedProductCard.swift:shadow:y:341:310", default: 8))
            .matchedTransitionSource(id: product.id, in: heroNamespace)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer (Figma FeedCard/Footer)

    private var cardFooter: some View {
        HStack {
            Text("Shop all")
                .gravityTextStyle(GravityTypography.headerBold)
                .foregroundStyle(.white)

            Spacer()

            // Arrow button: 32x32, semi-transparent bg
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: PurlTune.value("Components/FeedProductCard.swift:frame:width:361:31", default: 32), height: PurlTune.value("Components/FeedProductCard.swift:frame:height:361:123", default: 32))
                .background(.white.opacity(PurlTune.value("Components/FeedProductCard.swift:opacity:_:362:44", default: 0.1)), in: Circle())
        }
    }

}

#Preview("Grid layout") {
    @Previewable @Namespace var ns
    ScrollView {
        FeedProductCard(
            merchant: .preview,
            layout: .grid,
            width: 360,
            height: 480,
            heroNamespace: ns
        )
        .padding()
    }
    .background(PurlTune.token("Components/FeedProductCard.swift:background:_:380:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
    .environment(NavigationCoordinator())
}

#Preview("Single layout") {
    @Previewable @Namespace var ns
    ScrollView {
        FeedProductCard(
            merchant: .preview,
            layout: .single,
            width: 360,
            height: 480,
            heroNamespace: ns
        )
        .padding()
    }
    .background(PurlTune.token("Components/FeedProductCard.swift:background:_:396:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
    .environment(NavigationCoordinator())
}

#Preview("Video rail layout") {
    @Previewable @Namespace var ns
    ScrollView {
        FeedProductCard(
            merchant: .previewWithVideo,
            layout: .hScroll,
            width: 360,
            height: 480,
            heroNamespace: ns
        )
        .padding()
    }
    .background(PurlTune.token("Components/FeedProductCard.swift:background:_:412:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
    .environment(NavigationCoordinator())
}
