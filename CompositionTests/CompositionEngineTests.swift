import XCTest
@testable import ShopFeedSummer26

final class CompositionEngineTests: XCTestCase {
    @MainActor private func fixture(_ id: String, persistence: UserDefaults? = nil) throws -> CompositionContext {
        let merchants = LocalMerchantService.mergeMerchants([
            DossierReviewLibrary.merchants, QuietFeedReviewCatalog.merchants, LocalMerchantService.loadMerchants()
        ])
        let definition = try XCTUnwrap(NextGeneration20Catalog.definitions.first { $0.id == id })
        let signal = try XCTUnwrap(NextGeneration20Catalog.signals.first { $0.id == id })
        let spec = try XCTUnwrap(NextGeneration20Catalog.card(signal: signal, merchants: merchants, generation: 0))
        return CompositionContext(definition: definition, spec: spec, merchants: merchants, session: GenerativeFeedPrototypeSession(persistence: persistence))
    }

    @MainActor func testLichenFeaturedChoicesKeepCanonicalCategoryGates() throws {
        let c = try fixture("ng20-lichen")
        XCTAssertEqual(c.definition.presentation.actionStyle, .link)
        let choice = try XCTUnwrap(c.definition.root.children?.last)
        XCTAssertEqual(choice.layout, .featured)
        XCTAssertEqual(choice.options?.map(\.id), ["storage", "seating", "objects"])
        for option in try XCTUnwrap(choice.options) {
            XCTAssertEqual(option.preview.kind, .media)
            XCTAssertEqual(option.preview.mediaFit, .cover)
            let group = try XCTUnwrap(c.spec.groups.first { $0.id == option.id })
            c.session.choose(group, for: c.spec)
            XCTAssertEqual(Set(c.visibleRoles), Set(option.roles))
            XCTAssertTrue(c.reviewItems.allSatisfy { $0.merchant.id == "lichen" })
            c.session.clearGroup(c.spec)
        }
        XCTAssertNil(c.session.activeGroup(for: c.spec))
    }

    @MainActor func testAllTwentySpecsResolveRealInventory() throws {
        XCTAssertEqual(NextGeneration20Catalog.definitions.count, 20)
        for definition in NextGeneration20Catalog.definitions {
            let context = try fixture(definition.id)
            XCTAssertEqual(context.spec.resolvedProducts(from: context.merchants).count, definition.references.count)
            if definition.action == .compare { XCTAssertTrue(context.reviewItems.isEmpty) }
            else { XCTAssertFalse(context.reviewItems.isEmpty, definition.id) }
        }
    }

    @MainActor func testDirectionIsAHardRelevanceGateAndSurvivesRecomposition() throws {
        let c = try fixture("ng20-salomon-directions")
        let trail = try XCTUnwrap(c.spec.groups.first { $0.id == "trail" })
        c.session.choose(trail, for: c.spec)
        let expected = Set(trail.products.compactMap { NextGenerationFeedCardSpec.resolve($0, in: c.merchants)?.id })
        XCTAssertEqual(Set(c.visibleRoles.compactMap(c.directProduct).map(\.id)), expected)
        let chosen = try XCTUnwrap(c.selected)
        c.session.select(chosen, for: c.spec)
        c.session.regenerate(c.spec)
        let rebuilt = c.session.resolve(c.spec, merchants: c.merchants)
        XCTAssertEqual(c.session.activeGroup(for: rebuilt)?.id, "trail")
        XCTAssertEqual(c.session.state(for: rebuilt).selectedID, chosen.id)
        XCTAssertNotEqual(c.definition.root(revision: 0).layout, c.definition.root(revision: 1).layout)
        c.session.clearGroup(c.spec)
        XCTAssertNil(c.session.activeGroup(for: c.spec))
        XCTAssertEqual(c.visibleRoles.count, 4)
    }

    @MainActor func testSwapKeepsAnchorAndOtherObjectsAndSavedSnapshot() throws {
        let c = try fixture("ng20-vomero-kit")
        let anchor = try XCTUnwrap(c.product("anchor"))
        let jacket = try XCTUnwrap(c.product("three"))
        let slot = try XCTUnwrap(c.spec.groups.first { $0.id == "slot.one" })
        let alternative = try XCTUnwrap(NextGenerationFeedCardSpec.resolve(try XCTUnwrap(slot.products.last), in: c.merchants))
        c.session.selectRoomProduct(alternative, slot: slot, for: c.spec)
        XCTAssertEqual(c.product("one")?.id, alternative.id)
        XCTAssertEqual(c.product("anchor")?.id, anchor.id)
        XCTAssertEqual(c.product("three")?.id, jacket.id)
        let savedIDs = c.reviewItems.map(\.id)
        c.session.saveDossierPlan(c.reviewItems, for: c.spec)
        let original = try XCTUnwrap(NextGenerationFeedCardSpec.resolve(try XCTUnwrap(slot.products.first), in: c.merchants))
        c.session.selectRoomProduct(original, slot: slot, for: c.spec)
        XCTAssertEqual(c.state.savedDossierPlans.first, savedIDs)
        XCTAssertNotEqual(c.reviewItems.map(\.id), savedIDs)
    }

    @MainActor func testComparisonRequiresTwoExplicitSelections() throws {
        let c = try fixture("ng20-chairs")
        XCTAssertTrue(c.state.comparisonIDs.isEmpty)
        c.session.revealReviewComparison(true, for: c.spec)
        XCTAssertFalse(c.state.comparisonRevealed)
        let products = c.spec.resolvedProducts(from: c.merchants)
        c.session.toggleReviewComparison(products[0], for: c.spec)
        XCTAssertEqual(c.state.comparisonIDs.count, 1)
        c.session.toggleReviewComparison(products[1], for: c.spec)
        c.session.revealReviewComparison(true, for: c.spec)
        XCTAssertTrue(c.state.comparisonRevealed)
        XCTAssertEqual(c.reviewItems.count, 2)
        c.session.toggleReviewComparison(products[2], for: c.spec)
        XCTAssertEqual(c.state.comparisonIDs.count, 2)
        XCTAssertFalse(c.state.comparisonRevealed)
    }

    @MainActor func testJacketReviewDoesNotIncludeUnchosenAlternatives() throws {
        let c = try fixture("ng20-jacket")
        XCTAssertEqual(c.reviewItems.count, 4)
        XCTAssertGreaterThan(c.definition.references.count, c.reviewItems.count)
        XCTAssertNotNil(c.spec.groups.first { $0.id == "slot.one" })
    }

    @MainActor func testValidationRejectsAnImageBoundToAnotherProduct() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "ng20-compositions", withExtension: "json"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var cards = try XCTUnwrap(object["cards"] as? [[String: Any]])
        var entities = try XCTUnwrap(cards[0]["entities"] as? [String: [String: Any]])
        let wrongArt = entities["one"]?["art"]
        entities["anchor"]?["art"] = wrongArt
        cards[0]["entities"] = entities; object["cards"] = cards
        let bad = try JSONDecoder().decode(NextGeneration20Catalog.Payload.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(CompositionValidation.accepts(bad))
    }

    @MainActor private func continuation(_ source: CompositionContext, signalID: String) throws -> CompositionContext {
        let signal = try XCTUnwrap(NextGeneration20Catalog.signals.first { $0.id == signalID })
        let base = try XCTUnwrap(NextGeneration20Catalog.card(signal: signal, merchants: source.merchants, generation: 0))
        let spec = source.session.resolve(base, merchants: source.merchants)
        let definition = try XCTUnwrap(source.session.compositionDefinition(for: spec))
        return .init(definition: definition, spec: spec, merchants: source.merchants, session: source.session)
    }

    @MainActor func testRoomComparisonReturnsChosenChairAndRestoresExactKeptRoom() throws {
        let room = try fixture(DemoJourneyCatalog.room)
        let originalIDs = room.reviewItems.map(\.id)
        room.session.compareRoomChairs(room)
        let comparison = try continuation(room, signalID: DemoJourneyCatalog.chairs)
        XCTAssertEqual(comparison.definition.id, DemoJourneyCatalog.roomComparison)
        XCTAssertTrue(comparison.state.comparisonIDs.contains(try XCTUnwrap(room.product("one")).id))
        let chosen = try XCTUnwrap(comparison.directProduct("alternative2"))
        room.session.toggleReviewComparison(chosen, for: comparison.spec)
        room.session.useChairInRoom(chosen, context: comparison)
        XCTAssertEqual(room.product("one")?.id, chosen.id)
        XCTAssertEqual(room.product("anchor")?.id, originalIDs.first)
        XCTAssertEqual(Array(room.reviewItems.map(\.id).suffix(2)), Array(originalIDs.suffix(2)))
        room.session.saveDossierPlan(room.reviewItems, for: room.spec)
        let kept = try XCTUnwrap(room.session.journeyMemory.kept.first)
        let other = try XCTUnwrap(comparison.directProduct("alternative1"))
        room.session.useChairInRoom(other, context: comparison)
        XCTAssertNotEqual(room.product("one")?.id, chosen.id)
        room.session.resumeJourneySelection(kept)
        XCTAssertEqual(room.product("one")?.id, chosen.id)
        XCTAssertEqual(room.reviewItems.map(\.id), kept.products.map(\.id))
    }

    @MainActor func testFootwearContinuationUsesSelectedShoeAndRestoresDirectionToo() throws {
        let source = try fixture(DemoJourneyCatalog.footwear)
        let trail = try XCTUnwrap(source.spec.groups.first { $0.id == "trail" })
        source.session.choose(trail, for: source.spec)
        let shoe = try XCTUnwrap(source.directProduct("quest"))
        source.session.select(shoe, for: source.spec)
        source.session.buildAroundSelectedShoe(source)
        let look = try continuation(source, signalID: DemoJourneyCatalog.footwear)
        XCTAssertEqual(look.definition.id, DemoJourneyCatalog.footwearLook)
        XCTAssertEqual(look.product("anchor")?.id, shoe.id)
        let exported = NextGeneration20Catalog.specificationJSON(for: look.definition)
        let decoded = try JSONDecoder().decode(GeneratedComposition.self, from: Data(exported.utf8))
        XCTAssertEqual(decoded.entities["anchor"]?.productID, shoe.product.id)
        XCTAssertNil(look.definition.background, "Never reuse the Vomero styling scene for a Salomon shoe")
        let slot = try XCTUnwrap(look.spec.groups.first { $0.id == "slot.one" })
        let pants = try XCTUnwrap(look.directProduct("denim"))
        source.session.selectRoomProduct(pants, slot: slot, for: look.spec)
        source.session.saveDossierPlan(look.reviewItems, for: look.spec)
        let kept = try XCTUnwrap(source.session.journeyMemory.kept.first)
        source.session.returnToShoeSelection()
        source.session.choose(try XCTUnwrap(source.spec.groups.first { $0.id == "city" }), for: source.spec)
        source.session.buildAroundSelectedShoe(source)
        source.session.resumeJourneySelection(kept)
        let restored = try continuation(source, signalID: DemoJourneyCatalog.footwear)
        XCTAssertEqual(restored.product("anchor")?.id, shoe.id)
        XCTAssertEqual(restored.product("one")?.id, pants.id)
        XCTAssertEqual(source.session.activeGroup(for: source.spec)?.id, "trail")
        XCTAssertEqual(restored.reviewItems.map(\.id), kept.products.map(\.id))
    }

    @MainActor func testKeptBookSurvivesRelaunchAndResetIsDemoScoped() throws {
        let name = "journey-test-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("untouched", forKey: "customFeedsByPreviewBuyer")
        let book = try fixture(DemoJourneyCatalog.books, persistence: defaults)
        let selected = try XCTUnwrap(book.directProduct("book1"))
        book.session.setCanvasPosition(.init(x: 12, y: 34), for: book.spec)
        book.session.keepJourneySelection([selected], for: book.spec)
        let relaunched = GenerativeFeedPrototypeSession(persistence: defaults)
        let kept = try XCTUnwrap(relaunched.journeyMemory.kept.first)
        XCTAssertEqual(kept.products.map(\.id), [selected.id])
        relaunched.resumeJourneySelection(kept)
        XCTAssertEqual(relaunched.state(for: book.spec).selectedID, selected.id)
        XCTAssertEqual(relaunched.state(for: book.spec).canvasPosition, .init(x: 12, y: 34))
        XCTAssertFalse(relaunched.state(for: book.spec).canvasIsExploring)
        relaunched.resetJourneyDemo()
        XCTAssertTrue(GenerativeFeedPrototypeSession(persistence: defaults).journeyMemory.kept.isEmpty)
        XCTAssertEqual(defaults.string(forKey: "customFeedsByPreviewBuyer"), "untouched")
    }

    func testJourneyMemoryRejectsCorruptionAndKeepsSnapshotsImmutable() throws {
        var memory = FeedJourneyMemory()
        let product = FeedJourneyMemory.Product(merchantID: "merchant", productID: 1)
        memory.checkpoints["direction"] = Data("trail".utf8)
        memory.continuation.footwearAnchor = product
        memory.keep(source: "source", stateID: "look", title: "Look", products: [product], checkpoint: Data("original".utf8),
                    scope: .footwear, linkedStateIDs: ["direction"])
        memory.keep(source: "source", stateID: "look", title: "Changed", products: [product], checkpoint: Data("changed".utf8))
        XCTAssertEqual(memory.kept.count, 1)
        memory.checkpoints["direction"] = Data("city".utf8)
        memory.continuation.comparingRoom = true
        let restored = try XCTUnwrap(memory.resume(try XCTUnwrap(memory.kept.first).id))
        XCTAssertEqual(restored.checkpoint, Data("original".utf8))
        XCTAssertEqual(memory.checkpoints["direction"], Data("trail".utf8))
        XCTAssertTrue(memory.continuation.comparingRoom, "Resuming footwear must not reset the room")
        XCTAssertEqual(FeedJourneyMemory.restore(try JSONEncoder().encode(memory)).kept.count, 1)
        XCTAssertTrue(FeedJourneyMemory.restore(Data("broken".utf8)).kept.isEmpty)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(memory)) as? [String: Any])
        object["version"] = 99
        XCTAssertTrue(FeedJourneyMemory.restore(try JSONSerialization.data(withJSONObject: object)).kept.isEmpty)
    }

    @MainActor func testScenePagingAndResetAreScopedToTheCard() throws {
        let c = try fixture("ng20-kinto")
        c.session.setCompositionPage(1, nodeID: "gallery", for: c.spec)
        XCTAssertEqual(c.state.compositionPages["gallery"], 1)
        c.session.reset(c.spec)
        XCTAssertTrue(c.state.compositionPages.isEmpty)
        XCTAssertTrue(c.state.savedDossierPlans.isEmpty)
    }
}
