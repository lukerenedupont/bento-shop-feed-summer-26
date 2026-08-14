import SwiftUI

struct SampleMerchant: Identifiable {
    let id: String
    let name: String
    let description: String
    let rating: Double
    let totalRatings: Int
    let totalReviews: Int
    let primaryColor: Color
    let secondaryColor: Color
    let collections: [Collection]
    let products: [Product]
    let featuredImageURLs: [String]
    let logoImageURL: String?
    let wordmarkImageURL: String?
    let coverImageURL: String?
    let videoURL: String?
    let coverDominantColor: String?
    let productCategory: String?
    /// Wordmark-style logos render fitted inside a white circle instead of
    /// filling it, so wide marks stay legible as avatars.
    var logoFitsInCircle: Bool = false

    /// Rail/pill-friendly name: drops collab suffixes ("Feature — Salomon"
    /// → "Feature") so labels survive narrow layouts without truncating.
    var displayName: String {
        name.components(separatedBy: " — ").first ?? name
    }

    var hasVideos: Bool { videoURL != nil }

    var bestVideoURL: URL? {
        guard let videoURL else { return nil }
        return URL(string: videoURL)
    }

    var bestCoverImageURL: String? {
        coverImageURL ?? featuredImageURLs.first
    }

    var brandColor: Color {
        if let hex = coverDominantColor, !hex.isEmpty {
            return Color(hex: hex)
        }
        return primaryColor
    }

    var bestLogoURL: String? { logoImageURL }

    var bestWordmarkURL: String? { wordmarkImageURL }

    struct Product: Identifiable, Hashable {
        let id: Int
        let title: String
        let price: String
        let handle: String
        let productType: String?
        let vendor: String
        let imageURL: String?
        let shopURL: String?
        let tags: [String]
        var allImageURLs: [String] = []
        var currencyCode: String = "USD"
        var productDescription: String?
        /// Generated product film, when the feed supplies one.
        var videoUrl: String? = nil
    }

    struct Collection: Identifiable {
        let id: String
        let name: String
        let imageURL: String?

        init(id: String? = nil, name: String, imageURL: String? = nil) {
            self.id = id ?? name
            self.name = name
            self.imageURL = imageURL
        }
    }

    @MainActor
    static var all: [SampleMerchant] {
        let live = RemoteMerchantService.shared.merchants
        if !live.isEmpty { return live }
        // Previews, deep links, and pushed pages can all render before
        // HomePage seeds RemoteMerchantService — the bundled snapshot is
        // always a safe source of truth, so nothing races an empty catalog.
        return bundledSnapshot.isEmpty ? previews : bundledSnapshot
    }

    /// Bundled `prototype-merchants.json`, decoded once.
    private static let bundledSnapshot: [SampleMerchant] = LocalMerchantService.loadMerchants()

    @MainActor
    static var byId: [String: SampleMerchant] {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }

    @MainActor
    static var merchantByProductId: [Int: SampleMerchant] {
        var dict: [Int: SampleMerchant] = [:]
        for merchant in all {
            for product in merchant.products {
                dict[product.id] = merchant
            }
        }
        return dict
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard !cleaned.isEmpty else {
            self = .gray
            return
        }

        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)

        if cleaned.count == 8 {
            let r = Double((rgb >> 24) & 0xFF) / 255
            let g = Double((rgb >> 16) & 0xFF) / 255
            let b = Double((rgb >> 8) & 0xFF) / 255
            let a = Double(rgb & 0xFF) / 255
            self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
        } else {
            let r = Double((rgb >> 16) & 0xFF) / 255
            let g = Double((rgb >> 8) & 0xFF) / 255
            let b = Double(rgb & 0xFF) / 255
            self.init(.sRGB, red: r, green: g, blue: b)
        }
    }
}
