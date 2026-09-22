import SwiftUI

struct LibrarySearchPrototype: View {
    @Bindable var session: LibraryShellSession
    var onSelect: (ShopCanvasLibrary.Product) -> Void
    @FocusState private var isFocused: Bool

    private var results: [ShopCanvasLibrary.Product] {
        LibraryCatalogSearch.results(for: session.searchQuery)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if session.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("A good place to start").font(.title3.weight(.semibold))
                    HStack(spacing: 8) {
                        ForEach(["Linen", "Lighting", "Tableware"], id: \.self) { query in
                            Button(query) { session.searchQuery = query }
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(Color.black.opacity(0.05), in: Capsule())
                        }
                    }
                }
                if results.isEmpty {
                    ContentUnavailableView("No matching products", systemImage: "magnifyingglass",
                                           description: Text("Try a product, shop, or category name."))
                } else {
                    LibraryCatalogGrid(products: results, onSelect: onSelect)
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search products and shops", text: $session.searchQuery)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit { isFocused = false }
                    .accessibilityIdentifier("library.search.input")
                if !session.searchQuery.isEmpty {
                    Button { session.searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            .frame(width: 32, height: 44)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Color.black.opacity(0.05), in: Capsule())
            .padding(.horizontal, 20).padding(.bottom, 12)
            .background(.background)
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .task { isFocused = true }
    }
}

/// Reuses the shared product card and exact native product identities for both surfaces.
struct LibraryCatalogGrid: View {
    let products: [ShopCanvasLibrary.Product]
    let onSelect: (ShopCanvasLibrary.Product) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], alignment: .leading, spacing: 24) {
            ForEach(products, id: \.id) { product in
                Button { onSelect(product) } label: {
                    ProductCard(
                        image: nil,
                        imageURL: ShopCanvasLibrary.resolve(product.image)?.absoluteString,
                        merchantName: product.merchantIDs.first.flatMap { id in
                            ShopCanvasLibrary.merchantsByID[id].map { LibraryMerchantNames.name(for: id, fallback: $0.name) }
                        },
                        productName: product.title,
                        showFavoriteButton: false
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("library.result.\(product.nativeID)")
            }
        }
    }
}
