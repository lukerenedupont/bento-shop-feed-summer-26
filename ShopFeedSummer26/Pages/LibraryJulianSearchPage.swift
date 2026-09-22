import SwiftUI
import JulianAgentUI

/// Catalog results retain this app's shared product cards; all search chrome comes from Julian.
struct LibraryInlineSearchResults: View {
    let query: String
    let onSelect: (ShopCanvasLibrary.Product) -> Void
    private var results: [ShopCanvasLibrary.Product] { LibraryCatalogSearch.results(for: query) }

    var body: some View {
        ScrollView {
            if results.isEmpty {
                ContentUnavailableView("No matching products", systemImage: "magnifyingglass",
                    description: Text("Try a product, shop, or category name."))
                    .padding(.top, 40)
            } else {
                LibraryCatalogGrid(products: results, onSelect: onSelect)
                    .padding(20)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaPadding(.bottom, 100)
    }
}

struct LibraryJulianSearchPage: View {
    @Bindable var state: JulianShellState
    let onSelect: (ShopCanvasLibrary.Product) -> Void
    var body: some View {
        LibraryInlineSearchResults(query: state.searchQuery) { product in
            state.searchActive = false
            onSelect(product)
        }
        .safeAreaInset(edge: .top) { JulianSearchHeader(state: state).padding(.bottom, 8) }
        .background(.white)
        .environment(\.colorScheme, .light)
        .toolbar(.hidden, for: .navigationBar)
    }
}
