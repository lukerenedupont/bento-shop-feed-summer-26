import SwiftUI

public struct ShopCompactRatingLabel: View {
    private let text: String
    private let textStyle: GravityTextStyle
    private let textColor: Color
    private let starColor: Color
    private let starLeading: Bool
    private let relativeTextStyle: Font.TextStyle?

    @ScaledMetric private var scaledStarSize: CGFloat

    public init(
        _ text: String,
        textStyle: GravityTextStyle = .badge,
        relativeTo dynamicTypeTextStyle: Font.TextStyle? = nil,
        textColor: Color = GravityColor.text,
        starColor: Color = GravityColor.iconStars,
        starLeading: Bool = false
    ) {
        self.text = text
        self.textStyle = textStyle
        self.textColor = textColor
        self.starColor = starColor
        self.starLeading = starLeading
        self.relativeTextStyle = dynamicTypeTextStyle
        _scaledStarSize = ScaledMetric(
            wrappedValue: ShopIconSize.xSmall.points,
            relativeTo: dynamicTypeTextStyle ?? .body
        )
    }

    public var body: some View {
        HStack(alignment: .center, spacing: GravitySpacing.space2) {
            if starLeading {
                ShopIcon(.starFilled, pointSize: starSize, color: starColor)
            }

            ShopText(text, style: textStyle, color: textColor)
                .monospacedDigit()

            if starLeading == false {
                ShopIcon(.starFilled, pointSize: starSize, color: starColor)
            }
        }
        .accessibilityHidden(true)
    }

    private var starSize: CGFloat {
        relativeTextStyle == nil ? ShopIconSize.xSmall.points : scaledStarSize
    }
}

/// Compact rating display with a numeric rating, single star icon, and optional count.
///
/// Use this for merchant/footer-style ratings. For product review stars, use
/// `ShopRatingView` / `ShopRatingStars`, which render the five-star review pattern.
///
/// Renders the strings carried by `rating`; nothing is formatted here.
public struct ShopCompactRating: View {
    private let rating: ShopProductCardRating
    private let textStyle: GravityTextStyle
    private let textColor: Color
    private let starColor: Color
    private let countColor: Color
    private let starLeading: Bool
    private let relativeTextStyle: Font.TextStyle?

    public init(
        rating: ShopProductCardRating,
        textStyle: GravityTextStyle = .badge,
        relativeTo dynamicTypeTextStyle: Font.TextStyle? = nil,
        textColor: Color = GravityColor.text,
        starColor: Color = GravityColor.iconStars,
        countColor: Color = GravityColor.textTertiary,
        starLeading: Bool = false
    ) {
        self.rating = rating
        self.textStyle = textStyle
        self.textColor = textColor
        self.starColor = starColor
        self.countColor = countColor
        self.starLeading = starLeading
        self.relativeTextStyle = dynamicTypeTextStyle
    }

    public var body: some View {
        HStack(alignment: .center, spacing: GravitySpacing.space2) {
            ShopCompactRatingLabel(
                rating.formattedAverage,
                textStyle: textStyle,
                relativeTo: relativeTextStyle,
                textColor: textColor,
                starColor: starColor,
                starLeading: starLeading
            )

            if let formattedCount = rating.formattedCount {
                ShopText("(\(formattedCount))", style: textStyle, color: countColor)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SwiftUI.Text(rating.accessibilityLabel))
    }
}

#Preview("ShopCompactRating") {
    VStack(alignment: .leading, spacing: GravitySpacing.space12) {
        ShopCompactRating(rating: ShopProductCardRating(average: 4.8, count: 124))
        ShopCompactRating(rating: ShopProductCardRating(average: 3.7))
        ShopCompactRating(rating: ShopProductCardRating(average: 4.8, count: 12_500), relativeTo: .caption)
            .environment(\.dynamicTypeSize, .accessibility5)
        ShopCompactRating(
            rating: ShopProductCardRating(average: 5.0, count: 2_300),
            textStyle: .captionBold,
            textColor: GravityColor.text,
            starColor: GravityColor.text,
            countColor: GravityColor.textTertiary
        )
        .padding(.horizontal, GravitySpacing.space6)
        .padding(.vertical, GravitySpacing.space2)
        .background(GravityColor.bgOverlayFixedDark04)
        .clipShape(Capsule())
    }
    .padding()
    .background(GravityColor.bg)
}
