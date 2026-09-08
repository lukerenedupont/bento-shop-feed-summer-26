import Foundation

/// PROTOTYPE deterministic generation seam. Every rebuild repeats retrieval
/// and validation from the current signal/job; no arbitrary UI is generated.
@MainActor
enum NextGenerationFeedCardCatalog {
    static let prototypeEnabled = true
    /// Keep the discussion fixture identical in Home, gallery and inspector.
    /// The full app's merged/live inventory remains separate and untouched.
    static let prototypeMerchants = LocalMerchantService.loadMerchants()

    static func cards(signals: [PrototypeShoppingSignal], merchants: [SampleMerchant]) -> [NextGenerationFeedCardSpec] {
        signals.compactMap { card(signal: $0, merchants: merchants) }
    }

    static func card(
        signal: PrototypeShoppingSignal, merchants: [SampleMerchant],
        jobOverride: PrototypeShoppingJob? = nil, generation: Int = 0
    ) -> NextGenerationFeedCardSpec? {
        let observed = signal.products.compactMap { NextGenerationFeedCardSpec.resolve($0, in: merchants) }
        guard observed.count == signal.products.count,
              let merchant = merchants.first(where: { $0.id == signal.merchantID }) else { return nil }
        let job: PrototypeShoppingJob
        let title: String
        let subtitle: String
        let layout: NextGenerationCardLayout
        let interaction: PrototypeCardInteraction
        let anchor: FeedStory.ProductReference?
        var candidates: [ResolvedStoryProduct]
        let reason: String
        var groups = signal.groups.filter { group in
            !group.products.isEmpty && group.products.allSatisfy {
                (group.merchantID == nil || group.merchantID == $0.merchantID)
                    && NextGenerationFeedCardSpec.resolve($0, in: merchants) != nil
            }
        }
        switch signal.kind {
        case .purchase:
            job = .complete
            title = "With the jacket you bought"
            subtitle = "Grey or black fleece, from the same collaboration."
            layout = .relationship
            interaction = .swap
            anchor = signal.products.first
            candidates = merchant.products.filter {
                $0.title.localizedCaseInsensitiveContains("fleece pant")
            }.map { ResolvedStoryProduct(merchant: merchant, product: $0) }
            reason = "A demo jacket purchase creates a completion job. The purchased jacket stays at the top; a horizontal carousel presents pants from the same Nike × Stüssy assortment. Selection keeps imagery, identity, price and the canonical purchase URL together. Buy pants opens that SKU's merchant page, not a simulated checkout."
        case .repeatedViews, .savedShortlist:
            let defaultJob: PrototypeShoppingJob = signal.kind == .savedShortlist ? .continueJourney : .compare
            job = jobOverride.flatMap { signal.supportedJobs.contains($0) ? $0 : nil } ?? defaultJob
            title = job == .compare ? "Still considering these chairs?" : "Back to your chair shortlist"
            subtitle = job == .compare ? "\(merchant.displayName) · Your chair shortlist" : "Pick up with the chairs you saved."
            layout = job == .compare ? .comparison : .hero
            interaction = .shortlist
            anchor = nil
            candidates = observed
            reason = "The demo shortlist supports comparison or continuation. Two chairs remain visible with canonical finishes and a calculated same-currency price difference. Bringing in another candidate keeps the focused chair. Save a preference or inspect the exact product; dimensions, stock and reviews are not inferred."
        case .merchantAffinity:
            job = .merchantDiscovery
            title = merchant.displayName
            subtitle = "Graphic design, archives and visual culture."
            layout = .merchant
            interaction = .browse
            anchor = nil
            candidates = merchant.products.map { ResolvedStoryProduct(merchant: merchant, product: $0) }
            groups = [.init(id: "design-library", title: "From the bookshelf", context: "Books and printed matter.", merchantID: merchant.id, products: candidates.map(reference))]
            reason = "Demo publishing affinity yields the merchant's real catalog assortment. The shelf and optional fisheye canvas share the same entities and selection. This is an editorial grouping, not a claimed new launch; repeating grid cells do not represent additional inventory."
        case .activeWorld:
            job = .continueWorld
            title = "For your living room"
            subtitle = "Try one beside the table you saved."
            layout = .continuation
            interaction = .selectForWorld
            anchor = signal.products.first
            candidates = merchant.products.filter {
                $0.title.hasPrefix("Chair #1") || $0.title.hasPrefix("Papa Teddy Chair")
            }.map { ResolvedStoryProduct(merchant: merchant, product: $0) }
            reason = "The demo Living Room World holds a saved coffee table. Select a chair, then carry the same selection into a local room plan. Not a spatial compatibility assessment."
        case .broadJourney:
            guard groups.count >= 2 else { return nil }
            job = .narrow
            title = "Where does your coffee go?"
            subtitle = "A slower morning, or out the door?"
            layout = .directions
            interaction = .steer
            anchor = nil
            candidates = groups.flatMap(\.products).compactMap { NextGenerationFeedCardSpec.resolve($0, in: merchants) }
            reason = "A demo broad coffee search leaves the use case unresolved. Choosing counter or commute filters to that group's actual products and changes the card in place. The other direction cannot leak into the result."
        case .aestheticAffinity:
            guard groups.count >= 2 else { return nil }
            job = .discoverMerchants
            title = "Three shops for your home"
            subtitle = "For the furniture and objects you keep saving."
            layout = .multiMerchant
            interaction = .selectMerchant
            anchor = nil
            candidates = groups.flatMap(\.products).compactMap { NextGenerationFeedCardSpec.resolve($0, in: merchants) }
            reason = "Demo furniture affinity makes Forom, House of Leon and Lichen the primary entities. Each merchant retains its own description and representative inventory when selected."
        }
        guard !candidates.isEmpty else { return nil }
        // Deterministic reranking is deliberately modest. It never introduces
        // an unrelated item and never shuffles a shopper's explicit shortlist.
        if generation > 0, ![.compare, .continueJourney].contains(job) {
            let offset = generation % candidates.count
            candidates = Array(candidates.dropFirst(offset)) + Array(candidates.prefix(offset))
        }
        let alternatives: [NextGenerationCardLayout] = switch layout {
        case .directions, .multiMerchant: [layout] // no misleading product-only alternate
        case .hero: [.hero, .comparison]
        case .merchant: [.merchant, .hero, .fisheye]
        default: [layout, .hero]
        }
        return NextGenerationFeedCardSpec(
            id: "next-gen-\(signal.id)", signal: signal, job: job,
            title: title, subtitle: subtitle, layout: layout, alternatives: alternatives,
            interaction: interaction, anchor: anchor, productReferences: candidates.map(reference),
            reasonForSelection: reason, groups: groups, generation: generation
        )
    }

    private static func reference(_ item: ResolvedStoryProduct) -> FeedStory.ProductReference {
        .init(merchantID: item.merchant.id, productID: item.product.id)
    }
}
