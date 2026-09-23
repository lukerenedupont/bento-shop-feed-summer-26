import Foundation

private enum CurrencyFormatters {
    static let values: [String: NumberFormatter] = Dictionary(uniqueKeysWithValues:
        ["USD", "CAD", "EUR", "GBP", "AUD", "TRY", "JPY", "KRW"].map { code in
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.numberStyle = .currency
            formatter.currencyCode = code
            return (code, formatter)
        }
    )
}

/// Missing amounts stay unknown; currency belongs to the product, not its view.
func formatPrice(_ price: String, currencyCode: String = "USD") -> String {
    let value = price.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return "" }
    guard let amount = Double(value), amount.isFinite else { return value }
    if let formatter = CurrencyFormatters.values[currencyCode],
       let result = formatter.string(from: NSNumber(value: amount)) {
        return result
    }
    return "\(currencyCode) \(String(format: "%.2f", amount))"
}

func formatPrice(_ product: SampleMerchant.Product) -> String {
    formatPrice(product.price, currencyCode: product.currencyCode)
}

/// Product imagery always carries a commerce affordance without fabricating
/// an amount when the source catalog did not supply one.
func productCardPriceBadge(_ product: SampleMerchant.Product) -> String {
    let price = formatPrice(product)
    return price.isEmpty ? "Price at shop" : price
}
