import Foundation
import ShopCompositionCore

// CLI adapter for the exact validator used by the app. Deliberately checks
// structure, not filesystem provenance or live commerce availability.
struct Binding: Decodable {}
struct Card: Decodable {
    let id: String
    let root: CompositionNode
    let alternates: [CompositionNode]
    let entities: [String: Binding]
    let presentation: CompositionPresentation
}
struct Payload: Decodable {
    let schema: String
    let cards: [Card]
    let assets: [String: Binding]
    let journeyTemplates: [String: CompositionJourneyTemplate]?
}

guard CommandLine.arguments.count == 2 else {
    print("Usage: composition-check <composition.json>"); exit(2)
}
do {
    let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    guard data.count <= 2_000_000 else { print("payload: exceeds 2 MB"); exit(1) }
    let payload = try JSONDecoder().decode(Payload.self, from: data)
    guard payload.schema == "shop-composition/2", (1...100).contains(payload.cards.count),
          Set(payload.cards.map(\.id)).count == payload.cards.count else {
        print("payload: unsupported schema or invalid card count/IDs"); exit(1)
    }
    let assets = Set(payload.assets.keys)
    var problems: [CompositionIssue] = []
    for template in (payload.journeyTemplates ?? [:]).values {
        problems += CompositionStructure.issues(in: template.root, roles: Set(template.roles), assets: assets)
    }
    for card in payload.cards {
        let roles = Set(card.entities.keys)
        for root in [card.root] + card.alternates {
            problems += CompositionStructure.issues(in: root, roles: roles, assets: assets)
        }
    }
    guard problems.isEmpty else {
        problems.prefix(50).forEach { print($0.description) }; exit(1)
    }
    print("Validated \(payload.cards.count) cards with ShopCompositionCore")
} catch {
    print("Composition decoding failed: \(error)"); exit(1)
}
