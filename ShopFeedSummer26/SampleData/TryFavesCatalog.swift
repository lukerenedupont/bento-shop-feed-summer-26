import Foundation

/// FASHN's garment slot. Raw values are the exact strings the
/// `fal-ai/fashn/tryon/v1.6` API accepts for `category`.
enum TryOnGarmentCategory: String, Codable, CaseIterable {
    case tops
    case bottoms
    case onePieces = "one-pieces"

    var railTitle: String {
        switch self {
        case .tops: "Select a top"
        case .bottoms: "Select bottoms"
        case .onePieces: "Select a one-piece"
        }
    }
}

/// How the source product photo frames the garment. Raw values are the exact
/// strings the FASHN API accepts for `garment_photo_type`. Catalog photography
/// in the bundled shelves is mixed, so `.auto` is the honest default; authored
/// overrides exist where the framing is known.
enum TryOnGarmentPhotoType: String, Codable {
    case auto
    case flatLay = "flat-lay"
    case model
}

/// One try-on-ready garment, normalized from the shopper's saved products:
/// the exact variant identifier, the image the generator will dress the
/// avatar with, its FASHN category, and the photo framing.
struct TryOnGarment: Identifiable, Hashable {
    /// The exact Shop variant in `gid` form. The bundled prototype catalog is
    /// product-grained — each record's image already shows one specific
    /// variant — so the product ID doubles as the variant ID here. A live
    /// integration would substitute the true `ProductVariant` gid.
    let variantID: String
    let title: String
    let shop: String
    let price: String
    let imageURL: String
    let category: TryOnGarmentCategory
    let photoType: TryOnGarmentPhotoType
    let merchantID: String
    let productID: Int

    var id: String { variantID }
}

/// The authored garment set for the Try your faves world: apparel pulled from
/// the buyer's saved-product shelves and normalized for FASHN. Curation is
/// explicit — shelf data has no product taxonomy, and keyword guesses drag in
/// dog beds ("Ripstop") and watches ("Stainless STEEl"), so every entry names
/// its category by hand.
@MainActor
enum TryFavesCatalog {
    private struct Reference {
        let merchantID: String
        let productID: Int
        let category: TryOnGarmentCategory
        var photoType: TryOnGarmentPhotoType = .auto
    }

    private static let references: [Reference] = [
        // Tops
        Reference(merchantID: "shelf-shop-wicked-clothes-45c0043", productID: 3_412_777_982_406_864_989, category: .tops),
        Reference(merchantID: "shelf-shop-comfrt-6d9274b", productID: 8_836_003_514_488_376_238, category: .tops),
        Reference(merchantID: "shelf-shop-skims-ea54323", productID: 8_688_619_307_981_730_890, category: .tops),
        Reference(merchantID: "shelf-shop-maison-martineau-3ec1c45", productID: 1_778_353_368_178_203_614, category: .tops),
        Reference(merchantID: "shelf-shop-dover-street-market-london-6ae9cc9", productID: 7_653_383_194_154_608_404, category: .tops),
        Reference(merchantID: "shelf-shop-madhappy-063b805", productID: 938_284_826_115_102_395, category: .tops),
        // Bottoms
        Reference(merchantID: "shelf-shop-manmade-83eea37", productID: 2_927_149_863_966_340_124, category: .bottoms),
        Reference(merchantID: "shelf-shop-everlane-6fc9aaf", productID: 1_008_974_818_049_996_062, category: .bottoms),
        Reference(merchantID: "shelf-shop-percival-menswear-326f72a", productID: 500_080_131_239_668_559, category: .bottoms),
        Reference(merchantID: "shelf-shop-state-and-liberty-clothing-company-72d72a8", productID: 11_648_765_413_713_573, category: .bottoms),
        Reference(merchantID: "shelf-shop-bearbottom-clothing-fc2dbc3", productID: 7_842_330_081_293_745_106, category: .bottoms),
        Reference(merchantID: "shelf-shop-unbound-merino-191f851", productID: 7_349_694_584_695_230_143, category: .bottoms),
        // One-pieces
        Reference(merchantID: "shelf-shop-solid-striped-81de82d", productID: 2_744_348_685_090_419_915, category: .onePieces),
    ]

    static let garments: [TryOnGarment] = {
        let merchants = HypothesisShelfCatalog.merchants
        return references.compactMap { reference in
            guard let merchant = merchants.first(where: { $0.id == reference.merchantID }),
                  let product = merchant.products.first(where: { $0.id == reference.productID }),
                  let imageURL = product.imageURL else {
                return nil
            }
            return TryOnGarment(
                variantID: "gid://shopify/ProductVariant/\(product.id)",
                title: product.title,
                shop: merchant.displayName,
                price: product.price,
                imageURL: imageURL,
                category: reference.category,
                photoType: reference.photoType,
                merchantID: reference.merchantID,
                productID: reference.productID
            )
        }
    }()

    static func garments(in category: TryOnGarmentCategory) -> [TryOnGarment] {
        garments.filter { $0.category == category }
    }

    static func garment(for variantID: String) -> TryOnGarment? {
        garments.first { $0.variantID == variantID }
    }
}

/// A valid outfit selection: either separates or a one-piece. The generator
/// applies bottoms first, then the top onto the intermediate render, so the
/// upper layer occludes naturally at the waist.
enum TryFavesOutfit: Hashable {
    case separates(top: TryOnGarment, bottom: TryOnGarment)
    case onePiece(TryOnGarment)

    /// Variant IDs in generation order. This ordered list is part of the
    /// render cache key, so the same selection never generates twice.
    var orderedVariantIDs: [String] {
        switch self {
        case let .separates(top, bottom): [bottom.variantID, top.variantID]
        case let .onePiece(garment): [garment.variantID]
        }
    }

    var garments: [TryOnGarment] {
        switch self {
        case let .separates(top, bottom): [top, bottom]
        case let .onePiece(garment): [garment]
        }
    }
}
