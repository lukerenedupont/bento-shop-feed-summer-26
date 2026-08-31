import SwiftUI
import UIKit

struct RelatedDeal: Identifiable {
    let merchant: SampleMerchant
    let products: [SampleMerchant.Product]

    var id: String { merchant.id }
}

struct RelatedDealCard: View {
    let deal: RelatedDeal
    @Environment(NavigationCoordinator.self) private var coordinator

    private var backgroundProduct: SampleMerchant.Product? {
        deal.products.first
    }

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.store(merchantId: deal.merchant.id))
        } label: {
            ZStack {
                Group {
                    if let backgroundProduct {
                        ProductImageView(product: backgroundProduct, merchant: deal.merchant)
                    } else {
                        MerchantCoverImage(merchant: deal.merchant)
                    }
                }
                .frame(width: 266, height: 263)
                .clipped()

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.18), location: 0),
                        .init(color: .clear, location: 0.34),
                        .init(color: .clear, location: 0.52),
                        .init(color: .black.opacity(0.08), location: 0.68),
                        .init(color: .black.opacity(0.30), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: GravitySpacing.space12) {
                    merchantIdentity.frame(height: 100)
                    productRow

                    Text("Save $10 on orders over $50")
                        .gravityTextStyle(GravityTypography.buttonSmall)
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(.white.opacity(0.64), in: Capsule())
                }
                .padding(GravitySpacing.space12)
            }
            .frame(width: 266, height: 263)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shop all from \(deal.merchant.displayName)")
    }

    private var merchantIdentity: some View {
        VStack(spacing: GravitySpacing.space8) {
            if MerchantBrandAssets.hasVerifiedBundledWordmark(for: deal.merchant.id)
                || hasUsableRemoteWordmark {
                MerchantWordmarkImage(
                    merchant: deal.merchant,
                    maxHeight: 40,
                    maxWidth: 120,
                    bundledAssetName: MerchantBrandAssets.wordmarkName(for: deal.merchant.id)
                )
            } else {
                Text(deal.merchant.displayName)
                    .font(GravityFont.expressiveBold.fixedFont(size: 24))
                    .tracking(-0.5)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)
            }

            if deal.merchant.totalRatings > 0 {
                HStack(spacing: GravitySpacing.space2) {
                    Text(String(format: "%.1f", deal.merchant.rating))
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .medium))
                    Text("(\(compactRatingCount(deal.merchant.totalRatings)))")
                }
                .gravityTextStyle(GravityTypography.captionMedium)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
    }

    private var hasUsableRemoteWordmark: Bool {
        guard let source = deal.merchant.bestWordmarkURL,
              let url = URL(string: source) else { return false }
        return url.pathExtension.lowercased() != "svg"
    }

    private var productRow: some View {
        HStack(spacing: GravitySpacing.space8) {
            ForEach(deal.products) { product in
                ProductImageView(product: product, merchant: deal.merchant)
                    .frame(width: 75, height: 75)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                            .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
                    }
            }
        }
        .frame(width: 241, height: 75)
    }

    private func compactRatingCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return String(count)
    }
}

struct TopicCollectionCard: View {
    let story: FeedStory
    let merchants: [SampleMerchant]
    var height: CGFloat = 220

    @Environment(NavigationCoordinator.self) private var coordinator

    private var lifestyleURL: URL? {
        if let presentation = FeedCoverCatalog.presentation(for: story) {
            return presentation.coverURL(from: merchants)
        }
        return story.lifestyleImageURL(
            from: merchants,
            format: .landscape,
            role: "topic-featured-collection"
        )
    }

    private var fallbackProduct: ResolvedStoryProduct? {
        story.resolvedProducts(from: merchants).first
    }

    private var bundledCoverName: String? {
        if let presentation = FeedCoverCatalog.presentation(for: story),
           let name = presentation.source.bundledAssetName {
            return name
        }
        return FeedCoverCatalog.fallbackImageName(for: story)
    }

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.story(storyId: story.id))
        } label: {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let lifestyleURL {
                        CachedAsyncImage(url: lifestyleURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else if let fallbackProduct {
                                ProductImageView(product: fallbackProduct.product, merchant: fallbackProduct.merchant)
                            } else {
                                Color(hex: story.accentHex)
                            }
                        }
                    } else if let bundledCoverName {
                        Image(bundledCoverName)
                            .resizable()
                            .scaledToFill()
                    } else if let fallbackProduct {
                        ProductImageView(product: fallbackProduct.product, merchant: fallbackProduct.merchant)
                    } else {
                        Color(hex: story.accentHex)
                    }
                }
                .frame(width: 364, height: height)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: GravitySpacing.space12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(story.title)
                            .font(GravityFont.expressiveBold.fixedFont(size: 23))
                            .tracking(-0.5)
                            .lineLimit(2)
                        if !story.subtitle.isEmpty {
                            Text(story.subtitle)
                                .font(GravityFont.medium.fixedFont(size: 13))
                                .lineLimit(1)
                                .foregroundStyle(.white.opacity(0.86))
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.18), in: Circle())
                }
                .foregroundStyle(.white)
                .padding(GravitySpacing.space16)
            }
            .frame(width: 364, height: height)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

struct TopicCuratedLookCard: View {
    let style: TopicCuratedLookStyle
    let products: [ResolvedStoryProduct]
    let onOpenLook: () -> Void

    private let width: CGFloat = 364
    private let height: CGFloat = 473

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                switch style {
                case .green:
                    greenCollage
                case .oxblood:
                    oxbloodCollage
                }
            }
            .frame(width: width, height: height)
            .clipped()

            if style == .green {
                // The Figma export contains a flattened control. Reconstruct
                // the artwork's vertical green ramp so the live CTA does not
                // sit on a visible rectangular color patch.
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 17 / 255, green: 192 / 255, blue: 75 / 255), location: 0),
                        .init(color: Color(red: 18 / 255, green: 217 / 255, blue: 85 / 255), location: 0.76),
                        .init(color: Color(red: 16 / 255, green: 198 / 255, blue: 84 / 255), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 174, height: 54)
            }

            Button {
                openLook()
            } label: {
                shopTheLookPill
            }
            .buttonStyle(PressScaleButtonStyle())
            .padding(GravitySpacing.space12)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        }
        .gravityShadow(GravityShadows.medium)
        .accessibilityLabel("Shop the curated look")
    }

    /// Crops the 400×521 Figma export to its exact 364×473 green artwork.
    /// This removes the navy presentation frame without stretching or
    /// regenerating any of the product collage.
    private var greenCollage: some View {
        ZStack(alignment: .topLeading) {
            Image("hype-curated-look-green")
                .resizable()
                .frame(width: 400, height: 521)
                .offset(x: -12, y: -20)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .clipped()
    }

    private var oxbloodCollage: some View {
        ZStack(alignment: .bottomLeading) {
            Color(red: 141 / 255, green: 63 / 255, blue: 57 / 255)

            collageImage("hype-look-red-1", width: 215, height: 220)
                .rotationEffect(.degrees(-11.79))
                .position(x: 55, y: 82)

            collageImage("hype-look-red-2", width: 230, height: 294)
                .rotationEffect(.degrees(8.83))
                .position(x: 42, y: 247)

            collageImage("hype-look-red-3", width: 223, height: 161)
                .rotationEffect(.degrees(-11.45))
                .position(x: 136, y: 208)

            collageImage("hype-look-red-4", width: 227, height: 268)
                .rotationEffect(.degrees(8.67))
                .position(x: 292, y: 99)

            collageImage("hype-look-red-5", width: 252, height: 320)
                .rotationEffect(.degrees(-1.56))
                .position(x: 250, y: 348)

        }
    }

    private func openLook() {
        HapticFeedback.light.fire()
        guard !products.isEmpty else { return }
        onOpenLook()
    }

    private func collageImage(_ name: String, width: CGFloat, height: CGFloat) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
            .shadow(color: .black.opacity(0.24), radius: 20, y: 8)
    }

    private var shopTheLookPill: some View {
        HStack(spacing: GravitySpacing.space6) {
            Text("Shop the look")
                .font(GravityFont.semiBold.fixedFont(size: 14))
                .foregroundStyle(GravityColors.textFixedLight)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(.horizontal, GravitySpacing.space12)
        .frame(height: 38)
        .background(.black.opacity(0.58), in: Capsule())
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
        .contentShape(Capsule())
    }
}

struct TopicRecentPostCard: View {
    let post: ShopPost
    var ageLabel = "4m ago"

    @ViewBuilder
    private var media: some View {
        switch post.media {
        case let .video(url, _, _, _):
            LoopingVideoPlayer(
                url: url,
                playbackGroupID: "topic-recent-post-\(post.id)"
            )
        case let .image(url, _, _):
            CachedAsyncImage(url: url) { phase in
                if case let .success(image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Color.white.opacity(0.08)
                }
            }
        }
    }

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            guard let actionURL = post.actionURL else { return }
            UIApplication.shared.open(actionURL)
        } label: {
            media
            .frame(width: 148, height: 219)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: GravitySpacing.space8) {
                    MerchantAvatarView(
                        logoURL: post.merchant.logoURL,
                        name: post.merchant.name,
                        size: 32,
                        fallbackColor: GravityColors.bgFillFixedDusk
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text(post.merchant.name)
                            .gravityTextStyle(GravityTypography.captionBold)
                            .lineLimit(1)
                        Text(ageLabel)
                            .gravityTextStyle(GravityTypography.caption)
                            .foregroundStyle(GravityColors.textFixedLight.opacity(0.75))
                            .lineLimit(1)
                    }
                    .frame(width: 84, alignment: .leading)
                }
                .frame(width: 124, alignment: .leading)
                .foregroundStyle(GravityColors.textFixedLight)
                .padding(GravitySpacing.space12)
            }
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            }
            .gravityShadow(GravityShadows.medium)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Recent post from \(post.merchant.name)")
    }
}

/// Keeps the Figma post rail visible before the authenticated PostCard feed
/// arrives. The media and merchant identity are real catalog data, and the
/// supporting label explicitly avoids presenting it as a fabricated post age.
struct TopicMerchantMediaCard: View {
    let item: ResolvedStoryProduct

    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
        } label: {
            ProductImageView(product: item.product, merchant: item.merchant, fallbackIndex: 1)
                .frame(width: 148, height: 219)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: GravitySpacing.space8) {
                        MerchantAvatarView(merchant: item.merchant, size: 32)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.merchant.displayName)
                                .gravityTextStyle(GravityTypography.captionBold)
                                .lineLimit(1)
                            Text("Recently added")
                                .gravityTextStyle(GravityTypography.caption)
                                .foregroundStyle(GravityColors.textFixedLight.opacity(0.75))
                                .lineLimit(1)
                        }
                        .frame(width: 84, alignment: .leading)
                    }
                    .frame(width: 124, alignment: .leading)
                    .foregroundStyle(GravityColors.textFixedLight)
                    .padding(GravitySpacing.space12)
                }
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            }
            .gravityShadow(GravityShadows.medium)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Recently added by \(item.merchant.displayName)")
    }
}

struct TopicMerchantShowcaseCard: View {
    let merchant: SampleMerchant

    @Environment(NavigationCoordinator.self) private var coordinator

    private var products: [SampleMerchant.Product] {
        Array(merchant.products.prefix(3))
    }

    /// Merchant cover art frequently arrives as a baked campaign collage.
    /// Use one product's authored alternate frame instead so the card always
    /// has a single clean photographic background.
    private var backgroundImageURL: String? {
        merchant.products.lazy.compactMap { product in
            product.allImageURLs.dropFirst().first
        }.first
            ?? merchant.products.first?.imageURL
            ?? merchant.featuredImageURLs.first
    }

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.store(merchantId: merchant.id))
        } label: {
            ZStack {
                MerchantImage(merchant: merchant, urlString: backgroundImageURL)
                    .frame(width: 344, height: 382)
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.28), .clear, .black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 0) {
                    HStack {
                        MerchantWordmarkImage(
                            merchant: merchant,
                            maxHeight: 34,
                            maxWidth: 150,
                            bundledAssetName: MerchantBrandAssets.wordmarkName(for: merchant.id)
                        )
                        Spacer()
                        if merchant.totalRatings > 0 {
                            Label(String(format: "%.1f", merchant.rating), systemImage: "star.fill")
                                .font(GravityFont.medium.fixedFont(size: 12))
                        }
                    }
                    .frame(height: 46)

                    Spacer(minLength: GravitySpacing.space16)

                    HStack(spacing: GravitySpacing.space8) {
                        ForEach(products) { product in
                            ProductImageView(product: product, merchant: merchant)
                                .frame(width: 101, height: 101)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
                                .gravityShadow(GravityShadows.small)
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding(GravitySpacing.space12)
            }
            .frame(width: 344, height: 382)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Shop \(merchant.displayName)")
    }
}

/// Generic topic merchant module for topic recipes without a Figma-specific card.
struct TopicBrandGridCard: View {
    let merchant: SampleMerchant

    @Environment(NavigationCoordinator.self) private var coordinator
    @AppStorage("topicFollowedMerchantIDs") private var followedMerchantIDs = ""

    private var products: [SampleMerchant.Product] {
        guard !merchant.products.isEmpty else { return [] }
        return (0..<6).map { merchant.products[$0 % merchant.products.count] }
    }

    private var backgroundImageURL: String? {
        merchant.bestCoverImageURL
    }

    private var isFollowing: Bool {
        followedMerchantIDSet.contains(merchant.id)
    }

    private var followedMerchantIDSet: Set<String> {
        Set(followedMerchantIDs.split(separator: ",").map(String.init))
    }

    private var ratingCountText: String {
        let count = merchant.totalRatings
        if count >= 1_000_000 { return String(format: "(%.1fM)", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "(%.1fK)", Double(count) / 1_000) }
        return "(\(count))"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                HapticFeedback.light.fire()
                coordinator.pushRoute(.store(merchantId: merchant.id))
            } label: {
                ZStack {
                    MerchantImage(merchant: merchant, urlString: backgroundImageURL)
                        .frame(width: 364, height: 388)
                        .clipped()

                    LinearGradient(
                        colors: [.black.opacity(0.34), .black.opacity(0.18), .black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(spacing: GravitySpacing.space10) {
                        MerchantWordmarkImage(
                            merchant: merchant,
                            maxHeight: 42,
                            maxWidth: 146,
                            bundledAssetName: MerchantBrandAssets.wordmarkName(for: merchant.id)
                        )
                            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.fixed(108), spacing: 8), count: 3),
                            spacing: 8
                        ) {
                            ForEach(Array(products.enumerated()), id: \.offset) { _, product in
                                merchantProductTile(product)
                            }
                        }

                        HStack(spacing: 5) {
                            Text("Shop all")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .font(GravityFont.semiBold.fixedFont(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundStyle(.white)
                    .padding(GravitySpacing.space12)
                }
                .frame(width: 364, height: 388)
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Shop all from \(merchant.displayName)")

            HStack(spacing: 8) {
                if merchant.totalRatings > 0 {
                    HStack(spacing: 3) {
                        Text(String(format: "%.1f", merchant.rating))
                        Image(systemName: "star.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(ratingCountText)
                    }
                    .font(GravityFont.medium.fixedFont(size: 11))
                    .foregroundStyle(.white)
                }

                Button {
                    toggleFollow()
                } label: {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(GravityFont.semiBold.fixedFont(size: 13))
                        .padding(.horizontal, 13)
                        .frame(height: 34)
                        .foregroundStyle(.white)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityAddTraits(isFollowing ? .isSelected : [])
            }
            .padding(.top, GravitySpacing.space12)
            .padding(.trailing, GravitySpacing.space12)
        }
        .frame(width: 364, height: 388)
    }

    private func merchantProductTile(_ product: SampleMerchant.Product) -> some View {
        ZStack {
            ProductImageView(product: product, merchant: merchant)
                .frame(width: 108, height: 108)

            Text(formatPrice(product.price))
                .font(GravityFont.medium.fixedFont(size: 12))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(height: 20)
                .background(.black.opacity(0.38), in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)

            ProductFavoriteIcon(color: .white, addsContrastShadow: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(10)
        }
        .frame(width: 108, height: 108)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
    }

    private func toggleFollow() {
        HapticFeedback.light.fire()
        var ids = followedMerchantIDSet
        if isFollowing {
            ids.remove(merchant.id)
        } else {
            ids.insert(merchant.id)
        }
        followedMerchantIDs = ids.sorted().joined(separator: ",")
    }
}

struct TopicCategoryClusterCard: View {
    let title: String
    let products: [ResolvedStoryProduct]
    let onBrowse: () -> Void

    @Environment(NavigationCoordinator.self) private var coordinator

    private let cardWidth: CGFloat = 304
    private let tileGap = GravitySpacing.space8

    private var displayedProducts: [ResolvedStoryProduct] {
        guard !products.isEmpty else { return [] }
        return (0..<5).map { products[$0 % products.count] }
    }

    var body: some View {
        if displayedProducts.count == 5 {
            VStack(alignment: .leading, spacing: GravitySpacing.space10) {
                VStack(spacing: tileGap) {
                    HStack(spacing: tileGap) {
                        ForEach(Array(displayedProducts.prefix(2).enumerated()), id: \.offset) { _, item in
                            productTile(item, size: 136)
                        }
                    }

                    HStack(spacing: tileGap) {
                        ForEach(Array(displayedProducts.dropFirst(2).enumerated()), id: \.offset) { _, item in
                            productTile(item, size: 88)
                        }
                    }
                }

                Button {
                    HapticFeedback.light.fire()
                    onBrowse()
                } label: {
                    HStack(spacing: GravitySpacing.space4) {
                        Text(title)
                            .font(GravityFont.bold.fixedFont(size: 20))
                            .tracking(-1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(GravityColors.textFixedLight)
                    .frame(height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Browse \(title)")
            }
            .padding(GravitySpacing.space12)
            .frame(width: cardWidth, height: 288, alignment: .topLeading)
            .background(
                Color(red: 108 / 255, green: 74 / 255, blue: 61 / 255).opacity(0.7),
                in: RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
            )
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        }
    }

    private func productTile(_ item: ResolvedStoryProduct, size: CGFloat) -> some View {
        Button {
            open(item)
        } label: {
            ZStack(alignment: .topLeading) {
                ProductImageView(product: item.product, merchant: item.merchant)
                    .frame(width: size, height: size)
                    .background(GravityColors.bgFillFixedLight)
                    .clipped()

                Color.black.opacity(0.04)

                Text(formatPrice(item.product.price))
                    .gravityTextStyle(GravityTypography.badgeBold)
                    .foregroundStyle(GravityColors.textFixedLight)
                    .padding(.horizontal, GravitySpacing.space6)
                    .padding(.vertical, GravitySpacing.space2)
                    .background(GravityColors.bgOverlayFixedIcon, in: Capsule())
                    .padding(GravitySpacing.space10)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                ProductFavoriteIcon(color: GravityColors.textFixedLight)
                    .gravityShadow(GravityShadows.feedText)
                    .padding(5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(item.product.title), \(formatPrice(item.product.price))")
    }

    private func open(_ item: ResolvedStoryProduct) {
        HapticFeedback.light.fire()
        coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
    }
}

struct TopicProductBentoColumn: View {
    let products: [ResolvedStoryProduct]
    let largeTileFirst: Bool

    var body: some View {
        VStack(spacing: GravitySpacing.space8) {
            if largeTileFirst {
                tile(at: 0, size: 240)
                compactRow(firstIndex: 1)
            } else {
                compactRow(firstIndex: 0)
                tile(at: 2, size: 240)
            }
        }
        .frame(width: 240, height: 365, alignment: .top)
    }

    private func compactRow(firstIndex: Int) -> some View {
        HStack(spacing: GravitySpacing.space6) {
            tile(at: firstIndex, size: 117)
            tile(at: firstIndex + 1, size: 117)
        }
    }

    @ViewBuilder
    private func tile(at index: Int, size: CGFloat) -> some View {
        if !products.isEmpty {
            TopicBentoProductTile(item: products[index % products.count], size: size)
        }
    }
}

struct TopicBentoProductTile: View {
    let item: ResolvedStoryProduct
    let size: CGFloat

    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
        } label: {
            ZStack(alignment: .topLeading) {
                ProductImageView(product: item.product, merchant: item.merchant)
                    .frame(width: size, height: size)
                    .background(GravityColors.bgFillFixedLight)
                    .clipped()

                Color.black.opacity(0.04)

                Text(formatPrice(item.product.price))
                    .gravityTextStyle(GravityTypography.badgeBold)
                    .foregroundStyle(GravityColors.textFixedLight)
                    .padding(.horizontal, GravitySpacing.space6)
                    .padding(.vertical, GravitySpacing.space2)
                    .background(GravityColors.bgOverlayFixedIcon, in: Capsule())
                    .padding(GravitySpacing.space10)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                ProductFavoriteIcon(color: GravityColors.textFixedLight)
                    .frame(width: 48, height: 48)
                    .gravityShadow(GravityShadows.feedText)
            }
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                    .strokeBorder(GravityColors.border, lineWidth: 0.5)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(item.product.title), \(formatPrice(item.product.price))")
    }
}

struct TopicExploreProductCard: View {
    let item: ResolvedStoryProduct
    let cardWidth: CGFloat
    let mediaHeight: CGFloat

    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
        } label: {
            VStack(alignment: .leading, spacing: GravitySpacing.space10) {
                ProductImageView(product: item.product, merchant: item.merchant)
                    .frame(width: cardWidth, height: mediaHeight)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        ProductFavoriteIcon(color: .white)
                            .gravityShadow(GravityShadows.feedText)
                            .padding(GravitySpacing.space6)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                            .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
                    }

                VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                    Text(item.merchant.displayName)
                        .font(GravityFont.regular.fixedFont(size: 12))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)

                    Text(item.product.title)
                        .font(GravityFont.semiBold.fixedFont(size: 14))
                        .tracking(-0.1)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(formatPrice(item.product.price))
                        .font(GravityFont.medium.fixedFont(size: 13))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .frame(height: 66, alignment: .topLeading)
                .padding(.horizontal, GravitySpacing.space2)
            }
            .frame(width: cardWidth, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(item.product.title), \(formatPrice(item.product.price))")
    }
}

/// Shared destination for category clusters and authored looks. Both now open
/// the complete assortment instead of routing to an arbitrary first product.
struct TopicProductCollectionSheet: View {
    let assortment: TopicPresentedAssortment
    let accentColor: Color

    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: GravitySpacing.space8, alignment: .top),
        GridItem(.flexible(), spacing: GravitySpacing.space8, alignment: .top),
    ]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: GravitySpacing.space20) {
                    ForEach(assortment.products) { item in
                        Button {
                            HapticFeedback.light.fire()
                            dismiss()
                            coordinator.pushRoute(
                                .product(merchantId: item.merchant.id, productId: item.product.id)
                            )
                        } label: {
                            ProductCard(
                                image: nil,
                                imageURL: item.product.imageURL,
                                merchantName: item.merchant.displayName,
                                productName: item.product.title,
                                price: formatPrice(item.product.price),
                                showFavoriteButton: true
                            )
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
                .padding(.bottom, GravitySpacing.space32)
            }
            .background(GravityColors.bg)
            .navigationTitle(assortment.title)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                if !assortment.subtitle.isEmpty {
                    Text(assortment.subtitle)
                        .font(GravityFont.medium.fixedFont(size: 14))
                        .foregroundStyle(GravityColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, GravitySpacing.space16)
                        .padding(.vertical, GravitySpacing.space12)
                        .background(GravityColors.bg)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(accentColor, in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

extension View {
    @ViewBuilder
    func topicSnapping(enabled: Bool) -> some View {
        if enabled {
            scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        } else {
            self
        }
    }
}
