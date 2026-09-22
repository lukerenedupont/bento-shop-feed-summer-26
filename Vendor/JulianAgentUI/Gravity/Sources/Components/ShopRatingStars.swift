import SwiftUI

/// Displays a fixed five-star rating with partial fill.
///
/// Mirrors RN `ReviewStars` as a read-only display primitive: callers can set
/// the rating, filled color, and rendered star size, while the empty-star color
/// and five-star shape stay consistent with Gravity.
public struct ShopRatingStars: View {
    private let rating: Double
    private let fillColor: Color
    private let size: CGFloat
    private let relativeTextStyle: Font.TextStyle?

    @ScaledMetric private var scaledSize: CGFloat

    public init(
        rating: Double,
        fillColor: Color = GravityColor.iconStars,
        size: CGFloat = 12,
        relativeTo textStyle: Font.TextStyle? = nil
    ) {
        self.rating = rating
        self.fillColor = fillColor
        self.size = size
        self.relativeTextStyle = textStyle
        _scaledSize = ScaledMetric(
            wrappedValue: size,
            relativeTo: textStyle ?? .body
        )
    }

    public var body: some View {
        HStack(spacing: .zero) {
            ForEach(0..<5, id: \.self) { index in
                RatingStarShape(
                    fillPercentage: fillPercentage(for: index),
                    fillColor: fillColor,
                    emptyColor: GravityColor.bgOverlayHighlightHover,
                    size: effectiveSize
                )
            }
        }
        .accessibilityHidden(true)
    }

    private var effectiveSize: CGFloat {
        relativeTextStyle == nil ? size : scaledSize
    }

    private var normalizedRating: Double {
        (rating * 10).rounded() / 10
    }

    private func fillPercentage(for index: Int) -> CGFloat {
        CGFloat(min(max(normalizedRating - Double(index), 0), 1))
    }
}

private struct RatingStarShape: View {
    let fillPercentage: CGFloat
    let fillColor: Color
    let emptyColor: Color
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            star(color: emptyColor)

            star(color: fillColor)
                .frame(width: size * fillPercentage, alignment: .leading)
                .clipped()
        }
        .frame(width: size, height: size)
    }

    private func star(color: Color) -> some View {
        SwiftUI.Text("★")
            .font(.system(size: size))
            .foregroundStyle(color)
            .frame(width: size, height: size, alignment: .center)
    }
}

#Preview("ShopRatingStars") {
    VStack(spacing: GravitySpacing.space16) {
        ShopRatingStars(rating: 5.0)
        ShopRatingStars(rating: 4.3)
        ShopRatingStars(rating: 3.0)
        ShopRatingStars(rating: 1.7)
        ShopRatingStars(rating: 0.0)
        ShopRatingStars(rating: 4.8, relativeTo: .caption)
            .environment(\.dynamicTypeSize, .accessibility5)
    }
    .padding()
    .background(GravityColor.bg)
}
