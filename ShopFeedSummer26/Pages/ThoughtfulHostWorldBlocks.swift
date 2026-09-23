import SwiftUI

/// Renders one authored Thoughtful Host block selected by its recipe. The
/// shared World renderer owns ordering; this adapter owns only block visuals.
/// Demo posts retain their original merchant identity; no dates are invented.
struct ThoughtfulHostWorldBlock: View {
    let blockID: String
    let products: [ResolvedStoryProduct]
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var presentedPost: ShopPost?

    private let portaID = "gid://shopify/Shop/60704260314"
    private let gutter: CGFloat = 12
    private var posts: [ShopPost] {
        let available = ShopPostService.shared.bundledPrototypePosts
        return ["prototype-caraway-table", "prototype-fuumuu-studio"].compactMap { id in
            available.first { $0.id == id }
        }
    }

    private func item(_ sourceID: String) -> ResolvedStoryProduct? {
        products.first { $0.product.sourceProductID == sourceID }
    }

    @ViewBuilder
    var body: some View {
        Group {
            switch blockID {
            case "statement": statement
            case "kitchen-film": featuredFilm
            case "scene-gallery": productStoryGallery
            case "posts": postRail
            case "table-look": curatedTable
            case "merchant-feature": portaFeature
            case "material-detail": materialDetail
            case "image-pause": fullBleedPause
            case "ask": askRefinement
            default: EmptyView()
            }
        }
        .sheet(item: $presentedPost) { post in
            GeometryReader { geometry in
                ShopPostFeedCard(post: post, merchants: ShopCanvasLibrary.merchants,
                    width: geometry.size.width, height: geometry.size.height,
                    isActive: true, cornerRadius: 0)
            }
            .overlay(alignment: .topTrailing) {
                Button { presentedPost = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .padding(16)
                .accessibilityLabel("Close post")
            }
            .presentationDragIndicator(.visible)
        }
    }

    private var statement: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A table worth lingering around")
                .font(GravityFont.expressiveBold.fixedFont(size: 34))
                .tracking(-0.9)
                .lineSpacing(-4)
            Text("Warm materials, useful objects, and small details for hosting that feels personal rather than perfect.")
                .font(GravityFont.regular.fixedFont(size: 16))
                .lineSpacing(3)
                .foregroundStyle(.white.opacity(0.72))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var featuredFilm: some View {
        if let post = posts.first,
           case let .video(url, _, _, _) = post.media {
            VStack(alignment: .leading, spacing: 24) {
                heading("In the kitchen")
                Button {
                    presentedPost = post
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        LoopingVideoPlayer(
                            url: url,
                            playbackEnabled: presentedPost == nil,
                            playbackGroupID: "host-featured-film"
                        )
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.64)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.merchant.name)
                                .font(GravityFont.semiBold.fixedFont(size: 15))
                            Text(post.title ?? post.caption ?? "Watch the story")
                                .font(GravityFont.regular.fixedFont(size: 14))
                                .foregroundStyle(.white.opacity(0.82))
                                .lineLimit(2)
                        }
                        .padding(20)
                    }
                    .frame(height: 520)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                }
                .buttonStyle(PressScaleButtonStyle())
                .padding(.horizontal, gutter)
                .accessibilityIdentifier("host.featured-film")
            }
        }
    }

    private var productStoryGallery: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Set the scene")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(["welcome-tray", "serving-tray-table", "linen-garden", "porta-bowl-detail"], id: \.self) { name in
                        photograph(name)
                            .frame(width: name == "linen-garden" ? 286 : 250, height: 370)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, gutter, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private var postRail: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("From the shops")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(posts) { post in
                        TopicRecentPostCard(post: post, width: 220, height: 300,
                            playbackEnabled: presentedPost == nil,
                            onOpen: { presentedPost = post })
                            .accessibilityIdentifier("host.post.\(post.id)")
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, gutter, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .frame(height: 300)
        }
    }

    private var curatedTable: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Build the table")
            Text("Three distinct pieces, brought together as one useful setting.")
                .font(GravityFont.regular.fixedFont(size: 15))
                .foregroundStyle(.white.opacity(0.68))
                .padding(.horizontal, 20)
                .padding(.top, -12)
            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(products.prefix(3))) { item in
                    Button { open(item) } label: {
                        ProductCard(
                            image: nil,
                            imageURL: item.product.imageURL,
                            merchantName: item.merchant.displayName,
                            productName: item.product.title,
                            price: formatPrice(item.product),
                            showFavoriteButton: true,
                            favoriteIconHasContrastShadow: true
                        )
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal, gutter)
        }
    }

    /// Reuse the existing merchant collection card, including its one clear
    /// merchant destination, rather than adding another merchant presentation.
    private var portaFeature: some View {
        GeometryReader { geometry in
            if let merchant = ShopCanvasLibrary.merchants.first(where: { $0.id == portaID }) {
                let references = products.filter {
                    $0.product.associatedMerchantIDs?.contains(portaID) == true
                }.map { FeedStory.ProductReference(merchantID: portaID, productID: $0.product.id) }
                let story = FeedStory(id: "host-porta-collection", eyebrow: "", title: merchant.displayName,
                    subtitle: "", format: .world, topicKeys: ["merchant-card"], accentHex: "#26372E",
                    coverImageName: nil, destinationLabel: "Explore", products: references)
                MerchantCollectionFeedCard(
                    story: story,
                    presentation: MerchantCollectionPresentation(
                        storyID: story.id, merchantID: portaID, productCount: 6,
                        coverProductID: references.first?.productID ?? 0, coverImageIndex: 0,
                        lifestyleCoverURL: ShopCanvasLibrary.rootURL.appendingPathComponent("catalog/host-prototype/porta-table.jpg").absoluteString
                    ),
                    merchants: ShopCanvasLibrary.merchants,
                    width: geometry.size.width, height: 480,
                    foregroundTopPadding: 24, borderOpacity: 0.08, shadowOpacity: 0
                )
                .accessibilityIdentifier("host.explore-porta")
            }
        }
        .frame(height: 480)
        .padding(.horizontal, gutter)
    }

    @ViewBuilder
    private var materialDetail: some View {
        if let linen = item("cosmos:820800012") {
            VStack(alignment: .leading, spacing: 24) {
                heading("Linen, up close")
                GeometryReader { geometry in
                    let available = geometry.size.width - 10
                    Button { open(linen) } label: {
                        HStack(spacing: 10) {
                            photograph("linen-table-green")
                                .frame(width: available * 0.56, height: 320)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                            photograph("linen-detail")
                                .frame(width: available * 0.44, height: 320)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel("Linen tablecloth, setting and fabric detail")
                    .accessibilityIdentifier("host.linen-detail")
                }
                .frame(height: 320)
                .padding(.horizontal, gutter)
                Text(linen.merchant.displayName)
                    .font(GravityFont.regular.fixedFont(size: 13))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, gutter)
                    .padding(.top, -12)
            }
        }
    }

    private var fullBleedPause: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("A quieter moment")
            photograph("welcome-tray")
                .frame(height: 500)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .padding(.horizontal, gutter)
        }
    }

    private var askRefinement: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.julianShell.openAsk()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Make this World your own")
                        .font(GravityFont.semiBold.fixedFont(size: 16))
                    Text("Ask Shop to refine the table, mood, or occasion.")
                        .font(GravityFont.regular.fixedFont(size: 14))
                        .foregroundStyle(.white.opacity(0.68))
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(20)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.horizontal, gutter)
        .accessibilityIdentifier("host.refine-world")
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(GravityFont.expressiveBold.fixedFont(size: 24))
            .tracking(-0.5).foregroundStyle(.white)
            .padding(.horizontal, gutter)
    }

    private func open(_ item: ResolvedStoryProduct) {
        HapticFeedback.light.fire()
        coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
    }

    private func photograph(_ name: String) -> some View {
        let url = ShopCanvasLibrary.rootURL.appendingPathComponent("catalog/host-prototype/\(name).jpg")
        return CachedAsyncImage(url: url) { phase in
            if case let .success(image) = phase { image.resizable().scaledToFill() }
            else { Color(hex: "#38473D") }
        }
    }
}
