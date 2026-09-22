import Foundation
import SwiftUI

public func shopReviewStarAccessibilityLabel(
    rating: Int,
    bundle: Bundle = .gravityResources,
    locale: Locale = .current
) -> String {
    let category = ShopPluralCategory.category(
        for: rating,
        localizationBundle: bundle,
        fallbackLocale: locale
    )
    return String(
        format: NSLocalizedString(
            "Reviews.RateInput.RateStars.\(category.rawValue)",
            bundle: bundle,
            comment: "Accessibility label for an individual rating star."
        ),
        locale: locale,
        rating
    )
}

public struct ShopReviewStarsInput: View {
    private let value: Int
    private let starSize: CGFloat
    private let onRate: (Int) -> Void

    public init(value: Int = 0, starSize: CGFloat = 24, onRate: @escaping (Int) -> Void) {
        self.value = value
        self.starSize = starSize
        self.onRate = onRate
    }

    public var body: some View {
        HStack(spacing: GravitySpacing.space2) {
            ForEach(1 ... 5, id: \.self) { rating in
                SwiftUI.Button {
                    onRate(rating)
                } label: {
                    ShopIcon(.starFilled, pointSize: starSize, color: rating <= value ? GravityColor.iconStars : GravityColor.bgFillTertiary)
                        .frame(width: starSize + 4, height: starSize + 4)
                }
                .buttonStyle(.plain)
                // The visual value does not represent an in-place accessibility selection.
                .accessibilityLabel(SwiftUI.Text(shopReviewStarAccessibilityLabel(rating: rating)))
            }
        }
    }
}
