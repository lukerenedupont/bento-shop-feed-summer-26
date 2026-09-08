import SwiftUI

/// A narrow state-preserving review handoff, not a replacement for the Worlds.
/// Reuses the existing Canvas/Spatial destinations when the job needs them.
struct QuietShoppingJourneyPrototype: View {
    let spec: NextGenerationFeedCardSpec
    let merchants: [SampleMerchant]
    let session: GenerativeFeedPrototypeSession
    @Environment(\.dismiss) private var dismiss
    @State private var detail: ResolvedStoryProduct?
    @State private var showsSpatial = false
    @State private var spatialDetail: ResolvedStoryProduct?
    @State private var world: WorldSession

    init(spec: NextGenerationFeedCardSpec, merchants: [SampleMerchant], session: GenerativeFeedPrototypeSession) {
        self.spec = spec; self.merchants = merchants; self.session = session
        let form: WorldExperienceForm = spec.job == .narrow ? .canvas : .spatial
        let definition = WorldDefinition(id: spec.signal.worldID ?? spec.id, title: spec.title,
            purpose: .intent, subject: "Review shopper", primaryExperience: form,
            availableExperiences: [form], lifetime: .session, paths: [])
        var context = WorldContext()
        if let group = session.activeGroup(for: spec) {
            context.set(.init(key: "direction", value: group.title, source: .stated, scope: .local))
        }
        let destination = WorldSession(definition: definition, context: context)
        if let selected = session.selected(in: session.products(for: spec, merchants: merchants), for: spec) {
            destination.send(.selectProduct(selected.id))
        }
        _world = State(initialValue: destination)
    }

    private var state: GenerativeFeedPrototypeSession.CardState { session.state(for: spec) }
    private var products: [ResolvedStoryProduct] {
        session.products(for: spec, merchants: merchants).filter { !state.removedIDs.contains($0.id) }
    }
    private var anchor: ResolvedStoryProduct? {
        spec.anchor.flatMap { NextGenerationFeedCardSpec.resolve($0, in: merchants) }
    }
    private var selected: ResolvedStoryProduct? { session.selected(in: products, for: spec) }
    private var roomProducts: [ResolvedStoryProduct] {
        [anchor].compactMap { $0 } + spec.groups.compactMap { session.roomProduct(slot: $0, for: spec, merchants: merchants) }
    }

    var body: some View {
        Group {
            if spec.job == .narrow {
                CanvasAgentWorldDestination(session: world, products: products, onClose: { dismiss() }, onOpenProduct: { detail = $0 })
                    .onDisappear { returnCanvasState() }
            } else {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if spec.job == .complete { outfit }
                            else if spec.job == .continueWorld { room }
                            else { shortlist }
                        }.padding(20)
                    }
                    .background(Color(hex: "#F7F6F2"))
                    .navigationTitle(spec.job == .complete ? "Your look" : spec.job == .continueWorld ? "Your room" : "Your shortlist")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                    .fullScreenCover(isPresented: $showsSpatial) {
                        SpatialARWorldDestination(session: world, products: roomProducts,
                            onClose: { showsSpatial = false }, onOpenProduct: { spatialDetail = $0 })
                            .sheet(item: $spatialDetail) { GenerativeProductReview(item: $0) }
                    }
                }
            }
        }
        .sheet(item: $detail) { GenerativeProductReview(item: $0) }
        .environment(\.colorScheme, .light)
        .presentationDetents([.large])
        .accessibilityIdentifier("quiet.journey")
    }

    private var outfit: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                if let anchor { product(anchor) }
                if let selected { product(selected) }
            }
            if let selected {
                Button(state.savedSelectionIDs.contains(selected.id) ? "Remove saved look" : "Save look") {
                    session.toggleSaved(selected, for: spec)
                }
                .buttonStyle(.borderedProminent).tint(.black)
                .accessibilityIdentifier("quiet.saveLook")
            }
            Text("Try another pair").font(GravityFont.semiBold.fixedFont(size: 16))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(products) { item in
                        Button { session.select(item, for: spec) } label: {
                            QuietProductImage(item: item).frame(width: 100, height: 140)
                                .overlay(alignment: .bottom) {
                                    if selected?.id == item.id { Capsule().fill(.black).frame(width: 24, height: 3) }
                                }
                        }.buttonStyle(.plain).accessibilityLabel("Wear \(item.product.title)")
                    }
                }
            }
            Divider()
            Text("Styling reference").font(GravityFont.semiBold.fixedFont(size: 16))
            QuietLocalImage(name: "quiet-dossier-look0").frame(height: 370)
            Text("AI-generated Dossier image. Styling inspiration, not a rendering of your selected look or of you.")
                .font(GravityFont.regular.fixedFont(size: 12)).foregroundStyle(.secondary)
        }
    }

    private var room: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let anchor { product(anchor) }
            ForEach(spec.groups) { slot in
                if let item = session.roomProduct(slot: slot, for: spec, merchants: merchants) {
                    HStack(spacing: 16) {
                        QuietProductImage(item: item).frame(width: 120, height: 130)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(slot.title).font(GravityFont.medium.fixedFont(size: 12)).foregroundStyle(.secondary)
                            Text(item.product.title).font(GravityFont.semiBold.fixedFont(size: 15))
                            Text(GenerativeFeedStyle.price(item.product)).font(GravityFont.regular.fixedFont(size: 14))
                            Menu("Swap") {
                                ForEach(slot.products, id: \.self) { reference in
                                    if let alternative = NextGenerationFeedCardSpec.resolve(reference, in: merchants) {
                                        Button(alternative.product.title) { session.selectRoomProduct(alternative, slot: slot, for: spec) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Button("See in room") {
                if let selected { world.send(.selectProduct(selected.id)) }
                for slot in spec.groups {
                    if let item = session.roomProduct(slot: slot, for: spec, merchants: merchants) {
                        world.send(.setFact(.init(key: "room-\(slot.id)", value: item.id, source: .stated, scope: .local)))
                    }
                }
                showsSpatial = true
            }
            .buttonStyle(.borderedProminent).tint(.black)
            Text("Composition preview. The spatial prototype previews one selected product; it does not verify dimensions or place the full arrangement.")
                .font(GravityFont.regular.fixedFont(size: 12)).foregroundStyle(.secondary)
        }
    }

    private var shortlist: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(products.filter { state.comparisonIDs.contains($0.id) }) { item in
                product(item)
                Button(state.savedSelectionIDs.contains(item.id) ? "Remove saved sofa" : "Save sofa") {
                    session.toggleSaved(item, for: spec)
                }.buttonStyle(.bordered).tint(.black)
            }
        }
    }

    private func product(_ item: ResolvedStoryProduct) -> some View {
        Button { detail = item } label: {
            VStack(alignment: .leading, spacing: 10) {
                QuietProductImage(item: item).frame(height: 200)
                Text(item.product.title).font(GravityFont.semiBold.fixedFont(size: 15))
                Text("\(item.merchant.displayName) · \(GenerativeFeedStyle.price(item.product))")
                    .font(GravityFont.regular.fixedFont(size: 13)).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(item.product.title)")
    }

    private func returnCanvasState() {
        let candidates = spec.resolvedProducts(from: merchants)
        for item in candidates where world.state.rejectedProductIDs.contains(item.id) { session.remove(item, for: spec) }
        if let selected = candidates.first(where: { $0.id == world.state.selectedProductID }) {
            session.select(selected, for: spec)
        }
    }
}
