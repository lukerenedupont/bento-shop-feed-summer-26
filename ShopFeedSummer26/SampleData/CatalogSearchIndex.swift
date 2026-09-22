import Foundation

/// Tokenizes one immutable merchant snapshot once, rather than repeating the
/// same string work for every suggested collection and custom-feed query.
/// Only the current snapshot is retained; changed product content invalidates
/// it even when merchant IDs and product counts have not changed.
@MainActor
enum CatalogSearchIndex {
    struct Document {
        let merchant: SampleMerchant
        let product: SampleMerchant.Product
        let title: Set<String>
        let type: Set<String>
        let tags: Set<String>
        let description: Set<String>
        let brand: Set<String>
        let vocabulary: Set<String>

        var reference: FeedStory.ProductReference {
            .init(merchantID: merchant.id, productID: product.id)
        }

        init(merchant: SampleMerchant, product: SampleMerchant.Product) {
            self.merchant = merchant
            self.product = product
            title = CatalogSearchText.tokens(in: product.title)
            type = CatalogSearchText.tokens(in: product.productType ?? "")
            tags = CatalogSearchText.tokens(in: product.tags.joined(separator: " "))
            description = CatalogSearchText.tokens(in: product.productDescription ?? "")
            let vendor = CatalogSearchText.tokens(in: product.vendor)
            brand = vendor.union(CatalogSearchText.tokens(in: merchant.name))
            vocabulary = title.union(type).union(tags).union(description).union(vendor)
        }

        func relevance(intentTerms: Set<String>, relatedTerms: Set<String>) -> Int {
            title.intersection(intentTerms).count * 30
                + type.intersection(intentTerms).count * 26
                + tags.intersection(intentTerms).count * 18
                + brand.intersection(intentTerms).count * 16
                + description.intersection(intentTerms).count * 5
                + title.intersection(relatedTerms).count * 18
                + type.intersection(relatedTerms).count * 16
                + tags.intersection(relatedTerms).count * 12
                + brand.intersection(relatedTerms).count * 10
                + description.intersection(relatedTerms).count * 3
        }
    }

    private static var cached: (merchants: [SampleMerchant], locale: String, documents: [Document])?

    static func documents(in merchants: [SampleMerchant]) -> [Document] {
        let locale = Locale.current.identifier
        if let cached, cached.locale == locale, cached.merchants == merchants {
            return cached.documents
        }
        let documents = merchants.flatMap { merchant in
            merchant.products.map { Document(merchant: merchant, product: $0) }
        }
        cached = (merchants, locale, documents)
        return documents
    }
}

enum CatalogSearchText {
    // A constant, not a dictionary rebuilt for every word in every product.
    private static let irregular: [String: String] = [
        "hats": "hat", "caps": "cap", "beanies": "beanie",
        "shoes": "shoe", "sneakers": "sneaker", "boots": "boot",
        "bags": "bag", "books": "book", "chairs": "chair",
        "lamps": "lamp", "pants": "pant", "tees": "tee",
        "watches": "watch",
    ]

    static func tokens(in value: String) -> Set<String> {
        Set(
            value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map { token in
                    let value = String(token)
                    return irregular[value] ?? value
                }
                .filter { !$0.isEmpty }
        )
    }
}
