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
    /// Tall brand card: cover backdrop, avatar + rating header, and two
    /// floating product chips at the bottom.
    case merchantSpotlight(SampleMerchant, [ResolvedStoryProduct])
    /// Short brand moment: cover (or brand color) with the wordmark centered.
    case merchantWordmark(SampleMerchant)
    /// A loose cluster of circular shop avatars — a browsable brand shelf
    /// without card chrome.
    case avatarCluster([SampleMerchant])

    var id: String {
        switch self {
        case let .product(item): "product:\(item.id)"
        case let .merchant(merchant, _): "merchant:\(merchant.id)"
        case let .category(story, _): "category:\(story.id)"
        case let .post(story, item): "post:\(story.id):\(item.id)"
        case let .merchantSpotlight(merchant, _): "spotlight:\(merchant.id)"
        case let .merchantWordmark(merchant): "wordmark:\(merchant.id)"
        case let .avatarCluster(merchants): "avatars:\(merchants.map(\.id).joined(separator: "-"))"
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
        case let .merchantSpotlight(merchant, products):
            TopicMasonrySpotlightCard(merchant: merchant, products: products, cardWidth: cardWidth)
        case let .merchantWordmark(merchant):
            TopicMasonryWordmarkCard(merchant: merchant, cardWidth: cardWidth)
        case let .avatarCluster(merchants):
            TopicMasonryAvatarCluster(merchants: merchants, cardWidth: cardWidth)
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

/// Tall brand spotlight: the merchant's cover is the whole surface, identity
/// (avatar, name, rating) sits at the top, and two products float at the
/// bottom as tappable chips wearing the standard price badge.
private struct TopicMasonrySpotlightCard: View {
    let merchant: SampleMerchant
    let products: [ResolvedStoryProduct]
    let cardWidth: CGFloat

    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        Button {
            coordinator.pushRoute(.store(merchantId: merchant.id))
        } label: {
            ZStack {
                Color.clear
                    .overlay { MerchantCoverImage(merchant: merchant) }
                    .clipped()

                // Soft top scrim keeps the identity row legible on any cover.
                LinearGradient(
                    colors: [.black.opacity(0.45), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }
            .overlay(alignment: .topLeading) {
                HStack(spacing: GravitySpacing.space8) {
                    MerchantLogoImage(merchant: merchant, size: 36)
                        .background(Circle().fill(.white))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(merchant.displayName)
                            .gravityTextStyle(GravityTypography.captionBold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if merchant.totalRatings > 0 {
                            HStack(spacing: 3) {
                                GravityIcon.starFilled.image
                                    .resizable().scaledToFit()
                                    .frame(width: 10, height: 10)
                                    .foregroundStyle(.white)
                                Text(String(format: "%.1f", merchant.rating))
                                    .gravityTextStyle(GravityTypography.caption)
                                    .foregroundStyle(.white)
                                Text("(\(merchant.totalRatings))")
                                    .gravityTextStyle(GravityTypography.caption)
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(GravitySpacing.space12)
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: GravitySpacing.space8) {
                    ForEach(products.prefix(2)) { item in
                        productChip(item)
                    }
                }
                .padding(GravitySpacing.space12)
            }
            .frame(width: cardWidth, height: cardWidth * 1.62)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .gravityShadow(GravityShadows.small)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func productChip(_ item: ResolvedStoryProduct) -> some View {
        // Two chips share the card width inside the 12pt card padding.
        let side = (cardWidth - GravitySpacing.space12 * 2 - GravitySpacing.space8) / 2
        return Button {
            coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
        } label: {
            ProductImageView(product: item.product, merchant: item.merchant)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous))
                .background {
                    RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous)
                        .fill(.white)
                }
                .overlay(alignment: .topLeading) {
                    Text(formatPrice(item.product.price))
                        .gravityTextStyle(GravityTypography.badgeBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GravityRadius.max))
                        .environment(\.colorScheme, .dark)
                        .padding(6)
                }
                .gravityShadow(GravityShadows.small)
        }
        .buttonStyle(.plain)
    }
}

/// Short brand moment: the merchant's cover (or brand color) carries the
/// card and the wordmark holds the center. A quieter store entry point than
/// the product pager — pure brand voice.
private struct TopicMasonryWordmarkCard: View {
    let merchant: SampleMerchant
    let cardWidth: CGFloat

    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        Button {
            coordinator.pushRoute(.store(merchantId: merchant.id))
        } label: {
            ZStack {
                Color.clear
                    .overlay { MerchantCoverImage(merchant: merchant) }
                    .clipped()

                // Center vignette so the wordmark reads on busy covers.
                RadialGradient(
                    colors: [.black.opacity(0.38), .black.opacity(0.12)],
                    center: .center,
                    startRadius: 0,
                    endRadius: cardWidth * 0.7
                )

                VStack(spacing: GravitySpacing.space4) {
                    MerchantWordmarkImage(
                        merchant: merchant,
                        maxHeight: 30,
                        maxWidth: cardWidth * 0.72
                    )
                    .frame(maxWidth: cardWidth * 0.72, alignment: .center)
                    if merchant.totalRatings > 0 {
                        HStack(spacing: 3) {
                            GravityIcon.starFilled.image
                                .resizable().scaledToFit()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(.white)
                            Text(String(format: "%.1f", merchant.rating))
                                .gravityTextStyle(GravityTypography.caption)
                                .foregroundStyle(.white)
                            Text("(\(merchant.totalRatings))")
                                .gravityTextStyle(GravityTypography.caption)
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
                }
            }
            .frame(width: cardWidth, height: cardWidth * 0.78)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .gravityShadow(GravityShadows.small)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

/// A loose 2-wide cluster of circular shop avatars — no card chrome, the
/// circles float directly on the topic surface. Each avatar is a store link.
private struct TopicMasonryAvatarCluster: View {
    let merchants: [SampleMerchant]
    let cardWidth: CGFloat

    @Environment(NavigationCoordinator.self) private var coordinator

    private var diameter: CGFloat { (cardWidth - GravitySpacing.space12) / 2 }

    var body: some View {
        let rows = stride(from: 0, to: merchants.count, by: 2).map {
            Array(merchants[$0..<min($0 + 2, merchants.count)])
        }
        VStack(spacing: GravitySpacing.space12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: GravitySpacing.space12) {
                    ForEach(row) { merchant in
                        Button {
                            coordinator.pushRoute(.store(merchantId: merchant.id))
                        } label: {
                            // A white disc backs every avatar so transparent
                            // wordmark logos still read as floating circles.
                            MerchantLogoImage(merchant: merchant, size: diameter)
                                .background(Circle().fill(.white))
                                .gravityShadow(GravityShadows.small)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
            }
        }
        .frame(width: cardWidth)
        .padding(.vertical, GravitySpacing.space8)
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

#Preview("Brand cards: spotlight, wordmark, avatars") {
    let merchants = SampleMerchant.previews
    let story = PersonalizedFeedStories.all.first!
    let products = story.resolvedProducts(from: merchants)

    ScrollView {
        HStack(alignment: .top, spacing: GravitySpacing.space16) {
            VStack(spacing: GravitySpacing.space16) {
                if let merchant = products.first?.merchant {
                    TopicMasonryCard(
                        item: .merchantSpotlight(merchant, products.filter { $0.merchant.id == merchant.id }),
                        cardWidth: 170
                    )
                }
                if let merchant = merchants.last {
                    TopicMasonryCard(item: .merchantWordmark(merchant), cardWidth: 170)
                }
            }
            VStack(spacing: GravitySpacing.space16) {
                TopicMasonryCard(item: .avatarCluster(Array(merchants.prefix(6))), cardWidth: 170)
                if let merchant = merchants.dropFirst().first {
                    TopicMasonryCard(item: .merchantWordmark(merchant), cardWidth: 170)
                }
            }
        }
        .padding()
    }
    .background(GravityColors.bg)
    .environment(NavigationCoordinator())
}
