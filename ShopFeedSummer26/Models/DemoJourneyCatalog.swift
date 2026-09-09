import Foundation
import ShopCompositionCore

/// Explicit authored transitions, not live recommendations. Recipes live in the
/// generator; this adapter binds only canonical entities already in the catalog.
@MainActor
enum DemoJourneyCatalog {
    static let room = "ng20-woven-room"
    static let chairs = "ng20-chairs"
    static let footwear = "ng20-salomon-directions"
    static let books = "ng20-standards-library"
    static let roomComparison = "ng20-journey-room-comparison"
    static let footwearLook = "ng20-journey-footwear-look"
    static var launchSignalID: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-startDemoJourney"), args.indices.contains(flag + 1) else { return nil }
        return ["room": room, "footwear": footwear, "books": books][args[flag + 1]]
    }

    static func sourceID(_ id: String) -> String {
        switch id {
        case roomComparison: chairs
        case footwearLook: footwear
        default: id
        }
    }
    static func base(_ id: String) -> GeneratedComposition? {
        NextGeneration20Catalog.definitions.first { $0.id == id }
    }
    static func continuation(for id: String, memory: FeedJourneyMemory) -> GeneratedComposition? {
        if sourceID(id) == chairs, memory.continuation.comparingRoom,
           let source = base(room), let template = NextGeneration20Catalog.journeyTemplate("roomComparison"),
           let slot = source.groups.first(where: { $0.id == "slot.one" }), slot.products.count == 3 {
            var entities: [String: CompositionEntity] = [:]
            for (role, ref) in zip(template.roles, slot.products) {
                entities[role] = source.entities.values.first { $0.reference == ref }
            }
            return bind(source: source, template: template, entities: entities, id: roomComparison,
                        title: "Choose a chair for your room", action: .compare, cta: "Compare chairs")
        }
        if sourceID(id) == footwear, let anchor = memory.continuation.footwearAnchor,
           let source = base("ng20-vomero-kit"), let directions = base(footwear),
           let template = NextGeneration20Catalog.journeyTemplate("footwearLook"),
           let shoe = directions.entities.values.first(where: { $0.merchantID == anchor.merchantID && $0.productID == anchor.productID }) {
            var entities = source.entities
            entities["anchor"] = shoe
            return bind(source: directions, template: template, entities: entities, id: footwearLook,
                        title: "Build around this pair", action: .review, cta: "Review this combination")
        }
        return nil
    }
    private static func bind(source: GeneratedComposition, template: CompositionJourneyTemplate,
                             entities: [String: CompositionEntity], id: String, title: String,
                             action: GeneratedComposition.Action, cta: String) -> GeneratedComposition? {
        guard Set(template.roles) == Set(entities.keys),
              CompositionStructure.issues(in: template.root, roles: Set(entities.keys), assets: []).isEmpty,
              entities.values.allSatisfy({ entity in
                  let art = NextGeneration20Catalog.asset(entity.art)
                  return art?.merchantID == entity.merchantID && art?.productID == entity.productID
              }) else { return nil }
        return .init(id: id, title: title, job: action == .compare ? "compare" : "complete", theme: .sand,
                     entities: entities, order: template.roles, root: template.root,
                     presentation: source.presentation, action: action, cta: cta, background: nil, footer: [],
                     reason: "Authored demo continuation from your explicit selection. Canonical product photography; no new scene is generated.",
                     alternates: [], generation: "Deterministic journey binding; no live model call", destination: nil, slots: nil)
    }
    static func specification(_ definition: GeneratedComposition, source: NextGenerationFeedCardSpec,
                              merchants: [SampleMerchant]) -> NextGenerationFeedCardSpec? {
        guard let first = definition.references.first, definition.references.allSatisfy({ NextGenerationFeedCardSpec.resolve($0, in: merchants) != nil }) else { return nil }
        let signal = PrototypeShoppingSignal(id: definition.id, kind: .activeWorld,
            summary: definition.reason, products: definition.references, merchantID: first.merchantID,
            worldID: "demo-\(sourceID(definition.id))", groups: definition.groups)
        let comparing = definition.action == .compare
        return .init(id: "next-gen-\(definition.id)", signal: signal, job: comparing ? .compare : .complete,
                     title: definition.title, subtitle: "", layout: comparing ? .comparison : .relationship,
                     alternatives: [comparing ? .comparison : .relationship], interaction: comparing ? .shortlist : .browse,
                     anchor: definition.references.first, productReferences: definition.references,
                     reasonForSelection: definition.reason, groups: definition.groups)
    }
}
