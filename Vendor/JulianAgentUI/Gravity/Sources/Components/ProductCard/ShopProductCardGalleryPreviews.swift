#if DEBUG
import SwiftUI

// MARK: - Preview helpers

private func productPreviewImage(_ top: Color, _ bottom: Color) -> some View {
    LinearGradient(
        colors: [top.opacity(0.35), bottom.opacity(0.55)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct OverlayPositionSample: View {
    let position: ShopProductImageOverlayPosition
    let label: String

    var body: some View {
        VStack(spacing: GravitySpacing.space4) {
            ShopProductImageTile(displayWidth: 150) {
                productPreviewImage(.blue, .purple)
            } overlay: {
                ShopProductImageOverlayLayout {
                    ShopProductImageOverlayItem(position) {
                        ShopBadge(label, variant: .brand)
                    }
                }
            }

            ShopText(label, style: .caption)
        }
    }
}

// MARK: - Vertical cards

#Preview("Gallery – Vertical cards") {
    ScrollView {
        VStack(spacing: GravitySpacing.space24) {
            ShopProductCard(cardWidth: 180) {
                ShopProductImageTile(displayWidth: 180) {
                    productPreviewImage(.pink, .orange)
                } overlay: {
                    ShopProductImageOverlayLayout {
                        ShopProductImageOverlayItem(.topLeading) {
                            ShopBadge("Sale", variant: .critical)
                        }
                        ShopProductImageOverlayItem(.bottomTrailing) {
                            ShopFavoriteButton(isFavorite: true)
                        }
                    }
                }
            } metadata: {
                ShopProductCardMetadata(
                    shopName: "Nike",
                    title: "Air Classic Sneaker",
                    rating: ShopProductCardRating(average: 4.5, count: 342),
                    price: "$89.99",
                    originalPrice: "$120.00"
                )
            }

            ShopProductCard(cardWidth: 180) {
                ShopProductImageTile(displayWidth: 180) {
                    productPreviewImage(.green, .teal)
                } overlay: {
                    ShopProductImageOverlayLayout {
                        ShopProductImageOverlayItem(.bottomTrailing) {
                            ShopFavoriteButton(isFavorite: false)
                        }
                    }
                }
            } metadata: {
                ShopProductCardMetadata(title: "Minimal Card", price: "$24.00")
            }

            ShopProductCard(cardWidth: 180) {
                ShopProductImageTile(displayWidth: 180) {
                    productPreviewImage(.indigo, .blue)
                }
            } metadata: {
                ShopProductCardMetadata(
                    shopName: "Studio Store",
                    title: "Ceramic Mug",
                    price: "$18.00",
                    variantTitle: "Sand / 12oz",
                    lastPurchasedText: "Last purchased May 20"
                )
            }
        }
        .padding()
    }
}

// MARK: - Horizontal / line item cards

#Preview("Gallery – Horizontal / line item") {
    VStack(spacing: GravitySpacing.space16) {
        ShopProductCard(layout: .horizontal(imageWidth: 112, spacing: GravitySpacing.space12), cardWidth: 340) {
            ShopProductImageTile(displayWidth: 112) {
                productPreviewImage(.red, .pink)
            } overlay: {
                ShopProductImageOverlayLayout {
                    ShopProductImageOverlayItem(.bottomTrailing) {
                        ShopFavoriteButton(isFavorite: true)
                    }
                }
            }
        } metadata: {
            ShopProductCardMetadata(
                shopName: "prime cosmetics",
                title: "Lip Essentials Set",
                rating: ShopProductCardRating(average: 3.5, count: 20),
                price: "$81.00"
            )
        }

        ShopProductCard(layout: .horizontal(imageWidth: 112, spacing: GravitySpacing.space12), cardWidth: 340) {
            ShopProductImageTile(displayWidth: 112) {
                productPreviewImage(.yellow, .orange)
            }
        } metadata: {
            ShopProductCardMetadata(
                title: "No favorite, no badge",
                price: "$12.00"
            )
        }
    }
    .padding()
}

// MARK: - Overlay positions

#Preview("Gallery – Overlay positions") {
    ScrollView {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: GravitySpacing.space16
        ) {
            OverlayPositionSample(position: .topLeading, label: "topLeading")
            OverlayPositionSample(position: .topTrailing, label: "topTrailing")
            OverlayPositionSample(position: .bottomLeading, label: "bottomLeading")
            OverlayPositionSample(position: .bottomTrailing, label: "bottomTrailing")
        }
        .padding()
    }
}

// MARK: - Combined overlays

#Preview("Gallery – Combined overlays") {
    ShopProductImageTile(displayWidth: 260) {
        productPreviewImage(.mint, .cyan)
    } overlay: {
        ShopProductImageOverlayLayout {
            ShopProductImageOverlayItem(.topLeading) {
                ShopBadge("$24.00", variant: .subdued)
            }
            ShopProductImageOverlayItem(.topTrailing) {
                ShopBadge("New", variant: .brand)
            }
            ShopProductImageOverlayItem(.bottomLeading) {
                ShopBadge("-40%", variant: .critical)
            }
            ShopProductImageOverlayItem(.bottomTrailing) {
                ShopFavoriteButton(isFavorite: true)
            }
        }
    }
    .padding()
}

// MARK: - Overlay content variants

#Preview("Gallery – Overlay content") {
    VStack(alignment: .leading, spacing: GravitySpacing.space16) {
        ShopText("Badge variants", style: .captionBold)
        HStack(spacing: GravitySpacing.space8) {
            ShopBadge("Sale", variant: .critical)
            ShopBadge("New", variant: .brand)
            ShopBadge("$24.00", variant: .subdued)
            ShopBadge("Default", variant: .default)
        }

        ShopText("Favorite states", style: .captionBold)
        HStack(spacing: GravitySpacing.space16) {
            ShopFavoriteButton(isFavorite: false)
            ShopFavoriteButton(isFavorite: true)
        }
    }
    .padding()
}
#endif
