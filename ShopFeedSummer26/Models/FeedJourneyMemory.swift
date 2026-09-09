import Foundation

/// Device-local demo memory, separate from composition, account saves and World
/// inference. Checkpoints are opaque to this module; the app owns their schema.
struct FeedJourneyMemory: Codable {
    struct Product: Codable, Hashable {
        let merchantID: String
        let productID: Int
        var id: String { "\(merchantID)-\(productID)" }
    }
    struct Continuation: Codable, Equatable {
        var footwearAnchor: Product?
        var comparingRoom = false
    }
    enum Scope: String, Codable { case room, footwear, books, standalone }
    struct KeptSelection: Codable, Identifiable {
        let id: UUID
        let sourceSignalID: String
        let stateID: String
        let title: String
        let products: [Product]
        let checkpoint: Data
        let linkedCheckpoints: [String: Data]
        let scope: Scope
        let continuation: Continuation
    }
    private(set) var version = 1
    var hasSeenDisclosure = false
    var checkpoints: [String: Data] = [:]
    var continuation = Continuation()
    private(set) var kept: [KeptSelection] = []

    mutating func keep(source: String, stateID: String, title: String, products: [Product], checkpoint: Data,
                       scope: Scope = .standalone, linkedStateIDs: [String] = []) {
        guard !products.isEmpty, products.count <= 60, checkpoint.count <= 100_000,
              products.allSatisfy({ !$0.merchantID.isEmpty && $0.productID > 0 }) else { return }
        // An exact selection is immutable; browsing does not rewrite it.
        if kept.contains(where: { $0.sourceSignalID == source && $0.products == products }) { return }
        kept.insert(.init(id: UUID(), sourceSignalID: source, stateID: stateID, title: title,
                          products: products, checkpoint: checkpoint,
                          linkedCheckpoints: checkpoints.filter { linkedStateIDs.contains($0.key) },
                          scope: scope, continuation: continuation), at: 0)
        if kept.count > 50 { kept.removeLast(kept.count - 50) }
    }
    mutating func resume(_ id: UUID) -> KeptSelection? {
        guard let selection = kept.first(where: { $0.id == id }) else { return nil }
        checkpoints[selection.stateID] = selection.checkpoint
        // Resuming one journey never resets another journey's decisions.
        checkpoints.merge(selection.linkedCheckpoints) { _, saved in saved }
        switch selection.scope {
        case .footwear: continuation.footwearAnchor = selection.continuation.footwearAnchor
        case .room: continuation.comparingRoom = selection.continuation.comparingRoom
        case .books, .standalone: break
        }
        return selection
    }
    mutating func remove(_ id: UUID) { kept.removeAll { $0.id == id } }

    static func restore(_ data: Data?) -> Self {
        guard let data, data.count <= 2_000_000,
              let value = try? JSONDecoder().decode(Self.self, from: data), value.version == 1,
              value.checkpoints.count <= 100, value.kept.count <= 50,
              value.kept.allSatisfy({ !$0.products.isEmpty && $0.products.count <= 60 && $0.checkpoint.count <= 100_000 })
        else { return .init() }
        return value
    }
}
