@testable import Gravity
import Testing

struct ShopReviewStarsInputTests {
    @Test
    func formatsLocalizedSingularStarLabel() {
        #expect(shopReviewStarAccessibilityLabel(rating: 1) == "Rate 1 star")
    }

    @Test
    func formatsLocalizedPluralStarLabel() {
        #expect(shopReviewStarAccessibilityLabel(rating: 3) == "Rate 3 stars")
    }
}
