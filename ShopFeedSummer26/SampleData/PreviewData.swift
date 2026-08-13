import Foundation
import SwiftUI

// MARK: - SampleMerchant Previews
//
// Lightweight, fully offline preview data for Xcode #Preview blocks.
//
// Source of truth: the bundled `prototype-merchants.json` snapshot used by the
// sample-data fallback. `LocalMerchantService.loadMerchants()` reads it via
// `NSDataAsset`, which works in Xcode previews since the asset catalog is in
// the preview target. If for any reason loading fails, `.synthetic` kicks in
// so previews never go fully blank.

extension SampleMerchant {
    /// All bundled preview merchants. Loaded from the same JSON snapshot the
    /// "Continue with sample data" path uses, so previews look like real Shop
    /// content without any network or auth.
    static var previews: [SampleMerchant] {
        let merchants = LocalMerchantService.loadMerchants()
        return merchants.isEmpty ? [.synthetic] : merchants
    }

    /// First preview merchant — used when a single merchant is enough.
    static var preview: SampleMerchant { previews.first ?? .synthetic }

    /// First merchant in the bundled snapshot that has a video URL, falling back
    /// to `.preview` if none ship with video.
    static var previewWithVideo: SampleMerchant {
        previews.first { $0.videoURL != nil } ?? preview
    }

    /// Fully synthetic merchant used only if the bundled JSON can't load.
    /// Hard-coded so previews never break in unusual build configurations.
    static let synthetic = SampleMerchant(
        id: "preview-merchant",
        name: "Preview Co.",
        description: "A synthetic merchant used as a preview fallback.",
        rating: 4.7,
        totalRatings: 1284,
        totalReviews: 1100,
        primaryColor: Color(hex: "#5433EB"),
        secondaryColor: Color(hex: "#111111"),
        collections: [
            SampleMerchant.Collection(id: "all", name: "All products", imageURL: nil),
            SampleMerchant.Collection(id: "new", name: "New arrivals", imageURL: nil),
        ],
        products: (1...6).map { i in
            SampleMerchant.Product(
                id: i,
                title: "Preview product \(i)",
                price: String(format: "%.2f", Double(20 + i * 12)),
                handle: "preview-product-\(i)",
                productType: nil,
                vendor: "Preview Co.",
                imageURL: nil,
                shopURL: nil,
                tags: [],
                allImageURLs: [],
                currencyCode: "USD",
                productDescription: "A great preview product."
            )
        },
        featuredImageURLs: [],
        logoImageURL: nil,
        wordmarkImageURL: nil,
        coverImageURL: nil,
        videoURL: nil,
        coverDominantColor: "#5433EB",
        productCategory: "All"
    )
}

// MARK: - Personalized Feed Story Previews

extension FeedStory {
    /// Offline story fixtures backed by the bundled official product snapshot.
    static var previews: [FeedStory] { PersonalizedFeedStories.all }
    static var preview: FeedStory { previews[0] }
}

// MARK: - AgentProduct Previews

extension AgentProduct {
    /// Build a list of AgentProduct previews from a SampleMerchant's products.
    /// Useful for previewing agent shelves, comparison cards, and search results
    /// without going through the streaming SSE client.
    static func previews(from merchant: SampleMerchant = .preview, limit: Int = 6) -> [AgentProduct] {
        Array(merchant.products.prefix(limit)).map { product in
            AgentProduct(
                id: String(product.id),
                title: product.title,
                price: "$\(product.price)",
                originalPrice: nil,
                imageURL: product.imageURL.flatMap(URL.init(string:)),
                allImageURLs: product.allImageURLs.compactMap(URL.init(string:)),
                rating: merchant.rating,
                ratingCount: merchant.totalRatings,
                shopName: merchant.name,
                shopLogoURL: merchant.bestLogoURL.flatMap(URL.init(string:)),
                descriptors: [],
                labels: []
            )
        }
    }

    /// Comparison-style products with descriptors filled in, for previewing
    /// ComparisonShelf / ComparisonCard.
    static var comparisonPreviews: [AgentProduct] {
        let merchant = SampleMerchant.preview
        let descriptors: [[ComparisonAttribute]] = [
            [
                ComparisonAttribute(header: "Pros", value: "Lightweight, breathable knit"),
                ComparisonAttribute(header: "Cons", value: "Runs slightly small"),
                ComparisonAttribute(header: "Best for", value: "Daily wear"),
            ],
            [
                ComparisonAttribute(header: "Pros", value: "Premium materials, durable"),
                ComparisonAttribute(header: "Cons", value: "Higher price point"),
                ComparisonAttribute(header: "Best for", value: "Long-term value"),
            ],
            [
                ComparisonAttribute(header: "Pros", value: "Versatile, easy to style"),
                ComparisonAttribute(header: "Cons", value: "Limited color options"),
                ComparisonAttribute(header: "Best for", value: "Capsule wardrobes"),
            ],
        ]
        let labels = ["Editor's pick", "Best value", "Most popular"]

        return Array(zip(merchant.products.prefix(3), zip(descriptors, labels))).map { product, pair in
            AgentProduct(
                id: String(product.id),
                title: product.title,
                price: "$\(product.price)",
                originalPrice: nil,
                imageURL: product.imageURL.flatMap(URL.init(string:)),
                allImageURLs: product.allImageURLs.compactMap(URL.init(string:)),
                rating: merchant.rating,
                ratingCount: merchant.totalRatings,
                shopName: merchant.name,
                shopLogoURL: merchant.bestLogoURL.flatMap(URL.init(string:)),
                descriptors: pair.0,
                labels: [pair.1]
            )
        }
    }
}

// MARK: - SearchSuggestion Previews

extension SearchSuggestion {
    /// A mixed list of shop + query suggestions, modeling a typical typeahead
    /// response when the user has typed a few characters.
    static var previews: [SearchSuggestion] {
        let merchants = SampleMerchant.previews.prefix(2)
        let shops: [SearchSuggestion] = merchants.map { merchant in
            .shop(ShopResult(
                name: merchant.name,
                logoURL: merchant.bestLogoURL.flatMap(URL.init(string:)),
                rating: merchant.rating,
                ratingCount: merchant.totalRatings,
                incentiveText: merchant.id.hashValue.isMultiple(of: 2) ? "5% back" : nil
            ))
        }
        let queries: [SearchSuggestion] = [
            .query(QueryResult(text: "running shoes under $120")),
            .query(QueryResult(text: "gift ideas for mom")),
            .query(QueryResult(text: "cozy weekend sweaters")),
        ]
        return shops + queries
    }
}

// MARK: - RecentConversation Previews

extension RecentConversation {
    /// A small set of recent conversations for the RecentsPanel preview.
    static var previews: [RecentConversation] {
        let merchant = SampleMerchant.preview
        let thumbnails: [URL] = merchant.products
            .prefix(3)
            .compactMap { $0.imageURL }
            .compactMap(URL.init(string:))
        let now = Date()
        return [
            RecentConversation(
                id: "preview-1",
                title: "Hiking boots for snow",
                lastMessageSentAt: now.addingTimeInterval(-60 * 4),
                thumbnailURLs: thumbnails
            ),
            RecentConversation(
                id: "preview-2",
                title: "Gift ideas under $50",
                lastMessageSentAt: now.addingTimeInterval(-60 * 60 * 3),
                thumbnailURLs: Array(thumbnails.prefix(2))
            ),
            RecentConversation(
                id: "preview-3",
                title: "Comparison of espresso machines",
                lastMessageSentAt: now.addingTimeInterval(-60 * 60 * 24 * 2),
                thumbnailURLs: Array(thumbnails.prefix(1))
            ),
        ]
    }
}

// MARK: - SuggestionItem Previews

extension SuggestionItem {
    /// A few follow-up suggestion chips.
    static var previews: [SuggestionItem] {
        [
            SuggestionItem(label: "More like this"),
            SuggestionItem(label: "Under $80"),
            SuggestionItem(label: "Compare top picks"),
            SuggestionItem(label: "Show in black"),
        ]
    }
}

// MARK: - AgentProductSection Previews

extension AgentProductSection {
    /// A standard shelf section for previewing AgentProductShelf, etc.
    static var preview: AgentProductSection {
        AgentProductSection(
            title: "Recommended for you",
            subtitle: "Based on your preferences",
            products: AgentProduct.previews(),
            isComparison: false,
            isShelfSection: true
        )
    }

    /// A comparison section for previewing ComparisonShelf.
    static var comparisonPreview: AgentProductSection {
        AgentProductSection(
            title: "Side by side",
            subtitle: "How these compare",
            products: AgentProduct.comparisonPreviews,
            isComparison: true
        )
    }
}
