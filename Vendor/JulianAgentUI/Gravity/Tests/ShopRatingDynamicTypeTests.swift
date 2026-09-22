import SwiftUI
import Testing
import UIKit
@testable import Gravity

@MainActor
struct ShopRatingDynamicTypeTests {
    private static let measurementTolerance: CGFloat = 0.5

    @Test
    func fixedRatingStarsKeepTheirSizeAtAccessibilityTextSizes() {
        let standardSize = measuredSize(
            ShopRatingStars(rating: 4.3, size: 12),
            dynamicTypeSize: .large
        )
        let accessibilitySize = measuredSize(
            ShopRatingStars(rating: 4.3, size: 12),
            dynamicTypeSize: .accessibility5
        )

        #expect(approximatelyEqual(standardSize.width, accessibilitySize.width))
        #expect(approximatelyEqual(standardSize.height, accessibilitySize.height))
    }

    @Test
    func scaledRatingStarsGrowWithAccessibilityTextSizes() {
        let standardSize = measuredSize(
            ShopRatingStars(rating: 4.3, size: 12, relativeTo: .caption),
            dynamicTypeSize: .large
        )
        let accessibilitySize = measuredSize(
            ShopRatingStars(rating: 4.3, size: 12, relativeTo: .caption),
            dynamicTypeSize: .accessibility5
        )

        #expect(accessibilitySize.width > standardSize.width)
        #expect(accessibilitySize.height > standardSize.height)
        #expect(approximatelyEqual(accessibilitySize.width, accessibilitySize.height * 5))
    }

    @Test
    func compactRatingCanScaleItsStarWithCaptionText() {
        let fixedSize = measuredSize(
            ShopCompactRating(
                rating: ShopProductCardRating(average: 4.8),
                textStyle: .captionBold
            ),
            dynamicTypeSize: .accessibility5
        )
        let scaledSize = measuredSize(
            ShopCompactRating(
                rating: ShopProductCardRating(average: 4.8),
                textStyle: .captionBold,
                relativeTo: .caption
            ),
            dynamicTypeSize: .accessibility5
        )

        #expect(scaledSize.width > fixedSize.width)
        #expect(scaledSize.height >= fixedSize.height)
    }

    @Test
    func compactRatingLabelCanScaleItsStarWithBodyText() {
        let fixedSize = measuredSize(
            ShopCompactRatingLabel("5", textStyle: .bodyTitleSmall),
            dynamicTypeSize: .accessibility5
        )
        let scaledSize = measuredSize(
            ShopCompactRatingLabel(
                "5",
                textStyle: .bodyTitleSmall,
                relativeTo: .body
            ),
            dynamicTypeSize: .accessibility5
        )

        #expect(scaledSize.width > fixedSize.width)
        #expect(scaledSize.height >= fixedSize.height)
    }

    @Test
    func ratingViewScalesItsStarsAtAccessibilityTextSizes() {
        let fixedSize = measuredSize(
            ShopRatingView(rating: ShopProductCardRating(average: 4.3), size: 12)
                .fixedSize(),
            dynamicTypeSize: .accessibility5
        )
        let scaledSize = measuredSize(
            ShopRatingView(rating: ShopProductCardRating(average: 4.3), size: 12, relativeTo: .caption)
                .fixedSize(),
            dynamicTypeSize: .accessibility5
        )

        #expect(scaledSize.width > fixedSize.width)
        #expect(scaledSize.height > fixedSize.height)
    }

    private func measuredSize<Content: View>(
        _ content: Content,
        dynamicTypeSize: DynamicTypeSize
    ) -> CGSize {
        let controller = UIHostingController(
            rootView: AnyView(
                content.environment(\.dynamicTypeSize, dynamicTypeSize)
            )
        )

        return controller.sizeThatFits(
            in: CGSize(width: 1_000, height: 1_000)
        )
    }

    private func approximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) <= Self.measurementTolerance
    }
}
