import SwiftUI

public enum ShopProductCardLayout: Sendable {
    case vertical
    /// - Parameter scalesToFit: When `true`, the square image is capped at `imageWidth` but may
    ///   shrink below it to fit a height-constrained slot, and the metadata drops its height floor
    ///   so the row can compress instead of overflowing.
    case horizontal(imageWidth: CGFloat, spacing: CGFloat = GravitySpacing.space8, scalesToFit: Bool = false)
}

/// Presentational product card shell.
///
/// This component owns product-card layout only. Feature wrappers own
/// interaction, navigation, tracking, context menus, and data mapping. Image
/// presentation should usually be supplied with `ShopProductImageTile` so callers
/// can attach feature-specific modifiers (for example zoom transition sources)
/// to the image tile itself.
public struct ShopProductCard<ImageTile: View, Metadata: View>: View {
    private let layout: ShopProductCardLayout
    private let cardWidth: CGFloat?
    private let imageTile: ImageTile
    private let metadata: Metadata
    private let includesMetadata: Bool

    public init(
        layout: ShopProductCardLayout = .vertical,
        cardWidth: CGFloat? = nil,
        @ViewBuilder imageTile: () -> ImageTile,
        @ViewBuilder metadata: () -> Metadata
    ) {
        self.init(
            layout: layout,
            cardWidth: cardWidth,
            includesMetadata: true,
            imageTile: imageTile,
            metadata: metadata
        )
    }

    private init(
        layout: ShopProductCardLayout,
        cardWidth: CGFloat?,
        includesMetadata: Bool,
        @ViewBuilder imageTile: () -> ImageTile,
        @ViewBuilder metadata: () -> Metadata
    ) {
        self.layout = layout
        self.cardWidth = cardWidth
        self.imageTile = imageTile()
        self.metadata = metadata()
        self.includesMetadata = includesMetadata
    }

    public var body: some View {
        switch layout {
        case .vertical:
            verticalContent
        case let .horizontal(horizontalImageWidth, horizontalSpacing, horizontalScalesToFit):
            let content = horizontalContent(
                imageWidth: horizontalImageWidth,
                spacing: horizontalSpacing,
                scalesToFit: horizontalScalesToFit
            )
            if let cardWidth {
                content.frame(width: cardWidth, alignment: .topLeading)
            } else {
                content.frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    @ViewBuilder
    private var verticalContent: some View {
        let content = Group {
            if includesMetadata {
                VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                    imageTile

                    metadata
                        .padding(.horizontal, GravitySpacing.space4)
                }
            } else {
                imageTile
            }
        }

        if let cardWidth {
            content.frame(width: cardWidth, alignment: .topLeading)
        } else {
            content.frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func horizontalContent(imageWidth horizontalImageWidth: CGFloat, spacing: CGFloat, scalesToFit: Bool) -> some View {
        HStack(alignment: .center, spacing: spacing) {
            if scalesToFit {
                // Keep the thumbnail square but let it shrink below `imageWidth` when the slot is
                // height-constrained, so the row compresses instead of overflowing.
                imageTile
                    .frame(maxWidth: horizontalImageWidth, maxHeight: horizontalImageWidth)
                    .aspectRatio(1, contentMode: .fit)
            } else {
                imageTile
                    .frame(width: horizontalImageWidth, height: horizontalImageWidth)
            }

            if includesMetadata {
                metadata
                    .frame(
                        maxWidth: .infinity,
                        minHeight: scalesToFit ? nil : horizontalImageWidth,
                        maxHeight: horizontalImageWidth,
                        alignment: .leading
                    )
            }
        }
    }
}

public extension ShopProductCard where Metadata == EmptyView {
    init(
        layout: ShopProductCardLayout = .vertical,
        cardWidth: CGFloat? = nil,
        @ViewBuilder imageTile: () -> ImageTile
    ) {
        self.init(
            layout: layout,
            cardWidth: cardWidth,
            includesMetadata: false,
            imageTile: imageTile,
            metadata: { EmptyView() }
        )
    }
}

#Preview("Vertical product card") {
    ShopProductCard(cardWidth: 160) {
        ShopProductImageTile(displayWidth: 160) {
            Color.gray.opacity(0.2)
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
            title: "Classic Sneaker",
            rating: ShopProductCardRating(average: 4.5, count: 342),
            price: "$89.99",
            originalPrice: "$120.00"
        )
    }
    .padding()
}

#Preview("Horizontal product card") {
    ShopProductCard(layout: .horizontal(imageWidth: 105), cardWidth: 300) {
        ShopProductImageTile(displayWidth: 105) {
            Color.gray.opacity(0.2)
        } overlay: {
            ShopProductImageOverlayLayout {
                ShopProductImageOverlayItem(.bottomTrailing) {
                    ShopFavoriteButton(isFavorite: false)
                }
            }
        }
    } metadata: {
        ShopProductCardMetadata(
            title: "Classic Sneaker",
            rating: ShopProductCardRating(average: 4.5, count: 342),
            price: "$120.00"
        )
    }
    .padding()
}
