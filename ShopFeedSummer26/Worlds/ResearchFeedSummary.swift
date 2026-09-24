import SwiftUI

/// Optional research summary inside the shared editorial card composition.
struct ResearchFeedSummary: View {
    let world: ShoppingResearchWorld
    private var highlights: [ResearchOffer] {
        Array(world.featuredShoes().prefix(1))
            + Array(world.offers.filter { $0.section == "apparel" && $0.markdownPercent != nil }.prefix(1))
    }
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(highlights) { offer in
                ProductCard(image: nil, imageURL: offer.image, priceBadge: offer.displayPrice,
                            showFavoriteButton: false)
                    .environment(\.colorScheme, .light)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .foregroundStyle(.white)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }
}
