import Foundation

/// Fail-closed structural validation at the generation seam. Commerce IDs are
/// additionally resolved against the canonical catalog before a card is planned.
enum CompositionValidation {
    static func accepts(_ payload: NextGeneration20Catalog.Payload) -> Bool {
        guard payload.cards.count <= 100, !payload.cards.isEmpty,
              Set(payload.cards.map(\.id)).count == payload.cards.count else { return false }
        for asset in payload.assets.values {
            guard let image = asset.imageURL, FileManager.default.fileExists(atPath: image.path) else { return false }
            if asset.video != nil {
                guard let video = asset.videoURL, FileManager.default.fileExists(atPath: video.path) else { return false }
            }
        }
        for card in payload.cards {
            let roles = Set(card.entities.keys)
            guard card.title.count <= 70, card.cta.count <= 32,
                  !card.order.isEmpty, Set(card.order) == roles,
                  card.order.count == roles.count, roles.count <= 60,
                  card.entities.values.allSatisfy({ entity in
                      guard entity.productID > 0, let asset = payload.assets[entity.art] else { return false }
                      return asset.merchantID == entity.merchantID && asset.productID == entity.productID
                  }),
                  card.footer.allSatisfy({ roles.contains($0) || $0 == "$group" }),
                  card.background.map({ payload.assets[$0] != nil }) ?? true else { return false }
            for slot in card.slots ?? [] {
                guard roles.contains(slot.role), (1...12).contains(slot.alternatives.count),
                      slot.alternatives.contains(slot.role), slot.alternatives.allSatisfy(roles.contains) else { return false }
            }
            for root in [card.root] + card.alternates {
                var ids = Set<String>()
                guard accepts(root, roles: roles, assets: Set(payload.assets.keys), depth: 0, ids: &ids) else { return false }
            }
        }
        return true
    }
    private static func accepts(_ node: CompositionNode, roles: Set<String>, assets: Set<String>, depth: Int, ids: inout Set<String>) -> Bool {
        guard depth < 9, ids.count < 80, !node.id.isEmpty, ids.insert(node.id).inserted else { return false }
        let validRole: (String) -> Bool = { roles.contains($0) || $0 == "$selected" }
        let children = node.children ?? []
        if let asset = node.asset, !assets.contains(asset) { return false }
        if let role = node.role, !validRole(role) { return false }
        if let list = node.roles, !list.allSatisfy({ roles.contains($0) || $0 == "$group" }) { return false }
        switch node.kind {
        case .row, .column:
            guard (1...6).contains(children.count) else { return false }
            if let weights = node.weights {
                guard weights.count == children.count, weights.allSatisfy({ (1...8).contains($0) }) else { return false }
            }
        case .product:
            guard node.role != nil else { return false }
            if let alternatives = node.alternatives, !alternatives.isEmpty {
                guard alternatives.count <= 12, alternatives.allSatisfy(roles.contains), alternatives.contains(node.role!) else { return false }
            }
        case .media:
            guard node.asset != nil || node.role != nil else { return false }
        case .grid:
            guard (1...4).contains(node.columns ?? 2), !(node.roles ?? []).isEmpty else { return false }
        case .choice:
            let options = node.options ?? []
            guard (2...3).contains(options.count), node.response != nil,
                  Set(options.map(\.id)).count == options.count else { return false }
            for option in options {
                guard !option.roles.isEmpty, option.roles.allSatisfy(roles.contains), option.title.count <= 40,
                      accepts(option.preview, roles: roles, assets: assets, depth: depth + 1, ids: &ids) else { return false }
            }
        case .compare:
            guard (2...4).contains(node.roles?.count ?? 0) else { return false }
        case .steps:
            guard (1...6).contains(node.roles?.count ?? 0), node.labels?.count == node.roles?.count else { return false }
        case .pager:
            guard (1...5).contains(children.count) else { return false }
        case .merchant, .spacer, .canvas: break
        }
        for child in children {
            guard accepts(child, roles: roles, assets: assets, depth: depth + 1, ids: &ids) else { return false }
        }
        if let response = node.response {
            guard accepts(response, roles: roles, assets: assets, depth: depth + 1, ids: &ids) else { return false }
        }
        return true
    }
}
