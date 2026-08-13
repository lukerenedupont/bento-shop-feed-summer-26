import Foundation
import SwiftUI

/// Loads merchant data from the bundled prototype-merchants.json snapshot.
/// Used as a fallback when the Shop Server token is missing or expired.
enum LocalMerchantService {

    static func loadMerchants() -> [SampleMerchant] {
        guard let asset = NSDataAsset(name: "prototype-merchants"),
              let snapshot = try? JSONDecoder().decode(MerchantSnapshot.self, from: asset.data) else {
            return []
        }

        return snapshot.merchants.compactMap { entry in
            let products = entry.products.enumerated().map { index, p in
                SampleMerchant.Product(
                    id: stableId(p.id, fallback: index + 1),
                    title: p.title,
                    price: p.price,
                    handle: p.slug,
                    productType: p.productType,
                    vendor: p.vendor ?? entry.name,
                    imageURL: p.imageUrl,
                    shopURL: p.shopUrl,
                    tags: p.tags ?? [],
                    allImageURLs: p.allImageUrls ?? [p.imageUrl].compactMap { $0 },
                    currencyCode: p.currencyCode ?? "USD",
                    productDescription: p.description
                )
            }

            guard !products.isEmpty else { return nil }

            return SampleMerchant(
                id: entry.id,
                name: entry.name,
                description: entry.description ?? "",
                rating: entry.rating ?? 4.8,
                totalRatings: entry.totalRatings ?? 0,
                totalReviews: entry.totalReviews ?? 0,
                primaryColor: Color(hex: entry.colors?.primary ?? "#5433EB"),
                secondaryColor: Color(hex: entry.colors?.secondary ?? "#111111"),
                collections: (entry.collections ?? []).map { col in
                    SampleMerchant.Collection(
                        id: col.id,
                        name: col.title,
                        imageURL: col.imageUrl
                    )
                },
                products: products,
                featuredImageURLs: entry.images?.featured ?? [],
                logoImageURL: entry.images?.logo,
                wordmarkImageURL: entry.images?.wordmark,
                coverImageURL: entry.images?.cover ?? entry.images?.thumbnail,
                videoURL: entry.videoUrl,
                coverDominantColor: entry.colors?.coverDominant,
                productCategory: entry.productCategory,
                logoFitsInCircle: entry.images?.logoFit ?? false
            )
        }
    }

    private static func stableId(_ raw: String?, fallback: Int) -> Int {
        guard let raw, !raw.isEmpty else { return fallback }
        if let numeric = Int(raw) { return numeric }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in raw.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(Int.max))
    }
}

// MARK: - JSON Models

private struct MerchantSnapshot: Decodable {
    let merchants: [MerchantEntry]
}

private struct MerchantEntry: Decodable {
    let id: String
    let name: String
    let handle: String?
    let description: String?
    let rating: Double?
    let totalRatings: Int?
    let totalReviews: Int?
    let colors: ColorsEntry?
    let images: ImagesEntry?
    let videoUrl: String?
    let collections: [CollectionEntry]?
    let products: [ProductEntry]
    let productCategory: String?
}

private struct ColorsEntry: Decodable {
    let primary: String?
    let secondary: String?
    let coverDominant: String?
    let logoDominant: String?
}

private struct ImagesEntry: Decodable {
    let logo: String?
    let logoFit: Bool?
    let wordmark: String?
    let cover: String?
    let thumbnail: String?
    let featured: [String]?
}

private struct CollectionEntry: Decodable {
    let id: String
    let title: String
    let imageUrl: String?
}

private struct ProductEntry: Decodable {
    let id: String?
    let title: String
    let slug: String
    let description: String?
    let price: String
    let currencyCode: String?
    let imageUrl: String?
    let allImageUrls: [String]?
    let shopUrl: String?
    let productType: String?
    let vendor: String?
    let tags: [String]?
}
