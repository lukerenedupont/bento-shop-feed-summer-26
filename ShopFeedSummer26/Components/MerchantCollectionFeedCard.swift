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

    @Environment(NavigationCoordinator.self) private var coordinator

    private var merchant: SampleMerchant? {
        merchants.first { $0.id == presentation.merchantID }
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

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.homePath.append(HomeRoute.store(merchantId: presentation.merchantID))
        } label: {
            ZStack {
                collectionCover
                contrastScrim

                VStack(alignment: .leading, spacing: 0) {
                    merchantHeader

                    Spacer(minLength: 24)

                    productGrid
                        .padding(.bottom, 14)

                    collectionFooter
                }
                .padding(20)
                .opacity(isActive ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isActive)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            }
            .gravityShadow(GravityShadows.medium)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(merchant?.displayName ?? "Merchant") collection")
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
                } else if let merchant {
                    merchant.brandColor
                } else {
                    Color(hex: story.accentHex)
                }
            }
            .frame(width: width, height: height)
            .clipped()
        } else if let merchant {
            MerchantCoverImage(merchant: merchant)
                .frame(width: width, height: height)
                .clipped()
        } else {
            Color(hex: story.accentHex)
        }
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
            if let merchant {
                VStack(alignment: .leading, spacing: 5) {
                    if MerchantBrandAssets.hasVerifiedBundledWordmark(for: merchant.id) {
                        MerchantWordmarkImage(
                            merchant: merchant,
                            maxHeight: 42,
                            maxWidth: 174,
                            bundledAssetName: MerchantBrandAssets.wordmarkName(for: merchant.id)
                        )
                    } else {
                        Text(merchant.displayName)
                            .font(.system(size: 28, weight: .semibold))
                            .tracking(-0.7)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    if merchant.totalRatings > 0 {
                        HStack(spacing: 3) {
                            Text(String(format: "%.1f", merchant.rating))
                            Image(systemName: "star.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("(\(merchant.totalRatings))")
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
