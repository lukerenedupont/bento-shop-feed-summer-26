import Foundation
import ShopCompositionCore

/// App adapter: the pure core validates trees; this layer validates local media
/// and commerce bindings. Diagnostics retain the card/node/field that failed.
enum CompositionValidation {
    static func accepts(_ payload: NextGeneration20Catalog.Payload) -> Bool {
        issues(in: payload).isEmpty
    }

    static func issues(in payload: NextGeneration20Catalog.Payload) -> [CompositionIssue] {
        var result: [CompositionIssue] = []
        func require(_ condition: Bool, _ path: String, _ message: String) {
            if !condition { result.append(.init(path: path, message: message)) }
        }
        require((1...100).contains(payload.cards.count), "cards", "Payload requires 1...100 cards")
        require(Set(payload.cards.map(\.id)).count == payload.cards.count, "cards.id", "Card IDs must be unique")
        for (key, asset) in payload.assets {
            require(asset.imageURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false,
                    "assets.\(key).image", "Missing or unsafe local image")
            if asset.video != nil {
                require(asset.videoURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false,
                        "assets.\(key).video", "Missing or unsafe local video")
            }
        }
        for template in (payload.journeyTemplates ?? [:]).values {
            result += CompositionStructure.issues(in: template.root, roles: Set(template.roles), assets: Set(payload.assets.keys))
        }
        for card in payload.cards {
            let roles = Set(card.entities.keys)
            require(card.title.count <= 70 && card.cta.count <= 32, card.id + ".copy", "Title/CTA exceeds native text budget")
            require(!card.order.isEmpty && Set(card.order) == roles && card.order.count == roles.count && roles.count <= 60,
                    card.id + ".order", "Order must list every role exactly once, up to 60 roles")
            for (role, entity) in card.entities {
                let asset = payload.assets[entity.art]
                require(entity.productID > 0 && asset?.merchantID == entity.merchantID && asset?.productID == entity.productID,
                        card.id + ".entities.\(role).art", "Artwork must bind to the same merchant and product")
            }
            require(card.footer.allSatisfy { roles.contains($0) || $0 == "$group" }, card.id + ".footer", "Unknown footer role")
            require(card.background.map { payload.assets[$0] != nil } ?? true, card.id + ".background", "Unknown background asset")
            if card.presentation.disclosure == .stylingStudy {
                require(card.background.flatMap { payload.assets[$0] }?.generated == true,
                        card.id + ".presentation.disclosure", "Styling-study disclosure requires a generated background")
            }
            for slot in card.slots ?? [] {
                require(roles.contains(slot.role) && (1...12).contains(slot.alternatives.count)
                        && slot.alternatives.contains(slot.role) && slot.alternatives.allSatisfy(roles.contains),
                        card.id + ".slots.\(slot.role)", "Swap must retain its anchor and use allowed roles")
            }
            for root in [card.root] + card.alternates {
                result += CompositionStructure.issues(in: root, roles: roles, assets: Set(payload.assets.keys))
            }
        }
        return result
    }
}
