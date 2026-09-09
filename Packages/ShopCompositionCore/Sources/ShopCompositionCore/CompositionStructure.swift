import Foundation

/// Trusted native capabilities, independent of SwiftUI, catalog I/O and app state.
public enum CompositionKind: String, Codable {
    case spacer, row, column, media, product, grid, choice, compare, steps, pager, merchant, canvas
}
public enum CompositionLayout: String, Codable { case row, column, featured }
public enum CompositionMediaFit: String, Codable { case contain, cover }
public enum CompositionPlayback: String, Codable { case still, video }
public enum CompositionProductPresentation: String, Codable { case object, tile }
public struct CompositionPresentation: Codable {
    public enum ActionStyle: String, Codable { case prominent, link }
    public enum Disclosure: String, Codable { case none, stylingStudy }
    public let actionStyle: ActionStyle
    public let disclosure: Disclosure
}

/// Authored continuation recipe; commerce bindings are supplied and validated
/// by the journey adapter, never invented by the renderer.
public struct CompositionJourneyTemplate: Decodable {
    public let roles: [String]
    public let root: CompositionNode
}

public final class CompositionNode: Codable, Identifiable {
    public let id: String
    public let kind: CompositionKind
    public let children: [CompositionNode]?
    public let weights: [Int]?
    public let asset: String?
    public let role: String?
    public let productPresentation: CompositionProductPresentation?
    public let mediaFit: CompositionMediaFit?
    public let playback: CompositionPlayback?
    public let alternatives: [String]?
    public let roles: [String]?
    public let columns: Int?
    public let options: [CompositionChoice]?
    public let response: CompositionNode?
    public let layout: CompositionLayout?
    public let labels: [String]?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id, kind, children, weights, asset, role, productPresentation, mediaFit,
             playback, alternatives, roles, columns, options, response, layout, labels
    }
    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
    public init(from decoder: Decoder) throws {
        let all = try decoder.container(keyedBy: AnyKey.self)
        let supported = Set(CodingKeys.allCases.map(\.rawValue))
        if let unknown = all.allKeys.first(where: { !supported.contains($0.stringValue) }) {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath + [unknown],
                debugDescription: "Unsupported composition field: \(unknown.stringValue)"))
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(CompositionKind.self, forKey: .kind)
        children = try c.decodeIfPresent([CompositionNode].self, forKey: .children)
        weights = try c.decodeIfPresent([Int].self, forKey: .weights)
        asset = try c.decodeIfPresent(String.self, forKey: .asset)
        role = try c.decodeIfPresent(String.self, forKey: .role)
        productPresentation = try c.decodeIfPresent(CompositionProductPresentation.self, forKey: .productPresentation)
        mediaFit = try c.decodeIfPresent(CompositionMediaFit.self, forKey: .mediaFit)
        playback = try c.decodeIfPresent(CompositionPlayback.self, forKey: .playback)
        alternatives = try c.decodeIfPresent([String].self, forKey: .alternatives)
        roles = try c.decodeIfPresent([String].self, forKey: .roles)
        columns = try c.decodeIfPresent(Int.self, forKey: .columns)
        options = try c.decodeIfPresent([CompositionChoice].self, forKey: .options)
        response = try c.decodeIfPresent(CompositionNode.self, forKey: .response)
        layout = try c.decodeIfPresent(CompositionLayout.self, forKey: .layout)
        labels = try c.decodeIfPresent([String].self, forKey: .labels)
    }
}
public struct CompositionChoice: Codable, Identifiable {
    public let id: String
    public let title: String
    public let roles: [String]
    public let preview: CompositionNode
}
public struct CompositionIssue: Equatable, CustomStringConvertible {
    public let path: String
    public let message: String
    public init(path: String, message: String) { self.path = path; self.message = message }
    public var description: String { "\(path): \(message)" }
}

/// Validates one complete tree against allowed role and asset IDs. No filesystem,
/// merchant lookup or UI dependencies; callers decide how failures are presented.
public enum CompositionStructure {
    public static func issues(in root: CompositionNode, roles: Set<String>, assets: Set<String>) -> [CompositionIssue] {
        var issues: [CompositionIssue] = []
        var ids = Set<String>()
        var visitedCount = 0
        var reportedBudget = false
        func visit(_ node: CompositionNode, path: String, depth: Int) {
            func check(_ condition: Bool, _ field: String, _ message: String) {
                if !condition { issues.append(.init(path: "\(path).\(field)", message: message)) }
            }
            guard depth < 9, visitedCount < 80 else {
                if !reportedBudget {
                    issues.append(.init(path: path, message: "Tree exceeds depth/node budget"))
                    reportedBudget = true
                }
                return
            }
            visitedCount += 1
            check(!node.id.isEmpty && ids.insert(node.id).inserted, "id", "Node IDs must be nonempty and unique")
            let children = node.children ?? []
            let validRole: (String) -> Bool = { roles.contains($0) || $0 == "$selected" }
            if let role = node.role { check(validRole(role), "role", "Unknown role: \(role)") }
            if let asset = node.asset { check(assets.contains(asset), "asset", "Unknown asset: \(asset)") }
            if let list = node.roles { check(list.allSatisfy { roles.contains($0) || $0 == "$group" }, "roles", "Unknown product role") }
            check(node.productPresentation == nil || node.kind == .product, "productPresentation", "Only product nodes have product presentation")
            check((node.mediaFit == nil && node.playback == nil) || node.kind == .media, "mediaFit/playback", "Only media nodes have media options")
            check(node.layout == nil || node.kind == .choice || node.kind == .steps, "layout", "Layout is only supported by choices and steps")
            check(children.isEmpty || [.row, .column, .pager].contains(node.kind), "children", "This primitive does not render children")
            check(node.response == nil || node.kind == .choice, "response", "Only choices render a response")
            check(node.options == nil || node.kind == .choice, "options", "Only choices render options")
            check(node.weights == nil || node.kind == .row || node.kind == .column, "weights", "Only stacks use weights")
            check(node.columns == nil || node.kind == .grid, "columns", "Only grids use column counts")
            check(node.labels == nil || node.kind == .steps, "labels", "Only steps use labels")
            switch node.kind {
            case .row, .column:
                check((1...6).contains(children.count), "children", "Stacks require 1...6 children")
                if let weights = node.weights {
                    check(weights.count == children.count && weights.allSatisfy { (1...8).contains($0) }, "weights", "Provide one weight in 1...8 per child")
                }
            case .product:
                check(node.role != nil, "role", "Product requires a role")
                if let alternatives = node.alternatives, !alternatives.isEmpty {
                    check(alternatives.count <= 12 && alternatives.allSatisfy(roles.contains) && alternatives.contains(node.role ?? ""), "alternatives", "Alternatives must include the anchor and resolve to allowed roles")
                }
            case .media:
                check(node.asset != nil || node.role != nil, "asset/role", "Media requires an asset or role")
            case .grid:
                check((1...4).contains(node.columns ?? 2) && !(node.roles ?? []).isEmpty, "columns/roles", "Grid requires roles and 1...4 columns")
            case .choice:
                let options = node.options ?? []
                check((2...3).contains(options.count) && node.response != nil, "options/response", "Choices require 2...3 options and a response")
                check(Set(options.map(\.id)).count == options.count && options.allSatisfy { !$0.id.isEmpty }, "options", "Choice IDs must be nonempty and unique")
                check(node.layout != .featured || options.count == 3, "layout", "Featured choice requires exactly three options")
                for (index, option) in options.enumerated() {
                    check(!option.roles.isEmpty && option.roles.allSatisfy(roles.contains) && option.title.count <= 40, "options[\(index)]", "Choice must have allowed roles and a title of at most 40 characters")
                    visit(option.preview, path: "\(path).options[\(index)].preview", depth: depth + 1)
                }
            case .compare:
                check((2...4).contains(node.roles?.count ?? 0), "roles", "Comparison requires 2...4 roles")
            case .steps:
                check((1...6).contains(node.roles?.count ?? 0) && node.labels?.count == node.roles?.count, "labels/roles", "Steps require 1...6 roles and matching labels")
                check(node.layout != .featured, "layout", "Steps support row or column layout")
            case .pager:
                check((1...5).contains(children.count), "children", "Pager requires 1...5 children")
            case .merchant, .spacer, .canvas: break
            }
            for (index, child) in children.enumerated() { visit(child, path: "\(path).children[\(index)]", depth: depth + 1) }
            if let response = node.response { visit(response, path: "\(path).response", depth: depth + 1) }
        }
        visit(root, path: root.id, depth: 0)
        return issues
    }
}
