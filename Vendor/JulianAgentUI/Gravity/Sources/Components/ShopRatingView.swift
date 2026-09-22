import Foundation
import SwiftUI

/// A compact rating display with stars and an optional review count.
///
/// The count hides automatically when the available width is too narrow, matching
/// RN ShopProductCardRating behavior where stars are more important than truncated
/// count text.
///
/// Renders the strings carried by `rating`; nothing is formatted here.
public struct ShopRatingView: View {
    private let rating: ShopProductCardRating
    private let fillColor: Color
    private let countColor: Color
    private let size: CGFloat
    private let relativeTextStyle: Font.TextStyle?

    @ScaledMetric private var scaledSize: CGFloat
    @State private var availableWidth: CGFloat = 0

    public init(
        rating: ShopProductCardRating,
        fillColor: Color = GravityColor.iconStars,
        countColor: Color = GravityColor.text,
        size: CGFloat = 12,
        relativeTo textStyle: Font.TextStyle? = nil
    ) {
        self.rating = rating
        self.fillColor = fillColor
        self.countColor = countColor
        self.size = size
        self.relativeTextStyle = textStyle
        _scaledSize = ScaledMetric(
            wrappedValue: size,
            relativeTo: textStyle ?? .body
        )
    }

    public var body: some View {
        HStack(alignment: .center, spacing: GravitySpacing.space2) {
            ShopRatingStars(rating: rating.average, fillColor: fillColor, size: effectiveSize)

            if showsCount, let formattedCount = rating.formattedCount {
                ShopText(
                    "(\(formattedCount))",
                    style: .captionMedium,
                    color: countColor
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: RatingViewWidthPreferenceKey.self,
                    value: proxy.size.width
                )
            }
        )
        .onPreferenceChange(RatingViewWidthPreferenceKey.self) { width in
            availableWidth = width
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SwiftUI.Text(rating.accessibilityLabel))
    }

    private var effectiveSize: CGFloat {
        relativeTextStyle == nil ? size : scaledSize
    }

    private var showsCount: Bool {
        availableWidth >= effectiveSize * 10
    }
}

private struct RatingViewWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview("ShopRatingView") {
    VStack(alignment: .leading, spacing: GravitySpacing.space16) {
        ShopRatingView(rating: ShopProductCardRating(average: 4.7, count: 1_243))
        ShopRatingView(rating: ShopProductCardRating(average: 3.2, count: 56))
        ShopRatingView(rating: ShopProductCardRating(average: 4.9, count: 12_500))
        ShopRatingView(rating: ShopProductCardRating(average: 2.0))
        ShopRatingView(rating: ShopProductCardRating(average: 4.8, count: 12_500), relativeTo: .caption)
            .environment(\.dynamicTypeSize, .accessibility5)
    }
    .padding()
    .background(GravityColor.bg)
}
