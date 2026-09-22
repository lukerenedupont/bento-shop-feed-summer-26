import Foundation

/// Rating string formatting. Called from models at transform time only; rating views render
/// the strings a `ShopProductCardRating` already carries.
public enum ShopRatingFormatter {
    public static func formattedRating(
        _ value: Double,
        locale: Locale = .current,
        showsTrailingZero: Bool = true
    ) -> String {
        let rounded = NSNumber(value: (value * 10).rounded() / 10)
        return ShopNumberFormatting.decimal(
            rounded,
            locale: locale,
            minimumFractionDigits: showsTrailingZero ? 1 : 0,
            maximumFractionDigits: 1
        ) ?? rounded.stringValue
    }

    /// Compact review count: floor to tenths with a K/M/B suffix (1_250 → "1.2K").
    public static func formattedCompactCount(
        _ value: Int,
        locale: Locale = .current
    ) -> String {
        let compact: (value: Double, suffix: String?)
        switch value {
        case ..<1_000:
            compact = (Double(value), nil)
        case 1_000:
            compact = (1, "K")
        case ..<1_000_000:
            compact = (floor(Double(value) / 100) / 10, "K")
        case 1_000_000:
            compact = (1, "M")
        case ..<1_000_000_000:
            compact = (floor(Double(value) / 100_000) / 10, "M")
        default:
            compact = (floor(Double(value) / 100_000_000) / 10, "B")
        }

        let number = NSNumber(value: compact.value)
        let formatted = ShopNumberFormatting.decimal(
            number,
            locale: locale,
            minimumFractionDigits: 0,
            maximumFractionDigits: compact.suffix == nil ? 0 : 1
        ) ?? number.stringValue
        return formatted + (compact.suffix ?? "")
    }

    public static func accessibilityLabel(
        formattedRating: String,
        count: Int?,
        bundle: Bundle = .gravityResources,
        locale: Locale = .current
    ) -> String {
        if let count {
            let category = ShopPluralCategory.category(
                for: count,
                localizationBundle: bundle,
                fallbackLocale: locale
            )
            let key = "Reviews.RatingSummaryOnProductCard.a11yLabel.\(category.rawValue)"
            return String(
                format: NSLocalizedString(
                    key,
                    bundle: bundle,
                    comment: "Accessibility label for product card rating with review count."
                ),
                locale: locale,
                formattedRating,
                count
            )
        }

        return String(
            format: NSLocalizedString(
                "Reviews.DisplayRating.RatedStars",
                bundle: bundle,
                comment: "Accessibility label for a rating without review count."
            ),
            locale: locale,
            formattedRating,
            5
        )
    }
}
