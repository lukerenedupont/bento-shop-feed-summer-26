import Foundation

@MainActor
extension GenerativeFeedPrototypeSession {
    func compositionDefinition(for spec: NextGenerationFeedCardSpec) -> GeneratedComposition? {
        DemoJourneyCatalog.continuation(for: spec.signal.id, memory: journeyMemory)
            ?? NextGeneration20Catalog.definition(for: spec)
    }
    func openLaunchJourneyIfRequested() {
        guard !didOpenLaunchJourney else { return }
        guard let source = DemoJourneyCatalog.launchSignalID else { return }
        didOpenLaunchJourney = true
        requestJourney(source)
    }
    func requestJourney(_ source: String) {
        guard DemoJourneyCatalog.base(source) != nil else { return }
        setSignalEnabled(true, id: source)
        requestedJourneySignalID = source
    }
    func keepJourneySelection(_ items: [ResolvedStoryProduct], for spec: NextGenerationFeedCardSpec) {
        guard spec.signal.id.hasPrefix("ng20-"), state(for: spec).interactionsEnabled, !items.isEmpty,
              items.allSatisfy({ item in spec.productReferences.contains { $0.merchantID == item.merchant.id && $0.productID == item.product.id } }) else { return }
        var checkpoint = state(for: spec)
        if items.count == 1 { checkpoint.selectedID = items[0].id }
        guard let data = try? JSONEncoder().encode(checkpoint) else { return }
        let source = DemoJourneyCatalog.sourceID(spec.signal.id)
        let scope: FeedJourneyMemory.Scope = source == DemoJourneyCatalog.footwear ? .footwear
            : [DemoJourneyCatalog.room, DemoJourneyCatalog.chairs].contains(source) ? .room
            : source == DemoJourneyCatalog.books ? .books : .standalone
        let linkedIDs = spec.signal.id == DemoJourneyCatalog.footwearLook ? ["next-gen-\(DemoJourneyCatalog.footwear)"]
            : spec.signal.id == DemoJourneyCatalog.roomComparison ? ["next-gen-\(DemoJourneyCatalog.room)"] : []
        journeyMemory.keep(source: source, stateID: spec.id,
            title: items.count == 1 ? items[0].product.title : spec.title,
            products: items.map { .init(merchantID: $0.merchant.id, productID: $0.product.id) }, checkpoint: data,
            scope: scope, linkedStateIDs: linkedIDs)
        persistJourneyMemory()
    }
    func canResumeJourney(_ selection: FeedJourneyMemory.KeptSelection) -> Bool {
        var probe = journeyMemory
        probe.continuation = selection.continuation
        guard let definition = DemoJourneyCatalog.continuation(for: selection.sourceSignalID, memory: probe)
                ?? DemoJourneyCatalog.base(selection.sourceSignalID),
              selection.stateID == "next-gen-\(definition.id)",
              (try? JSONDecoder().decode(CardState.self, from: selection.checkpoint)) != nil else { return false }
        return selection.products.allSatisfy { product in
            definition.references.contains { $0.merchantID == product.merchantID && $0.productID == product.productID }
        }
    }
    func resumeJourneySelection(_ selection: FeedJourneyMemory.KeptSelection) {
        guard canResumeJourney(selection), let kept = journeyMemory.resume(selection.id) else { return }
        restoreJourneyState(kept.checkpoint, id: kept.stateID)
        for (id, checkpoint) in kept.linkedCheckpoints { restoreJourneyState(checkpoint, id: id) }
        persistJourneyMemory()
        showsKeptSelections = false
        requestJourney(kept.sourceSignalID)
    }
    func removeJourneySelection(_ selection: FeedJourneyMemory.KeptSelection) {
        journeyMemory.remove(selection.id)
        persistJourneyMemory()
    }
    func hasKept(_ items: [ResolvedStoryProduct], for spec: NextGenerationFeedCardSpec) -> Bool {
        let refs = items.map { FeedJourneyMemory.Product(merchantID: $0.merchant.id, productID: $0.product.id) }
        return journeyMemory.kept.contains { $0.sourceSignalID == DemoJourneyCatalog.sourceID(spec.signal.id) && $0.products == refs }
    }
    func buildAroundSelectedShoe(_ context: CompositionContext) {
        guard context.definition.id == DemoJourneyCatalog.footwear, state(for: context.spec).interactionsEnabled,
              activeGroup(for: context.spec) != nil, let selected = context.selected else { return }
        journeyMemory.continuation.footwearAnchor = .init(merchantID: selected.merchant.id, productID: selected.product.id)
        guard let definition = DemoJourneyCatalog.continuation(for: DemoJourneyCatalog.footwear, memory: journeyMemory),
              let spec = DemoJourneyCatalog.specification(definition, source: context.spec, merchants: context.merchants) else { return }
        select(selected, for: spec)
        persistJourneyMemory()
        requestJourney(DemoJourneyCatalog.footwear)
    }
    func returnToShoeSelection() {
        journeyMemory.continuation.footwearAnchor = nil
        persistJourneyMemory()
        requestJourney(DemoJourneyCatalog.footwear)
    }
    func compareRoomChairs(_ context: CompositionContext) {
        guard context.definition.id == DemoJourneyCatalog.room, state(for: context.spec).interactionsEnabled, let chosen = context.product("one") else { return }
        journeyMemory.continuation.comparingRoom = true
        guard let definition = DemoJourneyCatalog.continuation(for: DemoJourneyCatalog.chairs, memory: journeyMemory),
              let spec = DemoJourneyCatalog.specification(definition, source: context.spec, merchants: context.merchants) else { return }
        var checkpoint = state(for: spec)
        let alternatives = spec.resolvedProducts(from: context.merchants).filter { $0.id != chosen.id }
        checkpoint.comparisonIDs = [chosen.id] + alternatives.prefix(1).map(\.id)
        checkpoint.selectedID = chosen.id
        checkpoint.comparisonRevealed = false
        if let data = try? JSONEncoder().encode(checkpoint) { restoreJourneyState(data, id: spec.id) }
        persistJourneyMemory()
        requestJourney(DemoJourneyCatalog.chairs)
    }
    func useChairInRoom(_ item: ResolvedStoryProduct, context: CompositionContext) {
        guard context.definition.id == DemoJourneyCatalog.roomComparison, state(for: context.spec).interactionsEnabled,
              let room = NextGenerationFeedCardCatalog.cards(signals: NextGeneration20Catalog.signals, merchants: context.merchants)
                .first(where: { $0.signal.id == DemoJourneyCatalog.room }),
              let slot = room.groups.first(where: { $0.id == "slot.one" }),
              slot.products.contains(where: { $0.merchantID == item.merchant.id && $0.productID == item.product.id }) else { return }
        selectRoomProduct(item, slot: slot, for: room)
        persistJourneyMemory()
        requestJourney(DemoJourneyCatalog.room)
    }
}
