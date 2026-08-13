import Foundation

actor ShopServerClient {
    private let endpoint = URL(string: "https://server.shop.app/graphql")!
    private let authorization: String
    private let sessionId: String
    private let installDeviceId: String
    private let externalDeviceId: String

    init(authorization: String) {
        self.authorization = authorization
        self.sessionId = UUID().uuidString

        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: "ShopServerExternalDeviceId") {
            self.externalDeviceId = stored
        } else {
            let generated = UUID().uuidString
            defaults.set(generated, forKey: "ShopServerExternalDeviceId")
            self.externalDeviceId = generated
        }

        if let stored = defaults.string(forKey: "ShopServerInstallDeviceId") {
            self.installDeviceId = stored
        } else {
            let generated = UUID().uuidString
            defaults.set(generated, forKey: "ShopServerInstallDeviceId")
            self.installDeviceId = generated
        }
    }

    func discoverShops(first: Int) async throws -> [ShopServerShop] {
        struct Variables: Encodable {
            let first: Int
        }

        let response: MerchantDiscoveryResponse = try await execute(
            query: Self.merchantDiscoveryQuery,
            variables: Variables(first: first)
        )
        return response.shopWebMerchantDiscovery
    }

    func shop(handle: String) async throws -> ShopServerShop? {
        struct Variables: Encodable {
            let handle: String
        }

        let response: ShopByHandleResponse = try await execute(
            query: Self.shopByHandleQuery,
            variables: Variables(handle: handle)
        )
        return response.shop
    }

    func shopsByHandles(_ handles: [String]) async throws -> [ShopServerShop] {
        var shops: [ShopServerShop] = []
        for handle in handles {
            if let shop = try await shop(handle: handle) {
                shops.append(shop)
            }
        }
        return shops
    }

    func followedShops(first: Int) async throws -> [ShopServerShop] {
        struct Variables: Encodable {
            let first: Int
        }

        let response: ShopsFollowedResponse = try await execute(
            query: Self.shopsFollowedQuery,
            variables: Variables(first: first)
        )
        return response.shopsFollowed.nodes
    }

    func products(brokerId: String, first: Int) async throws -> [ShopServerProduct] {
        struct Variables: Encodable {
            let brokerId: String
            let first: Int
        }

        let response: ProductsResponse = try await execute(
            query: Self.productsQuery,
            variables: Variables(brokerId: brokerId, first: first)
        )
        return response.shopProductSearch.nodes
    }

    private func execute<Response: Decodable, Variables: Encodable>(
        query: String,
        variables: Variables
    ) async throws -> Response {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("Shop/2.235.0 ios/17.0", forHTTPHeaderField: "User-Agent")
        request.setValue("Shop/2.235.0 ios/17.0", forHTTPHeaderField: "X-User-Agent")
        request.setValue(externalDeviceId, forHTTPHeaderField: "X-Device-Id-Hw")
        request.setValue(installDeviceId, forHTTPHeaderField: "X-Device-Id")
        request.setValue(sessionId, forHTTPHeaderField: "Session-Id")

        request.httpBody = try JSONEncoder().encode(GraphQLRequest(query: query, variables: variables))

        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw ShopServerClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ShopServerClientError.httpStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(GraphQLResponse<Response>.self, from: data)
        if let errors = decoded.errors, !errors.isEmpty {
            throw ShopServerClientError.graphQLError(errors.map(\.message).joined(separator: "\n"))
        }
        guard let response = decoded.data else {
            throw ShopServerClientError.missingData
        }

        return response
    }

    private static let shopFields = """
    id
    name
    defaultHandle
    myshopifyDomain
    shopifyId
    visualTheme {
      description
      logoImage { url(maxWidth: 512) altText width height }
      featuredImages { url(maxWidth: 1200) altText width height }
      brandSettings {
        colors {
          primary
          secondary
          secondaryText
          logoAverage
          logoDominant
          coverDominant
        }
        logos {
          logoImage { url(maxWidth: 512) altText width height }
        }
        headerTheme {
          slogan
          videoUrl
          coverImage { url(maxWidth: 1600) altText width height }
          thumbnailImage { url(maxWidth: 800) altText width height }
          wordmark { url(maxWidth: 800) altText width height }
          startingScrimColor
          endingScrimColor
        }
      }
    }
    navigationItems {
      id
      title
      slug
      heroImage { url(maxWidth: 800) altText width height }
    }
    productReviewAnalytics {
      averageRating
      totalProductRatings
      totalProductReviews
    }
    """

    private static let shopByHandleQuery = """
    query ShopByHandle($handle: String!) {
      shop(handle: $handle) {
        \(shopFields)
      }
    }
    """

    private static let merchantDiscoveryQuery = """
    query MerchantDiscovery($first: Int!) {
      shopWebMerchantDiscovery(first: $first) {
        \(shopFields)
      }
    }
    """

    private static let productsQuery = """
    query Products($brokerId: ID!, $first: Int!) {
      shopProductSearch(brokerId: $brokerId, first: $first) {
        nodes {
          id
          title
          slug
          description
          price { amount currencyCode }
          images { url(maxWidth: 900) altText width height }
          url
        }
      }
    }
    """

    private static let shopsFollowedQuery = """
    query ShopsFollowed($first: Int!) {
      shopsFollowed(first: $first) {
        nodes {
          \(shopFields)
        }
      }
    }
    """
}

private struct GraphQLRequest<Variables: Encodable>: Encodable {
    let query: String
    let variables: Variables
}

private struct GraphQLResponse<Data: Decodable>: Decodable {
    let data: Data?
    let errors: [GraphQLError]?
}

private struct GraphQLError: Decodable {
    let message: String
}

enum ShopServerClientError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case graphQLError(String)
    case missingData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Shop Server returned an invalid response."
        case .httpStatus(let status):
            if status == 401 || status == 403 {
                return "Shop Server rejected the request. Sign out and sign back in with your Shop account to get a fresh session."
            }
            return "Shop Server returned HTTP \(status)."
        case .graphQLError(let message):
            return message
        case .missingData:
            return "Shop Server returned no data."
        }
    }
}

struct MerchantDiscoveryResponse: Decodable {
    let shopWebMerchantDiscovery: [ShopServerShop]
}

struct ShopByHandleResponse: Decodable {
    let shop: ShopServerShop?
}

struct ProductsResponse: Decodable {
    let shopProductSearch: ProductConnection
}

struct ProductConnection: Decodable {
    let nodes: [ShopServerProduct]
}

struct ShopsFollowedResponse: Decodable {
    let shopsFollowed: ShopsFollowedConnection
}

struct ShopsFollowedConnection: Decodable {
    let nodes: [ShopServerShop]
}

struct ShopServerShop: Decodable {
    let id: String
    let name: String
    let defaultHandle: String?
    let myshopifyDomain: String?
    let shopifyId: String?
    let visualTheme: VisualTheme?
    let navigationItems: [NavigationItem]
    let productReviewAnalytics: ProductReviewAnalytics?
}

struct VisualTheme: Decodable {
    let description: String?
    let logoImage: ShopImage?
    let featuredImages: [ShopImage]
    let brandSettings: BrandSettings?
}

struct BrandSettings: Decodable {
    let colors: BrandColors?
    let logos: BrandLogos?
    let headerTheme: HeaderTheme?
}

struct BrandColors: Decodable {
    let primary: String?
    let secondary: String?
    let secondaryText: String?
    let logoAverage: String?
    let logoDominant: String?
    let coverDominant: String?
}

struct BrandLogos: Decodable {
    let logoImage: ShopImage?
}

struct HeaderTheme: Decodable {
    let slogan: String?
    let videoUrl: String?
    let coverImage: ShopImage?
    let thumbnailImage: ShopImage?
    let wordmark: ShopImage?
    let startingScrimColor: String?
    let endingScrimColor: String?
}

struct NavigationItem: Decodable {
    let id: String
    let title: String
    let slug: String
    let heroImage: ShopImage?
}

struct ProductReviewAnalytics: Decodable {
    let averageRating: Double?
    let totalProductRatings: Int
    let totalProductReviews: Int
}

struct ShopServerProduct: Decodable {
    let id: String
    let title: String
    let slug: String
    let description: String?
    let price: Money
    let images: [ShopImage]
    let url: String?
}

struct Money: Decodable {
    let amount: String
    let currencyCode: String
}

struct ShopImage: Decodable {
    let url: String?
    let altText: String?
    let width: Int?
    let height: Int?
}
