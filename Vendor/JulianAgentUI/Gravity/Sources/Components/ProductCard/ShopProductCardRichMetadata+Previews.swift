import SwiftUI

#Preview("ShopProductCardRichMetadata / Product details rows") {
    ProductCardRichMetadataPreviewContainer {
        ProductCardRichMetadataPreviewSection("Default product details row") {
            ShopProductCard(layout: .horizontal(imageWidth: 128), cardWidth: 360) {
                ProductCardPreviewImageTileForRichMetadata(
                    displayWidth: 128,
                    color: .orange,
                    overlay: .favorite
                )
            } metadata: {
                ShopProductCardRichMetadata(
                    title: "Original Sichuan Chili Crisp (XL)",
                    rating: ShopProductCardRating(average: 4.6, count: 2964),
                    price: "$32.00"
                ) {
                    ShopProductCardMerchantFooter(
                        merchantName: "Fly by Jing",
                        shopRating: ShopProductCardRating(average: 4.8, count: 1200)
                    ) {
                        ShopAvatar(name: "Fly by Jing", size: .xs)
                    }
                }
            }
            .frame(width: 360, height: 144)
        }

        ProductCardRichMetadataPreviewSection("Discounted product with merchant rating") {
            ShopProductCard(layout: .horizontal(imageWidth: 128), cardWidth: 360) {
                ProductCardPreviewImageTileForRichMetadata(
                    displayWidth: 128,
                    color: .blue,
                    overlay: .sale
                )
            } metadata: {
                ShopProductCardRichMetadata(
                    title: "Carbonator Pro Stainless Steel Sparkling Water Maker",
                    rating: ShopProductCardRating(average: 4.8, count: 151),
                    price: "$199.00",
                    originalPrice: "$249.00"
                ) {
                    ShopProductCardMerchantFooter(
                        merchantName: "Aarke",
                        shopRating: ShopProductCardRating(average: 4.9, count: 842)
                    ) {
                        ShopAvatar(name: "Aarke", size: .xs)
                    }
                }
            }
            .frame(width: 360, height: 144)
        }

        ProductCardRichMetadataPreviewSection("Price range + trailing offer") {
            ShopProductCard(layout: .horizontal(imageWidth: 128), cardWidth: 360) {
                ProductCardPreviewImageTileForRichMetadata(
                    displayWidth: 128,
                    color: .green,
                    overlay: .none
                )
            } metadata: {
                ShopProductCardRichMetadata(
                    title: "Everyday Cotton Oversized Tee",
                    rating: nil,
                    priceRange: "$38.00–$58.00"
                ) {
                    ShopProductCardMerchantFooter(merchantName: "MATE") {
                        ShopAvatar(name: "MATE", size: .xs)
                    } trailing: {
                        ShopBadge("Save $5", variant: .brand)
                    }
                }
            }
            .frame(width: 360, height: 144)
        }

        ProductCardRichMetadataPreviewSection("Long title stress case") {
            ShopProductCard(layout: .horizontal(imageWidth: 128), cardWidth: 360) {
                ProductCardPreviewImageTileForRichMetadata(
                    displayWidth: 128,
                    color: .purple,
                    overlay: .sale
                )
            } metadata: {
                ShopProductCardRichMetadata(
                    title: "Very long product title that should wrap to two lines while preserving the merchant footer at the bottom",
                    rating: ShopProductCardRating(average: 4.2, count: 87),
                    price: "$128.00",
                    titleLineLimit: 2
                ) {
                    ShopProductCardMerchantFooter(merchantName: "Parachute") {
                        ShopAvatar(name: "Parachute", size: .xs)
                    }
                }
            }
            .frame(width: 360, height: 168)
        }
    }
}

#Preview("ShopProductCardRichMetadata / Inside ShopCard") {
    ProductCardRichMetadataPreviewContainer {
        ProductCardRichMetadataPreviewSection("Rich horizontal product card inside ShopCard") {
            ShopCard(shadow: .s, cornerRadius: ShopRadius.r28, padding: GravitySpacing.space8) {
                ShopProductCard(layout: .horizontal(imageWidth: 128)) {
                    ProductCardPreviewImageTileForRichMetadata(
                        displayWidth: 128,
                        color: .orange,
                        overlay: .favorite
                    )
                } metadata: {
                    ShopProductCardRichMetadata(
                        title: "Original Sichuan Chili Crisp (XL)",
                        rating: ShopProductCardRating(average: 4.6, count: 2964),
                        price: "$32.00"
                    ) {
                        ShopProductCardMerchantFooter(
                            merchantName: "Fly by Jing",
                            shopRating: ShopProductCardRating(average: 4.8, count: 1200)
                        ) {
                            ShopAvatar(name: "Fly by Jing", size: .xs)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        ProductCardRichMetadataPreviewSection("Discounted row inside ShopCard") {
            ShopCard(shadow: .s, cornerRadius: ShopRadius.r28, padding: GravitySpacing.space8) {
                ShopProductCard(layout: .horizontal(imageWidth: 128)) {
                    ProductCardPreviewImageTileForRichMetadata(
                        displayWidth: 128,
                        color: .blue,
                        overlay: .sale
                    )
                } metadata: {
                    ShopProductCardRichMetadata(
                        title: "Carbonator Pro Stainless Steel Sparkling Water Maker",
                        rating: ShopProductCardRating(average: 4.8, count: 151),
                        price: "$199.00",
                        originalPrice: "$249.00"
                    ) {
                        ShopProductCardMerchantFooter(merchantName: "Aarke") {
                            ShopAvatar(name: "Aarke", size: .xs)
                        } trailing: {
                            ShopBadge("Save $50", variant: .brand)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("ShopProductCardRichMetadata / Footer permutations") {
    ProductCardRichMetadataPreviewContainer {
        ProductCardRichMetadataPreviewSection("Merchant only") {
            ShopProductCardRichMetadata(title: "Classic Sneaker", price: "$120.00") {
                ShopProductCardMerchantFooter(merchantName: "Nike") {
                    ShopAvatar(name: "Nike", size: .xs)
                }
            }
            .frame(width: 260, height: 132)
        }

        ProductCardRichMetadataPreviewSection("Merchant + compact shop rating") {
            ShopProductCardRichMetadata(
                title: "Classic Sneaker",
                rating: ShopProductCardRating(average: 4.5, count: 342),
                price: "$120.00"
            ) {
                ShopProductCardMerchantFooter(
                    merchantName: "Nike",
                    shopRating: ShopProductCardRating(average: 4.8, count: 1820)
                ) {
                    ShopAvatar(name: "Nike", size: .xs)
                }
            }
            .frame(width: 260, height: 132)
        }

        ProductCardRichMetadataPreviewSection("Merchant + offer pill") {
            ShopProductCardRichMetadata(title: "Classic Sneaker", price: "$89.99", originalPrice: "$120.00") {
                ShopProductCardMerchantFooter(merchantName: "Nike") {
                    ShopAvatar(name: "Nike", size: .xs)
                } trailing: {
                    ShopBadge("20% off", variant: .brand)
                }
            }
            .frame(width: 260, height: 132)
        }
    }
}

// MARK: - Rich metadata preview helpers

private struct ProductCardRichMetadataPreviewContainer<Content: View>: View {
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

private struct ProductCardRichMetadataPreviewSection<Content: View>: View {
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

private struct ProductCardPreviewImageTileForRichMetadata: View {
    let displayWidth: CGFloat
    let color: ProductCardRichMetadataPreviewColor
    let overlay: ProductCardRichMetadataPreviewOverlay

    var body: some View {
        ShopProductImageTile(
            displayWidth: displayWidth,
        ) {
            ProductCardRichMetadataPreviewArtwork(color: color)
        } overlay: {
            switch overlay {
            case .none:
                EmptyView()
            case .favorite:
                ShopProductImageOverlayLayout {
                    ShopProductImageOverlayItem(.bottomTrailing) {
                        ShopFavoriteButton(isFavorite: true)
                    }
                }
            case .sale:
                ShopProductImageOverlayLayout {
                    ShopProductImageOverlayItem(.topLeading) {
                        ShopBadge("Sale")
                    }
                    ShopProductImageOverlayItem(.bottomTrailing) {
                        ShopFavoriteButton(isFavorite: false)
                    }
                }
            }
        }
    }
}

private struct ProductCardRichMetadataPreviewArtwork: View {
    let color: ProductCardRichMetadataPreviewColor

    var body: some View {
        ZStack {
            LinearGradient(colors: color.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)

            RoundedRectangle(cornerRadius: ShopRadius.r16, style: .continuous)
                .fill(.white.opacity(0.28))
                .frame(width: 72, height: 88)
                .rotationEffect(.degrees(-8))

            ShopText(color.label, style: .captionBold, color: GravityColor.textFixedLight)
        }
    }
}



private enum ProductCardRichMetadataPreviewOverlay {
    case none
    case favorite
    case sale
}

private enum ProductCardRichMetadataPreviewColor {
    case orange
    case blue
    case green
    case pink
    case purple
    case teal

    var label: String {
        switch self {
        case .orange:
            "SPICE"
        case .blue:
            "SKY"
        case .green:
            "LEAF"
        case .pink:
            "ROSE"
        case .purple:
            "PLUM"
        case .teal:
            "WAVE"
        }
    }

    var gradient: [Color] {
        switch self {
        case .orange:
            [Color.orange.opacity(0.82), Color.red.opacity(0.78)]
        case .blue:
            [Color.blue.opacity(0.74), Color.cyan.opacity(0.82)]
        case .green:
            [Color.green.opacity(0.72), Color.mint.opacity(0.82)]
        case .pink:
            [Color.pink.opacity(0.72), Color.red.opacity(0.58)]
        case .purple:
            [Color.purple.opacity(0.72), Color.indigo.opacity(0.9)]
        case .teal:
            [Color.teal.opacity(0.74), Color.blue.opacity(0.66)]
        }
    }
}
