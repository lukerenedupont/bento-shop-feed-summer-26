import SwiftUI

/// A single native host for arbitrary validated composition trees. The model
/// specifies relationships and structure; this host owns Shop chrome and actions.
struct GeneratedCompositionCard: View {
    let definition: GeneratedComposition
    let spec: NextGenerationFeedCardSpec
    let merchants: [SampleMerchant]
    let session: GenerativeFeedPrototypeSession
    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    let isActive: Bool
    var visibleContentBottom: CGFloat? = nil
    let onInspect: () -> Void
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var detail: ResolvedStoryProduct?
    @State private var showsReview = false

    private var context: CompositionContext { .init(definition: definition, spec: spec, merchants: merchants, session: session) }
    private var ink: Color { definition.usesDarkInk ? .black : .white }
    private var usesEditorialAction: Bool { ["editorial", "study"].contains(definition.root.mode ?? "") }
    private var title: String { session.activeGroup(for: spec)?.title ?? definition.title }
    private var state: GenerativeFeedPrototypeSession.CardState { session.state(for: spec) }
    private var footerCardSide: CGFloat { min(144, (width - 52) / 2.4) }
    private var hasSavedPlan: Bool { state.savedDossierPlans.contains(context.reviewItems.map(\.id)) }
    private var actionTitle: String {
        if definition.action == .canvas { return state.canvasIsExploring ? "Done exploring" : definition.cta }
        if definition.action == .compare { return state.comparisonRevealed ? "Review the pair" : state.comparisonIDs.count == 2 ? definition.cta : "Select two to compare" }
        if definition.action == .save && hasSavedPlan { return "Saved" }
        return definition.cta
    }

    var body: some View {
        ZStack {
            definition.theme.surface
            if let asset = NextGeneration20Catalog.asset(definition.background) {
                CompositionMedia(asset: asset, active: isActive, fills: true).frame(width: width, height: height)
                LinearGradient(colors: [.black.opacity(0.34), .clear, .black.opacity(0.50)], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
            }
            VStack(spacing: 16) {
                GeometryReader { proxy in
                    CompositionNodeView(node: definition.root(revision: state.generation), context: context,
                        size: proxy.size, active: isActive, onDetail: { detail = $0 })
                }
                VStack(alignment: .leading, spacing: 12) {
                    if definition.action != .compare {
                        Group {
                            if definition.root.mode == "study" {
                                Text(state.hasInteracted ? "Styling study · image unchanged" : "Styling study")
                                    .font(GravityFont.medium.fixedFont(size: 12))
                                    .foregroundStyle(ink.opacity(0.85))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else if let selected = context.selected, state.hasInteracted {
                                HStack(spacing: 8) {
                                    Text(selected.product.title).lineLimit(1)
                                    Spacer(minLength: 0)
                                    if Double(selected.product.price) != nil { Text(GenerativeFeedStyle.price(selected.product)) }
                                }
                                .font(GravityFont.medium.fixedFont(size: 12))
                                .foregroundStyle(ink.opacity(0.8))
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("ng20.focusedProduct")
                            } else { Color.clear }
                        }
                        // Reserve the information slot so a focus/swap never
                        // resizes or shifts the anchor and surrounding objects.
                        .frame(height: 24)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text(title).feedCardTitleStyle().lineLimit(2)
                            .accessibilityIdentifier("ng20.heading")
                        Spacer(minLength: 0)
                        Menu {
                            Button("Inspect specification", action: onInspect)
                            if !definition.alternates.isEmpty {
                                Button("Try another composition") { session.regenerate(spec) }
                            }
                            Button("Reset this card") { session.reset(spec) }
                        } label: {
                            Image(systemName: "ellipsis").font(.system(size: 22, weight: .medium)).frame(width: 44, height: 44)
                        }.accessibilityLabel("Card options")
                    }.foregroundStyle(ink)
                    if !definition.footer.isEmpty {
                        CompositionProductRail(roles: definition.footer, context: context, height: footerCardSide, onDetail: { detail = $0 })
                            .frame(height: footerCardSide)
                    }
                    Button(action: primaryAction) {
                        if usesEditorialAction {
                            HStack {
                                Text(actionTitle).font(GravityFont.semiBold.fixedFont(size: 16))
                                Spacer()
                                Image(systemName: "arrow.right").font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundStyle(ink)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .contentShape(Rectangle())
                        } else {
                            Text(actionTitle).font(GravityFont.semiBold.fixedFont(size: 16))
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .foregroundStyle(definition.background == nil && !definition.theme.usesDarkInk ? .black : .white)
                                .background(definition.background == nil && !definition.theme.usesDarkInk ? Color.white : .black, in: Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!state.interactionsEnabled || (definition.action == .compare && state.comparisonIDs.count != 2))
                    .accessibilityIdentifier("ng20.primary")
                }
                .visualEffect { content, proxy in
                    content.offset(y: visibleContentBottom.map { -max(0, proxy.frame(in: .scrollView(axis: .vertical)).maxY - $0) } ?? 0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, topPadding)
            .padding(.bottom, 24)
        }
        .frame(width: width, height: height).clipped()
        .environment(\.colorScheme, definition.usesDarkInk ? .light : .dark)
        .sheet(item: $detail) { GenerativeProductReview(item: $0) }
        .sheet(isPresented: $showsReview) { CompositionSelectionReview(context: context) }
        .onChange(of: isActive) { _, active in if !active { session.setCanvasExploring(false, for: spec) } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ng20.card.\(definition.id)")
    }

    private func primaryAction() {
        switch definition.action {
        case .detail: detail = context.selected
        case .merchant:
            if let item = context.selected { coordinator.pushRoute(.store(merchantId: item.merchant.id)) }
        case .save: session.saveDossierPlan(context.reviewItems, for: spec)
        case .canvas: session.setCanvasExploring(!state.canvasIsExploring, for: spec)
        case .compare:
            if state.comparisonRevealed { showsReview = true }
            else { session.revealReviewComparison(true, for: spec) }
        case .review: showsReview = true
        }
    }
}

@MainActor
struct CompositionContext {
    let definition: GeneratedComposition
    let spec: NextGenerationFeedCardSpec
    let merchants: [SampleMerchant]
    let session: GenerativeFeedPrototypeSession
    var state: GenerativeFeedPrototypeSession.CardState { session.state(for: spec) }
    var ink: Color { definition.usesDarkInk ? .black : .white }
    var visibleRoles: [String] {
        guard let group = session.activeGroup(for: spec) else { return definition.order }
        return definition.order.filter { role in definition.entities[role].map { group.products.contains($0.reference) } ?? false }
    }
    var selected: ResolvedStoryProduct? {
        session.selected(in: visibleRoles.compactMap { directProduct($0) }, for: spec)
    }
    func directProduct(_ role: String) -> ResolvedStoryProduct? {
        definition.entities[role].flatMap { NextGenerationFeedCardSpec.resolve($0.reference, in: merchants) }
    }
    func product(_ role: String) -> ResolvedStoryProduct? {
        if role == "$selected" { return selected }
        if let group = spec.groups.first(where: { $0.id == "slot.\(role)" }) {
            return session.roomProduct(slot: group, for: spec, merchants: merchants)
        }
        return directProduct(role)
    }
    func role(for item: ResolvedStoryProduct) -> String? {
        definition.order.first { definition.entities[$0]?.reference == .init(merchantID: item.merchant.id, productID: item.product.id) }
    }
    func entity(_ role: String) -> CompositionEntity? {
        guard let item = product(role), let key = self.role(for: item) else { return nil }
        return definition.entities[key]
    }
    func expandedRoles(_ roles: [String]) -> [String] {
        roles.flatMap { $0 == "$group" ? visibleRoles : [$0] }
    }
    var reviewItems: [ResolvedStoryProduct] {
        if definition.action == .compare {
            return definition.order.compactMap(directProduct).filter { state.comparisonIDs.contains($0.id) }
        }
        if session.activeGroup(for: spec) != nil { return visibleRoles.compactMap(directProduct) }
        var roles = definition.footer
        func walk(_ node: CompositionNode) {
            if let role = node.role, role != "$selected" { roles.append(role) }
            roles += (node.roles ?? []).filter { !$0.hasPrefix("$") }
            (node.children ?? []).forEach(walk)
        }
        walk(definition.root)
        if roles.isEmpty { roles = definition.order }
        var seen = Set<String>()
        return roles.compactMap(product).filter { seen.insert($0.id).inserted }
    }
}

struct CompositionMedia: View {
    let asset: CompositionAsset
    let active: Bool
    var fills = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    var body: some View {
        ZStack {
            DossierFileImage(url: asset.imageURL, fills: fills)
            if active && !reduceMotion && phase == .active, let url = asset.videoURL {
                LoopingVideoPlayer(url: url, playbackEnabled: true, playbackGroupID: "ng20-\(url.lastPathComponent)",
                    videoGravity: fills ? .resizeAspectFill : .resizeAspect).id(url)
            }
        }.clipped().accessibilityHidden(true)
    }
}

struct CompositionProductRail: View {
    let roles: [String]
    let context: CompositionContext
    let height: CGFloat
    let onDetail: (ResolvedStoryProduct) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(context.expandedRoles(roles), id: \.self) { role in
                    if let item = context.product(role) {
                        Button { onDetail(item) } label: {
                            CompositionProductImage(role: role, context: context, mode: "tile")
                                .frame(width: height, height: height)
                        }.buttonStyle(.plain).accessibilityLabel("View \(item.product.title)")
                        .contextMenu {
                            Button("Save for later") { context.session.toggleSaved(item, for: context.spec) }
                            if let slot = context.spec.groups.first(where: { $0.id == "slot.\(role)" }) {
                                Menu("Swap") {
                                    ForEach(slot.products, id: \.self) { reference in
                                        if let alternative = NextGenerationFeedCardSpec.resolve(reference, in: context.merchants) {
                                            Button(alternative.product.title) {
                                                context.session.selectRoomProduct(alternative, slot: slot, for: context.spec)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }.scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .frame(height: height)
    }
}

struct CompositionProductImage: View {
    let role: String
    let context: CompositionContext
    var mode = "object"
    var body: some View {
        GeometryReader { proxy in
            if let item = context.product(role), let entity = context.entity(role),
               let asset = NextGeneration20Catalog.asset(entity.art) {
                if mode == "tile" {
                    CompositionSquareProductCard(url: asset.imageURL,
                        price: Double(item.product.price) == nil ? nil : GenerativeFeedStyle.price(item.product))
                        .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                } else {
                    ZStack {
                        if !asset.image.hasSuffix(".png") { Color.white }
                        DossierFileImage(url: asset.imageURL).padding(10)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            } else {
                Image(systemName: "photo").foregroundStyle(context.ink.opacity(0.4)).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.accessibilityHidden(true)
    }
}

/// Give the native square card square media, so tall garments and wide shoes
/// are fitted rather than cropped by ProductCard's standard fill behavior.
private struct CompositionSquareProductCard: View {
    let url: URL?
    let price: String?
    @State private var image: UIImage?
    var body: some View {
        ProductCard(image: image.map { Image(uiImage: $0) }, priceBadge: price, showFavoriteButton: false)
            .task(id: url) {
                guard let url else { return }
                _ = await ImageURLCache.shared.loadImage(for: url)
                guard !Task.isCancelled, let source = ImageURLCache.shared.image(for: url) else { return }
                let side: CGFloat = 360
                image = UIGraphicsImageRenderer(size: .init(width: side, height: side)).image { output in
                    UIColor.white.setFill(); output.fill(CGRect(x: 0, y: 0, width: side, height: side))
                    let scale = (side - 24) / max(source.size.width, source.size.height)
                    let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
                    source.draw(in: CGRect(x: (side-size.width)/2, y: (side-size.height)/2, width: size.width, height: size.height))
                }
            }
    }
}

struct CompositionSelectionReview: View {
    let context: CompositionContext
    @Environment(\.dismiss) private var dismiss
    @State private var detail: ResolvedStoryProduct?
    @State private var spatialDetail: ResolvedStoryProduct?
    @State private var spatialSession: WorldSession?
    @State private var showsSpatial = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(context.reviewItems) { item in
                        Button { detail = item } label: {
                            HStack(spacing: 16) {
                                GenerativeProductMedia(item: item).frame(width: 115, height: 130)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.merchant.displayName).font(.caption).foregroundStyle(.secondary)
                                    Text(item.product.title).font(GravityFont.semiBold.fixedFont(size: 15))
                                    if Double(item.product.price) != nil { Text(GenerativeFeedStyle.price(item.product)).font(.subheadline) }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.multilineTextAlignment(.leading)
                        }.buttonStyle(.plain)
                    }
                    Button("Save this selection") { context.session.saveDossierPlan(context.reviewItems, for: context.spec) }
                        .buttonStyle(.borderedProminent).tint(.black)
                    if !context.state.savedDossierPlans.isEmpty { Text("Saved for this session").font(.footnote).foregroundStyle(.secondary) }
                    if context.definition.destination == "spatial" {
                        Button("See a piece in your room") {
                            let definition = WorldDefinition(id: context.definition.id, title: context.definition.title,
                                purpose: .intent, subject: "Review room", primaryExperience: .spatial,
                                availableExperiences: [.spatial], lifetime: .session, paths: [])
                            let world = WorldSession(definition: definition)
                            if let item = context.reviewItems.first { world.send(.selectProduct(item.id)) }
                            for (index, item) in context.reviewItems.enumerated() {
                                world.send(.setFact(.init(key: "room-piece-\(index)", value: item.id, source: .stated, scope: .local)))
                            }
                            spatialSession = world; showsSpatial = true
                        }.buttonStyle(.bordered).tint(.black)
                        Text("Spatial preview: one selected piece, not a verified fit or a render of the whole arrangement.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Text("Generated scenes are styling inspiration, not exact renders of this selection. Check price, size and compatibility with the merchant.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(20)
            }
            .navigationTitle(context.definition.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $detail) { GenerativeProductReview(item: $0) }
            .fullScreenCover(isPresented: $showsSpatial) {
                if let spatialSession {
                    SpatialARWorldDestination(session: spatialSession, products: context.reviewItems,
                        onClose: { showsSpatial = false }, onOpenProduct: { spatialDetail = $0 })
                        .sheet(item: $spatialDetail) { GenerativeProductReview(item: $0) }
                }
            }
        }.environment(\.colorScheme, .light).presentationDetents([.large])
    }
}
