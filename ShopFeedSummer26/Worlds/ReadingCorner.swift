import Foundation
import Observation

/// A reviewed set, not an inferred room, fit guarantee, or delivered quote.
struct ReadingCornerPiece: Decodable, Identifiable {
    enum Role: String, Codable, CaseIterable, Identifiable {
        case chair, table, light
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }
    let role: Role
    let handle: String
    let variantID: Int
    let variantTitle: String
    let observedImageID: Int
    let imageAspectRatio: Double
    let amountCents: Int
    let note: String
    let product: ShopCanvasLibrary.Product
    var id: String { product.id }
}

enum ReadingCornerCatalog {
    struct Snapshot: Decodable {
        let pieces: [ReadingCornerPiece]
        let cover: LibraryArtDirection.Cover
        let coverSource: String
        let coverImageSource: String
        let rightsStatus: String
    }
    static let storyID = "library-edit-oblist-reading-corner"
    static let merchantID = "gid://shopify/Shop/67152904457"
    static let originalBudgetCents = 60_000
    static let workingBudgetCents = 300_000 // Explicit September 24 shopper refinement.
    static let deck = "The Oblist · Living-room inspiration"
    static let prompt = "Put together a reading corner for the living room under $600."
    static let snapshot: Snapshot = {
        do {
            return try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf:
                ShopCanvasLibrary.rootURL.appendingPathComponent("reading-corner.json")))
        } catch { preconditionFailure("Invalid reading-corner supplement: \(error)") }
    }()
    static var story: FeedStory {
        FeedStory(id: storyID, eyebrow: "Shop Agent", title: "A corner to get lost in.",
                  subtitle: "", format: .world,
                  topicKeys: ["library", "catalog-only-media", "library-group:Reading corner"],
                  accentHex: "#42392E", coverImageName: nil, destinationLabel: "Make it yours",
                  products: snapshot.pieces.map { .init(merchantID: merchantID, productID: $0.product.nativeID) }
                    + ReadingCornerDiscoveryCatalog.additionalReferences)
    }
    static func money(_ cents: Int) -> String {
        (Decimal(cents) / 100).formatted(.currency(code: "USD").precision(.fractionLength(0...2)))
    }
}

/// One local set shared by the feed, swaps, and room moodboard. Unknown persisted
/// IDs fall back by role; swapping one piece cannot replace the rest of the set.
@Observable
final class ReadingCornerSelection {
    static let shared = ReadingCornerSelection()
    private struct Saved: Codable {
        var handles: [ReadingCornerPiece.Role: String]
        var budgetCents: Int
    }
    private let defaults: UserDefaults
    private let key = "reading-corner.selection.v1"
    private var saved: Saved
    let pieces: [ReadingCornerPiece]

    init(defaults: UserDefaults = .standard, pieces: [ReadingCornerPiece] = ReadingCornerCatalog.snapshot.pieces) {
        self.defaults = defaults
        self.pieces = pieces
        let restored = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Saved.self, from: $0) }
        saved = restored ?? Saved(handles: [:], budgetCents: ReadingCornerCatalog.workingBudgetCents)
        let refinementKey = key + ".budget-refinement-v2"
        if saved.budgetCents <= 0 || (!defaults.bool(forKey: refinementKey) && saved.budgetCents == ReadingCornerCatalog.originalBudgetCents) {
            saved.budgetCents = ReadingCornerCatalog.workingBudgetCents
        }
        defaults.set(true, forKey: refinementKey)
        persist()
    }
    var selected: [ReadingCornerPiece] {
        ReadingCornerPiece.Role.allCases.compactMap { role in
            pieces.first { $0.role == role && $0.handle == saved.handles[role] }
                ?? pieces.first { $0.role == role }
        }
    }
    var subtotalCents: Int { selected.reduce(0) { $0 + $1.amountCents } }
    var budgetCents: Int { saved.budgetCents }
    var budgetStatus: String { budgetStatus(total: subtotalCents) }
    func budgetStatus(total: Int) -> String {
        let difference = budgetCents - total
        if difference == 0 { return "At your \(ReadingCornerCatalog.money(budgetCents)) item budget" }
        return "\(ReadingCornerCatalog.money(abs(difference))) \(difference < 0 ? "over" : "under") your \(ReadingCornerCatalog.money(budgetCents)) item budget"
    }
    func choices(for role: ReadingCornerPiece.Role) -> [ReadingCornerPiece] {
        pieces.filter { $0.role == role }
    }
    func advance(_ role: ReadingCornerPiece.Role, by step: Int) {
        let choices = choices(for: role)
        guard !choices.isEmpty, let current = selected.first(where: { $0.role == role }),
              let index = choices.firstIndex(where: { $0.id == current.id }) else { return }
        let next = (index + step % choices.count + choices.count) % choices.count
        select(choices[next])
    }
    func total(replacing piece: ReadingCornerPiece) -> Int {
        subtotalCents - (selected.first { $0.role == piece.role }?.amountCents ?? 0) + piece.amountCents
    }
    func select(_ piece: ReadingCornerPiece) {
        guard pieces.contains(where: { $0.id == piece.id && $0.role == piece.role }) else { return }
        saved.handles[piece.role] = piece.handle
        persist()
    }
    func setBudget(cents: Int) {
        guard cents > 0 else { return }
        saved.budgetCents = cents
        persist()
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: key) }
    }
}
