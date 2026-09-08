import Foundation

// PROTOTYPE — can a signal → shopping job → composition feel more useful than
// a ranked product rail? Specifications contain semantic choices, not UI values.
enum NextGenerationCardLayout: String, CaseIterable, Identifiable {
    case relationship = "Relationship"
    case comparison = "Comparison"
    case merchant = "Merchant"
    case continuation = "Continuation"
    case hero = "Hero"
    var id: String { rawValue }
}

enum PrototypeShoppingJob: String {
    case complete = "Complete a purchase"
    case compare = "Compare a shortlist"
    case merchantDiscovery = "Explore a familiar merchant"
    case continueWorld = "Continue a World"
}

enum PrototypeCardInteraction: String {
    case swap = "Swap the supporting product"
    case shortlist = "Keep or remove a candidate"
    case browse = "Browse the merchant assortment"
    case selectForWorld = "Choose an item for the room plan"
}

struct PrototypeShoppingSignal: Identifiable {
    enum Kind { case purchase, repeatedViews, merchantAffinity, activeWorld }
    let id: String
    let kind: Kind
    let summary: String
    let products: [FeedStory.ProductReference]
    let merchantID: String
    var worldID: String? = nil
}

struct NextGenerationFeedCardSpec: Identifiable {
    let id: String
    let signal: PrototypeShoppingSignal
    let job: PrototypeShoppingJob
    let title: String
    let subtitle: String
    let layout: NextGenerationCardLayout
    let alternatives: [NextGenerationCardLayout]
    let interaction: PrototypeCardInteraction
    let anchor: FeedStory.ProductReference?
    let productReferences: [FeedStory.ProductReference]
    let reasonForSelection: String

    var prefersDarkNavigationText: Bool { job != .merchantDiscovery }
    var accessibilityDescription: String { "\(title). \(subtitle). \(interaction.rawValue). Demo shopping context." }

    func resolvedProducts(from merchants: [SampleMerchant]) -> [ResolvedStoryProduct] {
        productReferences.compactMap { Self.resolve($0, in: merchants) }
    }

    static func resolve(_ ref: FeedStory.ProductReference, in merchants: [SampleMerchant]) -> ResolvedStoryProduct? {
        guard let merchant = merchants.first(where: { $0.id == ref.merchantID }),
              let product = merchant.products.first(where: { $0.id == ref.productID }) else { return nil }
        return ResolvedStoryProduct(merchant: merchant, product: product)
    }
}

@MainActor
enum NextGenerationFeedCardCatalog {
    static let prototypeEnabled = true

    /// The fixture declares activity, never a layout. The job determines which
    /// entities are useful; only then do we choose a supported composition.
    static func cards(
        signals: [PrototypeShoppingSignal],
        merchants: [SampleMerchant]
    ) -> [NextGenerationFeedCardSpec] {
        signals.compactMap { signal in
            let observed = signal.products.compactMap { NextGenerationFeedCardSpec.resolve($0, in: merchants) }
            guard observed.count == signal.products.count,
                  let merchant = merchants.first(where: { $0.id == signal.merchantID }) else { return nil }
            let job: PrototypeShoppingJob
            let title: String
            let subtitle: String
            let layout: NextGenerationCardLayout
            let interaction: PrototypeCardInteraction
            let anchor: FeedStory.ProductReference?
            let candidates: [ResolvedStoryProduct]
            let reason: String
            switch signal.kind {
            case .purchase:
                job = .complete
                title = "With the jacket you bought"
                subtitle = "Keep the jacket. Try a different pair of pants."
                layout = .relationship
                interaction = .swap
                anchor = signal.products.first
                candidates = merchant.products.filter {
                    $0.title.localizedCaseInsensitiveContains("fleece pant")
                }.map { ResolvedStoryProduct(merchant: merchant, product: $0) }
                reason = "A demo jacket purchase creates a completion job. Pants from the same Nike × Stüssy assortment provide relevant options; the owned jacket stays fixed."
            case .repeatedViews:
                job = .compare
                title = "Still considering these chairs?"
                subtitle = "Your shortlist, together in one place."
                layout = .comparison
                interaction = .shortlist
                anchor = nil
                candidates = observed
                reason = "Repeated demo views of three chairs suggest a decision, not more discovery. Equal image space and catalog prices support comparison. No dimensions or review claims are invented."
            case .merchantAffinity:
                job = .merchantDiscovery
                title = merchant.displayName
                subtitle = "Another chapter for your design shelf."
                layout = .merchant
                interaction = .browse
                anchor = nil
                candidates = Array(merchant.products.prefix(4)).map { ResolvedStoryProduct(merchant: merchant, product: $0) }
                reason = "Demo affinity for Standards Manual makes the shop the primary entity. The assortment comes from its catalog; this is not labeled a new launch because release timing is unverified."
            case .activeWorld:
                job = .continueWorld
                title = "A chair for your living room"
                subtitle = "Try one beside the table you saved."
                layout = .continuation
                interaction = .selectForWorld
                anchor = signal.products.first
                candidates = merchant.products.filter {
                    $0.title.hasPrefix("Chair #1") || $0.title.hasPrefix("Papa Teddy Chair")
                }.map { ResolvedStoryProduct(merchant: merchant, product: $0) }
                reason = "The demo Living Room World already holds a saved coffee table. Bring forward the next decision—a chair—and retain the selection in the local room plan. This is not a spatial compatibility assessment."
            }
            guard !candidates.isEmpty else { return nil }
            return NextGenerationFeedCardSpec(
                id: "next-gen-\(signal.id)", signal: signal, job: job,
                title: title, subtitle: subtitle, layout: layout,
                alternatives: [layout, .hero], interaction: interaction, anchor: anchor,
                productReferences: candidates.map { .init(merchantID: $0.merchant.id, productID: $0.product.id) },
                reasonForSelection: reason
            )
        }
    }
}
