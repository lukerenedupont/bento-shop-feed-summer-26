import SwiftUI

/// Local continuation of the same card state. The existing Spatial destination
/// remains a one-object preview; no generated still is labelled as a changed room.
struct DossierSelectionReview: View {
    let record: DossierReviewRecord
    let spec: NextGenerationFeedCardSpec
    let merchants: [SampleMerchant]
    let session: GenerativeFeedPrototypeSession
    @Environment(\.dismiss) private var dismiss
    @State private var detail: ResolvedStoryProduct?
    @State private var spatialDetail: ResolvedStoryProduct?
    @State private var showsSpatial = false
    @State private var world: WorldSession?
    private var items: [ResolvedStoryProduct] {
        record.visibleObjects.compactMap { object in
            if let slot = spec.groups.first(where: { $0.id == object.id }) {
                return session.roomProduct(slot: slot, for: spec, merchants: merchants)
            }
            return NextGenerationFeedCardSpec.resolve(object.reference, in: merchants)
        }
    }
    private var planSaved: Bool { session.state(for: spec).savedDossierPlans.contains(items.map(\.id)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(Array(record.visibleObjects.enumerated()), id: \.element.id) { index, object in
                        if items.indices.contains(index) {
                            let item = items[index]
                            HStack(spacing: 16) {
                                Button { detail = item } label: {
                                    GenerativeProductMedia(item: item).frame(width: 125, height: 145)
                                }.buttonStyle(.plain).accessibilityLabel("View \(item.product.title)")
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(item.merchant.displayName).font(GravityFont.medium.fixedFont(size: 12)).foregroundStyle(.secondary)
                                    Text(item.product.title).font(GravityFont.semiBold.fixedFont(size: 15))
                                    if let slot = spec.groups.first(where: { $0.id == object.id }), slot.products.count > 1 {
                                        Menu("Swap") {
                                            ForEach(slot.products, id: \.self) { ref in
                                                if let candidate = NextGenerationFeedCardSpec.resolve(ref, in: merchants) {
                                                    Button(candidate.product.title) {
                                                        session.selectRoomProduct(candidate, slot: slot, for: spec)
                                                        session.setDossierObjectsVisible(true, for: spec)
                                                    }
                                                }
                                            }
                                        }.frame(minHeight: 44)
                                    } else {
                                        Button("Product details") { detail = item }.font(GravityFont.medium.fixedFont(size: 13)).frame(minHeight: 44)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    Button(planSaved ? "Saved for this session" : record.family == "gift" ? "Save for Leon" : "Save this composition") {
                        session.saveDossierPlan(items, for: spec)
                    }
                    .buttonStyle(.borderedProminent).tint(.black).disabled(planSaved)
                    .accessibilityIdentifier("dossier.savePlan")
                    if record.family == "room" {
                        Button("See a piece in your room") {
                            let definition = WorldDefinition(id: "review-\(record.key)", title: "Room study", purpose: .intent,
                                subject: "Review room", primaryExperience: .spatial, availableExperiences: [.spatial], lifetime: .session, paths: [])
                            let spatial = WorldSession(definition: definition)
                            if let selected = items.first { spatial.send(.selectProduct(selected.id)) }
                            for (index, item) in items.enumerated() {
                                spatial.send(.setFact(.init(key: "room-item-\(index)", value: item.id, source: .stated, scope: .local)))
                            }
                            world = spatial; showsSpatial = true
                        }.buttonStyle(.bordered).tint(.black)
                    }
                    Text("Original styling study")
                        .font(GravityFont.semiBold.fixedFont(size: 16))
                    DossierFileImage(url: record.imageURL(record.family == "gift" ? "gift" : "pairSquare"))
                        .frame(height: 280)
                    Text("Generated inspiration, not a rendering of the selection above. Product details use the source photographs. Prices, sizes and compatibility should be checked with the merchant.")
                        .font(GravityFont.regular.fixedFont(size: 13)).foregroundStyle(.secondary)
                }.padding(20)
            }
            .navigationTitle(record.family == "gift" ? "For Leon" : record.family == "room" ? "Your room study" : "Your composition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $detail) { GenerativeProductReview(item: $0) }
            .fullScreenCover(isPresented: $showsSpatial) {
                if let world {
                    SpatialARWorldDestination(session: world, products: items,
                        onClose: { showsSpatial = false }, onOpenProduct: { spatialDetail = $0 })
                        .sheet(item: $spatialDetail) { GenerativeProductReview(item: $0) }
                }
            }
        }
        .environment(\.colorScheme, .light)
        .presentationDetents([.large])
    }
}
