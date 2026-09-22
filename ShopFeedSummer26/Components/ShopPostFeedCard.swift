import SwiftUI

/// Full-height treatment for a real merchant-authored Shop Post.
struct ShopPostFeedCard: View {
    let post: ShopPost
    var relatedPosts: [ShopPost] = []
    let merchants: [SampleMerchant]
    let width: CGFloat
    let height: CGFloat
    let isActive: Bool
    var cornerRadius: CGFloat = GravityRadius.r28
    var bottomCornerRadius: CGFloat? = nil
    var foregroundTopPadding: CGFloat = GravitySpacing.space20
    var borderOpacity: Double = 0.16
    var shadowOpacity: Double = 1
    var onOverflowTap: (() -> Void)?

    @State private var selectedPostIndex = 0
    @State private var selectedProductIndex = 0
    @State private var productDragOffset: CGFloat = 0

    private var postPages: [ShopPost] {
        [post] + relatedPosts.filter { $0.id != post.id }
    }

    private var activePost: ShopPost {
        postPages[min(selectedPostIndex, postPages.count - 1)]
    }

    private var attachedProducts: [ResolvedStoryProduct] {
        let explicitProducts: [ResolvedStoryProduct] = activePost.productReferences.compactMap { reference in
            guard let merchant = merchants.first(where: { $0.id == reference.merchantID }),
                  let product = merchant.products.first(where: { $0.id == reference.productID }) else {
                return nil
            }
            return ResolvedStoryProduct(merchant: merchant, product: product)
        }
        if !explicitProducts.isEmpty { return explicitProducts }

        guard let merchant = merchants.first(where: { $0.id == activePost.merchant.id }) else {
            return []
        }
        return merchant.products.prefix(3).map {
            ResolvedStoryProduct(merchant: merchant, product: $0)
        }
    }

    private var resolvedBottomCornerRadius: CGFloat {
        bottomCornerRadius ?? cornerRadius
    }

    private var cardShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: cornerRadius,
            bottomLeadingRadius: resolvedBottomCornerRadius,
            bottomTrailingRadius: resolvedBottomCornerRadius,
            topTrailingRadius: cornerRadius,
            style: .continuous
        )
    }

    private var fallbackCoverImageName: String {
        FeedCoverCatalog.fallbackImageName(stableID: "shop-post-\(activePost.id)")
    }

    var body: some View {
        ZStack {
            media
                .frame(width: width, height: height)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.38), location: 0),
                    .init(color: .clear, location: 0.30),
                    .init(color: .clear, location: 0.66),
                    .init(color: .black.opacity(0.72), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            overflowButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, GravitySpacing.space12)
                .padding(.top, foregroundTopPadding)

            postActions
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, GravitySpacing.space12)
                .padding(
                    .bottom,
                    FeedCardStyle.foregroundBottomPadding + 82 + GravitySpacing.space20
                )

            postFooter
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.horizontal, FeedCardStyle.foregroundHorizontalPadding)
                .padding(.bottom, FeedCardStyle.foregroundBottomPadding)
        }
        .frame(width: width, height: height)
        .clipShape(cardShape)
        .overlay {
            cardShape
                .strokeBorder(.white.opacity(borderOpacity), lineWidth: 0.5)
        }
        .compositingGroup()
        .shadow(
            color: .black.opacity(0.12 * shadowOpacity),
            radius: 24,
            x: 0,
            y: 4
        )
        .contentShape(cardShape)
        .onTapGesture {
            guard let actionURL = activePost.actionURL else { return }
            UIApplication.shared.open(actionURL)
        }
        .onChange(of: selectedPostIndex) {
            selectedProductIndex = 0
            productDragOffset = 0
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayTitle). Post from \(activePost.merchant.name). \(primaryCopy ?? "")")
    }

    private var media: some View {
        TabView(selection: $selectedPostIndex) {
            ForEach(Array(postPages.enumerated()), id: \.element.id) { index, page in
                mediaPage(page, playsVideo: isActive && selectedPostIndex == index)
                    .frame(width: width, height: height)
                    .clipped()
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    @ViewBuilder
    private func mediaPage(_ page: ShopPost, playsVideo: Bool) -> some View {
        switch page.media {
        case let .video(url, posterURL, _, _):
            ZStack {
                if let posterURL {
                    postImage(url: posterURL, contentMode: .fill, usesCoverFallback: true)
                } else {
                    fallbackCover
                }
                if playsVideo {
                    LoopingVideoPlayer(url: url)
                        .transition(.opacity)
                }
            }
        case let .image(url, _, _):
            postImage(url: url, contentMode: .fill, usesCoverFallback: true)
        }
    }

    private var overflowButton: some View {
        Button {
            HapticFeedback.light.fire()
            onOverflowTap?()
        } label: {
            Image("feedback-overflow")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .shadow(color: .black.opacity(0.24), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More")
    }

    private var postActions: some View {
        PrototypeFeedbackActions(
            layout: .vertical,
            foregroundColor: .white,
            appliesShadow: true,
            includesOverflow: false,
            includesVolume: false,
            includesThread: true,
            usesPostActionOrder: true
        )
    }

    private var postFooter: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            postPagination

            HStack(spacing: GravitySpacing.space10) {
                merchantLogo
                Text(activePost.merchant.name)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.2)
                    .lineLimit(1)

                if let copy = primaryCopy {
                    Text(copy)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                }
            }
            .padding(.trailing, 52)

            Group {
                if attachedProducts.isEmpty {
                    collectionAttachment
                } else {
                    productDeck
                }
            }
            .padding(.top, GravitySpacing.space4)
        }
        .foregroundStyle(.white)
        .gravityShadow(GravityShadows.feedText)
    }

    @ViewBuilder
    private var postPagination: some View {
        if postPages.count > 1 {
            HStack(spacing: GravitySpacing.space6) {
                ForEach(postPages.indices, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(index == selectedPostIndex ? 0.96 : 0.38))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, GravitySpacing.space4)
        }
    }

    private var productDeck: some View {
        let count = attachedProducts.count
        let currentIndex = min(selectedProductIndex, max(0, count - 1))

        return ZStack(alignment: .leading) {
            if count > 0 {
                productDeckCard(
                    attachedProducts[(currentIndex + 2) % count],
                    surfaceTone: -0.16
                )
                    .scaleEffect(0.92, anchor: .leading)
                    .offset(x: 30)
                    .opacity(0.72)

                productDeckCard(
                    attachedProducts[(currentIndex + 1) % count],
                    surfaceTone: -0.08
                )
                    .scaleEffect(0.96, anchor: .leading)
                    .offset(x: 15)
                    .opacity(0.88)

                productDeckCard(attachedProducts[currentIndex], surfaceTone: 0.14)
                    .offset(x: productDragOffset)
            }
        }
        .frame(height: 82)
        .contentShape(Rectangle())
        .simultaneousGesture(productDeckGesture)
    }

    private func productDeckCard(
        _ item: ResolvedStoryProduct,
        surfaceTone: Double
    ) -> some View {
        HStack(spacing: GravitySpacing.space10) {
            ProductImageView(product: item.product, merchant: item.merchant)
                .frame(width: 64, height: 64)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.product.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(formatPrice(item.product))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
            }

            Spacer(minLength: GravitySpacing.space6)

            Image(systemName: "heart")
                .font(.system(size: 21, weight: .medium))
                .padding(.trailing, GravitySpacing.space8)
        }
        .padding(GravitySpacing.space6)
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(item.merchant.brandColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            (surfaceTone >= 0 ? Color.white : Color.black)
                                .opacity(abs(surfaceTone))
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.14), radius: 6, y: 3)
    }

    private var productDeckGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                productDragOffset = value.translation.width
            }
            .onEnded { value in
                let advances = abs(value.translation.width) > 52
                withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                    if advances, !attachedProducts.isEmpty {
                        let direction = value.translation.width < 0 ? 1 : -1
                        selectedProductIndex = (
                            selectedProductIndex + direction + attachedProducts.count
                        ) % attachedProducts.count
                    }
                    productDragOffset = 0
                }
            }
    }

    private var collectionAttachment: some View {
        HStack(spacing: GravitySpacing.space12) {
            collectionPreview

            Text("View collection")
                .font(.system(size: 15, weight: .semibold))

            Spacer(minLength: GravitySpacing.space8)

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
        }
        .padding(.horizontal, GravitySpacing.space12)
        .frame(height: 66)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var collectionPreview: some View {
        if activePost.merchant.id == "house-of-errors" {
            let assets = [
                "house-of-errors-product-1",
                "house-of-errors-product-2",
                "house-of-errors-product-3",
            ]
            ZStack {
                ForEach(Array(assets.enumerated()), id: \.offset) { index, asset in
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(.white.opacity(0.28), lineWidth: 0.5)
                        }
                        .rotationEffect(.degrees(Double(index - 1) * 5))
                        .offset(x: CGFloat(index - 1) * 13)
                        .zIndex(Double(index))
                }
            }
            .frame(width: 64, height: 48)
        } else {
            Image(systemName: "rectangle.grid.2x2.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.24), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private var merchantLogo: some View {
        if activePost.merchant.id == "house-of-errors" {
            Image("house-of-errors-avatar")
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(.white.opacity(0.34), lineWidth: 0.5) }
        } else if activePost.merchant.id == "kith" {
            Image("merchant-wordmark-kith")
                .resizable()
                .scaledToFit()
                .padding(7)
                .frame(width: 44, height: 44)
                .background(.black)
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(.white.opacity(0.34), lineWidth: 0.5) }
        } else if let logoURL = activePost.merchant.logoURL {
            postImage(url: logoURL, contentMode: .fit)
                .padding(7)
                .frame(width: 44, height: 44)
                .background(.white)
                .clipShape(Circle())
        } else {
            Text(merchantInitials)
                .font(.system(size: merchantInitials.count > 1 ? 12 : 17, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 44, height: 44)
                .background(.white)
                .clipShape(Circle())
        }
    }

    private var merchantInitials: String {
        activePost.merchant.name
            .split(separator: " ")
            .prefix(3)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    private var primaryCopy: String? {
        [activePost.caption, activePost.subtitle]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && $0 != displayTitle }
    }

    private var displayTitle: String {
        let title = activePost.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.flatMap { $0.isEmpty ? nil : $0 } ?? activePost.merchant.name
    }

    private func postImage(
        url: URL,
        contentMode: ContentMode,
        usesCoverFallback: Bool = false
    ) -> some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .empty:
                if usesCoverFallback { fallbackCover } else { Color.black.opacity(0.08) }
            case .failure:
                if usesCoverFallback { fallbackCover } else { Color.black.opacity(0.14) }
            @unknown default:
                if usesCoverFallback { fallbackCover } else { Color.black.opacity(0.08) }
            }
        }
    }

    private var fallbackCover: some View {
        Image(fallbackCoverImageName)
            .resizable()
            .scaledToFill()
    }
}
