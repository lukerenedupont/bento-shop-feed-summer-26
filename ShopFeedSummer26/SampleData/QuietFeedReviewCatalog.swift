import Foundation

/// PROTOTYPE — five authored jobs on the existing semantic feed seam.
/// No live model, purchase history, inventory freshness, or account mutations.
enum QuietFeedReviewCatalog {
    static let enabled: Bool = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-legacyGenerativeFeed") { return false }
        if args.contains("-quietFeedReview") { UserDefaults.standard.set(true, forKey: "quietFeedReviewEnabled") }
        return UserDefaults.standard.bool(forKey: "quietFeedReviewEnabled")
    }()

    static let merchants: [SampleMerchant] = {
        guard let url = Bundle.main.url(forResource: "quiet-review-catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return LocalMerchantService.decodeMerchants(from: data)
    }()

    static func ref(_ merchant: String, _ product: Int) -> FeedStory.ProductReference {
        .init(merchantID: merchant, productID: product)
    }
    static let tee = ref("bode", 8229947965634)
    static let sofa = ref("house-of-leon", 8505646055597)
    static let pants = [8925922951356, 9459028754620, 9007369158844].map { ref("sneaker-politics", $0) }
    static let sofas = [8505646055597, 8505645662381, 8214794371245].map { ref("house-of-leon", $0) }
    static let shoes = [7919493251255, 8151144530103, 4643336060976].map { ref("extra-butter-salomon", $0) }
    static let roomGroups: [PrototypeContentGroup] = [
        .init(id: "table", title: "Table", context: "", merchantID: nil, products: [
            ref("forom", 8817998889091), ref("forom", 8774121619587)]),
        .init(id: "chair", title: "Chair", context: "", merchantID: "house-of-leon", products: [
            ref("house-of-leon", 7873592688813), ref("house-of-leon", 7873592721581)])
    ]
    static let directions: [PrototypeContentGroup] = [
        .init(id: "classic", title: "Classic", context: "", merchantID: "goodr", products:
            [7446592192570, 7557722865722, 7557722210362].map { ref("goodr", $0) }),
        .init(id: "playful", title: "A little weird", context: "", merchantID: "goodr", products:
            [7389500047418, 7385047629882, 7569018617914].map { ref("goodr", $0) })
    ]
    static let signals: [PrototypeShoppingSignal] = [
        .init(id: "quiet-outfit", kind: .purchase,
              summary: "Authored styling scenario, NOT a purchase claim. BODE dossier supplied by Luke; exact tee and pants resolved from merchant catalogs.",
              products: [tee], merchantID: "bode"),
        .init(id: "quiet-compare", kind: .repeatedViews,
              summary: "Simulated sofa shortlist. Prices are frozen catalog snapshots; compare only known facts.",
              products: sofas, merchantID: "house-of-leon"),
        .init(id: "quiet-merchant", kind: .merchantAffinity,
              summary: "Simulated Salomon affinity. Existing Extra Butter campaign, not a verified new release.",
              products: shoes, merchantID: "extra-butter-salomon"),
        .init(id: "quiet-room", kind: .activeWorld,
              summary: "Simulated saved sofa. A composition sketch, not a spatial fit assessment.",
              products: [sofa], merchantID: "house-of-leon", worldID: "quiet-living-room", groups: roomGroups),
        .init(id: "quiet-direction", kind: .broadJourney,
              summary: "Simulated sunglasses journey. Authored visual groups, no live recommendation model.",
              products: [], merchantID: "goodr", worldID: "quiet-sunglasses", groups: directions)
    ]

    static func card(signal: PrototypeShoppingSignal, merchants: [SampleMerchant], generation: Int) -> NextGenerationFeedCardSpec? {
        let title: String
        let job: PrototypeShoppingJob
        let layout: NextGenerationCardLayout
        let interaction: PrototypeCardInteraction
        let anchor: FeedStory.ProductReference?
        let products: [FeedStory.ProductReference]
        switch signal.id {
        case "quiet-outfit":
            title = "Style this tee"; job = .complete; layout = .relationship; interaction = .swap
            anchor = tee; products = pants
        case "quiet-compare":
            title = "Still considering these?"; job = .compare; layout = .comparison; interaction = .shortlist
            anchor = nil; products = sofas
        case "quiet-merchant":
            title = "Salomon at Extra Butter"; job = .merchantDiscovery; layout = .merchant; interaction = .browse
            anchor = nil; products = shoes
        case "quiet-room":
            title = "Works with your sofa"; job = .continueWorld; layout = .continuation; interaction = .selectForWorld
            anchor = sofa; products = roomGroups.flatMap(\.products)
        case "quiet-direction":
            title = "Pick a direction"; job = .narrow; layout = .directions; interaction = .steer
            anchor = nil; products = directions.flatMap(\.products)
        default: return nil
        }
        guard (products + [anchor].compactMap { $0 }).allSatisfy({ NextGenerationFeedCardSpec.resolve($0, in: merchants) != nil }) else { return nil }
        return .init(id: "next-gen-\(signal.id)", signal: signal, job: job, title: title, subtitle: "",
                     layout: layout, alternatives: [layout], interaction: interaction, anchor: anchor,
                     productReferences: products, reasonForSelection: signal.summary, groups: signal.groups, generation: generation)
    }
}
