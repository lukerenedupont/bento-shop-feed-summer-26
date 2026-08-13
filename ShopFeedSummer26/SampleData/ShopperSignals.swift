import Foundation

/// The shopper-intent signals behind personalization, decoded from the
/// optional `signals` object in `personalized-feed.json`.
///
/// In production these come from real behavior (cart, orders, views,
/// searches); here they are authored fixtures so compartment sizing and
/// retargeting stay honest and testable. Views ask for a `SignalStrength`
/// and never read raw signal arrays, so swapping in a live source later
/// only touches this file.
struct ShopperSignals: Codable {
    struct ProductRef: Codable, Hashable {
        let merchantID: String
        let productID: Int
    }

    var cart: [ProductRef] = []
    var owned: [ProductRef] = []
    var viewed: [ProductRef] = []
    var searches: [String] = []

    static var current: ShopperSignals {
        PersonalizedFeedCatalog.current.signals ?? ShopperSignals()
    }

    /// Ordered by intent: an item in the cart outranks one you own,
    /// which outranks one you merely looked at.
    enum SignalStrength: Int, Comparable {
        case none = 0
        case viewed = 1
        case owned = 2
        case cart = 3

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    func strength(merchantID: String, productID: Int) -> SignalStrength {
        let ref = ProductRef(merchantID: merchantID, productID: productID)
        if cart.contains(ref) { return .cart }
        if owned.contains(ref) { return .owned }
        if viewed.contains(ref) { return .viewed }
        return .none
    }
}
