import Foundation
import SwiftUI

/// Loads merchant data from the bundled prototype-merchants.json snapshot.
/// Used as a fallback when the Shop Server token is missing or expired.
enum LocalMerchantService {

    static func loadMerchants() -> [SampleMerchant] {
        guard let asset = NSDataAsset(name: "prototype-merchants") else { return [] }
        return decodeMerchants(from: asset.data)
    }

    /// Same mapping, from any snapshot payload — the bundled asset or a live
    /// response from the dossier-lab feed API, which emits this exact shape.
    static func decodeMerchants(from data: Data) -> [SampleMerchant] {
        guard let snapshot = try? JSONDecoder().decode(MerchantSnapshot.self, from: data) else {
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
                    productDescription: p.description,
                    videoUrl: p.videoUrl,
                    allVideoURLs: p.allVideoUrls ?? []
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

    /// Combines catalogs in priority order. Generated dossier media wins when
    /// present, while the wider bundled catalog fills in real adjacent items
    /// and the buyer fixtures add canonical products absent from both.
    static func mergeMerchants(_ sources: [[SampleMerchant]]) -> [SampleMerchant] {
        var orderedIDs: [String] = []
        var merchantsByID: [String: SampleMerchant] = [:]

        for source in sources {
            for merchant in source {
                if let primary = merchantsByID[merchant.id] {
                    merchantsByID[merchant.id] = mergeMerchant(primary, with: merchant)
                } else {
                    orderedIDs.append(merchant.id)
                    merchantsByID[merchant.id] = merchant
                }
            }
        }

        return orderedIDs.compactMap { merchantsByID[$0] }
    }

    private static func mergeMerchant(
        _ primary: SampleMerchant,
        with fallback: SampleMerchant
    ) -> SampleMerchant {
        var productOrder = primary.products.map(\.id)
        var productsByID = Dictionary(uniqueKeysWithValues: primary.products.map { ($0.id, $0) })
        for product in fallback.products {
            if let existing = productsByID[product.id] {
                productsByID[product.id] = mergeProduct(existing, with: product)
            } else {
                productOrder.append(product.id)
                productsByID[product.id] = product
            }
        }

        let products = productOrder.compactMap { productsByID[$0] }
        let featured = unique(primary.featuredImageURLs + fallback.featuredImageURLs)

        return SampleMerchant(
            id: primary.id,
            name: primary.name,
            description: primary.description.isEmpty ? fallback.description : primary.description,
            rating: primary.rating,
            totalRatings: primary.totalRatings,
            totalReviews: primary.totalReviews,
            primaryColor: primary.primaryColor,
            secondaryColor: primary.secondaryColor,
            collections: primary.collections.isEmpty ? fallback.collections : primary.collections,
            products: products,
            featuredImageURLs: featured,
            logoImageURL: primary.logoImageURL ?? fallback.logoImageURL,
            wordmarkImageURL: primary.wordmarkImageURL ?? fallback.wordmarkImageURL,
            coverImageURL: primary.coverImageURL ?? fallback.coverImageURL,
            videoURL: primary.videoURL ?? fallback.videoURL,
            coverDominantColor: primary.coverDominantColor ?? fallback.coverDominantColor,
            productCategory: primary.productCategory ?? fallback.productCategory,
            logoFitsInCircle: primary.logoFitsInCircle || fallback.logoFitsInCircle
        )
    }

    private static func mergeProduct(
        _ primary: SampleMerchant.Product,
        with fallback: SampleMerchant.Product
    ) -> SampleMerchant.Product {
        SampleMerchant.Product(
            id: primary.id,
            title: primary.title,
            price: primary.price,
            handle: primary.handle,
            productType: primary.productType ?? fallback.productType,
            vendor: primary.vendor,
            imageURL: primary.imageURL ?? fallback.imageURL,
            shopURL: primary.shopURL ?? fallback.shopURL,
            tags: unique(primary.tags + fallback.tags),
            allImageURLs: unique(primary.allImageURLs + fallback.allImageURLs),
            currencyCode: primary.currencyCode,
            productDescription: primary.productDescription ?? fallback.productDescription,
            videoUrl: primary.videoUrl ?? fallback.videoUrl,
            allVideoURLs: unique(primary.allVideoURLs + fallback.allVideoURLs)
        )
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
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
    /// Present on generated feeds (dossier-lab films two clips per product);
    /// absent from the bundled snapshot, hence optional.
    let videoUrl: String?
    let allVideoUrls: [String]?
}
