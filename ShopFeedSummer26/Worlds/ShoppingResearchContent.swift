import SwiftUI
import SafariServices

struct ShoppingResearchContent: View {
    let world: ShoppingResearchWorld
    @Environment(NavigationCoordinator.self) private var coordinator
    @AppStorage private var model: String
    @AppStorage("shop-agent.saved-research-offers") private var savedOffers = ""
    @State private var modal: ResearchModal?
    @State private var apparelFilter = "Markdowns"
    private let lime = Color(hex: "#DFECA5")

    init(world: ShoppingResearchWorld) {
        self.world = world
        _model = AppStorage(wrappedValue: "All", "\(world.id).model")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            ForEach(Array(world.sections.enumerated()), id: \.offset) { _, section in
                switch section {
                case .offers: offersSection
                case .modelStudy: modelStudy
                case .merchantComparison:
                    ResearchMerchantComparison(world: world) { modal = .offer($0, usSize: $1) }
                case .film(let editorial): editorialFeature(editorial)
                case .apparel: apparelSection
                case .alternatives:
                    VStack(alignment: .leading, spacing: 18) {
                        heading("Other ways to go.")
                        offerRail(world.offers.filter { $0.section == "alternatives" })
                    }
                case .relatedWorlds(let storyIDs): relatedWorlds(storyIDs)
                case .stories(let editorials): storyRail(editorials)
                case .methodology: methodology
                }
            }
        }
        .foregroundStyle(.white)
        .sheet(item: $modal) { item in
            switch item {
            case .source(let url): ResearchSourceBrowser(url: url).ignoresSafeArea()
            case .offer(let offer, let size):
                ResearchOfferSheet(offer: offer, selectedSize: size,
                                   policy: world.shippingPolicies.first { $0.merchantID == offer.merchantID })
                    .environment(\.colorScheme, .light)
            }
        }
    }

    private var offersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("Find your Norda.")
            HStack(spacing: 8) {
                Menu {
                    ForEach(["All"] + world.models, id: \.self) { value in
                        Button(value == "All" ? "All Norda models" : "Norda \(value)") { model = value }
                    }
                } label: { filterLabel(model == "All" ? "All models" : "Norda \(model)") }
                .accessibilityIdentifier("research.model-filter")
                Spacer(minLength: 0)
            }.padding(.horizontal, 20)
            let offers = world.featuredShoes(model: model)
            if offers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No offers in this snapshot.").font(.headline)
                    Text("Try another model.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                }.padding(20)
            } else {
                offerRail(offers)
            }
        }
    }

    private func filterLabel(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title).font(GravityFont.medium.fixedFont(size: 13))
            Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 15).frame(minHeight: 44)
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.16)))
    }

    private func offerRail(_ offers: [ResearchOffer]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 10) {
                ForEach(offers) { offer in offerCard(offer).frame(width: 178) }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .frame(height: 230, alignment: .top)
    }

    private func offerCard(_ offer: ResearchOffer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                coordinator.pushRoute(.product(merchantId: offer.merchantID, productId: offer.nativeID))
            } label: {
                ProductCard(image: nil, imageURL: offer.image, priceBadge: offer.displayPrice, showFavoriteButton: false)
                    .environment(\.colorScheme, .light)
                    .frame(width: 178, height: 178)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(offer.title), \(offer.displayPrice), \(offer.merchantName)")
            .accessibilityIdentifier("research.product.\(offer.nativeID)")
            .overlay(alignment: .topTrailing) {
                if let discount = offer.markdownPercent {
                    Text("\(discount)% off")
                        .font(GravityFont.medium.fixedFont(size: 11)).foregroundStyle(.black)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(lime, in: Capsule()).padding(10)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { toggleSaved(offer) } label: {
                    Image(systemName: isSaved(offer) ? "heart.fill" : "heart")
                        .font(.system(size: 24)).foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).padding(6)
                .accessibilityLabel(isSaved(offer) ? "Unsave \(offer.title)" : "Save \(offer.title)")
            }
            Text(offer.section == "shoes" ? "Norda \(offer.model) · \(offer.color.localizedCapitalized)" : offer.title)
                .font(GravityFont.medium.fixedFont(size: 14))
                .lineLimit(2, reservesSpace: true)
                .frame(height: 40, alignment: .topLeading)
        }
    }

    private var modelStudy: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("A closer look.")
            if let offer = world.offers.first(where: { $0.model == (model == "All" ? "001A" : model) && $0.merchantName == "norda" }) {
                HStack(spacing: 8) {
                    ForEach(Array(offer.images.dropFirst().prefix(2).enumerated()), id: \.offset) { _, image in
                        ResearchImage(url: image, height: 228)
                            .background(Color(hex: "#EDEEE9")).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }.padding(.horizontal, 20)
                Button { modal = .offer(offer) } label: {
                    HStack {
                        Text("Explore Norda \(offer.model)")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }.font(GravityFont.medium.fixedFont(size: 15))
                }.padding(.horizontal, 20)
            }
        }
    }

    private func editorialFeature(_ item: ResearchEditorial) -> some View {
        Button { openSource(item.source) } label: {
            ZStack(alignment: .bottomLeading) {
                ResearchImage(url: item.image, height: 390)
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.title).font(GravityFont.expressiveBold.fixedFont(size: 34)).tracking(-1)
                    Text(item.detail).font(GravityFont.regular.fixedFont(size: 14))
                        .foregroundStyle(.white.opacity(0.8))
                }.padding(22)
            }
            .frame(height: 390)
            .overlay {
                Image(systemName: "play.fill").font(.system(size: 20))
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial, in: Circle())
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 12)
        }.buttonStyle(.plain)
    }

    private var apparelSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("The rest of your run.")
            HStack(spacing: 8) {
                ForEach(["Markdowns", "The wider kit"], id: \.self) { value in
                    Button { apparelFilter = value } label: {
                        Text(value).font(GravityFont.medium.fixedFont(size: 13))
                            .padding(.horizontal, 16).frame(minHeight: 44)
                            .foregroundStyle(apparelFilter == value ? Color(hex: "#26382D") : .white)
                            .background(apparelFilter == value ? lime : .white.opacity(0.08), in: Capsule())
                    }
                }
            }.padding(.horizontal, 20)
            offerRail(world.offers.filter {
                $0.section == "apparel" && (apparelFilter == "Markdowns" ? $0.markdownPercent != nil : $0.markdownPercent == nil)
            })
        }
    }

    private func storyRail(_ items: [ResearchEditorial]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Out there, somewhere.")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(items) { item in
                        Button { openSource(item.source) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                ResearchImage(url: item.image, height: 290)
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: item.isFilm ? "play.fill" : "arrow.up.right")
                                            .frame(width: 40, height: 40)
                                            .background(.ultraThinMaterial, in: Circle()).padding(12)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                Text(item.title).font(GravityFont.expressiveBold.fixedFont(size: 23)).tracking(-0.5)
                                Text(item.detail).font(GravityFont.regular.fixedFont(size: 13))
                                    .foregroundStyle(.white.opacity(0.7)).lineSpacing(3)
                            }.frame(width: 258, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                }
            }.contentMargins(.horizontal, 20, for: .scrollContent)
        }
    }

    private func relatedWorlds(_ storyIDs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Keep exploring.")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(storyIDs.compactMap { id in ShopCanvasLibrary.stories.first { $0.id == id } }) { story in
                        Button { coordinator.pushRoute(.story(storyId: story.id)) } label: {
                            LibraryProductHero(story: story, width: 258, height: 310)
                                .overlay(alignment: .bottomLeading) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(story.title).font(GravityFont.expressiveBold.fixedFont(size: 27)).tracking(-0.6)
                                        Label("Explore the edit", systemImage: "arrow.right").font(.footnote)
                                    }.padding(20)
                                }.clipShape(RoundedRectangle(cornerRadius: 20))
                        }.buttonStyle(.plain)
                    }
                }
            }.contentMargins(.horizontal, 20, for: .scrollContent)
        }
    }

    private var methodology: some View {
        DisclosureGroup("About these prices") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Checked \(world.offers.first?.observedAt.prefix(10) ?? ""). Prices come from USD storefronts, not our currency conversions. Best price compares the same model, color and US men's size. Shipping and tax may change the total. No live tracking or verified price history.")
                Button { openSource(world.heroSource) } label: {
                    Label("Cover film by Norda", systemImage: "arrow.up.right")
                }
                Text("The cover loops a short excerpt from Norda's 055 film. Other films and stories open at their original sources. They aren't endorsements of this edit.")
            }
            .font(GravityFont.regular.fixedFont(size: 13)).lineSpacing(3)
            .foregroundStyle(.white.opacity(0.7)).padding(.top, 12)
        }
        .font(GravityFont.medium.fixedFont(size: 14)).tint(.white.opacity(0.7))
        .padding(20)
    }

    private func heading(_ title: String) -> some View {
        Text(title).font(GravityFont.expressiveBold.fixedFont(size: 30)).tracking(-1)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, 20)
    }
    private func isSaved(_ offer: ResearchOffer) -> Bool { savedOffers.split(separator: "|").contains(Substring(offer.id)) }
    private func toggleSaved(_ offer: ResearchOffer) {
        var ids = Set(savedOffers.split(separator: "|").map(String.init))
        if !ids.insert(offer.id).inserted { ids.remove(offer.id) }
        savedOffers = ids.sorted().joined(separator: "|")
    }
    private func openSource(_ source: String) {
        guard let url = URL(string: source), url.scheme == "https" else { return }
        modal = .source(url)
    }
}

private enum ResearchModal: Identifiable {
    case offer(ResearchOffer, usSize: String? = nil)
    case source(URL)
    var id: String {
        switch self {
        case .offer(let offer, let size): "offer:\(offer.id):\(size ?? "all")"
        case .source(let url): url.absoluteString
        }
    }
}

private struct ResearchImage: View {
    let url: String
    let height: CGFloat
    var body: some View {
        Color.white.opacity(0.08)
            .overlay {
                GeometryReader { geometry in
                    if let source = URL(string: url) {
                        CachedAsyncImage(url: source) { phase in
                            switch phase {
                            case .success(let image): image.resizable().scaledToFill()
                            case .failure: Image(systemName: "photo").frame(maxWidth: .infinity, maxHeight: .infinity)
                            default: Color.clear
                            }
                        }.frame(width: geometry.size.width, height: height).clipped()
                    }
                }
            }
            .frame(height: height).clipped().accessibilityHidden(true)
    }
}

private struct ResearchSourceBrowser: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct ResearchOfferSheet: View {
    let offer: ResearchOffer
    let selectedSize: String?
    let policy: ResearchShippingPolicy?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ProductCard(image: nil, imageURL: offer.image, priceBadge: offer.displayPrice, showFavoriteButton: false)
                    Text(offer.title).font(.title2.weight(.semibold))
                    Text("\(offer.merchantName) · \(offer.currency) storefront").font(.subheadline)
                    if let reference = offer.displayReference {
                        Text("Shop reference price: \(reference). Price history not verified.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Text(selectedSize.map { "US men's \($0)" } ?? "Sizes at this price").font(.headline)
                    if selectedSize == nil {
                        Text(offer.availableVariants.joined(separator: "  ·  ")).font(.subheadline)
                    }
                    Text("Checked \(offer.observedAt.prefix(10)). Shipping, taxes and duties not compared. Confirm your size and current total at the shop.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let policy {
                        Text(policy.summary).font(.headline)
                        Text(policy.detail).font(.footnote).foregroundStyle(.secondary)
                        if let url = URL(string: policy.sourceURL) {
                            Link("Shipping policy", destination: url).font(.footnote)
                        }
                    }
                    if let url = offer.productURL(usMensSize: selectedSize) {
                        Link(destination: url) {
                            Label("Check at \(offer.merchantName)", systemImage: "arrow.up.right")
                                .frame(maxWidth: .infinity).padding(16)
                        }.foregroundStyle(.white).background(.black, in: Capsule())
                    }
                }.padding(20)
            }
            .navigationTitle("The price check").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
