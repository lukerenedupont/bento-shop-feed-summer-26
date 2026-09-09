import XCTest
@testable import ShopFeedSummer26

final class CompositionEngineTests: XCTestCase {
    @MainActor private func fixture(_ id: String) throws -> CompositionContext {
        let merchants = LocalMerchantService.mergeMerchants([
            DossierReviewLibrary.merchants, QuietFeedReviewCatalog.merchants, LocalMerchantService.loadMerchants()
        ])
        let definition = try XCTUnwrap(NextGeneration20Catalog.definitions.first { $0.id == id })
        let signal = try XCTUnwrap(NextGeneration20Catalog.signals.first { $0.id == id })
        let spec = try XCTUnwrap(NextGeneration20Catalog.card(signal: signal, merchants: merchants, generation: 0))
        return CompositionContext(definition: definition, spec: spec, merchants: merchants, session: GenerativeFeedPrototypeSession())
    }

    @MainActor func testLichenFeaturedChoicesKeepCanonicalCategoryGates() throws {
        let c = try fixture("ng20-lichen")
        XCTAssertEqual(c.definition.root.mode, "editorial")
        let choice = try XCTUnwrap(c.definition.root.children?.last)
        XCTAssertEqual(choice.axis, "featured")
        XCTAssertEqual(choice.options?.map(\.id), ["storage", "seating", "objects"])
        for option in try XCTUnwrap(choice.options) {
            XCTAssertEqual(option.preview.kind, .media)
            XCTAssertEqual(option.preview.fit, false)
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
        XCTAssertNotEqual(c.definition.root(revision: 0).axis, c.definition.root(revision: 1).axis)
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

    @MainActor func testScenePagingAndResetAreScopedToTheCard() throws {
        let c = try fixture("ng20-kinto")
        c.session.setCompositionPage(1, nodeID: "gallery", for: c.spec)
        XCTAssertEqual(c.state.compositionPages["gallery"], 1)
        c.session.reset(c.spec)
        XCTAssertTrue(c.state.compositionPages.isEmpty)
        XCTAssertTrue(c.state.savedDossierPlans.isEmpty)
    }
}
