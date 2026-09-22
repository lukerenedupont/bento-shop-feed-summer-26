import SwiftUI

/// Session-only state for the library navigation experiment. No live Agent or account calls.
@MainActor
@Observable
final class LibraryShellSession {
    enum Surface: Identifiable {
        case search
        case ask(LibraryAskContext)
        var id: String {
            switch self {
            case .search: "search"
            case .ask(let context): "ask:\(context.id)"
            }
        }
    }

    var surface: Surface?
    var context = LibraryAskContext.home
    var searchQuery = ""
    var pendingRoute: HomeRoute?
    private var threads: [String: LibraryAskThread] = [:]

    func thread(for context: LibraryAskContext) -> LibraryAskThread {
        if let thread = threads[context.id] { return thread }
        let thread = LibraryAskThread(context: context)
        threads[context.id] = thread
        return thread
    }

    func open(_ product: ShopCanvasLibrary.Product) {
        guard let merchantID = product.merchantIDs.first else { return }
        pendingRoute = .product(merchantId: merchantID, productId: product.nativeID)
        surface = nil
    }
}

struct LibraryAskContext {
    let id: String
    let title: String
    let productIDs: [String]

    static var home: Self {
        .init(id: "library", title: "The curated library", productIDs: ShopCanvasLibrary.manifest.selectedIds)
    }

    static func world(_ story: FeedStory) -> Self {
        .init(id: "world:\(story.id)", title: story.title, productIDs: story.products.compactMap {
            ShopCanvasLibrary.productsByNativeID[$0.productID]?.id
        })
    }

    static func product(_ nativeID: Int) -> Self {
        guard let product = ShopCanvasLibrary.productsByNativeID[nativeID] else { return .home }
        return .init(id: "product:\(product.id)", title: product.title, productIDs: [product.id])
    }

    static func merchant(_ merchantID: String) -> Self {
        guard let merchant = ShopCanvasLibrary.merchantsByID[merchantID] else { return .home }
        return .init(id: "merchant:\(merchantID)",
                     title: LibraryMerchantNames.name(for: merchantID, fallback: merchant.name),
                     productIDs: ShopCanvasLibrary.curatedProducts.filter { $0.merchantIDs.contains(merchantID) }.map(\.id))
    }

    var products: [ShopCanvasLibrary.Product] {
        var seen = Set<String>()
        return productIDs.compactMap { ShopCanvasLibrary.productsByID[$0] }
            .filter { $0.curated && seen.insert($0.id).inserted }
    }
}

/// Pre-indexes only the approved selection, preserving its order and exact seller joins.
enum LibraryCatalogSearch {
    private static let vocabulary: [String: Set<String>] = Dictionary(uniqueKeysWithValues:
        ShopCanvasLibrary.curatedProducts.map { product in
            let shops = product.merchantIDs.compactMap { id in
                ShopCanvasLibrary.merchantsByID[id].map {
                    LibraryMerchantNames.name(for: id, fallback: $0.name)
                }
            }.joined(separator: " ")
            return (product.id, CatalogSearchText.tokens(in: "\(product.title) \(product.brand) \(product.group) \(shops)"))
        })

    static func results(for query: String, in products: [ShopCanvasLibrary.Product] = ShopCanvasLibrary.curatedProducts) -> [ShopCanvasLibrary.Product] {
        let terms = CatalogSearchText.tokens(in: query)
        return products.filter { product in
            guard product.curated, let words = vocabulary[product.id] else { return false }
            return terms.allSatisfy { term in words.contains { $0.hasPrefix(term) } }
        }
    }
}

@MainActor
@Observable
final class LibraryAskThread {
    struct Exchange: Identifiable {
        let id = UUID()
        let question: String
        let answer: String
        let products: [ShopCanvasLibrary.Product]
    }

    let context: LibraryAskContext
    var draft = ""
    private(set) var exchanges: [Exchange] = []

    init(context: LibraryAskContext) { self.context = context }

    var starters: [String] {
        [context.productIDs.count == 1 ? "Show product details" : "Explore these pieces", "Which shops are here?"]
    }

    func send(_ prompt: String? = nil) {
        let question = (prompt ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        let answer: String
        let products: [ShopCanvasLibrary.Product]
        if question == "Which shops are here?" {
            var seen = Set<String>()
            let shops = context.products.flatMap(\.merchantIDs).filter { seen.insert($0).inserted }.compactMap { id in
                ShopCanvasLibrary.merchantsByID[id].map { LibraryMerchantNames.name(for: id, fallback: $0.name) }
            }
            answer = shops.isEmpty ? "No shops are recorded for this selection." : shops.joined(separator: ", ") + "."
            products = []
        } else if starters.contains(question) {
            answer = "From \(context.title). Open a piece to see its catalog details and original shop link."
            products = Array(context.products.prefix(4))
        } else {
            let matches = LibraryCatalogSearch.results(for: question, in: context.products)
            if matches.isEmpty {
                answer = "This demo can look up product or shop names in this selection, but it isn’t a live Agent. Try a name, or explore the pieces below."
                products = []
            } else {
                answer = "These catalog entries match your search within \(context.title). Prices and availability need to be confirmed at the shop."
                products = Array(matches.prefix(4))
            }
        }
        exchanges.append(.init(question: question, answer: answer, products: products))
        draft = ""
    }
}
