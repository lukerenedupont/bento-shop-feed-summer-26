import SwiftUI

/// The shared favorite affordance for product media. It intentionally mirrors
/// the outline-only heart used by the feed's product pile and has no visible
/// control background; the larger frame remains as an invisible tap target.
struct ProductFavoriteIcon: View {
    var color: Color = GravityColors.text
    var addsContrastShadow = false

    var body: some View {
        Image(systemName: "heart")
            .font(.system(size: 24, weight: .medium))
            .foregroundStyle(color)
            .shadow(
                color: addsContrastShadow ? .black.opacity(0.28) : .clear,
                radius: addsContrastShadow ? 2 : 0,
                y: 1
            )
            .frame(width: 38, height: 38)
    }
}

struct ProductFavoriteButton: View {
    var color: Color = GravityColors.text
    var addsContrastShadow = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            onTap?()
        } label: {
            ProductFavoriteIcon(
                color: color,
                addsContrastShadow: addsContrastShadow
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A flexible product card with square image, optional metadata, and optional favorites button.
///
/// Adapts to any width — the image is always square, and metadata stacks below when provided.
/// Matches the Figma "ProductCard" component with full and compact variants.
///
/// Usage:
/// ```swift
/// // Compact — image only
/// ProductCard(image: someImage)
///
/// // Full — with all metadata
/// ProductCard(
///     image: someImage,
///     merchantName: "Merchant Name",
///     productName: "Product Name",
///     rating: 4.5,
///     ratingCount: 38,
///     price: "$50.00"
/// )
/// ```
struct ProductCard: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    enum Style { case grid, list }

    // MARK: - Required

    let image: Image?

    // MARK: - Optional metadata

    var imageURL: String? = nil
    var merchantName: String? = nil
    var productName: String? = nil
    var rating: Double? = nil
    var ratingCount: Int? = nil
    var price: String? = nil
    var originalPrice: String? = nil
    var priceBadge: String? = nil
    var showFavoriteButton: Bool = true
    var favoriteIconHasContrastShadow = false
    var isFavorite: Bool = false
    var onFavoriteTap: (() -> Void)? = nil
    var style: Style = .grid
    var merchantLogoImage: Image? = nil
    var merchantLogoURL: String? = nil

    // MARK: - Private

    private var hasMetadata: Bool {
        merchantName != nil || productName != nil || rating != nil || price != nil
    }

    // MARK: - Body

    var body: some View {
        switch style {
        case .grid:
            gridLayout
        case .list:
            listLayout
        }
    }

    private var gridLayout: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            imageSection
            if hasMetadata {
                metadataSection
            }
        }
    }

    // MARK: - List Layout

    private var listLayout: some View {
        HStack(spacing: GravitySpacing.space8) {
            // Left: square image
            listImageSection

            // Right: product info — top-aligned name/rating/price, bottom-aligned merchant
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    if let productName {
                        Text(productName)
                            .gravityTextStyle(GravityTypography.captionBold)
                            .foregroundStyle(PurlTune.token("Components/ProductCard.swift:foregroundStyle:_:86:46", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                            .lineLimit(2)
                    }
                    if let rating, let ratingCount {
                        ratingRow(rating: rating, count: ratingCount)
                    }
                    if let price {
                        HStack(spacing: GravitySpacing.space4) {
                            Text(price)
                                .gravityTextStyle(GravityTypography.captionMedium)
                                .foregroundStyle(PurlTune.token("Components/ProductCard.swift:foregroundStyle:_:96:50", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                            if let originalPrice {
                                Text(originalPrice)
                                    .gravityTextStyle(GravityTypography.caption)
                                    .foregroundStyle(PurlTune.token("Components/ProductCard.swift:foregroundStyle:_:100:54", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                                    .strikethrough()
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                // Bottom merchant row
                if let merchantName {
                    HStack(spacing: 4) {
                        if let merchantLogoImage {
                            merchantLogoImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: PurlTune.value("Components/ProductCard.swift:frame:width:116:47", default: 20), height: PurlTune.value("Components/ProductCard.swift:frame:height:116:135", default: 20))
                                .clipShape(Circle())
                        } else if let merchantLogoURL, let url = URL(string: merchantLogoURL) {
                            CachedAsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                default:
                                    Color.gray.opacity(PurlTune.value("Components/ProductCard.swift:opacity:_:124:56", default: 0.2))
                                }
                            }
                            .frame(width: PurlTune.value("Components/ProductCard.swift:frame:width:127:43", default: 20), height: PurlTune.value("Components/ProductCard.swift:frame:height:127:131", default: 20))
                            .clipShape(Circle())
                        }
                        Text(merchantName)
                            .font(.custom("GTStandard-MMedium", size: 10))
                            .foregroundStyle(PurlTune.token("Components/ProductCard.swift:foregroundStyle:_:132:46", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                            .lineLimit(1)
                    }
                }
            }
			.frame(height: PurlTune.value("Components/ProductCard.swift:frame:height:137:19", default: 104)).padding(PurlTune.token("Components/ProductCard.swift:padding:_:137:32", default: GravitySpacing.space2, options: GravitySpacing.purlTuneOptions))

            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(PurlTune.value("Components/ProductCard.swift:padding:_:142:18", default: 8))
        .background(PurlTune.token("Components/ProductCard.swift:background:_:143:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r28)
                .strokeBorder(GravityColors.border, lineWidth: 0.5)
        )
    }

    private var listImageSection: some View {
        Color.white
            .frame(width: PurlTune.value("Components/ProductCard.swift:frame:width:153:27", default: 108), height: PurlTune.value("Components/ProductCard.swift:frame:height:153:116", default: 108))
            .overlay { imageContent }
            .overlay { Color.black.opacity(PurlTune.value("Components/ProductCard.swift:opacity:_:155:44", default: 0.04)) }
            .overlay { listImageControls }
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20))
            .overlay(
                RoundedRectangle(cornerRadius: GravityRadius.r20)
                    .strokeBorder(Color.white.opacity(PurlTune.value("Components/ProductCard.swift:opacity:_:160:55", default: 0.08)), lineWidth: 0.5)
            )
    }

    @ViewBuilder
    private var listImageControls: some View {
        if showFavoriteButton {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    favoriteButton
                }
            }
            .padding(PurlTune.value("Components/ProductCard.swift:padding:_:174:22", default: 8))
        }
    }

    // MARK: - Image

    private var imageSection: some View {
        imageBase
            .overlay { imageControls }
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20))
            .overlay(
                RoundedRectangle(cornerRadius: GravityRadius.r20)
                    .strokeBorder(Color.white.opacity(PurlTune.value("Components/ProductCard.swift:opacity:_:186:55", default: 0.08)), lineWidth: 0.5)
            )
            .gravityShadow(GravityShadows.small)
    }

    /// White background + product image + 4% darken overlay.
    private var imageBase: some View {
        Color.white
            .aspectRatio(1, contentMode: .fit)
            .overlay { imageContent }
            .overlay { Color.black.opacity(PurlTune.value("Components/ProductCard.swift:opacity:_:196:44", default: 0.04)) }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let image {
            image
                .resizable()
                .scaledToFill()
        } else if let imageURL, let url = URL(string: imageURL) {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let loaded):
                    loaded.resizable().scaledToFill()
                case .failure:
                    imageFallback
                default:
                    Rectangle().fill(PurlTune.token("Components/ProductCard.swift:fill:_:217:38", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                }
            }
        } else {
            Rectangle()
                .fill(PurlTune.token("Components/ProductCard.swift:fill:_:222:23", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
        }
    }

    @ViewBuilder
    private var imageControls: some View {
        ZStack {
            // Price badge (top-leading)
            if let priceBadge {
                VStack {
                    HStack {
                        Text(priceBadge)
                            .gravityTextStyle(GravityTypography.badgeBold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, PurlTune.value("Components/ProductCard.swift:padding:_:236:51", default: 6))
                            .padding(.vertical, PurlTune.value("Components/ProductCard.swift:padding:_:237:49", default: 2))
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GravityRadius.max))
                            .environment(\.colorScheme, .dark)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(PurlTune.token("Components/ProductCard.swift:padding:_:244:26", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
            }

            // Favorites heart (bottom-trailing)
            if showFavoriteButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        favoriteButton
                    }
                }
                .padding(PurlTune.token("Components/ProductCard.swift:padding:_:256:26", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
            }
        }
    }

    @ViewBuilder
    private var imageFallback: some View {
        if let image {
            image.resizable().scaledToFill()
        } else {
            Rectangle().fill(PurlTune.token("Components/ProductCard.swift:fill:_:266:30", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
        }
    }

    // MARK: - Favorite Button

    private var favoriteButton: some View {
        ProductFavoriteButton(
            addsContrastShadow: favoriteIconHasContrastShadow,
            onTap: onFavoriteTap
        )
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Merchant name
            if let merchantName {
                Text(merchantName)
                    .gravityTextStyle(GravityTypography.caption)
                    .foregroundStyle(PurlTune.token("Components/ProductCard.swift:foregroundStyle:_:309:38", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                    .lineLimit(1)
            }

            // Product name
            if let productName {
                Text(productName)
                    .gravityTextStyle(GravityTypography.captionBold)
                    .foregroundStyle(PurlTune.token("Components/ProductCard.swift:foregroundStyle:_:317:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    .lineLimit(1)
            }

            // Rating
            if let rating, let ratingCount {
                ratingRow(rating: rating, count: ratingCount)
            }

            // Price
            if let price {
                priceRow
            }
        }
        .padding(.horizontal, PurlTune.token("Components/ProductCard.swift:padding:_:331:31", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
    }

    // MARK: - Rating Row

    private func ratingRow(rating: Double, count: Int) -> some View {
        HStack(spacing: 2) {
            // Stars
            HStack(spacing: 0) {
                ForEach(0..<5) { index in
                    GravityIcon.starFilled.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: PurlTune.value("Components/ProductCard.swift:frame:width:344:39", default: 12), height: PurlTune.value("Components/ProductCard.swift:frame:height:344:127", default: 12))
                        .foregroundStyle(
                            Double(index) < rating
                                ? Color(hex: 0xFFB800)
                                : GravityColors.bgFillSecondary
                        )
                }
            }

            // Count
            Text("(\(count))")
                .gravityTextStyle(GravityTypography.caption)
                .foregroundStyle(PurlTune.token("Components/ProductCard.swift:foregroundStyle:_:356:34", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
        }
    }

    // MARK: - Price Row

    private var priceRow: some View {
        HStack(spacing: GravitySpacing.space4) {
            if let price {
                Text(price)
                    .gravityTextStyle(GravityTypography.captionMedium)
                    .foregroundStyle(PurlTune.token("Components/ProductCard.swift:foregroundStyle:_:367:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
            }
            if let originalPrice {
                Text(originalPrice)
                    .gravityTextStyle(GravityTypography.caption)
                    .foregroundStyle(PurlTune.token("Components/ProductCard.swift:foregroundStyle:_:372:38", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                    .strikethrough()
            }
        }
    }
}

// MARK: - Previews

#Preview("Grid — Full Metadata") {
    let merchant = SampleMerchant.all.first!
    let product = merchant.products.first!
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ProductCard(
                image: nil,
                imageURL: product.imageURL,
                merchantName: merchant.name,
                productName: product.title,
                rating: merchant.rating,
                ratingCount: merchant.totalRatings,
                price: "$\(product.price)",
                originalPrice: "$99.00",
                priceBadge: "30% OFF"
            )
            ProductCard(
                image: nil,
                imageURL: merchant.products.dropFirst().first?.imageURL,
                merchantName: merchant.name,
                productName: "Another Great Product",
                rating: 3.5,
                ratingCount: 12,
                price: "$42.00"
            )
        }
        .padding()
    }
    .background(PurlTune.token("Components/ProductCard.swift:background:_:409:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}

#Preview("Grid — Compact (Image Only)") {
    let merchant = SampleMerchant.all.first!
    HStack(spacing: 12) {
        ProductCard(image: nil, imageURL: merchant.products.first?.imageURL)
            .frame(width: PurlTune.value("Components/ProductCard.swift:frame:width:416:27", default: 140))
        ProductCard(image: nil)
            .frame(width: PurlTune.value("Components/ProductCard.swift:frame:width:418:27", default: 140))
    }
    .padding()
    .background(PurlTune.token("Components/ProductCard.swift:background:_:421:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}

#Preview("Grid — Favorited") {
    let merchant = SampleMerchant.all.first!
    let product = merchant.products.first!
    ProductCard(
        image: nil,
        imageURL: product.imageURL,
        merchantName: merchant.name,
        productName: product.title,
        rating: 4.8,
        ratingCount: 256,
        price: "$\(product.price)",
        isFavorite: true
    )
    .frame(width: PurlTune.value("Components/ProductCard.swift:frame:width:437:19", default: 180))
    .padding()
    .background(PurlTune.token("Components/ProductCard.swift:background:_:439:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}

#Preview("List Style") {
    let merchant = SampleMerchant.all.first!
    VStack(spacing: 12) {
        ForEach(merchant.products.prefix(3)) { product in
            ProductCard(
                image: nil,
                imageURL: product.imageURL,
                merchantName: merchant.name,
                productName: product.title,
                rating: merchant.rating,
                ratingCount: merchant.totalRatings,
                price: "$\(product.price)",
                style: .list,
                merchantLogoImage: nil,
                merchantLogoURL: merchant.bestLogoURL
            )
        }
    }
    .padding()
    .background(PurlTune.token("Components/ProductCard.swift:background:_:461:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}

#Preview("Dark Mode") {
    let merchant = SampleMerchant.all.first!
    let product = merchant.products.first!
    ProductCard(
        image: nil,
        imageURL: product.imageURL,
        merchantName: merchant.name,
        productName: product.title,
        rating: 4.2,
        ratingCount: 89,
        price: "$\(product.price)",
        originalPrice: "$79.00",
        priceBadge: "SALE"
    )
    .frame(width: PurlTune.value("Components/ProductCard.swift:frame:width:478:19", default: 180))
    .padding()
    .background(PurlTune.token("Components/ProductCard.swift:background:_:480:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
    .preferredColorScheme(.dark)
}
