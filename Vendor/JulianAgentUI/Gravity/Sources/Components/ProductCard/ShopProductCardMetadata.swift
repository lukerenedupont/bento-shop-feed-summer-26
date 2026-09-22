import SwiftUI

public struct ShopProductCardMetadataStyle {
    public var primaryTextColor: Color
    public var secondaryTextColor: Color
    public var tertiaryTextColor: Color
    public var priceTextColor: Color?
    public var starFillColor: Color

    public init(
        primaryTextColor: Color = GravityColor.text,
        secondaryTextColor: Color = GravityColor.textSecondary,
        tertiaryTextColor: Color = GravityColor.textTertiary,
        priceTextColor: Color? = nil,
        starFillColor: Color = GravityColor.iconStars
    ) {
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.tertiaryTextColor = tertiaryTextColor
        self.priceTextColor = priceTextColor
        self.starFillColor = starFillColor
    }
}

/// Canonical product-card metadata stack.
///
/// Mirrors ShopProductCard's constrained RN slots without carrying feature models or
/// interaction logic into `Gravity`.
public struct ShopProductCardMetadata: View {
    private let shopName: String?
    private let title: String?
    private let rating: ShopProductCardRating?
    private let price: String?
    private let originalPrice: String?
    private let variantTitle: String?
    private let lastPurchasedText: String?
    private let titleLineLimit: Int?
    private let ratingStarsRelativeTextStyle: Font.TextStyle?
    private let style: ShopProductCardMetadataStyle

    public init(
        shopName: String? = nil,
        title: String? = nil,
        rating: ShopProductCardRating? = nil,
        price: String? = nil,
        originalPrice: String? = nil,
        variantTitle: String? = nil,
        lastPurchasedText: String? = nil,
        titleLineLimit: Int? = 1,
        ratingStarsRelativeTo textStyle: Font.TextStyle? = nil,
        style: ShopProductCardMetadataStyle = ShopProductCardMetadataStyle()
    ) {
        self.shopName = shopName
        self.title = title
        self.rating = rating
        self.price = price
        self.originalPrice = originalPrice
        self.variantTitle = variantTitle
        self.lastPurchasedText = lastPurchasedText
        self.titleLineLimit = titleLineLimit
        self.ratingStarsRelativeTextStyle = textStyle
        self.style = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space2) {
            if let shopName, shopName.isEmpty == false {
                ShopText(shopName, style: .caption, color: style.secondaryTextColor)
                    .lineLimit(1)
            }

            if let title, title.isEmpty == false {
                // Merchant content: product titles are translatable on-device.
                ShopTranslatableText(title, style: .captionBold, color: style.primaryTextColor)
                    .lineLimit(titleLineLimit)
            }

            if let rating {
                ShopRatingView(
                    rating: rating,
                    fillColor: style.starFillColor,
                    countColor: style.primaryTextColor,
                    relativeTo: ratingStarsRelativeTextStyle
                )
                .padding(.top, GravitySpacing.space2)
            }

            if let price, price.isEmpty == false {
                ShopPriceLabel(
                    price: price,
                    originalPrice: originalPrice,
                    isDiscounted: originalPrice != nil,
                    priceColor: style.priceTextColor ?? style.primaryTextColor,
                    originalPriceColor: style.tertiaryTextColor,
                    lineLimit: 1
                )
                .padding(.top, GravitySpacing.space2)
            }

            if let variantTitle, variantTitle.isEmpty == false {
                // Merchant content: variant titles are translatable on-device.
                ShopTranslatableText(variantTitle, style: .caption, color: style.secondaryTextColor)
                    .lineLimit(1)
            }

            if let lastPurchasedText, lastPurchasedText.isEmpty == false {
                ShopText(lastPurchasedText, style: .caption, color: style.primaryTextColor)
                    .lineLimit(1)
            }
        }
    }
}

#Preview("Product card metadata") {
    VStack(alignment: .leading, spacing: GravitySpacing.space16) {
        ShopProductCardMetadata(
            shopName: "Nike",
            title: "Classic Sneaker",
            rating: ShopProductCardRating(average: 4.5, count: 342),
            price: "$89.99",
            originalPrice: "$120.00",
            variantTitle: "White / 10",
            lastPurchasedText: "Last purchased May 20"
        )

        ShopProductCardMetadata(
            title: "Image-only fallback title",
            price: "$120.00"
        )
    }
    .padding()
}
