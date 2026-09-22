import SwiftUI

// MARK: - ShopProductCard previews

#Preview("ShopProductCard / Layout overview") {
    ProductCardPreviewContainer {
        ProductCardPreviewSection("Fixed vertical feed card") {
            ShopProductCard(cardWidth: 164) {
                ProductCardPreviewImageTile(
                    displayWidth: 164,
                    color: .purple,
                    overlay: .favorite
                )
            } metadata: {
                ShopProductCardMetadata(
                    shopName: "Fly by Jing",
                    title: "Original Sichuan Chili Crisp",
                    rating: ShopProductCardRating(average: 4.6, count: 2964),
                    price: "$32.00"
                )
            }
        }

        ProductCardPreviewSection("Fixed vertical discounted card") {
            ShopProductCard(cardWidth: 164) {
                ProductCardPreviewImageTile(
                    displayWidth: 164,
                    color: .orange,
                    overlay: .discounted
                )
            } metadata: {
                ShopProductCardMetadata(
                    shopName: "Aarke",
                    title: "Carbonator Pro Stainless Steel",
                    rating: ShopProductCardRating(average: 4.8, count: 151),
                    price: "$199.00",
                    originalPrice: "$249.00"
                )
            }
        }

        ProductCardPreviewSection("Flexible store grid card") {
            ShopProductCard {
                GeometryReader { proxy in
                    ProductCardPreviewImageTile(
                        displayWidth: proxy.size.width,
                        color: .blue,
                        overlay: .none
                    )
                }
                .aspectRatio(1, contentMode: .fit)
            } metadata: {
                ShopProductCardMetadata(
                    title: "Everyday Cotton Oversized Tee in Washed Black",
                    rating: ShopProductCardRating(average: 4.3, count: 82),
                    price: "$48.00",
                    titleLineLimit: 2,
                    style: ShopProductCardMetadataStyle(starFillColor: GravityColor.iconStars)
                )
            }
        }
        .frame(width: 180)

        ProductCardPreviewSection("Horizontal recommendation card") {
            ShopProductCard(layout: .horizontal(imageWidth: 112), cardWidth: 320) {
                ProductCardPreviewImageTile(
                    displayWidth: 112,
                    color: .green,
                    overlay: .favorite
                )
            } metadata: {
                ShopProductCardMetadata(
                    title: "Mini Everywhere Belt Bag",
                    rating: ShopProductCardRating(average: 4.7, count: 421),
                    price: "$38.00",
                    variantTitle: "Black / One size"
                )
            }
        }

        ProductCardPreviewSection("Image-only card") {
            ShopProductCard(cardWidth: 132) {
                ProductCardPreviewImageTile(
                    displayWidth: 132,
                    color: .pink,
                    overlay: .favorite
                )
            }
        }
    }
}

#Preview("ShopProductCard / Feed grid permutations") {
    ScrollView {
        LazyVGrid(
            columns: [
                GridItem(.fixed(154), spacing: GravitySpacing.space16, alignment: .top),
                GridItem(.fixed(154), spacing: GravitySpacing.space16, alignment: .top),
            ],
            alignment: .center,
            spacing: GravitySpacing.space24
        ) {
            ProductCardPreviewGridCard(
                color: .purple,
                overlay: .favorite,
                shopName: "Fly by Jing",
                title: "Original Sichuan Chili Crisp",
                rating: ShopProductCardRating(average: 4.6, count: 2964),
                price: "$32.00"
            )

            ProductCardPreviewGridCard(
                color: .orange,
                overlay: .discounted,
                shopName: "Aarke",
                title: "Carbonator Pro",
                rating: ShopProductCardRating(average: 4.8, count: 151),
                price: "$199.00",
                originalPrice: "$249.00"
            )

            ProductCardPreviewGridCard(
                color: .blue,
                overlay: .topLeftLabel,
                shopName: nil,
                title: "Long product title that truncates to one line in feed cards",
                rating: nil,
                price: "$48.00"
            )

            ProductCardPreviewGridCard(
                color: .green,
                overlay: .topLeftLabel,
                shopName: "Baggu",
                title: "Reusable Tote",
                rating: ShopProductCardRating(average: 5.0, count: nil),
                price: "$14.00"
            )

            ProductCardPreviewGridCard(
                color: .pink,
                overlay: .none,
                shopName: "MATE the Label",
                title: "Organic Fleece Sweatpant",
                rating: nil,
                price: "$128.00",
                variantTitle: "Heather grey / M"
            )

            ProductCardPreviewGridCard(
                color: .teal,
                overlay: .favorite,
                shopName: "Parachute",
                title: "Linen Sheet Set",
                rating: ShopProductCardRating(average: 4.2, count: 87),
                price: "$149.00",
                lastPurchasedText: "Last purchased May 20"
            )
        }
        .padding(GravitySpacing.space20)
    }
    .background(GravityColor.background)
}

#Preview("ShopProductCard / Flexible store grid") {
    ScrollView {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: GravitySpacing.space12, alignment: .top),
                GridItem(.flexible(), spacing: GravitySpacing.space12, alignment: .top),
            ],
            alignment: .leading,
            spacing: GravitySpacing.space20
        ) {
            ForEach(ProductCardPreviewStoreProduct.samples) { product in
                ShopProductCard {
                    GeometryReader { proxy in
                        ProductCardPreviewImageTile(
                            displayWidth: proxy.size.width,
                            color: product.color,
                            overlay: product.overlay
                        )
                    }
                    .aspectRatio(1, contentMode: .fit)
                } metadata: {
                    ShopProductCardMetadata(
                        title: product.title,
                        rating: product.rating,
                        price: product.price,
                        originalPrice: product.originalPrice,
                        titleLineLimit: 2,
                        style: ShopProductCardMetadataStyle(starFillColor: GravityColor.iconStars)
                    )
                }
            }
        }
        .padding(GravitySpacing.space20)
    }
    .background(GravityColor.background)
}

#Preview("ShopProductCard / Horizontal permutations") {
    ProductCardPreviewContainer {
        ForEach(ProductCardPreviewStoreProduct.samples.prefix(5)) { product in
            ShopProductCard(layout: .horizontal(imageWidth: 96), cardWidth: 360) {
                ProductCardPreviewImageTile(
                    displayWidth: 96,
                    color: product.color,
                    overlay: product.overlay
                )
            } metadata: {
                ShopProductCardMetadata(
                    shopName: product.shopName,
                    title: product.title,
                    rating: product.rating,
                    price: product.price,
                    originalPrice: product.originalPrice,
                    variantTitle: product.variantTitle,
                    titleLineLimit: 2
                )
            }
        }
    }
}

#Preview("ShopProductCardMetadata / Field permutations") {
    ProductCardPreviewContainer {
        ProductCardPreviewMetadataRow("Title only") {
            ShopProductCardMetadata(title: "Classic Sneaker")
        }

        ProductCardPreviewMetadataRow("Shop + title") {
            ShopProductCardMetadata(shopName: "Nike", title: "Classic Sneaker")
        }

        ProductCardPreviewMetadataRow("Rating with count") {
            ShopProductCardMetadata(
                title: "Classic Sneaker",
                rating: ShopProductCardRating(average: 4.5, count: 342)
            )
        }

        ProductCardPreviewMetadataRow("Rating without count") {
            ShopProductCardMetadata(
                title: "Classic Sneaker",
                rating: ShopProductCardRating(average: 5.0)
            )
        }

        ProductCardPreviewMetadataRow("Price") {
            ShopProductCardMetadata(title: "Classic Sneaker", price: "$120.00")
        }

        ProductCardPreviewMetadataRow("Discounted price") {
            ShopProductCardMetadata(
                title: "Classic Sneaker",
                price: "$89.99",
                originalPrice: "$120.00"
            )
        }

        ProductCardPreviewMetadataRow("Variant title") {
            ShopProductCardMetadata(
                title: "Classic Sneaker",
                price: "$120.00",
                variantTitle: "White / 10"
            )
        }

        ProductCardPreviewMetadataRow("Last purchased") {
            ShopProductCardMetadata(
                title: "Classic Sneaker",
                price: "$120.00",
                lastPurchasedText: "Last purchased May 20"
            )
        }

        ProductCardPreviewMetadataRow("Long title / one line") {
            ShopProductCardMetadata(
                title: "Very long product title demonstrating feed truncation behavior",
                price: "$120.00",
                titleLineLimit: 1
            )
        }

        ProductCardPreviewMetadataRow("Long title / two lines") {
            ShopProductCardMetadata(
                title: "Very long product title demonstrating store-grid wrapping behavior",
                price: "$120.00",
                titleLineLimit: 2
            )
        }

        ProductCardPreviewMetadataRow("Dark/elevated palette") {
            ShopProductCardMetadata(
                shopName: "Fly by Jing",
                title: "Original Sichuan Chili Crisp",
                rating: ShopProductCardRating(average: 4.6, count: 2964),
                price: "$32.00",
                style: ShopProductCardMetadataStyle(
                    primaryTextColor: GravityColor.textFixedLight,
                    secondaryTextColor: GravityColor.textFixedLight.opacity(0.78),
                    tertiaryTextColor: GravityColor.textFixedLight.opacity(0.55),
                    starFillColor: GravityColor.textFixedLight
                )
            )
            .padding(GravitySpacing.space12)
            .background(GravityColor.fillFixedDark)
            .clipShape(RoundedRectangle(cornerRadius: ShopRadius.r16, style: .continuous))
        }
    }
}

#Preview("ShopProductImageTile / Image states") {
    ProductCardPreviewContainer {
        HStack(alignment: .top, spacing: GravitySpacing.space16) {
            ProductCardPreviewLabeledTile("Square") {
                ProductCardPreviewImageTile(displayWidth: 116, color: .purple, overlay: .none)
            }

            ProductCardPreviewLabeledTile("Favorite") {
                ProductCardPreviewImageTile(displayWidth: 116, color: .orange, overlay: .favorite)
            }

            ProductCardPreviewLabeledTile("No shadow") {
                ShopProductImageTile(
                    displayWidth: 116,
                    shadow: .none
                ) {
                    ProductCardPreviewArtwork(color: .blue)
                } overlay: {
                    EmptyView()
                }
            }
        }

        HStack(alignment: .top, spacing: GravitySpacing.space16) {
            ProductCardPreviewLabeledTile("3:4") {
                ShopProductImageTile(displayWidth: 116, aspectRatio: 0.75) {
                    ProductCardPreviewArtwork(color: .green)
                }
            }

            ProductCardPreviewLabeledTile("3:2") {
                ShopProductImageTile(displayWidth: 116, aspectRatio: 1.5) {
                    ProductCardPreviewArtwork(color: .pink)
                }
            }

            ProductCardPreviewLabeledTile("Placeholder") {
                ShopProductImageTile(displayWidth: 116) {
                    ShopIcon(.noImage, size: .large, color: GravityColor.textPlaceholder)
                }
            }
        }
    }
}

#Preview("ShopProductImageOverlayLayout / Positions") {
    ProductCardPreviewContainer {
        ProductCardPreviewOverlayTile("All standard positions") {
            ShopProductImageOverlayLayout {
                ShopProductImageOverlayItem(.topLeading) {
                    ProductCardPreviewPill("TL", color: GravityColor.fillBrand)
                }
                ShopProductImageOverlayItem(.topTrailing) {
                    ProductCardPreviewPill("TR", color: GravityColor.fillCritical)
                }
                ShopProductImageOverlayItem(.bottomLeading) {
                    ProductCardPreviewPill("BL", color: GravityColor.fillFixedDark)
                }
                ShopProductImageOverlayItem(.bottomTrailing) {
                    ShopFavoriteButton(isFavorite: true)
                }
            }
        }

        ProductCardPreviewOverlayTile("Conditional builder") {
            let showsTopLabel = true
            let showsFavorite = false

            ShopProductImageOverlayLayout {
                if showsTopLabel {
                    ShopProductImageOverlayItem(.topLeading) {
                        ProductCardPreviewPill("SALE", color: GravityColor.fillCritical)
                    }
                }

                if showsFavorite {
                    ShopProductImageOverlayItem(.bottomTrailing) {
                        ShopFavoriteButton(isFavorite: true)
                    }
                } else {
                    ShopProductImageOverlayItem(.bottomLeading) {
                        ProductCardPreviewPill("LOW", color: GravityColor.fillBrand)
                    }
                }
            }
        }
    }
}

// MARK: - Preview helpers

private struct ProductCardPreviewContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GravitySpacing.space24) {
                content()
            }
            .padding(GravitySpacing.space20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(GravityColor.background)
    }
}

private struct ProductCardPreviewSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            ShopText(title, style: .captionBold, color: GravityColor.textSecondary)
            content()
        }
    }
}

private struct ProductCardPreviewMetadataRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            ShopText(title, style: .captionBold, color: GravityColor.textSecondary)
            content()
                .frame(width: 260, alignment: .leading)
        }
    }
}

private struct ProductCardPreviewLabeledTile<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            content()
            ShopText(title, style: .caption, color: GravityColor.textSecondary)
                .frame(width: 116, alignment: .center)
        }
    }
}

private struct ProductCardPreviewOverlayTile<Overlay: View>: View {
    let title: String
    @ViewBuilder let overlay: () -> Overlay

    init(_ title: String, @ViewBuilder overlay: @escaping () -> Overlay) {
        self.title = title
        self.overlay = overlay
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            ShopProductImageTile(
                displayWidth: 180,
            ) {
                ProductCardPreviewArtwork(color: .purple)
            } overlay: {
                overlay()
            }

            ShopText(title, style: .caption, color: GravityColor.textSecondary)
                .frame(width: 180, alignment: .center)
        }
    }
}

private struct ProductCardPreviewGridCard: View {
    let color: ProductCardPreviewColor
    let overlay: ProductCardPreviewOverlay
    let shopName: String?
    let title: String
    let rating: ShopProductCardRating?
    let price: String
    var originalPrice: String?
    var variantTitle: String?
    var lastPurchasedText: String?

    var body: some View {
        ShopProductCard(cardWidth: 154) {
            ProductCardPreviewImageTile(
                displayWidth: 154,
                color: color,
                overlay: overlay
            )
        } metadata: {
            ShopProductCardMetadata(
                shopName: shopName,
                title: title,
                rating: rating,
                price: price,
                originalPrice: originalPrice,
                variantTitle: variantTitle,
                lastPurchasedText: lastPurchasedText
            )
        }
    }
}

private struct ProductCardPreviewImageTile: View {
    let displayWidth: CGFloat
    let color: ProductCardPreviewColor
    let overlay: ProductCardPreviewOverlay

    var body: some View {
        ShopProductImageTile(
            displayWidth: displayWidth,
        ) {
            ProductCardPreviewArtwork(color: color)
        } overlay: {
            overlayView
        }
    }

    @ViewBuilder
    private var overlayView: some View {
        switch overlay {
        case .none:
            EmptyView()
        case .favorite:
            ShopProductImageOverlayLayout {
                ShopProductImageOverlayItem(.bottomTrailing) {
                    ShopFavoriteButton(isFavorite: true)
                }
            }
        case .discounted:
            ShopProductImageOverlayLayout {
                ShopProductImageOverlayItem(.topLeading) {
                    ProductCardPreviewPill("SALE", color: GravityColor.fillCritical)
                }
                ShopProductImageOverlayItem(.bottomTrailing) {
                    ShopFavoriteButton(isFavorite: false)
                }
            }
        case .topLeftLabel:
            ShopProductImageOverlayLayout {
                ShopProductImageOverlayItem(.topLeading) {
                    ProductCardPreviewPill("NEW", color: GravityColor.fillBrand)
                }
            }
        }
    }
}

private struct ProductCardPreviewArtwork: View {
    let color: ProductCardPreviewColor

    var body: some View {
        ZStack {
            LinearGradient(
                colors: color.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.24))
                .frame(width: 72, height: 72)
                .offset(x: -28, y: -32)

            RoundedRectangle(cornerRadius: ShopRadius.r16, style: .continuous)
                .fill(.white.opacity(0.28))
                .frame(width: 88, height: 108)
                .rotationEffect(.degrees(-8))
                .offset(x: 18, y: 12)

            VStack(spacing: GravitySpacing.space4) {
                ShopIcon(.shop, size: .large, color: GravityColor.textFixedLight.opacity(0.92))
                ShopText(color.label, style: .captionBold, color: GravityColor.textFixedLight)
            }
        }
    }
}

private struct ProductCardPreviewPill: View {
    let label: String
    let color: Color

    init(_ label: String, color: Color) {
        self.label = label
        self.color = color
    }

    var body: some View {
        ShopText(label, style: .badgeBold, color: GravityColor.textFixedLight)
            .padding(.horizontal, GravitySpacing.space6)
            .padding(.vertical, GravitySpacing.space2)
            .background(color)
            .clipShape(Capsule())
    }
}

private enum ProductCardPreviewOverlay {
    case none
    case favorite
    case discounted
    case topLeftLabel
}

private enum ProductCardPreviewColor {
    case purple
    case orange
    case blue
    case green
    case pink
    case teal

    var label: String {
        switch self {
        case .purple:
            "PLUM"
        case .orange:
            "SPICE"
        case .blue:
            "SKY"
        case .green:
            "LEAF"
        case .pink:
            "ROSE"
        case .teal:
            "WAVE"
        }
    }

    var gradient: [Color] {
        switch self {
        case .purple:
            [Color.purple.opacity(0.72), Color.indigo.opacity(0.9)]
        case .orange:
            [Color.orange.opacity(0.82), Color.red.opacity(0.78)]
        case .blue:
            [Color.blue.opacity(0.74), Color.cyan.opacity(0.82)]
        case .green:
            [Color.green.opacity(0.72), Color.mint.opacity(0.82)]
        case .pink:
            [Color.pink.opacity(0.72), Color.red.opacity(0.58)]
        case .teal:
            [Color.teal.opacity(0.74), Color.blue.opacity(0.66)]
        }
    }
}

private struct ProductCardPreviewStoreProduct: Identifiable {
    let id = UUID()
    let shopName: String?
    let title: String
    let rating: ShopProductCardRating?
    let price: String
    let originalPrice: String?
    let variantTitle: String?
    let color: ProductCardPreviewColor
    let overlay: ProductCardPreviewOverlay

    static let samples: [ProductCardPreviewStoreProduct] = [
        ProductCardPreviewStoreProduct(
            shopName: "Fly by Jing",
            title: "Original Sichuan Chili Crisp (XL)",
            rating: ShopProductCardRating(average: 4.6, count: 2964),
            price: "$32.00",
            originalPrice: nil,
            variantTitle: nil,
            color: .orange,
            overlay: .favorite
        ),
        ProductCardPreviewStoreProduct(
            shopName: "Aarke",
            title: "Carbonator Pro Stainless Steel",
            rating: ShopProductCardRating(average: 4.8, count: 151),
            price: "$199.00",
            originalPrice: "$249.00",
            variantTitle: nil,
            color: .blue,
            overlay: .discounted
        ),
        ProductCardPreviewStoreProduct(
            shopName: "Baggu",
            title: "Standard Reusable Shopping Bag",
            rating: nil,
            price: "$14.00",
            originalPrice: nil,
            variantTitle: "Tomato / One size",
            color: .green,
            overlay: .topLeftLabel
        ),
        ProductCardPreviewStoreProduct(
            shopName: "Parachute",
            title: "Linen Sheet Set",
            rating: ShopProductCardRating(average: 4.9, count: 1203),
            price: "$149.00",
            originalPrice: "$189.00",
            variantTitle: "Bone / Queen",
            color: .teal,
            overlay: .favorite
        ),
        ProductCardPreviewStoreProduct(
            shopName: nil,
            title: "Minimal Product Without Shop Name",
            rating: nil,
            price: "$24.00",
            originalPrice: nil,
            variantTitle: nil,
            color: .purple,
            overlay: .none
        ),
    ]
}
