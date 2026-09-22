import SwiftUI

/// Displays a product price with an optional strikethrough original price.
///
/// The original price is only shown when `isDiscounted` is true, matching RN
/// ProductCardPrice behavior.
public struct ShopPriceLabel: View {
    private let price: String
    private let originalPrice: String?
    private let isDiscounted: Bool
    private let textStyle: GravityTextStyle
    private let priceColor: Color
    private let originalPriceColor: Color
    private let lineLimit: Int?

    public init(
        price: String,
        originalPrice: String? = nil,
        isDiscounted: Bool = false,
        textStyle: GravityTextStyle = .caption,
        priceColor: Color = GravityColor.text,
        originalPriceColor: Color = GravityColor.textTertiary,
        lineLimit: Int? = 2
    ) {
        self.price = price
        self.originalPrice = originalPrice
        self.isDiscounted = isDiscounted
        self.textStyle = textStyle
        self.priceColor = priceColor
        self.originalPriceColor = originalPriceColor
        self.lineLimit = lineLimit
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: GravitySpacing.space2) {
            SwiftUI.Text(price)
                .gravityTextStyle(currentPriceTextStyle, color: priceColor)
                .lineLimit(lineLimit)

            if isDiscounted, let originalPrice, originalPrice.isEmpty == false {
                SwiftUI.Text(originalPrice)
                    .gravityTextStyle(textStyle, color: originalPriceColor)
                    .strikethrough(true, color: originalPriceColor)
                    .lineLimit(lineLimit)
            }
        }
    }

    private var currentPriceTextStyle: GravityTextStyle {
        switch textStyle {
        case .caption:
            .captionBold
        case .bodySmall:
            .bodySmallBold
        case .bodyLarge:
            .bodyLarge
        default:
            textStyle
        }
    }
}

#Preview("ShopPriceLabel") {
    VStack(alignment: .leading, spacing: GravitySpacing.space12) {
        ShopPriceLabel(price: "$120.00")
        ShopPriceLabel(price: "$89.99", originalPrice: "$120.00", isDiscounted: true)
        ShopPriceLabel(
            price: "$49.99",
            originalPrice: "$99.99",
            isDiscounted: true,
            textStyle: .bodySmall,
            priceColor: GravityColor.textCritical
        )
    }
    .padding()
    .background(GravityColor.bg)
}
