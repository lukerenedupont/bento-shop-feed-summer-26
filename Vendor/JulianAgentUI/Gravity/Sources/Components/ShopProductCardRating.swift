import Foundation

/// Rating presentation model. Build it at transform/model time: every string a rating view
/// renders (including the accessibility label) is formatted once here, so `ShopRatingView` /
/// `ShopCompactRating` never format. Surfaces with custom copy supply its builder at transform time.
public struct ShopProductCardRating: Hashable, Sendable {
    public let average: Double
    public let count: Int?
    public let formattedAverage: String
    public let formattedCount: String?
    public let accessibilityLabel: String

    public init(
        average: Double,
        count: Int? = nil,
        showsTrailingZero: Bool = true,
        locale: Locale = .current,
        makeAccessibilityLabel: ((String, String?) -> String)? = nil
    ) {
        self.average = average
        self.count = count
        formattedAverage = ShopRatingFormatter.formattedRating(
            average,
            locale: locale,
            showsTrailingZero: showsTrailingZero
        )
        formattedCount = count.map { ShopRatingFormatter.formattedCompactCount($0, locale: locale) }
        if let makeAccessibilityLabel {
            accessibilityLabel = makeAccessibilityLabel(formattedAverage, formattedCount)
        } else {
            accessibilityLabel = ShopRatingFormatter.accessibilityLabel(
                formattedRating: formattedAverage,
                count: count,
                locale: locale
            )
        }
    }
}
