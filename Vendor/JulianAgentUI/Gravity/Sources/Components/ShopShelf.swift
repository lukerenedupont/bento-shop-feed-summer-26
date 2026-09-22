import SwiftUI

/// A horizontally scrolling shelf of items with inset scroll content and
/// edge-to-edge peeking.
///
/// The first item starts at `contentInset` from the leading edge. The same
/// inset is preserved after the last item at the end of the scroll range.
/// Content can scroll to the container edge, with partially clipped items
/// acting as a natural scroll affordance.
///
/// `ShopShelf` intentionally does not render a title or section chrome. Compose
/// headers, actions, and spacing at the callsite.
///
/// **Placement:** prefer giving `ShopShelf` the full container width. If the
/// shelf lives inside a horizontally-padded parent but should still bleed to
/// the screen edge, pass that parent padding as `edgeBleed`.
///
/// ```swift
/// ShopShelf {
///     ForEach(products) { product in
///         ShopProductCard(...).frame(width: 160)
///     }
/// }
/// ```
///
/// Use a custom inset when the shelf lives in a context with a non-standard
/// screen margin:
///
/// ```swift
/// ShopShelf(contentInset: GravitySpacing.space24) {
///     ForEach(items) { item in ... }
/// }
/// ```
///
/// Bleed out of a horizontally-padded parent:
///
/// ```swift
/// ShopShelf(edgeBleed: GravitySpacing.screenMargin) {
///     ForEach(items) { item in ... }
/// }
/// ```
///
/// For paged / snapping carousels with page indicators, use a carousel component.
public struct ShopShelf<Content: View>: View {
    private let contentInset: CGFloat
    private let itemSpacing: CGFloat
    private let edgeBleed: CGFloat
    private let allowsShadowOverflow: Bool
    private let content: Content

    /// - Parameters:
    ///   - contentInset: Scroll-content inset before the first item and after
    ///     the last item. Defaults to `GravitySpacing.screenMargin` (16 pt).
    ///   - itemSpacing: Gap between items. Defaults to
    ///     `GravitySpacing.cardRowGutter` (8 pt).
    ///   - edgeBleed: Amount to expand the shelf beyond its parent on each
    ///     horizontal edge. Use this when the parent already has horizontal
    ///     padding that the scroll rail should escape.
    ///   - allowsShadowOverflow: Adds vertical scroll-content padding and an
    ///     equal negative outer offset so elevated cards can render shadows and
    ///     metadata without increasing the shelf's layout footprint.
    ///   - content: The shelf items. Each item is responsible for its own
    ///     width — use `.frame(width:)` or a fixed-size component.
    public init(
        contentInset: CGFloat = GravitySpacing.screenMargin,
        itemSpacing: CGFloat = GravitySpacing.cardRowGutter,
        edgeBleed: CGFloat = .zero,
        allowsShadowOverflow: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.contentInset = contentInset
        self.itemSpacing = itemSpacing
        self.edgeBleed = edgeBleed
        self.allowsShadowOverflow = allowsShadowOverflow
        self.content = content()
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: itemSpacing) {
                content
            }
        }
        .scrollClipDisabled()
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, contentInset, for: .scrollContent)
        .contentMargins(.vertical, shadowOverflowInset, for: .scrollContent)
        .padding(.horizontal, -edgeBleed)
        .padding(.vertical, -shadowOverflowInset)
    }

    private var shadowOverflowInset: CGFloat {
        allowsShadowOverflow ? GravitySpacing.space16 : .zero
    }
}

// MARK: - Previews

private struct ShelfPreviewCard: View {
    let index: Int
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ShopCard(shadow: .s, cornerRadius: GravityRadius.radius16, padding: GravitySpacing.space0) {
            ZStack {
                RoundedRectangle(cornerRadius: GravityRadius.radius20, style: .continuous)
                    .fill(colors[index % colors.count])
                ShopText("#\(index + 1)", style: .sectionTitle, color: GravityColor.textFixedLight)
            }
            .frame(width: width, height: height)
        }
    }

    private let colors: [Color] = [
        .blue.opacity(0.7), .green.opacity(0.7), .orange.opacity(0.7),
        .purple.opacity(0.7), .red.opacity(0.7), .teal.opacity(0.7),
    ]
}

private struct ShelfPreviewProduct: Identifiable {
    let id: Int
    let shopName: String
    let title: String
    let price: String
    let color: Color
    let isFavorite: Bool
    let isOnSale: Bool
}

private struct ShelfPreviewProductCard: View {
    let product: ShelfPreviewProduct
    private let width: CGFloat = 152

    var body: some View {
        ShopProductCard(cardWidth: width) {
            ShopProductImageTile(
                displayWidth: width,
            ) {
                ZStack {
                    LinearGradient(
                        colors: [product.color.opacity(0.28), product.color.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RoundedRectangle(cornerRadius: GravityRadius.radius16, style: .continuous)
                        .fill(product.color.opacity(0.42))
                        .frame(width: width * 0.5, height: width * 0.62)
                        .rotationEffect(.degrees(-8))
                }
            } overlay: {
                ShopProductImageOverlayLayout {
                    if product.isOnSale {
                        ShopProductImageOverlayItem(.topLeading) {
                            ShopBadge("Sale")
                        }
                    }

                    ShopProductImageOverlayItem(.bottomTrailing) {
                        Circle()
                            .fill(product.isFavorite ? GravityColor.bgFillBrand : Color.black.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay {
                                ShopIcon(
                                    .navigationFavoritesFilled,
                                    size: .small,
                                    color: GravityColor.textFixedLight
                                )
                            }
                    }
                }
            }
        }
    }
}

private let shelfPreviewProducts: [ShelfPreviewProduct] = [
    ShelfPreviewProduct(id: 0, shopName: "MONTY", title: "Striped Carryall Tote", price: "$48.00", color: .red, isFavorite: false, isOnSale: false),
    ShelfPreviewProduct(id: 1, shopName: "FORAGE", title: "Washed Cotton Cap", price: "$32.00", color: .gray, isFavorite: false, isOnSale: false),
    ShelfPreviewProduct(id: 2, shopName: "HAPPY VALLEY", title: "Ribbed Tank Top", price: "$38.00", color: .green, isFavorite: true, isOnSale: true),
    ShelfPreviewProduct(id: 3, shopName: "CLAY", title: "Everyday Mug", price: "$24.00", color: .orange, isFavorite: false, isOnSale: false),
    ShelfPreviewProduct(id: 4, shopName: "COVE", title: "Relaxed Linen Shirt", price: "$86.00", color: .blue, isFavorite: false, isOnSale: true),
]

#Preview("Product card shelf") {
    VStack(alignment: .leading, spacing: GravitySpacing.space12) {
        HStack(alignment: .center, spacing: GravitySpacing.space8) {
            ShopText("Recently viewed", style: .sectionTitle)
            ShopIcon(.boldRightChevron, size: .small)
                .padding(GravitySpacing.space8)
                .background(GravityColor.bgFillSecondary)
                .clipShape(Circle())
        }
        .padding(.leading, GravitySpacing.screenMargin)

        ShopShelf {
            ForEach(shelfPreviewProducts) { product in
                ShelfPreviewProductCard(product: product)
            }
        }
    }
    .padding(.vertical, GravitySpacing.space20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(GravityColor.bg)
}

#Preview("Default — screen margin inset") {
    VStack(alignment: .leading, spacing: GravitySpacing.space12) {
        ShopText("Recently viewed", style: .sectionTitle)
            .padding(.leading, GravitySpacing.screenMargin)

        ShopShelf {
            ForEach(0..<6) { i in
                ShelfPreviewCard(index: i, width: 160, height: 200)
            }
        }
    }
    .padding(.vertical, GravitySpacing.space20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(GravityColor.bg)
}

#Preview("Big cards") {
    VStack(alignment: .leading, spacing: GravitySpacing.space12) {
        ShopText("From this shop", style: .sectionTitle)
            .padding(.leading, GravitySpacing.screenMargin)

        ShopShelf(itemSpacing: GravitySpacing.space16) {
            ForEach(0..<5) { i in
                ShelfPreviewCard(index: i, width: 300, height: 200)
            }
        }
    }
    .padding(.vertical, GravitySpacing.space20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(GravityColor.bg)
}

#Preview("Custom inset") {
    VStack(alignment: .leading, spacing: GravitySpacing.space12) {
        ShopText("Custom 24pt inset", style: .sectionTitle)
            .padding(.leading, GravitySpacing.space24)

        ShopShelf(contentInset: GravitySpacing.space24) {
            ForEach(0..<6) { i in
                ShelfPreviewCard(index: i, width: 120, height: 120)
            }
        }
    }
    .padding(.vertical, GravitySpacing.space20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(GravityColor.bg)
}

#Preview("Mixed heights — top-aligned") {
    VStack(alignment: .leading, spacing: GravitySpacing.space12) {
        ShopText("Top-aligned mixed heights", style: .sectionTitle)
            .padding(.leading, GravitySpacing.screenMargin)

        ShopShelf {
            ForEach(0..<6) { i in
                ShelfPreviewCard(index: i, width: 140, height: i % 2 == 0 ? 180 : 140)
            }
        }
    }
    .padding(.vertical, GravitySpacing.space20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(GravityColor.bg)
}
