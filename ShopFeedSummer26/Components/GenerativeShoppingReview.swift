import SwiftUI

/// Local saved-look review, not an account save or a full Wardrobe World.
/// Product details always resolve the exact objects held by the source card.
struct GenerativeSavedLooksReview: View {
    let spec: NextGenerationFeedCardSpec
    let merchants: [SampleMerchant]
    let session: GenerativeFeedPrototypeSession
    @Environment(\.dismiss) private var dismiss
    @State private var detail: ResolvedStoryProduct?

    private var saved: [ResolvedStoryProduct] {
        spec.resolvedProducts(from: merchants).filter { session.state(for: spec).savedSelectionIDs.contains($0.id) }
    }
    private var anchor: ResolvedStoryProduct? {
        spec.anchor.flatMap { NextGenerationFeedCardSpec.resolve($0, in: merchants) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GravitySpacing.space24) {
                    Text("The jacket stays. These are the combinations you kept.")
                        .font(GravityFont.regular.fixedFont(size: 17)).foregroundStyle(.secondary)
                    if saved.isEmpty {
                        ContentUnavailableView("No saved looks", systemImage: "heart", description: Text("Save a combination from the card to keep it here."))
                    }
                    ForEach(saved) { item in
                        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                            HStack(spacing: GravitySpacing.space12) {
                                if let anchor { productButton(anchor, caption: "You bought") }
                                productButton(item, caption: "Wear it with")
                            }
                            Button("Remove look", role: .destructive) { session.toggleSaved(item, for: spec) }
                                .font(GravityFont.medium.fixedFont(size: 13))
                                .frame(minHeight: 44)
                                .disabled(!session.state(for: spec).interactionsEnabled)
                                .accessibilityLabel("Remove saved look with \(item.product.title)")
                        }
                        Divider()
                    }
                }
                .padding(GravitySpacing.space20)
            }
            .navigationTitle("Saved looks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $detail) { GenerativeProductReview(item: $0) }
        }
        .environment(\.colorScheme, .light)
        .presentationDetents([.large])
    }

    private func productButton(_ item: ResolvedStoryProduct, caption: String) -> some View {
        Button { detail = item } label: {
            VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                Text(caption).font(GravityFont.medium.fixedFont(size: 12)).foregroundStyle(.secondary)
                GenerativeProductMedia(item: item).frame(height: 180)
                Text(item.product.title).font(GravityFont.semiBold.fixedFont(size: 14)).fixedSize(horizontal: false, vertical: true)
                Text(GenerativeFeedStyle.price(item.product)).font(GravityFont.regular.fixedFont(size: 14))
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(item.product.title)")
    }
}

/// Catalog-backed handoff: no invented variants, dimensions, stock or reviews.
/// The merchant link, not a simulated checkout, is the next commerce action.
struct GenerativeProductReview: View {
    let item: ResolvedStoryProduct
    @Environment(\.dismiss) private var dismiss

    private var destination: URL? {
        guard let url = item.product.shopURL.flatMap(URL.init(string:)),
              ["https", "http"].contains(url.scheme ?? ""), url.host != nil else { return nil }
        return url
    }

    private var completeDescription: String? {
        // The snapshot can cap long descriptions mid-sentence. Preserve only
        // complete source sentences rather than display or invent the ending.
        guard let text = item.product.productDescription,
              let end = text.lastIndex(where: { ".!?".contains($0) }) else { return nil }
        return String(text[...end])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GravitySpacing.space20) {
                    GenerativeProductMedia(item: item).frame(height: 300)
                    Text(item.merchant.displayName)
                        .font(GravityFont.medium.fixedFont(size: 14)).foregroundStyle(.secondary)
                    Text(item.product.title)
                        .font(GravityFont.expressiveSemiBold.fixedFont(size: 26))
                        .accessibilityIdentifier("generative.productTitle")
                    Text(GenerativeFeedStyle.price(item.product))
                        .font(GravityFont.semiBold.fixedFont(size: 20))
                    if let description = completeDescription {
                        Text(description)
                            .font(GravityFont.regular.fixedFont(size: 15)).foregroundStyle(.secondary)
                    }
                }
                .padding(GravitySpacing.space20)
            }
            .navigationTitle("Product details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                if let destination {
                    Link(destination: destination) {
                        HStack {
                            Text("View at \(item.merchant.displayName)")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(GravityFont.semiBold.fixedFont(size: 15))
                        .padding(GravitySpacing.space16)
                        .foregroundStyle(.white)
                        .background(.black, in: Capsule())
                    }
                    .accessibilityIdentifier("generative.merchantDestination")
                    .accessibilityValue(destination.absoluteString)
                    .padding(GravitySpacing.space20)
                    .background(.regularMaterial)
                }
            }
        }
        .environment(\.colorScheme, .light)
        .presentationDetents([.large])
    }
}
