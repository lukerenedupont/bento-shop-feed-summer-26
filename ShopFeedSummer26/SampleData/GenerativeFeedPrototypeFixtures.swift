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
        .init(
            id: "coffee-direction", kind: .broadJourney,
            summary: "Demo search: coffee tools; no counter-versus-commute preference yet.",
            products: [], merchantID: "fellow", worldID: "prototype-coffee",
            groups: [
                .init(id: "counter", title: "At the counter", context: "Take time over the first cup.", merchantID: "fellow", products: [
                    .init(merchantID: "fellow", productID: 7507479003236),
                    .init(merchantID: "fellow", productID: 2055410221171),
                ]),
                .init(id: "commute", title: "Out the door", context: "Bring your coffee with you.", merchantID: "fellow", products: [
                    .init(merchantID: "fellow", productID: 4807420739684),
                ]),
            ]
        ),
        .init(
            id: "home-merchants", kind: .aestheticAffinity,
            summary: "Demo affinity: repeatedly saves sculptural furniture and material-led home objects.",
            products: [], merchantID: "forom",
            groups: [
                .init(id: "forom", title: "Forom", context: "Sculptural furniture and objects selected for material presence.", merchantID: "forom", products: [
                    .init(merchantID: "forom", productID: 9080102322307),
                    .init(merchantID: "forom", productID: 8817998889091),
                ]),
                .init(id: "house-of-leon", title: "House of Leon", context: "Furniture informed by travel, natural materials, and enduring forms.", merchantID: "house-of-leon", products: [
                    .init(merchantID: "house-of-leon", productID: 7873592688813),
                    .init(merchantID: "house-of-leon", productID: 7014265454765),
                ]),
                .init(id: "lichen", title: "Lichen", context: "New York furniture, editions, and found design with a resourceful point of view.", merchantID: "lichen", products: [
                    .init(merchantID: "lichen", productID: 12518383059262),
                    .init(merchantID: "lichen", productID: 12462683128126),
                ]),
            ]
        ),
    ]
}
