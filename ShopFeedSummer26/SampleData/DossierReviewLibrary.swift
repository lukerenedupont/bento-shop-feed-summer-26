import Foundation

/// Review-only asset adapter. The semantic card/interaction seam stays unchanged.
struct DossierReviewObject: Decodable, Identifiable {
    let reference: FeedStory.ProductReference
    let role: String
    let image: String
    let originalImage: String
    var id: String { "\(reference.merchantID)-\(reference.productID)" }
}
struct DossierReviewRecord: Decodable, Identifiable {
    let key: String
    let family: String
    let title: String
    let merchant: String
    let objects: [DossierReviewObject]
    let images: [String: String]
    let videos: [String: String]
    let surface: String
    let note: String
    let defaultVisible: Bool
    var id: String { key }
    var anchor: DossierReviewObject { objects[0] }
    var isAssembly: Bool { ["room", "outfit", "kids", "setup"].contains(family) }
    var isOutfit: Bool { family == "outfit" || family == "kids" }
    var isWorld: Bool { ["room", "gift", "setup"].contains(family) }
    var visibleObjects: [DossierReviewObject] {
        ["watch", "merchant"].contains(family) ? [anchor] : objects
    }
    var sceneVariants: [String] {
        if family == "gift" { return ["gift", "object0"] }
        // Lead with a readable whole-scene still. The supplied films have
        // dramatic macro moves, so reveal those on the next swipe (except watches).
        if family == "outfit" || family == "kids" { return ["look0", "look1", "pairSquare"] }
        if family == "watch" { return ["look0", "look1", "pairSquare"] }
        return ["look1", "look0", "pairSquare"]
    }
    func imageURL(_ variant: String) -> URL? { images[variant].flatMap(DossierReviewLibrary.url) }
}

enum DossierReviewLibrary {
    static let enabled: Bool = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-quietStructuralReview") || args.contains("-legacyGenerativeFeed") { return false }
        if args.contains("-bentoMediaReview") { UserDefaults.standard.set(true, forKey: "bentoMediaReviewEnabled") }
        return UserDefaults.standard.bool(forKey: "bentoMediaReviewEnabled")
    }()
    static let records: [DossierReviewRecord] = decode("dossier-review-library") ?? []
    static let merchants: [SampleMerchant] = {
        guard let url = url("dossier-review-merchants.json"), let data = try? Data(contentsOf: url) else { return [] }
        return LocalMerchantService.decodeMerchants(from: data)
    }()
    static func url(_ filename: String) -> URL? {
        let path = filename as NSString
        return Bundle.main.url(forResource: path.deletingPathExtension, withExtension: path.pathExtension)
    }
    private static func decode<T: Decodable>(_ name: String) -> T? {
        guard let url = url(name + ".json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    static func record(for spec: NextGenerationFeedCardSpec) -> DossierReviewRecord? {
        records.first { spec.signal.id == "dossier-\($0.key)" }
    }
    static var signals: [PrototypeShoppingSignal] {
        records.map { record in
            .init(id: "dossier-\(record.key)", kind: record.isWorld ? .activeWorld : record.family == "watch" ? .repeatedViews : record.family == "merchant" ? .merchantAffinity : .purchase,
                  summary: "Authored \(record.family) scenario. \(record.note)", products: [record.anchor.reference],
                  merchantID: record.anchor.reference.merchantID, worldID: "review-\(record.key)")
        }
    }
    static func card(signal: PrototypeShoppingSignal, merchants: [SampleMerchant], generation: Int) -> NextGenerationFeedCardSpec? {
        guard let record = records.first(where: { signal.id == "dossier-\($0.key)" }) else { return nil }
        var references = record.visibleObjects.map(\.reference)
        var groups: [PrototypeContentGroup] = []
        if record.isAssembly {
            for (index, object) in record.objects.dropFirst().enumerated() {
                var choices = [object.reference]
                if record.family == "outfit", index == 0 {
                    choices += QuietFeedReviewCatalog.pants.prefix(2)
                } else if record.family == "room", object.role.lowercased().contains("chair") {
                    choices += [.init(merchantID: "house-of-leon", productID: 7873592688813), .init(merchantID: "house-of-leon", productID: 7873592721581)]
                } else if record.family == "room", object.role.lowercased().contains("table") {
                    choices += [.init(merchantID: "forom", productID: 8817998889091), .init(merchantID: "forom", productID: 8774121619587)]
                }
                groups.append(.init(id: object.id, title: object.role, context: "", merchantID: nil, products: choices))
                references += choices.dropFirst()
            }
        }
        guard references.allSatisfy({ NextGenerationFeedCardSpec.resolve($0, in: merchants) != nil }) else { return nil }
        let job: PrototypeShoppingJob = record.isOutfit ? .complete : record.isWorld ? .continueWorld : record.family == "watch" ? .continueJourney : .merchantDiscovery
        let layout: NextGenerationCardLayout = record.isOutfit ? .relationship : record.isWorld ? .continuation : record.family == "watch" ? .hero : .merchant
        let interaction: PrototypeCardInteraction = record.isOutfit ? .swap : record.isWorld ? .selectForWorld : .browse
        return .init(id: "next-gen-\(signal.id)", signal: signal, job: job, title: record.title, subtitle: "",
                     layout: layout, alternatives: [layout], interaction: interaction, anchor: record.anchor.reference,
                     productReferences: references, reasonForSelection: signal.summary, groups: groups, generation: generation)
    }
}
