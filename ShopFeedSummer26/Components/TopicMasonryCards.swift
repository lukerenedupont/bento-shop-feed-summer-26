import SwiftUI

/// Local projection of the heterogeneous card kinds rendered by Shop client's
/// `ShopProductDetailsMasonryRecommendationsFeed`. The prototype uses its local
/// commerce models, but preserves the client renderer's product, product-focused
/// merchant, hero action/category, and post card grammar.
enum TopicMasonryItem: Identifiable {
    case product(ResolvedStoryProduct)
    case merchant(SampleMerchant, [ResolvedStoryProduct])
    case category(FeedStory, [ResolvedStoryProduct])
    case post(FeedStory, ResolvedStoryProduct)

    var id: String {
        switch self {
        case let .product(item): "product:\(item.id)"
        case let .merchant(merchant, _): "merchant:\(merchant.id)"
        case let .category(story, _): "category:\(story.id)"
        case let .post(story, item): "post:\(story.id):\(item.id)"
        }
    }
}

struct TopicMasonryCard: View {
    let item: TopicMasonryItem
    let cardWidth: CGFloat

    var body: some View {
        switch item {
        case let .product(product):
            productCard(product)
        case let .merchant(merchant, products):
            TopicMasonryMerchantCard(merchant: merchant, products: products, cardWidth: cardWidth)
        case let .category(story, products):
            TopicMasonryCategoryCard(story: story, products: products, cardWidth: cardWidth)
        case let .post(story, product):
            TopicMasonryPostCard(story: story, item: product, cardWidth: cardWidth)
        }
    }

    private func productCard(_ item: ResolvedStoryProduct) -> some View {
        NavigationLink(value: HomeRoute.product(merchantId: item.merchant.id, productId: item.product.id)) {
            ProductCard(
                image: nil,
                imageURL: item.product.imageURL,
                merchantName: item.merchant.name,
                productName: item.product.title,
                rating: item.merchant.totalRatings > 0 ? item.merchant.rating : nil,
                ratingCount: item.merchant.totalRatings > 0 ? item.merchant.totalRatings : nil,
                price: formatPrice(item.product.price),
                showFavoriteButton: true
            )
            .frame(width: cardWidth, alignment: .topLeading)
        }
        .buttonStyle(.plain)
    }
}

/// Shop client's standard product-focused merchant treatment: square product
/// pager with image border/shadow and a compact merchant footer.
private struct TopicMasonryMerchantCard: View {
    let merchant: SampleMerchant
    let products: [ResolvedStoryProduct]
    let cardWidth: CGFloat

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var selectedIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            ZStack(alignment: .bottom) {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(products.prefix(4).enumerated()), id: \.element.id) { index, item in
                        Button {
                            coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
                        } label: {
                            ProductImageView(product: item.product, merchant: item.merchant, fallbackIndex: index)
                                .frame(width: cardWidth, height: cardWidth)
                                .clipped()
                        }
                        .buttonStyle(.plain)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                if products.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(0..<min(products.count, 4), id: \.self) { index in
                            Capsule()
                                .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.45))
                                .frame(width: index == selectedIndex ? 14 : 5, height: 5)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .frame(width: cardWidth, height: cardWidth)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
            }
            .gravityShadow(GravityShadows.small)

            Button {
                coordinator.pushRoute(.store(merchantId: merchant.id))
            } label: {
                HStack(spacing: GravitySpacing.space8) {
                    MerchantLogoImage(merchant: merchant, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(merchant.name)
                            .gravityTextStyle(GravityTypography.captionBold)
                            .foregroundStyle(GravityColors.text)
                            .lineLimit(1)
                        if merchant.totalRatings > 0 {
                            HStack(spacing: 3) {
                                GravityIcon.starFilled.image
                                    .resizable().scaledToFit()
                                    .frame(width: 11, height: 11)
                                    .foregroundStyle(Color(hex: 0xFFB800))
                                Text(String(format: "%.1f", merchant.rating))
                                    .gravityTextStyle(GravityTypography.caption)
                                    .foregroundStyle(GravityColors.textSecondary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(GravityColors.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: cardWidth, alignment: .topLeading)
        .padding(.bottom, GravitySpacing.space8)
    }
}

/// Shop client's HERO action card used as a category/collection entry point in
/// masonry. In masonry context it is a long card and omits the circular arrow.
private struct TopicMasonryCategoryCard: View {
    let story: FeedStory
    let products: [ResolvedStoryProduct]
    let cardWidth: CGFloat

    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        Button {
            coordinator.pushRoute(.story(storyId: story.id))
        } label: {
            ZStack(alignment: .bottomLeading) {
                if let item = products.first {
                    ProductImageView(product: item.product, merchant: item.merchant)
                        .frame(width: cardWidth, height: cardWidth * 1.42)
                        .clipped()
                } else {
                    Color(hex: story.accentHex)
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                    Text("Explore the collection")
                        .gravityTextStyle(GravityTypography.captionMedium)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(story.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                .padding(GravitySpacing.space16)
            }
            .frame(width: cardWidth, height: cardWidth * 1.42)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .gravityShadow(GravityShadows.small)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

/// Shop client's default post-card grammar: full-bleed media, bottom scrim,
/// caption, and merchant identity overlay.
private struct TopicMasonryPostCard: View {
    let story: FeedStory
    let item: ResolvedStoryProduct
    let cardWidth: CGFloat

    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        Button {
            coordinator.pushRoute(.story(storyId: story.id))
        } label: {
            ZStack(alignment: .bottomLeading) {
                ProductImageView(product: item.product, merchant: item.merchant)
                    .frame(width: cardWidth, height: cardWidth * 1.25)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.48)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                    Text(story.title)
                        .gravityTextStyle(GravityTypography.bodyTitleSmall)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    HStack(spacing: GravitySpacing.space8) {
                        MerchantLogoImage(merchant: item.merchant, size: 28)
                        Text(item.merchant.name)
                            .gravityTextStyle(GravityTypography.captionBold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                .padding(GravitySpacing.space12)
            }
            .frame(width: cardWidth, height: cardWidth * 1.25)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .gravityShadow(GravityShadows.small)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

#Preview("Shop client masonry card mix") {
    let merchants = SampleMerchant.previews
    let story = PersonalizedFeedStories.all.first!
    let products = story.resolvedProducts(from: merchants)

    ScrollView {
        HStack(alignment: .top, spacing: GravitySpacing.space16) {
            VStack(spacing: GravitySpacing.space16) {
                if let product = products.first {
                    TopicMasonryCard(item: .product(product), cardWidth: 170)
                }
                TopicMasonryCard(item: .category(story, products), cardWidth: 170)
            }
            VStack(spacing: GravitySpacing.space16) {
                if let merchant = products.first?.merchant {
                    TopicMasonryCard(item: .merchant(merchant, products), cardWidth: 170)
                }
                if let product = products.last {
                    TopicMasonryCard(item: .post(story, product), cardWidth: 170)
                }
            }
        }
        .padding()
    }
    .background(GravityColors.bg)
    .environment(NavigationCoordinator())
}
