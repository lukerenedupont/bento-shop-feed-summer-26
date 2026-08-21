import SwiftUI

enum TryOnExperience {
    static let cardID = "decart-live-try-on"

    // Stable apparel references from the bundled catalog. These are kept at
    // the front of the tray so the isolated prototype always has useful VTON
    // inputs, even when a generated feed contains furniture or accessories.
    private static let curatedReferences: [(merchantID: String, productID: Int)] = [
        ("feature-salomon", 6_882_429_894_727),
        ("feature-salomon", 6_882_429_861_959),
        ("feature-salomon", 6_882_429_993_031),
        ("feature-salomon", 7_580_944_400_455),
    ]

    @MainActor
    private static let curatedProducts: [ResolvedStoryProduct] = {
        let merchants = LocalMerchantService.loadMerchants()

        return curatedReferences.compactMap { reference in
            guard let merchant = merchants.first(where: { $0.id == reference.merchantID }),
                  let product = merchant.products.first(where: { $0.id == reference.productID }) else {
                return nil
            }
            return ResolvedStoryProduct(merchant: merchant, product: product)
        }
    }()

    @MainActor
    static func isCurated(_ item: ResolvedStoryProduct) -> Bool {
        curatedProducts.contains { $0.id == item.id }
    }

    @MainActor
    static func products(
        stories: [FeedStory] = PersonalizedFeedStories.all,
        merchants: [SampleMerchant]
    ) -> [ResolvedStoryProduct] {
        var seen = Set<String>()

        let feedProducts = stories
            .flatMap { $0.resolvedProducts(from: merchants) }

        return (curatedProducts + feedProducts)
            .filter { item in
                guard item.product.imageURL != nil else { return false }
                return seen.insert(item.id).inserted
            }
    }
}

/// The final Home feed card. It deliberately keeps the experiment separate
/// from normal story navigation while previewing the products available in the
/// live AI product studio.
struct TryOnFeedCard: View {
    let products: [ResolvedStoryProduct]
    let width: CGFloat
    let height: CGFloat
    var foregroundTopPadding: CGFloat = GravitySpacing.space20
    var scrollPinnedTitleTop: CGFloat? = nil
    let onTap: () -> Void

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            onTap()
        } label: {
            ZStack {
                Color.white

                Image("try-on-studio")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: width,
                        height: height,
                        alignment: .bottom
                    )
                    .scaleEffect(0.82, anchor: .bottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                VStack(alignment: .leading, spacing: 0) {
                    scrollAwareTitle

                    Spacer(minLength: GravitySpacing.space16)

                    bottomProductCarousel
                }
                .padding(.horizontal, FeedCardStyle.foregroundHorizontalPadding)
                .padding(.top, foregroundTopPadding)
                .padding(.bottom, FeedCardStyle.foregroundBottomPadding)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous)
                    .strokeBorder(.black.opacity(0.08), lineWidth: 0.5)
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.07), radius: 16, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Try products from your feed live")
        .accessibilityHint("Opens the live Decart studio and starts the camera")
    }

    private var title: some View {
        Text("Try it live.")
            .feedCardTitleStyle()
            .foregroundStyle(.black)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scrollAwareTitle: some View {
        title
            .visualEffect { title, proxy in
                title.offset(
                    y: max(
                        0,
                        (scrollPinnedTitleTop
                            ?? proxy.frame(in: .scrollView(axis: .vertical)).minY)
                            - proxy.frame(in: .scrollView(axis: .vertical)).minY
                    )
                )
            }
    }

    private var footer: some View {
        HStack(spacing: GravitySpacing.space8) {
            Text("\(products.count) products")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: GravitySpacing.space8)

            Text("Try live")
                .font(.system(size: 18, weight: .semibold))

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.black)
    }

    private var bottomProductCarousel: some View {
        let tileWidth = max((width - 64) / 2, 144)

        return VStack(spacing: FeedCardStyle.productFooterSpacing) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space8) {
                    ForEach(products) { item in
                        ProductCard(
                            image: nil,
                            imageURL: item.product.imageURL,
                            priceBadge: formatPrice(item.product.price),
                            showFavoriteButton: true
                        )
                        .allowsHitTesting(false)
                        .frame(width: tileWidth)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.leading, GravitySpacing.space20, for: .scrollContent)
            .padding(.horizontal, -GravitySpacing.space20)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))

            footer
        }
        .frame(height: tileWidth + FeedCardStyle.productFooterBlockHeight)
    }
}

#Preview {
    TryOnFeedCard(
        products: TryOnExperience.products(
            stories: FeedStory.previews,
            merchants: SampleMerchant.previews
        ),
        width: 377,
        height: 645,
        onTap: {}
    )
    .padding()
    .background(.black)
}
