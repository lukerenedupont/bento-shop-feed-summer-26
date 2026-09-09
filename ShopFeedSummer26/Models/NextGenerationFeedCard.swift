import Foundation

// PROTOTYPE — semantic specifications, not model-authored visual values.
enum NextGenerationCardLayout: String, CaseIterable, Identifiable {
    case relationship = "Relationship"
    case comparison = "Comparison"
    case merchant = "Merchant"
    case continuation = "Continuation"
    case hero = "Hero"
    case directions = "Directions"
    case multiMerchant = "Multi-merchant"
    case fisheye = "Fisheye canvas"
    var id: String { rawValue }
}

enum PrototypeShoppingJob: String, CaseIterable, Identifiable {
    case complete = "Complete a purchase"
    case compare = "Compare a shortlist"
    case continueJourney = "Resume a shortlist"
    case merchantDiscovery = "Explore a familiar merchant"
    case continueWorld = "Continue a World"
    case narrow = "Choose a direction"
    case discoverMerchants = "Discover related merchants"
    var id: String { rawValue }
}

enum PrototypeCardInteraction: String {
    case swap = "Swap the supporting product"
    case shortlist = "Focus and compare a candidate"
    case browse = "Browse the merchant assortment"
    case selectForWorld = "Choose an item for the room plan"
    case steer = "Choose a direction and refine the card"
    case selectMerchant = "Explore a merchant"

    var level: String {
        switch self {
        case .selectForWorld, .steer: "Stateful (session only)"
        default: "Interactive (local)"
        }
    }
}

/// A real merchant, or an explicitly editorial grouping—not a fabricated
/// merchant collection. Product references stay coupled to their grouping.
struct PrototypeContentGroup: Identifiable {
    let id: String
    let title: String
    let context: String
    let merchantID: String?
    let products: [FeedStory.ProductReference]
}

struct PrototypeShoppingSignal: Identifiable {
    enum Kind: String, CaseIterable, Identifiable {
        case purchase = "Purchased jacket"
        case repeatedViews = "Repeated chair views"
        case savedShortlist = "Saved chair shortlist"
        case merchantAffinity = "Publishing affinity"
        case activeWorld = "Active living room"
        case broadJourney = "Broad coffee search"
        case aestheticAffinity = "Furniture affinity"
        var id: String { rawValue }
    }
    let id: String
    var kind: Kind
    var summary: String
    let products: [FeedStory.ProductReference]
    let merchantID: String
    var worldID: String? = nil
    var groups: [PrototypeContentGroup] = []

    var supportedJobs: [PrototypeShoppingJob] {
        switch kind {
        case .purchase: [.complete]
        case .repeatedViews, .savedShortlist: [.compare, .continueJourney]
        case .merchantAffinity: [.merchantDiscovery]
        case .activeWorld: [.continueWorld]
        case .broadJourney: [.narrow]
        case .aestheticAffinity: [.discoverMerchants]
        }
    }
    var alternateSignals: [Kind] {
        switch kind {
        case .repeatedViews, .savedShortlist: [.repeatedViews, .savedShortlist]
        default: [kind]
        }
    }
}

enum PrototypePrimaryEntity {
    case product(FeedStory.ProductReference)
    case merchant(String)
    case merchantGroup([String])
    case journey(String)
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
    var groups: [PrototypeContentGroup] = []
    var generation = 0

    var primaryEntity: PrototypePrimaryEntity {
        switch job {
        case .merchantDiscovery: .merchant(signal.merchantID)
        case .discoverMerchants: .merchantGroup(groups.compactMap(\.merchantID))
        default: anchor.map(PrototypePrimaryEntity.product) ?? .journey(signal.worldID ?? signal.id)
        }
    }
    var isQuietReview: Bool { signal.id.hasPrefix("quiet-") || signal.id.hasPrefix("dossier-") }
    var prefersDarkNavigationText: Bool {
        // This card's entire surface is film, including the area behind the header.
        if signal.id == "dossier-6d91ee4227655be2" { return false }
        return isQuietReview || job != .merchantDiscovery
    }
    var accessibilityDescription: String { "\(title). \(subtitle). \(interaction.rawValue)." }

    func resolvedProducts(from merchants: [SampleMerchant]) -> [ResolvedStoryProduct] {
        productReferences.compactMap { Self.resolve($0, in: merchants) }
    }
    static func resolve(_ ref: FeedStory.ProductReference, in merchants: [SampleMerchant]) -> ResolvedStoryProduct? {
        guard let merchant = merchants.first(where: { $0.id == ref.merchantID }),
              let product = merchant.products.first(where: { $0.id == ref.productID }) else { return nil }
        return ResolvedStoryProduct(merchant: merchant, product: product)
    }
}
