import Foundation

/// Shared price formatting used across all surfaces.
func formatPrice(_ price: String) -> String {
    if let dollars = Double(price) {
        return String(format: "$%.2f", dollars)
    }
    return "$\(price)"
}
