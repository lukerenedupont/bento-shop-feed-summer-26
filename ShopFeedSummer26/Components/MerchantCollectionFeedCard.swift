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
        return Array(result.prefix(presentation.productCount))
    }

    private var coverURL: URL? {
        presentation.coverURL(from: merchants)
    }

    private var columnCount: Int {
        products.count > 4 ? 3 : 2
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

                VStack(alignment: .leading, spacing: 0) {
                    merchantHeader

                    Text(story.title)
                        .feedCardTitleStyle()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .padding(.top, GravitySpacing.space16)

                    Spacer(minLength: 24)

                    productGrid
                        .padding(.bottom, FeedCardStyle.productFooterSpacing)

                    collectionFooter
                }
                .padding(.horizontal, FeedCardStyle.foregroundHorizontalPadding)
                .padding(.top, foregroundTopPadding)
                .padding(.bottom, FeedCardStyle.foregroundBottomPadding)
                .opacity(isActive ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isActive)
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
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(brandMerchant?.displayName ?? "Merchant") collection")
        .accessibilityHint("Shop all")
    }

    @ViewBuilder
    private var collectionCover: some View {
        if !presentation.usesImageCover {
            quietMerchantSurface
        } else if let coverURL {
            CachedAsyncImage(url: coverURL) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                        .offset(y: presentation.coverYOffset)
                } else {
                    editorialFallbackCover
                }
            }
            .frame(width: width, height: height)
            .clipped()
        } else if let brandMerchant {
            MerchantCoverImage(merchant: brandMerchant)
                .frame(width: width, height: height)
                .clipped()
        } else {
            Color(hex: story.accentHex)
        }
    }

    /// A deliberately non-photographic fallback for catalog-only merchants.
    /// It prevents packaging, promotional banners, and embedded product copy
    /// from becoming oversized background typography behind the card UI.
    private var quietMerchantSurface: some View {
        ZStack {
            editorialFallbackCover

            Color(hex: story.accentHex)
                .opacity(0.24)

            LinearGradient(
                colors: [
                    (brandMerchant?.brandColor ?? Color(hex: story.accentHex)).opacity(0.88),
                    .black.opacity(0.42),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var editorialFallbackCover: some View {
        Image(FeedCoverCatalog.fallbackImageName(for: story))
            .resizable()
            .scaledToFill()
    }

    private var contrastScrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.38), location: 0),
                .init(color: .clear, location: 0.28),
                .init(color: .clear, location: 0.48),
                .init(color: .black.opacity(0.36), location: 0.72),
                .init(color: .black.opacity(0.58), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var merchantHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            if let brandMerchant {
                VStack(alignment: .leading, spacing: 5) {
                    if MerchantBrandAssets.hasVerifiedBundledWordmark(for: brandMerchant.id) {
                        MerchantWordmarkImage(
                            merchant: brandMerchant,
                            maxHeight: 42,
                            maxWidth: 174,
                            bundledAssetName: MerchantBrandAssets.wordmarkName(for: brandMerchant.id)
                        )
                    } else {
                        Text(brandMerchant.displayName)
                            .font(.system(size: 28, weight: .semibold))
                            .tracking(-0.7)
                            .foregroundStyle(.white)
                            .lineLimit(1)
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
                    }
                }
            }

            Spacer(minLength: 12)

            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.18), in: Circle())
        }
    }

    private var productGrid: some View {
        let spacing: CGFloat = 8
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: spacing),
            count: columnCount
        )

        return LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(products) { product in
                ProductCard(
                    image: nil,
                    imageURL: product.imageURL,
                    priceBadge: formatPrice(product.price),
                    showFavoriteButton: true
                )
                .allowsHitTesting(false)
            }
        }
    }

    private var collectionFooter: some View {
        HStack(spacing: 8) {
            Text("\(products.count) products")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("Shop all")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
