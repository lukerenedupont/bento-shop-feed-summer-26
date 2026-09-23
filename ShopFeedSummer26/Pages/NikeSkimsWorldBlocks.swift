import SwiftUI

/// Internal-reference editorial media from Nike's first-party NikeSKIMS pages.
/// Campaign media never carries a commerce destination; every shoppable action
/// resolves to the approved Shop Canvas product and exact merchant join.
enum NikeSkimsWorldMedia {
    static let storyID = "library-edit-9"
    static let brownHex = "#241C19"

    struct FabricCollection: Identifiable {
        let id: String
        let title: String
        let description: String

        var videoURL: URL? { NikeSkimsWorldMedia.url("fabric-\(id).mp4") }
        var posterURL: URL? { NikeSkimsWorldMedia.url("fabric-\(id)-poster.jpg") }
    }

    static let fabrics = [
        FabricCollection(id: "studio-stretch", title: "Studio Stretch", description: "Buttery soft Dri-FIT fabric with a breathable, light feel."),
        FabricCollection(id: "matte", title: "Matte", description: "Sculpting, smoothing, mid-level compression with Dri-FIT technology and statement lines."),
        FabricCollection(id: "airy", title: "Airy", description: "Breathable Dri-FIT layers designed to complete a total look."),
        FabricCollection(id: "satin-shine", title: "Satin Shine", description: "Sleek, lightweight material with subtle sheen, compression, and four-way stretch."),
        FabricCollection(id: "weightless", title: "Weightless", description: "Semi-sheer, ultra-lightweight styles with quick-dry technology."),
        FabricCollection(id: "ribbed-seamless", title: "Ribbed Seamless", description: "Soft, stretchy ribbed styles with a vintage wash and moisture-wicking technology."),
        FabricCollection(id: "stretch-knit", title: "Stretch Knit", description: "Soft-to-the-touch, lightweight styles with flattering drape and double-layer fabric."),
    ]

    static let collectionGallery = (1...9).compactMap { url(String(format: "collection-%02d.jpg", $0)) }
    static let colorGallery = (1...5).compactMap { url(String(format: "color-%02d.jpg", $0)) }
    static let buildGallery = (1...7).compactMap { url(String(format: "build-%02d.jpg", $0)) }
    static let movementGallery = (1...3).compactMap { url(String(format: "movement-%02d.jpg", $0)) }
    static let editorialLight = ["editorial-light-1.jpg", "editorial-light-2.jpg"].compactMap(url)
    static let editorialDark = ["editorial-dark-1.jpg", "editorial-dark-2.jpg"].compactMap(url)

    /// The close material study is the cover; the grid film is reserved for a
    /// later editorial beat so feed and destination never open on a collage.
    static var coverFilmURL: URL? { url("film-closing.mp4") }
    static var coverPosterURL: URL? { url("film-closing-poster.jpg") }
    static var bodyFilmURL: URL? { url("film-opening.mp4") }
    static var bodyPosterURL: URL? { url("film-opening-poster.jpg") }

    static func isStory(_ story: FeedStory) -> Bool { story.id == storyID }

    static func url(_ path: String) -> URL? {
        let result = ShopCanvasLibrary.rootURL
            .appendingPathComponent("nikeskims-world", isDirectory: true)
            .appendingPathComponent(path)
        return FileManager.default.fileExists(atPath: result.path) ? result : nil
    }
}

struct SelfCareResetTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .feedCardTitleStyle()
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 300, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct NikeSkimsFeedHero: View {
    let playbackEnabled: Bool

    var body: some View {
        ZStack {
            Color(hex: NikeSkimsWorldMedia.brownHex)
            AmbientProductVideo(
                videoURL: NikeSkimsWorldMedia.coverFilmURL,
                posterImageURL: NikeSkimsWorldMedia.coverPosterURL?.absoluteString,
                playbackEnabled: playbackEnabled,
                playbackGroupID: "nikeskims-opening"
            )
            .scaleEffect(1.01)
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.12), location: 0),
                    .init(color: .clear, location: 0.38),
                    .init(color: Color(hex: NikeSkimsWorldMedia.brownHex).opacity(0.18), location: 0.64),
                    .init(color: .black.opacity(0.68), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipped()
    }
}

/// Renders one authored NikeSKIMS block selected by its recipe. Product rails
/// remain Shop modules, separated from the campaign chapters they accompany.
struct NikeSkimsWorldBlock: View {
    let blockID: String
    let products: [ResolvedStoryProduct]
    @Environment(NavigationCoordinator.self) private var coordinator

    private let gutter: CGFloat = 12

    @ViewBuilder
    var body: some View {
        switch blockID {
        case "opening-products": productRail("The collection", items: window(0, 4))
        case "collections":
            imageRail(
                "Meet the collections",
                subtitle: "Performance Cotton, Matte, Airy, Satin Shine, Weightless, Ribbed Seamless and Stretch Knit—each with its own hand, finish and level of support.",
                urls: NikeSkimsWorldMedia.collectionGallery,
                height: 390
            )
        case "soft-structure": productRail("Soft structure", items: window(4, 4))
        case "light-study": editorialPair(NikeSkimsWorldMedia.editorialLight)
        case "fabrics": fabricChapter
        case "support": productRail("Support in motion", items: window(8, 4))
        case "color":
            imageRail(
                "Explore by color",
                subtitle: "A tonal study in warm neutrals, high-shine surfaces and grounded darks.",
                urls: NikeSkimsWorldMedia.colorGallery,
                height: 420
            )
        case "movement-film": closingFilm
        case "built-to-move": productRail("Built to move", items: window(12, 6))
        case "build-look":
            imageRail(
                "Build the look",
                subtitle: "Seven ways into a complete look—from bras and tights to soft layers, accessories and footwear.",
                urls: NikeSkimsWorldMedia.buildGallery,
                height: 390
            )
        case "dark-study": editorialPair(NikeSkimsWorldMedia.editorialDark)
        case "movement-studies":
            imageRail(
                "Movement studies",
                subtitle: "Studio, training and everyday movement, seen through three distinct silhouettes.",
                urls: NikeSkimsWorldMedia.movementGallery,
                height: 430
            )
        case "complete-edit": allProducts
        default: EmptyView()
        }
    }

    private var fabricChapter: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeading("A study in fabric")
            Text("Seven collections, each tuned for a different feel and way of moving.")
                .font(GravityFont.regular.fixedFont(size: 15))
                .foregroundStyle(.white.opacity(0.66))
                .padding(.horizontal, 20)
                .padding(.top, -12)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(NikeSkimsWorldMedia.fabrics) { fabric in
                        fabricCard(fabric)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, gutter, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private func fabricCard(_ fabric: NikeSkimsWorldMedia.FabricCollection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if let posterURL = fabric.posterURL {
                    CachedAsyncImage(url: posterURL) { phase in
                        if case let .success(image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Color(hex: "#B4A596")
                        }
                    }
                } else {
                    Color(hex: "#B4A596")
                }
                if let videoURL = fabric.videoURL {
                    LoopingVideoPlayer(url: videoURL, playbackEnabled: true)
                }
                LinearGradient(
                    colors: [.clear, .black.opacity(0.16)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: 306, height: 250)
            .clipped()

            VStack(alignment: .leading, spacing: 9) {
                Text(fabric.title)
                    .font(GravityFont.expressiveBold.fixedFont(size: 25))
                    .tracking(-0.6)
                    .fixedSize(horizontal: false, vertical: true)
                Text(fabric.description)
                    .font(GravityFont.regular.fixedFont(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
                Label("Playing", systemImage: "play.fill")
                    .font(GravityFont.medium.fixedFont(size: 12))
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
            .padding(16)
        }
        .foregroundStyle(.white)
        .frame(width: 306)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(fabric.title). \(fabric.description). Playing")
    }

    private var closingFilm: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeading("Body in motion")
            AmbientProductVideo(
                videoURL: NikeSkimsWorldMedia.bodyFilmURL,
                posterImageURL: NikeSkimsWorldMedia.bodyPosterURL?.absoluteString,
                playbackEnabled: true
            )
            .frame(height: 520)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .padding(.horizontal, gutter)
            .accessibilityLabel("NikeSKIMS campaign film")
        }
    }

    private func productRail(_ title: String, items: [ResolvedStoryProduct]) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeading(title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 10) {
                    ForEach(items) { item in
                        productButton(item, width: 148)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, gutter, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private func imageRail(
        _ title: String,
        subtitle: String? = nil,
        urls: [URL],
        height: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeading(title)
            if let subtitle {
                Text(subtitle)
                    .font(GravityFont.regular.fixedFont(size: 15))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .padding(.top, -12)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                        CachedAsyncImage(url: url) { phase in
                            if case let .success(image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                Color(hex: "#B4A596")
                            }
                        }
                        .frame(width: index.isMultiple(of: 3) ? 294 : 250, height: height)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .accessibilityLabel("NikeSKIMS campaign image \(index + 1) of \(urls.count)")
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, gutter, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    @ViewBuilder
    private func editorialPair(_ urls: [URL]) -> some View {
        if urls.count >= 2 {
            GeometryReader { geometry in
                let width = geometry.size.width - gutter * 2
                let leftWidth = width * 0.58
                let rightWidth = width - leftWidth - 8
                HStack(spacing: 8) {
                    campaignImage(urls[0])
                        .frame(width: leftWidth, height: 490)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    campaignImage(urls[1])
                        .frame(width: rightWidth, height: 490)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .padding(.horizontal, gutter)
            }
            .frame(height: 490)
        }
    }

    private func campaignImage(_ url: URL) -> some View {
        CachedAsyncImage(url: url) { phase in
            if case let .success(image) = phase { image.resizable().scaledToFill() }
            else { Color(hex: "#B4A596") }
        }
        .accessibilityLabel("NikeSKIMS campaign image")
    }

    private var allProducts: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeading("The full edit")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 28) {
                ForEach(products) { item in
                    productButton(item, width: nil)
                }
            }
            .padding(.horizontal, gutter)
        }
    }

    private func productButton(_ item: ResolvedStoryProduct, width: CGFloat?) -> some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
        } label: {
            ProductCard(
                image: nil,
                imageURL: item.product.imageURL,
                merchantName: item.merchant.displayName,
                productName: item.product.title,
                priceBadge: productCardPriceBadge(item.product),
                showFavoriteButton: true,
                favoriteIconHasContrastShadow: true
            )
            .frame(width: width)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityIdentifier("nikeskims.product.\(item.product.id)")
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(GravityFont.expressiveBold.fixedFont(size: 28))
            .tracking(-0.7)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
    }

    private func window(_ offset: Int, _ count: Int) -> [ResolvedStoryProduct] {
        guard offset < products.count else { return [] }
        return Array(products.dropFirst(offset).prefix(count))
    }
}
