import Foundation
import SwiftUI

/// Rich horizontal product-card metadata with a bottom-aligned footer.
///
/// Use this for product detail/list row patterns where title/rating/price sit at
/// the top/leading side and merchant or offer context sits at the bottom. Keep
/// navigation, tracking, and feature actions in feature wrappers.
public struct ShopProductCardRichMetadata<Footer: View>: View {
    private let title: String?
    private let rating: ShopProductCardRating?
    private let price: String?
    private let originalPrice: String?
    private let priceRange: String?
    private let titleLineLimit: Int?
    private let style: ShopProductCardMetadataStyle
    private let footer: Footer

    public init(
        title: String? = nil,
        rating: ShopProductCardRating? = nil,
        price: String? = nil,
        originalPrice: String? = nil,
        priceRange: String? = nil,
        titleLineLimit: Int? = 2,
        style: ShopProductCardMetadataStyle = ShopProductCardMetadataStyle(),
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.rating = rating
        self.price = price
        self.originalPrice = originalPrice
        self.priceRange = priceRange
        self.titleLineLimit = titleLineLimit
        self.style = style
        self.footer = footer()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space4) {
            VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                if let title, title.isEmpty == false {
                    // Merchant content: product titles are translatable on-device.
                    ShopTranslatableText(title, style: .captionBold, color: style.primaryTextColor)
                        .lineLimit(titleLineLimit)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                        .padding(.top, GravitySpacing.space2)
                }

                if let rating {
                    ShopRatingView(
                        rating: rating,
                        fillColor: style.starFillColor,
                        countColor: style.primaryTextColor
                    )
                    .padding(.top, GravitySpacing.space2)
                }

                if let priceRange, priceRange.isEmpty == false {
                    ShopText(priceRange, style: .captionBold, color: style.primaryTextColor)
                        .lineLimit(2)
                } else if let price, price.isEmpty == false {
                    ShopPriceLabel(
                        price: price,
                        originalPrice: originalPrice,
                        isDiscounted: originalPrice != nil,
                        priceColor: style.primaryTextColor,
                        originalPriceColor: style.tertiaryTextColor
                    )
                    .padding(.top, GravitySpacing.space2)
                }
            }
            .padding(.bottom, GravitySpacing.space20)

            Spacer(minLength: GravitySpacing.space4)

            footer
        }
        .padding(.vertical, GravitySpacing.space4)
        .padding(.leading, GravitySpacing.space4)
        .padding(.trailing, GravitySpacing.space10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

public extension ShopProductCardRichMetadata where Footer == EmptyView {
    init(
        title: String? = nil,
        rating: ShopProductCardRating? = nil,
        price: String? = nil,
        originalPrice: String? = nil,
        priceRange: String? = nil,
        titleLineLimit: Int? = 2,
        style: ShopProductCardMetadataStyle = ShopProductCardMetadataStyle()
    ) {
        self.init(
            title: title,
            rating: rating,
            price: price,
            originalPrice: originalPrice,
            priceRange: priceRange,
            titleLineLimit: titleLineLimit,
            style: style,
            footer: { EmptyView() }
        )
    }
}

/// Bottom row for rich product-card metadata.
///
/// This mirrors ProductDetails-style rows: merchant identity on the leading side
/// and compact rating or a badge-like trailing affordance on the trailing side.
public struct ShopProductCardMerchantFooter<Trailing: View>: View {
    private let merchantName: String
    private let avatar: AnyView?
    private let trailing: Trailing

    public init<ShopAvatar: View>(
        merchantName: String,
        @ViewBuilder avatar: () -> ShopAvatar,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.merchantName = merchantName
        self.avatar = AnyView(avatar())
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: GravitySpacing.space4) {
            HStack(alignment: .center, spacing: GravitySpacing.space8) {
                if let avatar {
                    avatar
                }

                ShopText(merchantName, style: .badgeBold)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
    }
}

public extension ShopProductCardMerchantFooter where Trailing == EmptyView {
    init<ShopAvatar: View>(
        merchantName: String,
        @ViewBuilder avatar: () -> ShopAvatar
    ) {
        self.init(
            merchantName: merchantName,
            avatar: avatar,
            trailing: { EmptyView() }
        )
    }
}

public extension ShopProductCardMerchantFooter where Trailing == ShopProductCardCompactRating {
    init<ShopAvatar: View>(
        merchantName: String,
        shopRating: ShopProductCardRating,
        @ViewBuilder avatar: () -> ShopAvatar
    ) {
        self.init(
            merchantName: merchantName,
            avatar: avatar,
            trailing: {
                ShopProductCardCompactRating(rating: shopRating)
            }
        )
    }
}

public struct ShopProductCardCompactRating: View {
    private let rating: ShopProductCardRating
    private let starFillColor: Color
    private let countColor: Color

    public init(
        rating: ShopProductCardRating,
        starFillColor: Color = GravityColor.iconStars,
        countColor: Color = GravityColor.textTertiary
    ) {
        self.rating = rating
        self.starFillColor = starFillColor
        self.countColor = countColor
    }

    public var body: some View {
        ShopCompactRating(
            rating: rating,
            textStyle: .badge,
            starColor: starFillColor,
            countColor: countColor
        )
    }
}
