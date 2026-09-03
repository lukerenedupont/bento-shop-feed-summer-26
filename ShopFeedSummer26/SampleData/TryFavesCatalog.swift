import Foundation

/// The garment slot a product occupies in the composer. Tops and bottoms map
/// straight onto FASHN's `category` values; footwear renders through a
/// nano-banana edit pass instead, because FASHN v1.6 has no shoe support.
enum TryOnGarmentCategory: String, Codable, CaseIterable {
    case tops
    case bottoms
    case footwear

    var railTitle: String {
        switch self {
        case .tops: "Select a top"
        case .bottoms: "Select bottoms"
        case .footwear: "Select shoes"
        }
    }

    /// Position in a look's product list: top, bottoms, then shoes.
    var displayRank: Int {
        switch self {
        case .tops: 0
        case .bottoms: 1
        case .footwear: 2
        }
    }
}

/// How the source product photo frames the garment. Raw values are the exact
/// strings the FASHN API accepts for `garment_photo_type`. Merchant PDP
/// heroes are a mix of model shots and flat-lays, so `.auto` is the default.
enum TryOnGarmentPhotoType: String, Codable {
    case auto
    case flatLay = "flat-lay"
    case model
}

/// One try-on-ready product: the exact Shop variant, the image the generator
/// works from, and display metadata for the composer and look panels.
struct TryOnGarment: Identifiable, Hashable {
    /// The exact Shop variant in `gid` form, taken from the shop.app link's
    /// `variantId`. Links shared without one fall back to the product ID.
    let variantID: String
    let title: String
    let shop: String
    /// Price as shown on shop.app, currency symbol included.
    let displayPrice: String
    let imageURL: String
    let category: TryOnGarmentCategory
    var photoType: TryOnGarmentPhotoType = .auto
    let productID: Int

    var id: String { variantID }
}

extension TryOnGarment {
    /// The garment as a product the PDP can render. Try Faves garments are
    /// authored against live shop.app listings rather than `SampleMerchant`,
    /// so they open through `ProductPage`'s agent-product seam.
    var agentProduct: AgentProduct {
        let image = URL(string: imageURL)
        return AgentProduct(
            id: variantID,
            title: title,
            price: displayPrice,
            originalPrice: nil,
            imageURL: image,
            allImageURLs: [image].compactMap { $0 },
            rating: nil,
            ratingCount: nil,
            shopName: shop,
            shopLogoURL: nil,
            descriptors: [],
            labels: []
        )
    }
}

/// The authored product set for the Try your faves composer — a hardcoded
/// selection of shop.app products (tops, bottoms, shoes), resolved to exact
/// variants and public CDN imagery. Regenerate entries by re-running the
/// shop.app link resolution against a new list.
@MainActor
enum TryFavesCatalog {
    private typealias Garment = TryOnGarment

    static let garments: [TryOnGarment] = [
        // Shoes
        Garment(
            variantID: "gid://shopify/ProductVariant/48213838069992",
            title: "Diemme Licata Dark Green Crackled Patent Leather",
            shop: "Très Bien",
            displayPrice: "€430",
            imageURL: "https://cdn.shopify.com/s/files/1/0686/0570/6472/files/Footwear_260410_017.jpg?width=1200",
            category: .footwear,
            productID: 9_367_370_596_584
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/47537177690443",
            title: "Camion Boots in Black",
            shop: "Stoy",
            displayPrice: "€554.95",
            imageURL: "https://cdn.shopify.com/s/files/1/0564/0978/4482/files/OURLEGACY_2006135020232_1.jpg?width=1200",
            category: .footwear,
            productID: 8_796_514_615_627
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/52171670651213",
            title: "Townee Penny Loafer",
            shop: "VINNY's",
            displayPrice: "€349",
            imageURL: "https://cdn.shopify.com/s/files/1/0575/2147/1683/files/Townee_BlackPolido.jpg?width=1200",
            category: .footwear,
            productID: 10_196_296_171_853
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/9374364369128",
            title: "Nike Pegasus Premium Natural / Mushroom",
            shop: "Très Bien",
            displayPrice: "€147",
            imageURL: "https://cdn.shopify.com/s/files/1/0686/0570/6472/files/Footwear_260410_009.jpg?width=1200",
            category: .footwear,
            productID: 9_374_364_369_128
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/56298727342411",
            title: "Heel Drop Racer Completely Black",
            shop: "Martin Sallières",
            displayPrice: "€295",
            imageURL: "https://cdn.shopify.com/s/files/1/0976/8979/6939/files/AW26_Racer_Black_1.jpg?width=1200",
            category: .footwear,
            productID: 15_473_933_058_379
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/9542905987356",
            title: "Tricker's Tramping Boot - Black Repello Suede",
            shop: "evan kinori",
            displayPrice: "€651.95",
            imageURL: "https://cdn.shopify.com/s/files/1/0769/8094/5180/files/EK_ECOM-AW24-1118_1f27cc53-1c2c-4921-ab94-466ef0dca183.jpg?width=1200",
            category: .footwear,
            productID: 9_542_905_987_356
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/9188367761631",
            title: "Spade Boot - Black Scotch Grain Leather",
            shop: "James Coward",
            displayPrice: "€696.95",
            imageURL: "https://cdn.shopify.com/s/files/1/0675/7217/0975/files/DSC04384.jpg?width=1200",
            category: .footwear,
            productID: 9_188_367_761_631
        ),

        // Tops
        Garment(
            variantID: "gid://shopify/ProductVariant/7109448564818",
            title: "Municipal T-Shirt - White",
            shop: "LADY WHITE CO.",
            displayPrice: "€84.95",
            imageURL: "https://cdn.shopify.com/s/files/1/0063/8094/5490/files/LW102-MUNICIPAL-T-SHIRT-WHITE-1.jpg?width=1200",
            category: .tops,
            productID: 7_109_448_564_818
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/53406670946635",
            title: "Auralee Washed Finx Twill Big Shirt Light Khaki",
            shop: "SOLAR MTP",
            displayPrice: "€396.66",
            imageURL: "https://cdn.shopify.com/s/files/1/0560/4481/4451/files/AURALEE_WASHED_FINX_TWILL_BIG_SHIRT_LIGHT_KHAKI_1.jpg?width=1200",
            category: .tops,
            productID: 14_793_905_865_035
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/57776192389451",
            title: "Cotton Silk Stripe Shirt in Sax Blue Stripe",
            shop: "Stoy",
            displayPrice: "€437.95",
            imageURL: "https://cdn.shopify.com/s/files/1/0564/0978/4482/files/AURALEE_21_1226040005310_1.jpg?width=1200",
            category: .tops,
            productID: 15_848_515_600_715
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/52596726464801",
            title: "Our Legacy Rascal Hood Purple",
            shop: "ESSXNYC",
            displayPrice: "€265.95",
            imageURL: "https://cdn.shopify.com/s/files/1/0747/7205/4305/files/ESSX_OUR_SS26_M2266RA_PURPLE_2_front_apparel.jpg?width=1200",
            category: .tops,
            productID: 10_327_215_964_449
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/9077973287144",
            title: "Acne Studios 1996 T-shirt Dusty White",
            shop: "Très Bien",
            displayPrice: "€290",
            imageURL: "https://cdn.shopify.com/s/files/1/0686/0570/6472/files/Acne_Studios_260515_014.jpg?width=1200",
            category: .tops,
            productID: 9_077_973_287_144
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/10326297215303",
            title: "Loam Fleece Jacket",
            shop: "Portal®",
            displayPrice: "€200",
            imageURL: "https://cdn.shopify.com/s/files/1/0844/8114/7207/files/PORTALFLATSAW25-3_700a0268-e92b-4ac3-bbe7-c4bbab3fe048.webp?width=1200",
            category: .tops,
            productID: 10_326_297_215_303
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/51857635279129",
            title: "Gnorda Dyneema Breaker Wind Shirt",
            shop: "gnuhr",
            displayPrice: "€305.95",
            imageURL: "https://cdn.shopify.com/s/files/1/0830/8863/8233/files/1.gnuhrflatJan20260252-Photoroom.png?width=1200",
            category: .tops,
            photoType: .flatLay,
            productID: 10_239_728_648_473
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/8578371551516",
            title: "Hooded Sweatshirt - Faded Black",
            shop: "evan kinori",
            displayPrice: "€214.95",
            imageURL: "https://cdn.shopify.com/s/files/1/0769/8094/5180/files/UO6Z0016.jpg?width=1200",
            category: .tops,
            productID: 8_578_371_551_516
        ),

        // Bottoms
        Garment(
            variantID: "gid://shopify/ProductVariant/50138283835685",
            title: "Hard Twist Denim Wide Pants - Indigo",
            shop: "Canoe Club",
            displayPrice: "€393.95",
            imageURL: "https://cdn.shopify.com/s/files/1/1640/7655/files/auralee-hard-twist-denim-wide-pants-indigo-1_3d86aea7-cec6-4497-9171-465e57ac14d9.jpg?width=1200",
            category: .bottoms,
            productID: 9_750_138_945_829
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/46425403916520",
            title: "Auralee Hard Twist Denim Wide Pants Indigo",
            shop: "Très Bien",
            displayPrice: "€395",
            imageURL: "https://cdn.shopify.com/s/files/1/0686/0570/6472/files/Auralee_250926_068.jpg?width=1200",
            category: .bottoms,
            productID: 8_863_730_794_728
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/15371923685700",
            title: "Commission Chino - Stonewashed Sand",
            shop: "mfpen",
            displayPrice: "€310",
            imageURL: "https://cdn.shopify.com/s/files/1/1233/8898/files/Comission-Chino_Stonewashed-Sand_2357.jpg?width=1200",
            category: .bottoms,
            productID: 15_371_923_685_700
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/15371924013380",
            title: "Straight Cut Jeans - Vintage Blue",
            shop: "mfpen",
            displayPrice: "€310",
            imageURL: "https://cdn.shopify.com/s/files/1/1233/8898/files/Straight-Cut-Jeans_Vintage-Blue_2069.jpg?width=1200",
            category: .bottoms,
            productID: 15_371_924_013_380
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/9457888166120",
            title: "Gramicci Pant Bark Pigment",
            shop: "Très Bien",
            displayPrice: "€110",
            imageURL: "https://cdn.shopify.com/s/files/1/0686/0570/6472/files/Gramicci_260428_011.jpg?width=1200",
            category: .bottoms,
            productID: 9_457_888_166_120
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/6637161185382",
            title: "105 Standard Denim - 90's Sky Blue",
            shop: "Canoe Club",
            displayPrice: "€295.95",
            imageURL: "https://cdn.shopify.com/s/files/1/1640/7655/files/orslow-105-90s-standard-denim-sky-blue-1.jpg?width=1200",
            category: .bottoms,
            productID: 6_637_161_185_382
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/8578347204892",
            title: "Single Pleat Pant - Tumbled Hemp Canvas",
            shop: "evan kinori",
            displayPrice: "€389.95",
            imageURL: "https://cdn.shopify.com/s/files/1/0769/8094/5180/files/EK_ECOM-AW24-074_f1db62fc-eecc-48e8-a627-a328b9c9ea94.jpg?width=1200",
            category: .bottoms,
            productID: 8_578_347_204_892
        ),
        Garment(
            variantID: "gid://shopify/ProductVariant/8970608902367",
            title: "Carpenter Jean - Black Bio Wash",
            shop: "James Coward",
            displayPrice: "€315.95",
            imageURL: "https://cdn.shopify.com/s/files/1/0675/7217/0975/files/CARPENTER-BLACKBIO_01.jpg?width=1200",
            category: .bottoms,
            productID: 8_970_608_902_367
        ),
    ]

    static func garments(in category: TryOnGarmentCategory) -> [TryOnGarment] {
        garments.filter { $0.category == category }
    }

    static func garment(for variantID: String) -> TryOnGarment? {
        garments.first { $0.variantID == variantID }
    }

    /// The outfit the seed avatar is photographed wearing. The home card and
    /// the first page of the experience present it as a pre-generated look.
    static let seedLookVariantIDs = [
        "gid://shopify/ProductVariant/7109448564818",   // Municipal T-Shirt - White
        "gid://shopify/ProductVariant/50138283835685",  // Hard Twist Denim Wide Pants
        "gid://shopify/ProductVariant/52171670651213",  // Townee Penny Loafer
    ]

    static var seedLookGarments: [TryOnGarment] {
        seedLookVariantIDs.compactMap(garment(for:))
    }
}

/// A valid outfit selection: a top-and-bottoms pairing with optional shoes,
/// or shoes alone on the already-dressed seed avatar. Generation order is
/// bottoms → top → shoes, so each layer composites onto the previous result.
enum TryFavesOutfit: Hashable {
    case separates(top: TryOnGarment, bottom: TryOnGarment, shoes: TryOnGarment?)
    case shoesOnly(TryOnGarment)

    /// Variant IDs in generation order. This ordered list is part of the
    /// render cache key, so the same selection never generates twice.
    var orderedVariantIDs: [String] {
        switch self {
        case let .separates(top, bottom, shoes):
            [bottom.variantID, top.variantID] + (shoes.map { [$0.variantID] } ?? [])
        case let .shoesOnly(garment):
            [garment.variantID]
        }
    }

    var garments: [TryOnGarment] {
        switch self {
        case let .separates(top, bottom, shoes):
            [top, bottom] + (shoes.map { [$0] } ?? [])
        case let .shoesOnly(garment):
            [garment]
        }
    }
}
