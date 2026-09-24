import Foundation

/// A published, source-checked observation, not a live monitoring promise.
struct ResearchOffer: Decodable, Identifiable {
    let id: String
    let nativeID: Int
    let merchantID: String
    let merchantName: String
    let title: String
    let brand: String
    let model: String
    let section: String
    let price: String
    let referencePrice: String?
    let currency: String
    let availableVariants: [String]
    let usMensSizes: [String]
    let variantIDs: [Int]
    let color: String
    let observedImageID: Int
    let image: String
    let images: [String]
    let sourceURL: String
    let observedAt: String
    let description: String

    var amount: Double { Double(price) ?? .infinity }
    var markdownPercent: Int? {
        guard let referencePrice, let reference = Double(referencePrice),
              reference > amount, amount >= 0 else { return nil }
        return Int(((reference - amount) / reference * 100).rounded())
    }
    var displayPrice: String { money(price) }
    func productURL(usMensSize: String? = nil) -> URL? {
        guard let usMensSize else { return URL(string: sourceURL) }
        guard let index = usMensSizes.firstIndex(of: usMensSize), variantIDs.indices.contains(index),
              var url = URLComponents(string: sourceURL) else { return nil }
        url.queryItems = (url.queryItems ?? []).filter { $0.name != "variant" }
            + [URLQueryItem(name: "variant", value: String(variantIDs[index]))]
        return url.url
    }
    var displayReference: String? { referencePrice.map(money) }
    func money(_ value: String) -> String {
        guard let number = Double(value), number.isFinite, number > 0 else { return "Price at shop" }
        let formatted = number.formatted(.number.precision(.fractionLength(0...2)))
        let prefix = ["EUR": "€", "GBP": "£", "CAD": "CA$", "USD": "$"][currency] ?? currency + " "
        return prefix + formatted
    }
    var libraryProduct: ShopCanvasLibrary.Product {
        .init(id: id, nativeID: nativeID, curated: true, merchantIDs: [merchantID],
              title: title, brand: brand, group: "Trail-running research", image: image,
              originalImage: image, url: sourceURL, price: price, currency: currency,
              description: "Observed variants at this price: \(availableVariants.joined(separator: ", ")).\n\n" + description,
              commerceCheck: "Price snapshot · \(observedAt.prefix(10)) · \(currency). Recheck size, price and delivery at the shop.",
              checkedAt: observedAt, images: images)
    }
}

struct ResearchEditorial: Identifiable {
    let id: String
    let title: String
    let detail: String
    let image: String
    let source: String
    let isFilm: Bool
}

/// Finite composition: new research edits supply content, not a new screen.
enum ResearchSection {
    case offers
    case modelStudy
    case merchantComparison
    case film(ResearchEditorial)
    case apparel
    case alternatives
    case relatedWorlds(storyIDs: [String])
    case stories([ResearchEditorial])
    case methodology
}

struct ShoppingResearchWorld {
    let id: String
    let title: String
    let headline: String
    let deck: String
    let prompt: String
    let heroImage: String
    let heroSource: String
    let coverFilm: ResearchCoverFilm?
    let offers: [ResearchOffer]
    let shippingPolicies: [ResearchShippingPolicy]
    let sections: [ResearchSection]

    var story: FeedStory {
        FeedStory(id: id, eyebrow: "Shop Agent", title: title, subtitle: "", format: .world,
                  topicKeys: ["library", "catalog-only-media", "agent-research"],
                  accentHex: "#26382D", coverImageName: nil, destinationLabel: "Explore your price edit",
                  products: offers.map { .init(merchantID: $0.merchantID, productID: $0.nativeID) })
    }
    var models: [String] { Array(Set(offers.filter { $0.section == "shoes" }.map(\.model))).sorted() }
    var shoeMerchantCount: Int { Set(offers.filter { $0.section == "shoes" }.map(\.merchantID)).count }
    var comparisonMatches: [ResearchShoeMatch] {
        let matches = Set(offers.filter { $0.section == "shoes" }.map { ResearchShoeMatch(model: $0.model, color: $0.color) })
        return matches.filter { match in
            Set(offers.filter { match.matches($0) }.map(\.merchantID)).count > 1
        }.sorted { $0.title < $1.title }
    }
    func featuredShoes(model: String = "All") -> [ResearchOffer] {
        if model != "All" { return shoeOffers(model: model, currency: "USD") }
        var seen = Set<ResearchShoeMatch>()
        return shoeOffers(model: model, currency: "USD").filter {
            seen.insert(ResearchShoeMatch(model: $0.model, color: $0.color)).inserted
        }
    }
    func comparison(match: ResearchShoeMatch, size: String, criterion: ResearchComparisonCriterion) -> ResearchComparison {
        ResearchComparison(offers: offers, match: match, size: size, criterion: criterion)
    }
    func shoeOffers(model: String = "All", currency: String) -> [ResearchOffer] {
        offers.filter { $0.section == "shoes" && $0.currency == currency && (model == "All" || $0.model == model) }
            .sorted { $0.amount < $1.amount }
    }
    var cover: LibraryArtDirection.Cover {
        .init(group: title, path: heroImage, role: "editorial",
              note: "First frame of Norda's official 055 film. Internal reference; no outfit association claimed.",
              sha256: coverFilm?.posterSHA256 ?? "", sourceProductID: nil, sourceMerchantID: coverFilm?.sourceMerchantID,
              portraitOffsetRatio: nil)
    }
}

enum ShoppingResearchCatalog {
    struct Snapshot: Decodable {
        let merchants: [ShopCanvasLibrary.Merchant]
        let offers: [ResearchOffer]
        let shippingPolicies: [ResearchShippingPolicy]
    }
    static let snapshot: Snapshot = {
        do {
            let url = ShopCanvasLibrary.rootURL.appendingPathComponent("running-research.json")
            let result = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
            precondition(validationIssues(result).isEmpty, "Invalid research snapshot")
            return result
        } catch { preconditionFailure("Missing research snapshot: \(error)") }
    }()

    static func validationIssues(_ snapshot: Snapshot) -> [String] {
        let eligible = Set(snapshot.merchants.filter {
            $0.platformOutcome == "confirmed_shopify" && $0.id.hasPrefix("gid://shopify/Shop/")
        }.map(\.id))
        var issues: [String] = []
        if Set(snapshot.offers.map(\.id)).count != snapshot.offers.count { issues.append("Duplicate offers") }
        for offer in snapshot.offers {
            if !eligible.contains(offer.merchantID) { issues.append("Unconfirmed merchant: \(offer.id)") }
            if !offer.amount.isFinite || offer.amount <= 0 { issues.append("Invalid price: \(offer.id)") }
            if offer.currency != "USD" { issues.append("Research offers must have sourced USD prices") }
            if offer.section == "shoes" && (offer.usMensSizes.count != offer.variantIDs.count || offer.color.isEmpty) {
                issues.append("Missing comparable size or color evidence")
            }
            if offer.availableVariants.isEmpty || offer.variantIDs.count != offer.availableVariants.count
                || offer.observedImageID <= 0 { issues.append("Missing variant evidence") }
            if !["shoes", "apparel", "alternatives"].contains(offer.section) { issues.append("Unknown offer category") }
            if let reference = offer.referencePrice, !(Double(reference).map { $0.isFinite && $0 > offer.amount } ?? false) {
                issues.append("Invalid reference price")
            }
            let merchant = snapshot.merchants.first { $0.id == offer.merchantID }
            let host = merchant?.url.flatMap { URL(string: $0)?.host() }
            if URL(string: offer.sourceURL)?.scheme != "https" || host == nil
                || URL(string: offer.sourceURL)?.host() != host || offer.observedAt.isEmpty {
                issues.append("Missing source evidence")
            }
        }
        return issues
    }

    static let norda = ShoppingResearchWorld(
        id: "library-edit-norda-price-research", title: "Your trail-running price edit",
        headline: "Go farther.\nSpend smarter.",
        deck: "Norda and the rest of your run.",
        prompt: "Find me good prices on Norda trail-running shoes, and other running gear I might like.",
        heroImage: ResearchCoverFilm.norda.posterPath,
        heroSource: ResearchCoverFilm.norda.sourcePage.absoluteString,
        coverFilm: .norda,
        offers: snapshot.offers,
        shippingPolicies: snapshot.shippingPolicies,
        sections: [
            .offers, .merchantComparison, .modelStudy,
            .film(.init(id: "norda-055-film", title: "Freedom of the soul.",
                        detail: "Norda 055",
                        image: "https://i.ytimg.com/vi/94vmhYRLw2M/maxresdefault.jpg",
                        source: "https://www.youtube.com/watch?v=94vmhYRLw2M", isFilm: true)),
            .apparel, .alternatives,
            .stories([
                .init(id: "western-states", title: "The long way round.",
                      detail: "Priscilla Forgie and Jenny Quilty at Western States. From Norda.",
                      image: "https://cdn.shopify.com/s/files/1/0820/7020/8817/articles/775-608803.jpg?v=1722479408&width=900",
                      source: "https://nordarun.com/blogs/stories/665-at-western-states-in-conversation-with-priscilla-forgie-and-jenny-quilty", isFilm: false),
                .init(id: "norda-002-reel", title: "A different kind of trail.",
                      detail: "Norda's 002 in motion.",
                      image: "https://i.ytimg.com/vi/sajyzMfhvUI/hqdefault.jpg",
                      source: "https://www.youtube.com/shorts/sajyzMfhvUI", isFilm: true),
                .init(id: "satisfy-journal", title: "For the feeling.",
                      detail: "Satisfy on Instagram.",
                      image: snapshot.offers.first { $0.merchantName == "SATISFY" }?.images.last ?? "",
                      source: "https://www.instagram.com/satisfyrunning/", isFilm: false),
            ]),
            .relatedWorlds(storyIDs: ["library-edit-21", "library-edit-11"]),
            .methodology,
        ])
    static var worlds: [ShoppingResearchWorld] { [norda] }
    static func world(for storyID: String) -> ShoppingResearchWorld? { worlds.first { $0.id == storyID } }
}
