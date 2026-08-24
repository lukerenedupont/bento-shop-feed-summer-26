import SwiftUI

/// Full-height merchant collection card based on the native Shop collection
/// treatment: lifestyle media, quiet merchant identity, dense square product
/// tiles, and one clear collection action.
struct MerchantCollectionFeedCard: View {
    let story: FeedStory
    let presentation: MerchantCollectionPresentation
    let merchants: [SampleMerchant]
    let width: CGFloat
    let height: CGFloat
    var isActive = true
    var cornerRadius: CGFloat = GravityRadius.r28
    var bottomCornerRadius: CGFloat? = nil
    var foregroundTopPadding: CGFloat = GravitySpacing.space20
    var scrollPinnedHeaderTop: CGFloat? = nil
    var borderOpacity: Double = 0.12
    var shadowOpacity: Double = 1

    @Environment(NavigationCoordinator.self) private var coordinator

    private var merchant: SampleMerchant? {
        merchants.first { $0.id == presentation.merchantID }
    }

    private var brandMerchant: SampleMerchant? {
        guard let brandMerchantID = presentation.brandMerchantID else { return merchant }
        return merchants.first { $0.id == brandMerchantID } ?? merchant
    }

    private var products: [SampleMerchant.Product] {
        guard let merchant else { return [] }
        var seen = Set<Int>()
        var result: [SampleMerchant.Product] = []

        for reference in story.products where reference.merchantID == merchant.id {
            guard let product = merchant.products.first(where: { $0.id == reference.productID }),
                  seen.insert(product.id).inserted else { continue }
            result.append(product)
        }
        for product in merchant.products where seen.insert(product.id).inserted {
            result.append(product)
        }
        // Every merchant collection uses the same compact three-up rail.
        // This keeps the lifestyle image dominant and the cards aligned.
        return Array(result.prefix(3))
    }

    private var coverURL: URL? {
        presentation.coverURL(from: merchants)
    }

    private var cardShape: UnevenRoundedRectangle {
        let bottomRadius = bottomCornerRadius ?? cornerRadius
        return UnevenRoundedRectangle(
            topLeadingRadius: cornerRadius,
            bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius,
            topTrailingRadius: cornerRadius,
            style: .continuous
        )
    }

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.homePath.append(
                HomeRoute.store(merchantId: presentation.brandMerchantID ?? presentation.merchantID)
            )
        } label: {
            ZStack {
                collectionCover
                contrastScrim

                collectionContent
            }
            .frame(width: width, height: height)
            .clipShape(cardShape)
            .overlay {
                cardShape
                    .strokeBorder(.white.opacity(borderOpacity), lineWidth: 0.5)
            }
            .shadow(
                color: .black.opacity(0.12 * shadowOpacity),
                radius: 24,
                y: 4
            )
        }
        // Keep vertical paging spatially stable; a drag should not trigger a
        // competing press spring on the card and merchant wordmark.
        .buttonStyle(.plain)
        .accessibilityLabel("\(brandMerchant?.displayName ?? "Merchant") collection")
        .accessibilityHint("Shop all")
    }

    @ViewBuilder
    private var collectionCover: some View {
        if let coverURL {
            CachedAsyncImage(url: coverURL) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                        .offset(y: presentation.coverYOffset)
                } else {
                    brandMerchant?.brandColor ?? Color(hex: story.accentHex)
                }
            }
            .frame(width: width, height: height)
            .clipped()
        } else {
            brandMerchant?.brandColor ?? Color(hex: story.accentHex)
        }
    }

    private var contrastScrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.42), location: 0),
                .init(color: .black.opacity(0.26), location: 0.14),
                .init(color: .black.opacity(0.08), location: 0.30),
                .init(color: .clear, location: 0.42),
                .init(color: .clear, location: 0.62),
                .init(color: .black.opacity(0.13), location: 0.78),
                .init(color: .black.opacity(0.58), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Merchant cards receive several different heights while the feed moves
    /// between its launch and takeover states. Budgeting the available height
    /// here keeps the identity and action anchored while product imagery stays
    /// intentionally compact instead of determining the card's intrinsic size.
    private var collectionContent: some View {
        let horizontalPadding = FeedCardStyle.foregroundHorizontalPadding
        let availableWidth = max(0, width - (horizontalPadding * 2))
        let availableHeight = max(
            0,
            height
                - foregroundTopPadding
                - FeedCardStyle.foregroundBottomPadding
        )
        let grid = productGridMetrics(
            availableWidth: availableWidth,
            availableHeight: availableHeight
        )

        return VStack(alignment: .leading, spacing: 0) {
            merchantHeader(availableWidth: availableWidth)
                .frame(height: 62, alignment: .top)
                .visualEffect { header, proxy in
                    header.offset(
                        y: max(
                            0,
                            (scrollPinnedHeaderTop
                                ?? proxy.frame(in: .scrollView(axis: .vertical)).minY)
                                - proxy.frame(in: .scrollView(axis: .vertical)).minY
                        )
                    )
                }

            Spacer(minLength: GravitySpacing.space16)

            productGrid(metrics: grid)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(width: availableWidth, height: availableHeight, alignment: .top)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, foregroundTopPadding)
        .padding(.bottom, FeedCardStyle.foregroundBottomPadding)
        .frame(width: width, height: height, alignment: .topLeading)
        .clipped()
    }

    private func merchantHeader(availableWidth: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let brandMerchant {
                VStack(alignment: .leading, spacing: 5) {
                    if MerchantBrandAssets.hasVerifiedBundledWordmark(for: brandMerchant.id) {
                        MerchantWordmarkImage(
                            merchant: brandMerchant,
                            maxHeight: 42,
                            maxWidth: max(0, min(174, availableWidth - 56)),
                            bundledAssetName: MerchantBrandAssets.wordmarkName(for: brandMerchant.id)
                        )
                        .gravityShadow(GravityShadows.feedText)
                    }

                    if brandMerchant.totalRatings > 0 {
                        HStack(spacing: 3) {
                            Text(String(format: "%.1f", brandMerchant.rating))
                            Image(systemName: "star.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("(\(brandMerchant.totalRatings))")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .gravityShadow(GravityShadows.feedText)
                    }
                }
                .frame(maxWidth: max(0, availableWidth - 44), alignment: .leading)
                .clipped()
            }

            Spacer(minLength: 12)

            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.18), in: Circle())
        }
        .frame(width: availableWidth, alignment: .leading)
    }

    private struct ProductGridMetrics {
        let columns: Int
        let rows: Int
        let spacing: CGFloat
        let tileSize: CGFloat

        var height: CGFloat {
            (CGFloat(rows) * tileSize) + (CGFloat(max(0, rows - 1)) * spacing)
        }
    }

    private func productGridMetrics(
        availableWidth: CGFloat,
        availableHeight: CGFloat
    ) -> ProductGridMetrics {
        let columns: Int
        switch products.count {
        case 0, 1:
            columns = 1
        case 2:
            columns = 2
        case 3:
            columns = 3
        case 4:
            columns = 2
        default:
            columns = 3
        }
        let rows = max(1, Int(ceil(Double(products.count) / Double(columns))))
        let spacing = GravitySpacing.space8
        let fixedContentHeight: CGFloat = 62 + GravitySpacing.space16
        let gridHeight = max(0, availableHeight - fixedContentHeight)
        let widthBound = (
            availableWidth - (CGFloat(columns - 1) * spacing)
        ) / CGFloat(columns)
        let heightBound = (
            gridHeight - (CGFloat(rows - 1) * spacing)
        ) / CGFloat(rows)
        let tileSize = max(0, min(widthBound, heightBound))

        return ProductGridMetrics(
            columns: columns,
            rows: rows,
            spacing: spacing,
            tileSize: tileSize
        )
    }

    private func productGrid(metrics: ProductGridMetrics) -> some View {
        let columns = Array(
            repeating: GridItem(.fixed(metrics.tileSize), spacing: metrics.spacing),
            count: metrics.columns
        )

        return LazyVGrid(columns: columns, spacing: metrics.spacing) {
            ForEach(products) { product in
                compactProductTile(product, size: metrics.tileSize)
            }
        }
        .frame(height: metrics.height)
    }

    private func compactProductTile(
        _ product: SampleMerchant.Product,
        size: CGFloat
    ) -> some View {
        Color.white
            .overlay {
                if let source = product.imageURL,
                   let url = URL(string: source) {
                    CachedAsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            GravityColors.bgFillSecondary
                        }
                    }
                } else {
                    GravityColors.bgFillSecondary
                }
            }
            .overlay { Color.black.opacity(0.04) }
            .overlay(alignment: .topLeading) {
                Text(formatPrice(product.price))
                    .gravityTextStyle(GravityTypography.badgeBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, GravitySpacing.space6)
                    .padding(.vertical, GravitySpacing.space2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .environment(\.colorScheme, .dark)
                    .padding(GravitySpacing.space8)
            }
            .overlay(alignment: .bottomTrailing) {
                ProductFavoriteIcon()
                    .padding(GravitySpacing.space8)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            }
            .gravityShadow(GravityShadows.small)
    }

}
