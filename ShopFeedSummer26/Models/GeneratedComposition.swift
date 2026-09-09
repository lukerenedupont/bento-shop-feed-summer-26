import Foundation
import SwiftUI
import ShopCompositionCore

// The app adapts a UI-independent, typed composition contract.
typealias CompositionKind = ShopCompositionCore.CompositionKind
typealias CompositionNode = ShopCompositionCore.CompositionNode
typealias CompositionChoice = ShopCompositionCore.CompositionChoice
typealias CompositionPresentation = ShopCompositionCore.CompositionPresentation
struct CompositionEntity: Codable {
    let merchantID: String
    let productID: Int
    let art: String
    let label: String
    let scene: String?
    let pair: String?
    let contact: String?
    var reference: FeedStory.ProductReference { .init(merchantID: merchantID, productID: productID) }
}
struct CompositionAsset: Decodable {
    let image: String
    let video: String?
    let generated: Bool
    let merchantID: String?
    let productID: Int?
    var imageURL: URL? { Self.localURL(image) }
    var videoURL: URL? { video.flatMap(Self.localURL) }
    private static func localURL(_ path: String) -> URL? {
        guard !path.contains(".."), !path.contains(":") else { return nil }
        if path.hasPrefix("bundle/media/") {
            return Bundle.main.resourceURL?.appendingPathComponent(path)
        }
        return DossierReviewLibrary.url(path)
    }
}
enum CompositionTheme: String, Codable {
    case paper, ink, sand, sage, blue, rose
    var surface: Color {
        switch self {
        case .paper: Color(hex: "#F4F3EF")
        case .ink: Color(hex: "#171918")
        case .sand: Color(hex: "#E8DDCA")
        case .sage: Color(hex: "#D8DECF")
        case .blue: Color(hex: "#234FC2")
        case .rose: Color(hex: "#E8C0C6")
        }
    }
    var usesDarkInk: Bool { self != .ink && self != .blue }
}
struct CompositionSlot: Codable {
    let role: String
    let alternatives: [String]
}
struct GeneratedComposition: Codable, Identifiable {
    enum Action: String, Codable { case review, detail, save, compare, canvas, merchant }
    let id: String
    let title: String
    let job: String
    let theme: CompositionTheme
    let entities: [String: CompositionEntity]
    let order: [String]
    let root: CompositionNode
    let presentation: CompositionPresentation
    let action: Action
    let cta: String
    let background: String?
    let footer: [String]
    let reason: String
    let alternates: [CompositionNode]
    let generation: String
    let destination: String?
    let slots: [CompositionSlot]?
    var usesDarkInk: Bool { background == nil && theme.usesDarkInk }
    var references: [FeedStory.ProductReference] {
        var seen = Set<FeedStory.ProductReference>()
        return order.compactMap { entities[$0]?.reference }.filter { seen.insert($0).inserted }
    }
    func root(revision: Int) -> CompositionNode {
        ([root] + alternates)[max(0, revision) % (alternates.count + 1)]
    }
    var groups: [PrototypeContentGroup] {
        var result: [PrototypeContentGroup] = []
        var seen = Set<String>()
        func walk(_ node: CompositionNode) {
            if let roles = node.alternatives, !roles.isEmpty, let role = node.role {
                let id = "slot.\(role)"
                if seen.insert(id).inserted {
                    result.append(.init(id: id, title: "Alternatives", context: "", merchantID: nil,
                        products: roles.compactMap { entities[$0]?.reference }))
                }
            }
            for choice in node.options ?? [] {
                if seen.insert(choice.id).inserted {
                    result.append(.init(id: choice.id, title: choice.title, context: "", merchantID: nil,
                        products: choice.roles.compactMap { entities[$0]?.reference }))
                }
                walk(choice.preview)
            }
            for child in node.children ?? [] { walk(child) }
            if let response = node.response { walk(response) }
        }
        ([root] + alternates).forEach(walk)
        for slot in slots ?? [] where seen.insert("slot.\(slot.role)").inserted {
            result.append(.init(id: "slot.\(slot.role)", title: "Alternatives", context: "", merchantID: nil,
                products: slot.alternatives.compactMap { entities[$0]?.reference }))
        }
        return result
    }
}

/// Composition generation seam. This review uses agent-authored model-output
/// fixtures, not a live AI service. Catalog validation happens before rendering.
enum NextGeneration20Catalog {
    struct Payload: Decodable {
        let schema: String
        let cards: [GeneratedComposition]
        let assets: [String: CompositionAsset]
        var journeyTemplates: [String: CompositionJourneyTemplate]? = nil
    }
    static let enabled: Bool = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-dossierOnly") || args.contains("-legacyGenerativeFeed") || args.contains("-quietStructuralReview") { return false }
        if args.contains("-nextGeneration20") { UserDefaults.standard.set(true, forKey: "nextGeneration20Enabled") }
        return UserDefaults.standard.bool(forKey: "nextGeneration20Enabled")
    }()
    private static let payload: Payload? = {
        do {
            guard let url = Bundle.main.url(forResource: "ng20-compositions", withExtension: "json") else { return nil }
            let data = try Data(contentsOf: url)
            guard data.count <= 2_000_000 else { print("Composition payload exceeds 2 MB"); return nil }
            let decoded = try JSONDecoder().decode(Payload.self, from: data)
            guard decoded.schema == "shop-composition/2" else { print("Unsupported composition schema: \(decoded.schema)"); return nil }
            let issues = CompositionValidation.issues(in: decoded)
            guard issues.isEmpty else {
                print(issues.prefix(20).map(\.description).joined(separator: "\n"))
                return nil
            }
            return decoded
        } catch {
            print("Composition decoding failed: \(error)")
            return nil
        }
    }()
    static var definitions: [GeneratedComposition] { payload?.cards ?? [] }
    static func journeyTemplate(_ id: String) -> CompositionJourneyTemplate? { payload?.journeyTemplates?[id] }
    static func specificationJSON(for definition: GeneratedComposition) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(definition) else { return "Unavailable" }
        return String(decoding: data, as: UTF8.self)
    }
    static func specificationJSON(for id: String) -> String {
        guard let url = Bundle.main.url(forResource: "ng20-compositions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cards = object["cards"] as? [[String: Any]],
              let card = cards.first(where: { $0["id"] as? String == id }),
              let encoded = try? JSONSerialization.data(withJSONObject: card, options: [.prettyPrinted, .sortedKeys]) else { return "Unavailable" }
        return String(decoding: encoded, as: UTF8.self)
    }
    static func definition(for spec: NextGenerationFeedCardSpec) -> GeneratedComposition? {
        definitions.first { $0.id == spec.signal.id }
    }
    static func asset(_ id: String?) -> CompositionAsset? { id.flatMap { payload?.assets[$0] } }
    static var signals: [PrototypeShoppingSignal] {
        definitions.compactMap { definition in
            guard let first = definition.references.first else { return nil }
            let kind: PrototypeShoppingSignal.Kind = switch definition.job {
            case "complete": .purchase
            case "compare", "inspect": .repeatedViews
            case "narrow": .broadJourney
            case "gift": .activeWorld
            default: .merchantAffinity
            }
            return .init(id: definition.id, kind: kind,
                summary: "Authored review scenario, not observed shopper history. \(definition.reason)",
                products: definition.references, merchantID: first.merchantID,
                worldID: "world-\(definition.id)", groups: definition.groups)
        }
    }
    static func card(signal: PrototypeShoppingSignal, merchants: [SampleMerchant], generation: Int) -> NextGenerationFeedCardSpec? {
        guard let definition = definitions.first(where: { $0.id == signal.id }),
              definition.references.allSatisfy({ NextGenerationFeedCardSpec.resolve($0, in: merchants) != nil }) else { return nil }
        let job: PrototypeShoppingJob = switch definition.job {
        case "complete": .complete
        case "compare": .compare
        case "inspect": .continueJourney
        case "narrow": .narrow
        case "gift": .continueWorld
        default: .merchantDiscovery
        }
        let layout: NextGenerationCardLayout = switch job {
        case .complete: .relationship
        case .compare: .comparison
        case .narrow: .directions
        case .merchantDiscovery: .merchant
        default: .hero
        }
        return .init(id: "next-gen-\(definition.id)", signal: signal, job: job,
            title: definition.title, subtitle: "", layout: layout, alternatives: [layout],
            interaction: definition.action == .compare ? .shortlist : job == .narrow ? .steer : .browse,
            anchor: definition.references.first, productReferences: definition.references,
            reasonForSelection: definition.reason + " \(definition.generation)", groups: definition.groups, generation: generation)
    }
}
