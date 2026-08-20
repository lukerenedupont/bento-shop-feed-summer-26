import Combine
import Foundation
import SwiftUI

enum MerchantSource: String, CaseIterable {
    case followed = "My followed shops"
    case discovery = "Top merchants (discovery)"
    case custom = "Custom handles"
}

@MainActor
final class PrototypeConfig: ObservableObject {
    static let shared = PrototypeConfig()

    @Published var merchantLimit: Int = 30
    @Published var productsPerMerchant: Int = 24

    /// Source of merchants to load.
    @Published var merchantSource: MerchantSource = .followed

    /// Specific merchant handles to load (used when source is .custom).
    @Published var merchantHandles: [String] = []

    private init() {}
}

@MainActor
final class RemoteMerchantService: ObservableObject {
    static let shared = RemoteMerchantService()

    @Published var merchants: [SampleMerchant] = []
    /// The unmodified authenticated `shopsFollowed` result. Home may publish a
    /// larger merged lookup catalog through `merchants`, but personalized
    /// destinations must keep using this relationship-backed collection.
    @Published private(set) var followedMerchants: [SampleMerchant] = []
    @Published private(set) var revision = 0
    @Published var isLoading = false
    @Published var error: String?
    @Published var needsConfiguration = false
    @Published var usingFallbackData = false

    /// Bypass live data and load from the bundled JSON snapshot.
    func loadFallbackData() {
        let local = LocalMerchantService.loadMerchants()
        guard !local.isEmpty else {
            merchants = []
            error = "Could not load bundled sample data. Make sure prototype-merchants.json is included in the app target."
            isLoading = false
            needsConfiguration = false
            usingFallbackData = false
            return
        }

        merchants = local
        followedMerchants = []
        revision += 1
        error = nil
        isLoading = false
        needsConfiguration = false
        usingFallbackData = true
    }

    func loadMerchants(force: Bool = false) async {
        guard !isLoading else { return }
        guard force || merchants.isEmpty else { return }

        isLoading = true
        error = nil
        needsConfiguration = false

        do {
            guard AuthService.shared.hasSession else {
                needsConfiguration = true
                throw ShopServerSetupError.missingAuthorization
            }
            let authorization = try await AuthService.shared.getAuthorization()

            let client = ShopServerClient(authorization: authorization)
            let config = PrototypeConfig.shared
            let shops: [ShopServerShop]

            switch config.merchantSource {
            case .followed where AuthService.shared.hasSession:
                shops = try await client.followedShops(first: config.merchantLimit)
            case .custom where !config.merchantHandles.isEmpty:
                shops = try await client.shopsByHandles(config.merchantHandles)
            default:
                shops = try await client.discoverShops(first: config.merchantLimit)
            }
            var loadedMerchants: [SampleMerchant] = []

            for shop in shops {
                let products = try await client.products(
                    brokerId: shop.id,
                    first: config.productsPerMerchant
                )
                loadedMerchants.append(Self.map(shop: shop, products: products))
            }

            let resolvedMerchants = loadedMerchants.filter { !$0.products.isEmpty }
            merchants = resolvedMerchants
            followedMerchants = config.merchantSource == .followed ? resolvedMerchants : []
            if merchants.isEmpty {
                throw ShopServerSetupError.emptyResult
            }
            usingFallbackData = false
            revision += 1
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private static func map(shop: ShopServerShop, products: [ShopServerProduct]) -> SampleMerchant {
        let colors = shop.visualTheme?.brandSettings?.colors
        let headerTheme = shop.visualTheme?.brandSettings?.headerTheme
        let logo = shop.visualTheme?.brandSettings?.logos?.logoImage?.url ?? shop.visualTheme?.logoImage?.url
        let featured = shop.visualTheme?.featuredImages.compactMap(\.url) ?? []
        let rating = shop.productReviewAnalytics?.averageRating ?? 4.8
        let totalReviews = shop.productReviewAnalytics?.totalProductReviews ?? 0
        let totalRatings = shop.productReviewAnalytics?.totalProductRatings ?? totalReviews

        return SampleMerchant(
            id: shop.id,
            name: shop.name,
            description: shop.visualTheme?.description ?? "",
            rating: rating,
            totalRatings: totalRatings,
            totalReviews: totalReviews,
            primaryColor: Color(hex: colors?.primary ?? colors?.logoDominant ?? "#5433EB"),
            secondaryColor: Color(hex: colors?.secondary ?? "#111111"),
            collections: shop.navigationItems.map { item in
                SampleMerchant.Collection(
                    id: item.id,
                    name: item.title,
                    imageURL: item.heroImage?.url
                )
            },
            products: products.map { product in
                let imageURLs = product.images.compactMap(\.url)
                return SampleMerchant.Product(
                    id: stableProductId(product.id),
                    title: product.title,
                    price: product.price.amount,
                    handle: product.slug,
                    productType: nil,
                    vendor: shop.name,
                    imageURL: imageURLs.first,
                    shopURL: product.url,
                    tags: [],
                    allImageURLs: imageURLs,
                    currencyCode: product.price.currencyCode,
                    productDescription: product.description
                )
            },
            featuredImageURLs: featured,
            logoImageURL: logo,
            wordmarkImageURL: headerTheme?.wordmark?.url,
            coverImageURL: headerTheme?.coverImage?.url ?? headerTheme?.thumbnailImage?.url,
            videoURL: headerTheme?.videoUrl,
            coverDominantColor: colors?.coverDominant,
            productCategory: shop.navigationItems.first?.title
        )
    }

    private static func stableProductId(_ id: String) -> Int {
        if let numeric = Int(id.split(separator: "/").last ?? "") {
            return numeric
        }

        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(Int.max))
    }
}

private enum ShopServerSetupError: LocalizedError {
    case missingAuthorization
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .missingAuthorization:
            return "Sign in with your Shop account to load live merchant data, or continue with sample data."
        case .emptyResult:
            return "Shop Server returned no stores with products. Try signing in again."
        }
    }
}
