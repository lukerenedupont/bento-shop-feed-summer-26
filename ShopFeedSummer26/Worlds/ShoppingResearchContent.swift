import SwiftUI
import SafariServices

struct ShoppingResearchContent: View {
    let world: ShoppingResearchWorld
    @Environment(NavigationCoordinator.self) private var coordinator
    @AppStorage private var model: String
    @AppStorage("shop-agent.saved-research-offers") private var savedOffers = ""
    @State private var modal: ResearchModal?
    @State private var activeMotionStoryID: String?
    @State private var showsBriefEditor = false
    @AppStorage private var deliveryContext: String
    @AppStorage private var raceContext: String
    @AppStorage private var styleContext: String
    private let lime = Color(hex: "#DFECA5")

    init(world: ShoppingResearchWorld) {
        self.world = world
        _model = AppStorage(wrappedValue: "All", "\(world.id).model")
        _deliveryContext = AppStorage(wrappedValue: "", "\(world.id).delivery-context")
        _raceContext = AppStorage(wrappedValue: "", "\(world.id).race-context")
        _styleContext = AppStorage(wrappedValue: "", "\(world.id).style-context")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            ForEach(Array(world.sections.enumerated()), id: \.offset) { _, section in
                switch section {
                case .offers:
                    offersSection
                    researchBrief
                case .modelStudy: modelStudy
                case .merchantComparison:
                    ResearchMerchantComparison(world: world) { modal = .offer($0, usSize: $1) }
                case .film(let editorial): editorialFeature(editorial)
                case .apparel: apparelSection
                case .alternatives: alternativeComparison
                case .runningShops(let merchantIDs): runningShops(merchantIDs)
                case .motionStories(let stories): motionStoryRail(stories)
                case .relatedWorlds(let storyIDs): relatedWorlds(storyIDs)
                case .stories(let editorials): storyRail(editorials)
                case .methodology: methodology
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.bottom, 180)
        .sheet(item: $modal) { item in
            switch item {
            case .source(let url): ResearchSourceBrowser(url: url).ignoresSafeArea()
            case .offer(let offer, let size):
                ResearchOfferSheet(offer: offer, selectedSize: size,
                                   policy: world.shippingPolicies.first { $0.merchantID == offer.merchantID })
                    .environment(\.colorScheme, .light)
            }
        }
        .sheet(isPresented: $showsBriefEditor) {
            ResearchBriefEditor(
                delivery: $deliveryContext,
                race: $raceContext,
                style: $styleContext
            )
            .environment(\.colorScheme, .light)
        }
    }

    private var researchBrief: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill")
                Text("Source-checked snapshot")
            }
            .font(GravityFont.semiBold.fixedFont(size: 13))
            .foregroundStyle(lime)

            Text("Built from your request.")
                .font(GravityFont.expressiveBold.fixedFont(size: 34)).tracking(-1.2)
                .accessibilityAddTraits(.isHeader)

            Text("“\(world.prompt)”")
                .font(GravityFont.medium.fixedFont(size: 17))
                .lineSpacing(3)
                .foregroundStyle(.white.opacity(0.92))

            Text("I checked \(world.offers.count) sourced offers across \(world.researchedMerchantCount) running shops, compared exact Norda matches, and built this edit with the best observed price, sale finds, a complete kit and other trail shoes worth seeing.")
                .font(GravityFont.regular.fixedFont(size: 14))
                .lineSpacing(3)
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 8) {
                briefFact("\(world.offers.count) sourced offers")
                briefFact("\(world.researchedMerchantCount) shops")
                briefFact("US · USD")
            }

            Button { showsBriefEditor = true } label: {
                VStack(spacing: 0) {
                    briefContextRow("Delivery destination", value: deliveryContext, emptyValue: "Add destination")
                    Divider().overlay(.white.opacity(0.1))
                    briefContextRow("Upcoming race", value: raceContext, emptyValue: "Add race")
                    Divider().overlay(.white.opacity(0.1))
                    briefContextRow("Fit & aesthetic", value: styleContext, emptyValue: "Add preferences")
                }
                .padding(.horizontal, 16)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("research.personalize-brief")
        }
        .padding(.horizontal, 20)
    }

    private func briefFact(_ value: String) -> some View {
        Text(value)
            .font(GravityFont.medium.fixedFont(size: 11))
            .foregroundStyle(.white.opacity(0.72))
            .padding(.horizontal, 10).frame(height: 30)
            .background(.white.opacity(0.07), in: Capsule())
    }

    private func briefContextRow(_ label: String, value: String, emptyValue: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(GravityFont.regular.fixedFont(size: 13))
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
            Text(value.isEmpty ? emptyValue : value)
                .font(GravityFont.semiBold.fixedFont(size: 13))
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(minHeight: 46)
    }

    private var offersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("Find your Norda.")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    modelPill("All")
                    ForEach(world.models, id: \.self) { modelPill($0) }
                }
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
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

    private func modelPill(_ value: String) -> some View {
        Button { model = value } label: {
            Text(value == "All" ? "All" : "Norda \(value)")
                .font(GravityFont.medium.fixedFont(size: 13))
                .padding(.horizontal, 16).frame(minHeight: 44)
                .foregroundStyle(model == value ? Color(hex: "#26382D") : .white)
                .background(model == value ? lime : .white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("research.model.\(value)")
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
            VStack(alignment: .leading, spacing: 2) {
                Text(offer.section == "shoes" ? "Norda \(offer.model) · \(offer.color.localizedCapitalized)" : offer.title)
                    .font(GravityFont.medium.fixedFont(size: 14))
                    .lineLimit(1)
                if offer.section == "shoes", model != "All" {
                    Text(offer.merchantName.localizedCapitalized)
                        .font(GravityFont.regular.fixedFont(size: 12))
                        .foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                }
            }
            .frame(height: 40, alignment: .topLeading)
        }
    }

    private var modelStudy: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("A closer look.")
            if let offer = world.offers.first(where: { $0.model == (model == "All" ? "001A" : model) && $0.merchantName == "norda" }) {
                if let editorial = trailEditorial {
                    Button { openSource(editorial.source) } label: {
                        ZStack(alignment: .bottomLeading) {
                            ResearchImage(url: editorial.image, height: 280)
                            LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Norda on trail")
                                    .font(GravityFont.expressiveBold.fixedFont(size: 27)).tracking(-0.6)
                                Text("Western States · Norda story")
                                    .font(GravityFont.regular.fixedFont(size: 13)).foregroundStyle(.white.opacity(0.78))
                            }.padding(18)
                        }
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }
                HStack(spacing: 8) {
                    ForEach(Array(offer.images.dropFirst().prefix(2).enumerated()), id: \.offset) { _, image in
                        ResearchImage(url: image, height: 180)
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

    private var trailEditorial: ResearchEditorial? {
        for section in world.sections {
            if case .stories(let items) = section,
               let editorial = items.first(where: { $0.id == "western-states" }) { return editorial }
        }
        return nil
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
        let offers = world.offers.filter { $0.section == "apparel" }
        let merchantOrder = ["District Vision", "SATISFY", "SOAR"]
        return VStack(alignment: .leading, spacing: 18) {
            heading("The rest of your run.")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(merchantOrder, id: \.self) { merchantName in
                        let merchantOffers = offers.filter { $0.merchantName == merchantName }
                        if let merchantID = merchantOffers.first?.merchantID, !merchantOffers.isEmpty {
                            runningKitMerchantCard(merchantID: merchantID, offers: merchantOffers)
                        }
                    }
                }.scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private func runningKitMerchantCard(merchantID: String, offers: [ResearchOffer]) -> some View {
        Button { coordinator.pushRoute(.store(merchantId: merchantID)) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(Array(offers.prefix(2))) { offer in
                        ProductCard(image: nil, imageURL: offer.image, priceBadge: offer.displayPrice,
                                    showFavoriteButton: false)
                            .environment(\.colorScheme, .light)
                            .frame(width: 126, height: 126)
                            .allowsHitTesting(false)
                    }
                }
                LibraryMerchantWordmark(merchantID: merchantID)
                    .frame(width: 150, height: 28, alignment: .leading)
                Text(merchantOfferSummary(offers))
                    .font(GravityFont.regular.fixedFont(size: 13))
                    .foregroundStyle(.white.opacity(0.68))
            }
            .padding(14)
            .frame(width: 292, alignment: .leading)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("research.kit-merchant.\(merchantID)")
    }

    private func merchantOfferSummary(_ offers: [ResearchOffer]) -> String {
        let saleCount = offers.filter { $0.markdownPercent != nil }.count
        let floor = offers.min(by: { $0.amount < $1.amount })?.displayPrice ?? "Price at shop"
        if saleCount > 0 { return "\(saleCount) sale \(saleCount == 1 ? "find" : "finds") · from \(floor)" }
        return "\(offers.count) \(offers.count == 1 ? "piece" : "pieces") · from \(floor)"
    }

    private var alternativeComparison: some View {
        let selected = world.featuredShoes(model: model).first
        let alternatives = world.alternativeNotes.compactMap { note in
            world.offers.first { $0.id == note.offerID }.map { (offer: $0, note: note) }
        }
        return VStack(alignment: .leading, spacing: 12) {
            heading("How they compare.")
            Text("Your Norda beside other directions for race day, long miles and daily training.")
                .font(GravityFont.regular.fixedFont(size: 14))
                .foregroundStyle(.white.opacity(0.68)).lineSpacing(3)
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 10) {
                    if let selected {
                        comparisonCard(offer: selected, useCase: "Your Norda",
                                       distinction: nordaDistinction(selected.model), highlighted: true)
                    }
                    ForEach(alternatives, id: \.note.id) { item in
                        comparisonCard(offer: item.offer, useCase: item.note.useCase,
                                       distinction: item.note.distinction, highlighted: false)
                    }
                }.scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            Text("At a glance from merchant product descriptions—not comparative wear testing.")
                .font(GravityFont.regular.fixedFont(size: 11))
                .foregroundStyle(.white.opacity(0.52)).padding(.horizontal, 20)
        }
    }

    private func comparisonCard(offer: ResearchOffer, useCase: String, distinction: String, highlighted: Bool) -> some View {
        Button { coordinator.pushRoute(.product(merchantId: offer.merchantID, productId: offer.nativeID)) } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(useCase)
                    .font(GravityFont.semiBold.fixedFont(size: 11))
                    .foregroundStyle(highlighted ? Color(hex: "#26382D") : .white.opacity(0.72))
                    .padding(.horizontal, 9).frame(height: 26)
                    .background(highlighted ? lime : .white.opacity(0.09), in: Capsule())
                ProductCard(image: nil, imageURL: offer.image, showFavoriteButton: false)
                    .environment(\.colorScheme, .light)
                    .frame(width: 164, height: 164).allowsHitTesting(false)
                Text(offer.title).font(GravityFont.medium.fixedFont(size: 14)).lineLimit(2)
                Text(distinction).font(GravityFont.regular.fixedFont(size: 11))
                    .foregroundStyle(.white.opacity(0.66)).lineLimit(3)
                HStack(alignment: .firstTextBaseline) {
                    Text(offer.displayPrice).font(GravityFont.expressiveBold.fixedFont(size: 22))
                    Spacer()
                    Text(offer.merchantName.localizedCapitalized)
                        .font(GravityFont.regular.fixedFont(size: 10)).foregroundStyle(.white.opacity(0.56)).lineLimit(1)
                }
            }
            .padding(12).frame(width: 188, height: 320, alignment: .topLeading)
            .background(.white.opacity(highlighted ? 0.10 : 0.055), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(highlighted ? lime.opacity(0.6) : .white.opacity(0.1)))
        }.buttonStyle(.plain)
    }

    private func nordaDistinction(_ model: String) -> String {
        switch model {
        case "003": "Laceless Bio-Dyneema · Vibram traction"
        case "001A": "Cushioned trail construction"
        case "005": "Race-day trail build"
        case "055": "Responsive technical-trail build"
        default: "Technical trail construction"
        }
    }

    private func runningShops(_ merchantIDs: [String]) -> some View {
        let merchants = merchantIDs.compactMap { ShopCanvasLibrary.merchantsByID[$0] }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(merchants, id: \.id) { merchant in
                    Button { coordinator.pushRoute(.store(merchantId: merchant.id)) } label: {
                        LibraryMerchantWordmark(merchantID: merchant.id)
                            .frame(width: 122, height: 34)
                            .padding(.horizontal, 18).frame(height: 64)
                            .background(.white.opacity(0.07), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("research.merchant-card.\(merchant.id)")
                }
            }
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }

    private func motionStoryRail(_ stories: [ResearchMotionStory]) -> some View {
        let resolved = stories.compactMap { story in
            world.offers.first { $0.id == story.offerID }.map { (story, $0) }
        }
        return VStack(alignment: .leading, spacing: 18) {
            heading("Running, in motion.")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(resolved, id: \.0.id) { story, offer in
                        ResearchMotionStoryCard(
                            story: story,
                            offer: offer,
                            isActive: activeMotionStoryID == story.id,
                            onOpen: {
                                coordinator.pushRoute(.product(merchantId: offer.merchantID, productId: offer.nativeID))
                            }
                        )
                        .id(story.id)
                    }
                }.scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $activeMotionStoryID)
            .onAppear { if activeMotionStoryID == nil { activeMotionStoryID = resolved.first?.0.id } }
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
                                        if item.isFilm {
                                            Image(systemName: "play.fill")
                                                .frame(width: 40, height: 40)
                                                .background(.ultraThinMaterial, in: Circle()).padding(12)
                                        }
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

private struct ResearchBriefEditor: View {
    @Binding var delivery: String
    @Binding var race: String
    @Binding var style: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("City or ZIP code", text: $delivery)
                        .textContentType(.postalCode)
                    TextField("Race and date", text: $race)
                    TextField("Fit, colors or aesthetic", text: $style, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Make this edit more personal")
                } footer: {
                    Text("These details stay on this device as context for the edit. Prices and delivery are not recalculated, and blank fields are never inferred.")
                }
            }
            .navigationTitle("Your running brief")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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

private struct ResearchMotionStoryCard: View {
    let story: ResearchMotionStory
    let offer: ResearchOffer
    let isActive: Bool
    let onOpen: () -> Void
    @State private var isVisible = false

    var body: some View {
        Button(action: onOpen) {
            ZStack(alignment: .bottomLeading) {
                AmbientProductVideo(
                    videoURL: URL(string: story.videoURL),
                    posterImageURL: offer.image,
                    playbackEnabled: isActive && isVisible,
                    playbackGroupID: "research-motion-\(story.id)"
                )
                .frame(width: 258, height: 368)
                LinearGradient(
                    stops: [.init(color: .clear, location: 0.45), .init(color: .black.opacity(0.82), location: 1)],
                    startPoint: .top, endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 5) {
                    Text(story.title)
                        .font(GravityFont.expressiveBold.fixedFont(size: 24)).tracking(-0.5)
                    Text(story.detail)
                        .font(GravityFont.regular.fixedFont(size: 13)).foregroundStyle(.white.opacity(0.78))
                    Text("View \(offer.title)")
                        .font(GravityFont.medium.fixedFont(size: 13)).padding(.top, 4)
                }.padding(18)
            }
            .frame(width: 258, height: 368)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(story.title). \(story.detail). View \(offer.title)")
        .accessibilityIdentifier("research.motion.\(story.id)")
        .onScrollVisibilityChange(threshold: 0.55) { isVisible = $0 }
        .onDisappear { isVisible = false }
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
