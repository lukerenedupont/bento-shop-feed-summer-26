import SwiftUI

/// Editorial groupings of already published products. These are aesthetic
/// directions, not a claim that each photograph depicts the grouped assortment.
enum ReadingCornerDiscoveryCatalog {
    struct Direction: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let sourceProductID: String
        let imageIndex: Int
        let productIDs: [String]
        var source: ShopCanvasLibrary.Product? { ShopCanvasLibrary.productsByID[sourceProductID] }
        var imageURL: URL? {
            guard let images = source?.images, images.indices.contains(imageIndex) else { return nil }
            return ShopCanvasLibrary.resolve(images[imageIndex])
        }
    }
    struct Category: Identifiable {
        let id: String
        let title: String
        let productIDs: [String]
    }
    static let easyChair = "catalog:gid://shopify/p/1WJk66AVvGdVHYidCxU0Oj"
    static let rivet = "catalog:gid://shopify/p/3O2ikTv0ScaeNGRN3Vx8Nq"
    static let hashira = "catalog:gid://shopify/p/1bXjxJidKLfetqPwILR2cS"
    static let brasilia = "catalog:gid://shopify/p/4Mn7PUHm5QzWBr192P2uHc"
    static let luver = "catalog:gid://shopify/p/3Lm7WscSuCpLpzGfeNoCfN"
    static let book = "catalog:gid://shopify/p/7GKbgzJ8iSvrCAoe7bgnWd"
    static let vase = "catalog:gid://shopify/p/7hTt5s8kxfzV3WH7ZVmuwy"
    static let cubo = "oblist:8578971828489"
    static let floorLamp = "oblist:8389367169289"
    static let tableLamp = "oblist:8424695562505"
    static let directions: [Direction] = [
        .init(id: "warm", title: "Warm & collected", subtitle: "Wood grain, open shapes, everyday objects.",
              sourceProductID: easyChair, imageIndex: 2, productIDs: [easyChair, cubo, luver]),
        .init(id: "soft", title: "Soft & sculptural", subtitle: "Rounded upholstery and pools of diffused light.",
              sourceProductID: brasilia, imageIndex: 1, productIDs: [brasilia, hashira, tableLamp]),
        .init(id: "quiet", title: "Quiet contrasts", subtitle: "Brushed metal, clean lines, one good book.",
              sourceProductID: rivet, imageIndex: 2, productIDs: [rivet, floorLamp, book]),
    ]
    static var categories: [Category] {
        let pieces = ReadingCornerCatalog.snapshot.pieces
        return [
            .init(id: "tables", title: "Side tables", productIDs: pieces.filter { $0.role == .table }.map(\.id) + [rivet]),
            .init(id: "chairs", title: "Reading chairs", productIDs: pieces.filter { $0.role == .chair }.map(\.id) + [easyChair, brasilia]),
            .init(id: "lighting", title: "A softer light", productIDs: [hashira, luver, floorLamp, tableLamp]),
            .init(id: "objects", title: "The finishing touches", productIDs: [vase, book, "catalog:gid://shopify/p/5d4PpgClbXc4x7Hyyg2qVh"]),
        ]
    }
    static let merchantIDs = [ReadingCornerCatalog.merchantID, "gid://shopify/Shop/83980288319",
                              "gid://shopify/Shop/7539621924", "gid://shopify/Shop/32176570505"]
    static let relatedStoryIDs = ["library-edit-30", "library-edit-20", "library-edit-22"]
    static var additionalReferences: [FeedStory.ProductReference] {
        let selectedIDs = Set(ReadingCornerCatalog.snapshot.pieces.map(\.id))
        var seen = selectedIDs
        return (directions.flatMap(\.productIDs) + categories.flatMap(\.productIDs)).compactMap { id in
            guard seen.insert(id).inserted, let p = ShopCanvasLibrary.productsByID[id],
                  let merchantID = p.merchantIDs.first else { return nil }
            return .init(merchantID: merchantID, productID: p.nativeID)
        }
    }
    static func productImage(_ item: ResolvedStoryProduct) -> URL? {
        // The immutable Brasilia lead photo shows another finish. The source
        // gallery supplies the dark-oak Bouclé 02 variant tied to its price.
        if item.product.sourceProductID == brasilia,
           let source = ShopCanvasLibrary.productsByID[brasilia]?.images.first(where: {
               $0.contains("8051000-000000ZZ_Brasilia_Lounge_Chair_Dark_Stained_Oak_Boucle_02_Angle")
           }) { return URL(string: source) }
        return item.product.imageURL.flatMap(URL.init(string:))
    }
    static func products(_ ids: [String]) -> [ResolvedStoryProduct] {
        ids.compactMap { id in
            guard let p = ShopCanvasLibrary.productsByID[id], let mid = p.merchantIDs.first,
                  let merchant = ShopCanvasLibrary.merchants.first(where: { $0.id == mid }),
                  let product = merchant.products.first(where: { $0.id == p.nativeID }) else { return nil }
            return ResolvedStoryProduct(merchant: merchant, product: product)
        }
    }
}

/// The same cached-image pipeline as other Worlds, with an explicit canvas
/// ratio. A matching source ratio fills the selected card without letterboxing.
struct CornerArtwork: View {
    let url: URL?
    var ratio: CGFloat = 1
    var body: some View {
        Color(hex: "#C9C0B2").aspectRatio(ratio, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    if let url { CachedAsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        } else {
                            Color(hex: "#C9C0B2")
                                .overlay { Image(systemName: "photo").foregroundStyle(.black.opacity(0.25)) }
                        }
                    } }
                }
            }.clipped().accessibilityHidden(true)
    }
}

struct ReadingCornerDiscovery: View {
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var directionID = "warm"
    @State private var assortment: TopicPresentedAssortment?
    private var direction: ReadingCornerDiscoveryCatalog.Direction {
        ReadingCornerDiscoveryCatalog.directions.first { $0.id == directionID } ?? ReadingCornerDiscoveryCatalog.directions[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            VStack(alignment: .leading, spacing: 18) {
                title("Find your kind of quiet.")
                Text("Three directions. A few pieces to get you there.")
                    .font(GravityFont.regular.fixedFont(size: 15)).foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 8) {
                    ForEach(ReadingCornerDiscoveryCatalog.directions) { item in
                        Button {
                            directionID = item.id
                        } label: {
                            Text(item.id == "warm" ? "Warm" : item.id == "soft" ? "Soft" : "Contrast")
                                .font(GravityFont.medium.fixedFont(size: 14))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(directionID == item.id ? .white : .white.opacity(0.1), in: Capsule())
                                .foregroundStyle(directionID == item.id ? .black : .white)
                        }.accessibilityIdentifier("corner.direction.\(item.id)")
                    }
                }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 12) {
                    CornerArtwork(url: direction.imageURL, ratio: 1.05)
                        .overlay(alignment: .bottomLeading) {
                            Text("\(direction.source?.brand ?? "") · Room inspiration")
                                .font(GravityFont.medium.fixedFont(size: 11)).foregroundStyle(.white)
                                .padding(9).background(.black.opacity(0.45), in: Capsule()).padding(12)
                        }.clipShape(RoundedRectangle(cornerRadius: 24))
                    Text(direction.title).font(GravityFont.expressiveBold.fixedFont(size: 26))
                    Text(direction.subtitle).font(GravityFont.regular.fixedFont(size: 15)).foregroundStyle(.white.opacity(0.72))
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(ReadingCornerDiscoveryCatalog.products(direction.productIDs)) { item in
                            discoveryProduct(item)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 18) {
                title("One piece can change it.")
                LazyVGrid(columns: [.init(.flexible(), spacing: 12), .init(.flexible(), spacing: 12)], spacing: 20) {
                    ForEach(ReadingCornerDiscoveryCatalog.categories) { category in
                        Button {
                            assortment = .init(title: category.title, subtitle: "Pieces to explore · Separate from your selected set",
                                               products: ReadingCornerDiscoveryCatalog.products(category.productIDs))
                        } label: {
                            VStack(alignment: .leading, spacing: 9) {
                                CornerArtwork(url: ReadingCornerDiscoveryCatalog.products(category.productIDs).first
                                    .flatMap { $0.product.imageURL.flatMap(URL.init(string:)) }, ratio: 1)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                HStack {
                                    Text(category.title).font(GravityFont.medium.fixedFont(size: 15))
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.up.right").font(.system(size: 11))
                                }
                            }
                        }.buttonStyle(.plain).accessibilityIdentifier("corner.category.\(category.id)")
                    }
                }
            }
            VStack(alignment: .leading, spacing: 18) {
                title("Shops with a point of view.")
                HStack(spacing: 10) {
                    ForEach(ReadingCornerDiscoveryCatalog.merchantIDs, id: \.self) { id in
                        Button { coordinator.pushRoute(.store(merchantId: id)) } label: {
                            LibraryMerchantWordmark(merchantID: id, onDark: false)
                                .padding(12).frame(maxWidth: .infinity).frame(height: 80)
                                .background(Color(hex: "#F0ECE4"), in: RoundedRectangle(cornerRadius: 16))
                        }.accessibilityLabel("Explore \(ShopCanvasLibrary.merchantsByID[id]?.name ?? "shop")")
                            .accessibilityIdentifier("corner.shop.\(id)")
                    }
                }.buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 18) {
                title("Stay a little longer.")
                ForEach(ReadingCornerDiscoveryCatalog.relatedStoryIDs, id: \.self) { id in
                    if let story = ShopCanvasLibrary.stories.first(where: { $0.id == id }) {
                        TopicCollectionCard(story: story, merchants: ShopCanvasLibrary.merchants, height: 230)
                            .accessibilityIdentifier("corner.story.\(id)")
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .sheet(item: $assortment) { item in
            TopicProductCollectionSheet(assortment: item, accentColor: Color(hex: "#42392E"))
                .environment(\.colorScheme, .light)
        }
    }

    private func title(_ value: String) -> some View {
        Text(value).font(GravityFont.expressiveBold.fixedFont(size: 29)).tracking(-0.5)
    }
    private func discoveryProduct(_ item: ResolvedStoryProduct) -> some View {
        Button { coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id)) } label: {
            VStack(alignment: .leading, spacing: 7) {
                CornerArtwork(url: ReadingCornerDiscoveryCatalog.productImage(item))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(item.product.title).font(GravityFont.medium.fixedFont(size: 12)).lineLimit(2)
                    .frame(height: 32, alignment: .topLeading)
                Text(productCardPriceBadge(item.product)).font(GravityFont.semiBold.fixedFont(size: 13))
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(.plain)
    }
}
