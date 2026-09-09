import Foundation

/// Authored examples of generative output, not a claim of runtime AI generation.
/// Commerce references and bounded scene geometry are data; Shop owns type,
/// navigation, hit targets, motion and all actual product destinations.
struct EditorialFeedPlan: Decodable, Identifiable {
    struct Placement: Decodable {
        let product: Int // -1 follows the shopper's focused product.
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let image: Int
        let shape: String
    }
    let id: String
    let merchant: String
    let title: String
    let kicker: String
    let treatment: String
    let palette: String
    let products: [Int]
    let labels: [String]
    let job: String
    let scene: [Placement]
    let backdrop: Bool
    let photoIndex: Int
    let headlineAnchor: String
    let interaction: String
    let showChoices: Bool

    var darkText: Bool { !backdrop }
    var references: [FeedStory.ProductReference] {
        products.map { .init(merchantID: merchant, productID: $0) }
    }
    var signal: PrototypeShoppingSignal {
        .init(id: id, kind: .merchantAffinity,
              summary: "Design fixture: explore \(kicker). Not observed account activity.",
              products: references, merchantID: merchant)
    }
}

enum EditorialFeedCatalog {
    static let plans: [EditorialFeedPlan] = {
        guard let url = Bundle.main.url(forResource: "EDITORIAL_PLANS", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([EditorialFeedPlan].self, from: data) else { return [] }
        return decoded.filter { plan in
            !plan.products.isEmpty && plan.products.count == plan.labels.count && plan.scene.allSatisfy {
                $0.product >= -1 && $0.product < plan.products.count && $0.width > 0 && $0.width <= 1
                    && $0.height > 0 && $0.height <= 1 && (0...1).contains($0.x) && (0...1).contains($0.y)
            }
        }
    }()

    static func plan(for id: String) -> EditorialFeedPlan? { plans.first { $0.id == id } }

    static func specification(_ plan: EditorialFeedPlan, merchants: [SampleMerchant], generation: Int) -> NextGenerationFeedCardSpec? {
        guard plan.references.allSatisfy({ NextGenerationFeedCardSpec.resolve($0, in: merchants) != nil }) else { return nil }
        let layout: NextGenerationCardLayout = plan.treatment == "books" ? .merchant : .hero
        return .init(
            id: "next-gen-\(plan.id)", signal: plan.signal, job: .merchantDiscovery,
            title: plan.title, subtitle: plan.kicker, layout: layout, alternatives: [layout],
            interaction: .browse, anchor: nil, productReferences: plan.references,
            reasonForSelection: "Authored generative-output example. \(plan.job) All images come from the referenced products' canonical galleries. Regeneration revalidates references; it does not call a model.",
            groups: [.init(id: plan.id, title: plan.title, context: plan.job, merchantID: plan.merchant, products: plan.references)],
            generation: generation
        )
    }
}
