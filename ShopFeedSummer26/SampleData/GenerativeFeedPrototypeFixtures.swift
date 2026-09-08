import Foundation

/// PROTOTYPE: invented activity for design discussion, NOT Luke's observed
/// purchase/view history. All merchant and product references are real records.
enum GenerativeFeedPrototypeFixtures {
    static let signals: [PrototypeShoppingSignal] = [
        .init(
            id: "complete-jacket", kind: .purchase,
            summary: "Demo purchase: Nike × Stüssy Reversible Varsity Jacket from Feature.",
            products: [.init(merchantID: "feature-salomon", productID: 6882429993031)],
            merchantID: "feature-salomon"
        ),
        .init(
            id: "compare-chairs", kind: .repeatedViews,
            summary: "Demo activity: revisited three House of Leon chairs.",
            products: [
                .init(merchantID: "house-of-leon", productID: 7873592688813),
                .init(merchantID: "house-of-leon", productID: 7873592721581),
                .init(merchantID: "house-of-leon", productID: 8590788591789),
            ],
            merchantID: "house-of-leon"
        ),
        .init(
            id: "merchant-books", kind: .merchantAffinity,
            summary: "Demo affinity: follows Standards Manual and returns to design books.",
            products: [], merchantID: "standards-manual"
        ),
        .init(
            id: "living-room", kind: .activeWorld,
            summary: "Demo Living Room World: saved the Sofita Marble Coffee Table; choosing a chair next.",
            products: [.init(merchantID: "house-of-leon", productID: 7014265454765)],
            merchantID: "house-of-leon", worldID: "prototype-living-room"
        ),
    ]
}
