import SwiftUI

/// PROTOTYPE — signal-driven jobs in the real Shop feed. Long-press the
/// heading for the design controls, which are absent from consumer mode.
struct NextGenerationFeedCardView: View {
    let sourceSpec: NextGenerationFeedCardSpec
    let merchants: [SampleMerchant]
    let width: CGFloat
    let height: CGFloat
    let foregroundTopPadding: CGFloat
    let isActive: Bool
    let session: GenerativeFeedPrototypeSession
    var bottomContentPadding: CGFloat = GravitySpacing.space24
    var visibleContentBottom: CGFloat? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var showsInspector = false
    @State private var showsRoomPlan = false
    @State private var showsSavedLooks = false
    @State private var detailProduct: ResolvedStoryProduct?

    private var spec: NextGenerationFeedCardSpec { session.resolve(sourceSpec, merchants: merchants) }
    private var products: [ResolvedStoryProduct] { session.products(for: spec, merchants: merchants) }
    private var activeGroup: PrototypeContentGroup? { session.activeGroup(for: spec) }
    private var anchor: ResolvedStoryProduct? {
        spec.anchor.flatMap { NextGenerationFeedCardSpec.resolve($0, in: merchants) }
    }
    private var selected: ResolvedStoryProduct? { session.selected(in: products, for: spec) }
    private var current: GenerativeFeedPrototypeSession.CardState { session.state(for: spec) }
    private var purchaseURL: URL? {
        guard let url = selected?.product.shopURL.flatMap(URL.init(string:)),
              ["https", "http"].contains(url.scheme ?? ""), url.host != nil else { return nil }
        return url
    }
    private var ink: Color { spec.prefersDarkNavigationText ? .black : .white }
    private var visibleProducts: [ResolvedStoryProduct] { products.filter { !current.removedIDs.contains($0.id) } }

    var body: some View {
        // Background is the sizing root. Intrinsic image sizes must never
        // participate in the feed's width/height proposal.
        GenerativeFeedStyle.surface(for: spec)
            .frame(width: width, height: height)
            .overlay(alignment: .topLeading) {
                if let composition = session.compositionDefinition(for: spec) {
                    GeneratedCompositionCard(definition: composition, spec: spec, merchants: merchants, session: session,
                        width: width, height: height, topPadding: foregroundTopPadding, isActive: isActive,
                        onInspect: { showsInspector = true })
                        .id(composition.id)
                } else if let record = DossierReviewLibrary.record(for: spec) {
                    DossierMediaFeedCard(record: record, spec: spec, merchants: merchants, session: session,
                        width: width, height: height, topPadding: foregroundTopPadding,
                        bottomPadding: bottomContentPadding, isActive: isActive,
                        visibleContentBottom: visibleContentBottom,
                        onInspect: { showsInspector = true })
                } else if spec.isQuietReview {
                    QuietShoppingCardPrototype(spec: spec, merchants: merchants, session: session,
                        width: width, height: height, topPadding: foregroundTopPadding,
                        bottomPadding: bottomContentPadding, isActive: isActive,
                        onInspect: { showsInspector = true })
                } else {
                VStack(alignment: .leading, spacing: GravitySpacing.space20) {
                    heading
                    GeometryReader { proxy in
                        composition(size: proxy.size)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                    controls
                }
                .padding(.horizontal, GravitySpacing.space20)
                .padding(.top, foregroundTopPadding)
                .padding(.bottom, bottomContentPadding)
                .frame(width: width, height: height)
                .foregroundStyle(ink)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous))
            .environment(\.colorScheme, spec.prefersDarkNavigationText ? .light : .dark)
            .sheet(isPresented: $showsInspector, onDismiss: {
                if session.requestedFeedControls {
                    session.requestedFeedControls = false
                    session.showsFeedControls = true
                }
            }) {
                GenerativeFeedInspector(sourceSpec: sourceSpec, merchants: merchants, session: session)
            }
            .sheet(isPresented: $showsRoomPlan) {
                roomPlan
            }
            .sheet(isPresented: $showsSavedLooks) {
                GenerativeSavedLooksReview(spec: spec, merchants: merchants, session: session)
            }
            .sheet(item: $detailProduct) { GenerativeProductReview(item: $0) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(spec.accessibilityDescription)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            if session.designMode {
                HStack {
                    Text("Design mode · \(spec.job.rawValue)")
                        .font(GravityFont.medium.fixedFont(size: 12))
                        .foregroundStyle(ink.opacity(0.65))
                    Spacer()
                    Button { showsInspector = true } label: {
                        Image(systemName: "slider.horizontal.3").frame(width: 44, height: 28)
                    }
                    .accessibilityLabel("Inspect this shopping experience")
                    .accessibilityIdentifier("generative.inspector")
                }
            }
            if spec.interaction == .swap, session.composition(for: spec) == .relationship, let anchor {
                Button { detailProduct = anchor } label: {
                    HStack(spacing: GravitySpacing.space16) {
                        GenerativeProductMedia(item: anchor).frame(width: 88, height: 88)
                        VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                            Text("You bought")
                                .font(GravityFont.medium.fixedFont(size: 12)).foregroundStyle(.secondary)
                            Text(anchor.product.title)
                                .font(GravityFont.semiBold.fixedFont(size: 15)).lineLimit(3)
                                .accessibilityIdentifier("generative.heading")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("generative.purchasedAnchor")
            } else if spec.interaction == .selectForWorld, session.composition(for: spec) == .continuation, let anchor {
                HStack(spacing: GravitySpacing.space12) {
                    GenerativeProductMedia(item: anchor).frame(width: 56, height: 64)
                    VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                        Text(spec.title)
                            .font(GravityFont.expressiveSemiBold.fixedFont(size: 22))
                            .accessibilityIdentifier("generative.heading")
                        Text("With your saved \(anchor.product.title)")
                            .font(GravityFont.regular.fixedFont(size: 13))
                            .foregroundStyle(.secondary).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(spec.job == .narrow ? activeGroup?.title ?? spec.title : spec.title)
                    .font(GravityFont.expressiveSemiBold.fixedFont(size: 28))
                    .tracking(-0.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("generative.heading")
                Text(spec.job == .narrow ? activeGroup?.context ?? spec.subtitle : spec.subtitle)
                    .font(GravityFont.regular.fixedFont(size: 15))
                    .foregroundStyle(ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .highPriorityGesture(LongPressGesture().onEnded { _ in showsInspector = true })
        .accessibilityAction(named: "Inspect demo context") { showsInspector = true }
    }

    @ViewBuilder
    private func composition(size: CGSize) -> some View {
        switch session.composition(for: spec) {
        case .relationship:
            relationship(size: size)
        case .comparison:
            comparison(size: size)
        case .merchant:
            merchant(size: size)
        case .continuation:
            continuation(size: size)
        case .hero:
            VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                if let anchor { compactProduct(anchor, caption: "Your anchor") }
                GenerativeProductMedia(item: selected)
                HStack(alignment: .top) {
                    identity(selected)
                    if spec.interaction == .swap, let selected {
                        Button { perform { session.toggleSaved(selected, for: spec) } } label: {
                            Image(systemName: current.savedSelectionIDs.contains(selected.id) ? "heart.fill" : "heart")
                                .font(.system(size: 20)).frame(width: 44, height: 44)
                        }
                        .disabled(!current.interactionsEnabled)
                        .accessibilityLabel(current.savedSelectionIDs.contains(selected.id) ? "Unsave this look" : "Save this look")
                        .accessibilityIdentifier("generative.saveSelection")
                    }
                }
                if [.shortlist, .swap].contains(spec.interaction) { thumbnailChoices }
            }
        case .directions, .multiMerchant:
            GenerativeDiscoveryComposition(spec: spec, merchants: merchants, session: session, size: size)
        case .fisheye:
            GenerativeFisheyeComposition(spec: spec, products: products, session: session,
                size: size, isActive: isActive, onOpen: { detailProduct = $0 })
        }
    }

    @ViewBuilder
    private func relationship(size: CGSize) -> some View {
        if anchor != nil, let selected {
            GenerativeOutfitComposition(
                selected: selected, products: visibleProducts, size: size,
                saved: current.savedSelectionIDs.contains(selected.id), enabled: current.interactionsEnabled,
                onSelect: { item in session.select(item, for: spec) },
                onSave: { perform { session.toggleSaved(selected, for: spec) } },
                onOpen: { detailProduct = $0 }
            )
        }
    }

    @ViewBuilder
    private func comparison(size: CGSize) -> some View {
        if selected != nil {
            let pair = session.comparisonPair(in: products, for: spec)
            GenerativeComparisonComposition(
                pair: pair, remaining: visibleProducts.filter { item in !pair.contains { $0.id == item.id } },
                selectedID: selected?.id, size: size, enabled: current.interactionsEnabled,
                onSelect: { item in perform { session.select(item, for: spec) } },
                onCompare: { item in perform { session.compare(item, in: products, for: spec) } }
            )
        } else {
            ContentUnavailableView("Shortlist cleared", systemImage: "checkmark", description: Text("Reset the shortlist to bring the chairs back."))
        }
    }

    private func merchant(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            HStack(spacing: GravitySpacing.space12) {
                if let merchant = products.first?.merchant {
                    MerchantAvatarView(merchant: merchant, size: 40)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(spec.groups.first?.title ?? "Selected books").font(GravityFont.semiBold.fixedFont(size: 17))
                    Text(spec.groups.first?.context ?? "Independent publishing.")
                        .font(GravityFont.regular.fixedFont(size: 13)).foregroundStyle(.secondary)
                }
            }
            GenerativeProductMedia(item: selected)
                .frame(height: max(size.height - 178, 100))
            identity(selected, showsMerchant: false)
            thumbnailChoices
        }
    }

    private func continuation(size: CGSize) -> some View {
        let mediaSide = min(size.width * 0.92, max(size.height - 80, 120))
        return VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GravitySpacing.space12) {
                    ForEach(visibleProducts) { item in
                        Button { session.select(item, for: spec) } label: {
                            // A square allocation preserves the entire catalog
                            // photograph, rather than letterboxing a wide strip.
                            GenerativeProductMedia(item: item, presentation: "comparison")
                                .frame(width: mediaSide, height: mediaSide)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Select \(item.product.title)")
                        .accessibilityAddTraits(selected?.id == item.id ? .isSelected : [])
                        .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.trailing, size.width - mediaSide, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: Binding<String?>(
                get: { selected?.id },
                set: { id in
                    if let item = visibleProducts.first(where: { $0.id == id }), item.id != selected?.id {
                        session.select(item, for: spec)
                    }
                }
            ), anchor: .leading)
            .frame(height: mediaSide)
            .scrollDisabled(!current.interactionsEnabled)
            .disabled(!current.interactionsEnabled)
            .accessibilityIdentifier("generative.roomCarousel")
            identity(selected)
        }
    }

    private var thumbnailChoices: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GravitySpacing.space8) {
                    ForEach(visibleProducts) { item in
                        Button { perform { session.select(item, for: spec) } } label: {
                            GenerativeProductMedia(item: item)
                                .frame(width: 52, height: 58)
                                .overlay {
                                    RoundedRectangle(cornerRadius: GravityRadius.r16)
                                        .strokeBorder(selected?.id == item.id ? ink : .clear, lineWidth: 2)
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(!current.interactionsEnabled)
                        .accessibilityLabel("Select \(item.product.title)")
                        .accessibilityAddTraits(selected?.id == item.id ? .isSelected : [])
                        .id(item.id)
                    }
                }
            }
            .onChange(of: selected?.id) { _, id in
                if let id { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .frame(height: 58)
    }

    private func compactProduct(_ item: ResolvedStoryProduct, caption: String) -> some View {
        HStack(spacing: GravitySpacing.space12) {
            GenerativeProductMedia(item: item).frame(width: 64, height: 72)
            VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                Text(caption).font(GravityFont.medium.fixedFont(size: 12)).foregroundStyle(.secondary)
                Text(item.product.title).font(GravityFont.semiBold.fixedFont(size: 14)).lineLimit(2)
            }
        }
    }

    private func identity(_ item: ResolvedStoryProduct?, showsMerchant: Bool = true, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space4) {
            if let item {
                Text(item.product.title)
                    .font(GravityFont.semiBold.fixedFont(size: compact ? 13 : 15))
                    .lineLimit(compact ? 4 : 3)
                    .fixedSize(horizontal: false, vertical: true)
                if showsMerchant {
                    Text(item.merchant.displayName)
                        .font(GravityFont.regular.fixedFont(size: 12))
                        .foregroundStyle(ink.opacity(0.65))
                }
                Text(GenerativeFeedStyle.price(item.product))
                    .font(GravityFont.medium.fixedFont(size: 14))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var controls: some View {
        if session.composition(for: spec) == .fisheye {
            HStack {
                Text("\(products.count) items").font(GravityFont.medium.fixedFont(size: 13)).foregroundStyle(.secondary)
                Spacer()
                Button {
                    session.setCanvasExploring(!current.canvasIsExploring, for: spec)
                } label: {
                    Text(current.canvasIsExploring ? "Done exploring" : "Explore library")
                        .font(GravityFont.semiBold.fixedFont(size: 14))
                        .padding(.horizontal, GravitySpacing.space20).frame(minHeight: 48)
                        .foregroundStyle(.black).background(.white, in: Capsule())
                }
                .disabled(!current.interactionsEnabled || !isActive)
                .accessibilityIdentifier("generative.primaryAction")
            }
        } else if spec.interaction == .shortlist {
            shortlistControls
        } else if [.steer, .selectMerchant].contains(spec.interaction), activeGroup == nil {
            Text(spec.interaction == .steer ? "Choose how you’ll use it" : "Select a shop to see more")
                .font(GravityFont.medium.fixedFont(size: 13))
                .foregroundStyle(ink.opacity(0.65))
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        } else {
            actionControls
        }
    }

    private var shortlistControls: some View {
        HStack(spacing: GravitySpacing.space12) {
            VStack(alignment: .leading, spacing: 0) {
                Menu {
                    if let selected {
                        Button("Remove \(selected.product.title) from shortlist", role: .destructive) {
                            perform { session.remove(selected, for: spec) }
                        }
                    }
                    Button("Reset shortlist") { session.restoreShortlist(spec) }
                } label: {
                    HStack(spacing: GravitySpacing.space8) {
                        Text(progressLabel).font(GravityFont.medium.fixedFont(size: 12))
                        Image(systemName: "ellipsis").font(.system(size: 14))
                    }
                    .frame(minHeight: 44)
                }
                .accessibilityLabel("Shortlist options")
                .accessibilityValue(progressLabel)
                if !current.removedIDs.isEmpty {
                    Button("Reset shortlist") { session.restoreShortlist(spec) }
                        .font(GravityFont.medium.fixedFont(size: 12)).frame(minHeight: 32)
                }
            }
            Spacer(minLength: 0)
            if let selected {
                let saved = current.savedSelectionIDs.contains(selected.id)
                Button { perform { session.toggleSaved(selected, for: spec) } } label: {
                    Image(systemName: saved ? "heart.fill" : "heart")
                        .font(.system(size: 20)).frame(width: 44, height: 48)
                }
                .accessibilityLabel(saved ? "Unsave this chair" : "Save this chair")
                .accessibilityIdentifier("generative.saveSelection")
            }
            Button {
                if let selected { detailProduct = selected }
                else { session.restoreShortlist(spec) }
            } label: {
                Text(selected == nil ? "Restore chairs" : "View chair")
                    .font(GravityFont.semiBold.fixedFont(size: 14))
                    .padding(.horizontal, GravitySpacing.space20).frame(minHeight: 48)
                    .foregroundStyle(.white).background(.black, in: Capsule())
            }
            .accessibilityIdentifier("generative.primaryAction")
        }
        .buttonStyle(.plain)
        .disabled(!current.interactionsEnabled)
    }

    private var actionControls: some View {
        HStack(spacing: GravitySpacing.space12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(progressLabel)
                    .font(GravityFont.medium.fixedFont(size: 13))
                    .foregroundStyle(ink.opacity(0.65))
                if spec.interaction == .swap, !current.savedSelectionIDs.isEmpty {
                    Button("Saved looks (\(current.savedSelectionIDs.count))") { showsSavedLooks = true }
                        .font(GravityFont.medium.fixedFont(size: 12)).frame(minHeight: 32)
                        .accessibilityIdentifier("generative.savedLooks")
                }
            }
            Spacer(minLength: 0)
            Button {
                perform {
                    switch spec.interaction {
                    case .swap: if let purchaseURL { openURL(purchaseURL) }
                    case .browse: advance()
                    case .shortlist: detailProduct = selected
                    case .selectForWorld: showsRoomPlan = true
                    case .steer, .selectMerchant:
                        if activeGroup != nil { session.clearGroup(spec) }
                        else if let first = spec.groups.first { session.choose(first, for: spec) }
                    }
                }
            } label: {
                Text(actionLabel)
                    .font(GravityFont.semiBold.fixedFont(size: 14))
                    .padding(.horizontal, GravitySpacing.space20)
                    .frame(minHeight: 48)
                    .foregroundStyle(spec.prefersDarkNavigationText ? Color.white : .black)
                    .background(ink, in: Capsule())
            }
            .disabled(!current.interactionsEnabled || (spec.interaction == .swap && purchaseURL == nil))
            .opacity(current.interactionsEnabled ? 1 : 0.45)
            .accessibilityIdentifier("generative.primaryAction")
            .accessibilityValue(spec.interaction == .swap ? purchaseURL?.absoluteString ?? "Purchase link unavailable" : "")
        }
    }

    private var progressLabel: String {
        if spec.interaction == .shortlist { return "\(visibleProducts.count) on your shortlist" }
        if spec.interaction == .steer { return activeGroup == nil ? "Choose a direction" : "\(products.count) matching options" }
        if spec.interaction == .selectMerchant { return activeGroup == nil ? "\(spec.groups.count) shops" : activeGroup?.title ?? "" }
        let index = products.firstIndex { $0.id == selected?.id } ?? 0
        return "\(index + 1) of \(products.count)"
    }
    private var actionLabel: String {
        switch spec.interaction {
        case .swap: "Buy pants"
        case .shortlist: visibleProducts.isEmpty ? "Restore chairs" : "View chair"
        case .browse: "Next item"
        case .selectForWorld: "Review room plan"
        case .steer: activeGroup == nil ? spec.groups.first?.title ?? "Choose" : "Change direction"
        case .selectMerchant: activeGroup == nil ? "Explore \(spec.groups.first?.title ?? "shops")" : "All shops"
        }
    }
    private func advance() {
        guard !visibleProducts.isEmpty else { return }
        let index = visibleProducts.firstIndex { $0.id == selected?.id } ?? 0
        session.select(visibleProducts[(index + 1) % visibleProducts.count], for: spec)
    }
    private func perform(_ action: () -> Void) {
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion || !isActive ? nil : SpringPreset.responsive, action)
    }

    private var roomPlan: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GravitySpacing.space24) {
                    Text("Your living room").font(GravityFont.expressiveSemiBold.fixedFont(size: 28))
                    Text("Your saved table and the chair you’re considering.")
                        .font(GravityFont.regular.fixedFont(size: 15)).foregroundStyle(.secondary)
                    if let anchor { compactProduct(anchor, caption: "Previously saved") }
                    GenerativeProductMedia(item: selected).frame(height: 260)
                    identity(selected)
                    Text("Choose a different chair")
                        .font(GravityFont.semiBold.fixedFont(size: 16))
                    thumbnailChoices
                    if session.designMode {
                        Text("Local state-continuity prototype, not a room rendering or the full World destination.")
                            .font(GravityFont.regular.fixedFont(size: 13)).foregroundStyle(.secondary)
                    }
                }
                .padding(GravitySpacing.space20)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsRoomPlan = false } } }
        }
        .presentationDetents([.large])
    }
}

/// Shop owns the mapping from semantic job to surface; the spec cannot supply
/// arbitrary colors, fonts, spacing, or animation curves.
enum GenerativeFeedStyle {
    static func surface(for spec: NextGenerationFeedCardSpec) -> Color {
        if let composition = NextGeneration20Catalog.definition(for: spec) { return composition.theme.surface }
        if let record = DossierReviewLibrary.record(for: spec) { return Color(hex: record.surface) }
        if spec.isQuietReview { return Color(hex: spec.job == .complete ? "#F5E9DA" : "#F7F6F2") }
        return switch spec.job {
        case .complete: Color(hex: "#F2F1ED")
        case .compare, .continueJourney: Color.white
        case .merchantDiscovery: Color(hex: "#20201E")
        case .continueWorld, .discoverMerchants: Color(hex: "#EFECE6")
        case .narrow: Color(hex: "#F2F1ED")
        }
    }
    static func price(_ product: SampleMerchant.Product) -> String {
        guard let value = Double(product.price) else { return product.price }
        return value.formatted(.currency(code: product.currencyCode))
    }
}

/// Bounded, fitted catalog image. Never replaces a failed product image with
/// unrelated merchant media. Bundled copies are keyed to exact canonical IDs.
struct GenerativeProductMedia: View {
    let item: ResolvedStoryProduct?
    var presentation: String? = nil
    var fillsFrame = false
    private var url: URL? {
        guard let item else { return nil }
        if let local = DossierReviewLibrary.url("dossier-product-\(item.product.id).jpg") { return local }
        if let local = Bundle.main.url(forResource: "quiet-product-\(item.merchant.id)-\(item.product.id)", withExtension: "jpg") { return local }
        if let local = NextGeneration20Catalog.asset("\(item.merchant.id)-\(item.product.id)-product")?.imageURL { return local }
        let name = "prototype-product-\(item.merchant.id)-\(item.product.id)"
        if let presentation, let local = Bundle.main.url(forResource: "\(name)-\(presentation)", withExtension: "jpg") { return local }
        let local = Bundle.main.url(forResource: name, withExtension: "jpg")
        return local ?? item.product.imageURL.flatMap(URL.init(string:))
    }
    var body: some View {
        GeometryReader { proxy in
            Color.white.overlay {
                if let url {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: fillsFrame ? .fill : .fit)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        case .failure:
                            Image(systemName: "photo").foregroundStyle(.gray)
                                .accessibilityLabel("Product image unavailable")
                        default: ProgressView().tint(.gray)
                        }
                    }
                    .id(url)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16))
        }
        .accessibilityHidden(true)
    }
}
