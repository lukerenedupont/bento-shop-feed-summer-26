import XCTest
@testable import ShopFeedSummer26

final class LibraryShellTests: XCTestCase {
    func testSearchPreservesCuratedOrderAndHasNoDuplicates() {
        let all = LibraryCatalogSearch.results(for: "  ")
        XCTAssertEqual(all.map(\.id), ShopCanvasLibrary.manifest.selectedIds)
        XCTAssertEqual(Set(all.map(\.id)).count, 328)
        XCTAssertTrue(LibraryCatalogSearch.results(for: "zzzznotacatalogitem").isEmpty)
    }

    func testSearchFindsProductShopAndCaseInsensitivePrefixes() throws {
        let linen = LibraryCatalogSearch.results(for: "LINEN")
        XCTAssertTrue(linen.contains { $0.id == "cosmos:820800012" })
        let shops = LibraryCatalogSearch.results(for: "salter hou")
        XCTAssertFalse(shops.isEmpty)
        XCTAssertTrue(shops.allSatisfy { $0.merchantIDs.contains("gid://shopify/Shop/61588471939") })
        XCTAssertEqual(LibraryCatalogSearch.results(for: "linen tablecloth").map(\.id),
                       LibraryCatalogSearch.results(for: "TABLECLOTH linen").map(\.id))
    }

    @MainActor
    func testNavigationActivatesOneShoppingContextAcrossTheAppAndAgentShell() throws {
        let coordinator = NavigationCoordinator()
        let world = LibraryAskContext.world(
            try XCTUnwrap(ShopCanvasLibrary.stories.first { $0.id == "library-edit-0" })
        )

        coordinator.activateShoppingContext(world)

        XCTAssertEqual(coordinator.libraryShell.context.id, world.id)
        XCTAssertEqual(coordinator.julianShell.context.id, world.id)
        XCTAssertEqual(coordinator.julianShell.context.title, world.title)
    }

    @MainActor
    func testDraftsAndResponsesRemainIsolatedByContext() throws {
        let session = LibraryShellSession()
        let host = LibraryAskContext.world(try XCTUnwrap(ShopCanvasLibrary.stories.first { $0.id == "library-edit-0" }))
        let other = LibraryAskContext.product(try XCTUnwrap(ShopCanvasLibrary.curatedProducts.first).nativeID)
        let thread = session.thread(for: host)
        thread.draft = "Something for the table"
        XCTAssertEqual(session.thread(for: host).draft, "Something for the table")
        XCTAssertEqual(session.thread(for: other).draft, "")
        XCTAssertEqual(session.thread(for: .home).draft, "")
        session.surface = .ask(host)
        session.surface = nil
        XCTAssertEqual(session.thread(for: host).draft, "Something for the table")
        thread.send(thread.starters[0])
        XCTAssertEqual(thread.draft, "")
        let exchange = try XCTUnwrap(thread.exchanges.first)
        XCTAssertFalse(exchange.products.isEmpty)
        XCTAssertTrue(exchange.products.allSatisfy { host.productIDs.contains($0.id) })
        XCTAssertTrue(session.thread(for: other).exchanges.isEmpty)
    }

    @MainActor
    func testBlankSubmissionIsIgnoredAndUnanswerableQuestionsAreHonest() {
        let thread = LibraryAskThread(context: .home)
        thread.send(" \n ")
        XCTAssertTrue(thread.exchanges.isEmpty)
        thread.send("Will this be delivered tomorrow?")
        XCTAssertTrue(thread.exchanges[0].answer.contains("isn’t a live Agent"))
        XCTAssertTrue(thread.exchanges[0].products.isEmpty)
    }

    @MainActor
    func testSelectingResultQueuesExactRouteUntilSheetDismissal() throws {
        let session = LibraryShellSession()
        let product = try XCTUnwrap(ShopCanvasLibrary.curatedProducts.first)
        session.surface = .search
        session.open(product)
        XCTAssertNil(session.surface)
        XCTAssertEqual(session.pendingRoute, .product(merchantId: product.merchantIDs[0], productId: product.nativeID))
    }

    func testSearchClearanceDoesNotResizeFeedCards() {
        let original = FeedViewportMetrics(containerSize: .init(width: 402, height: 820), safeAreaTop: 62, isForYou: true)
        let search = FeedViewportMetrics(containerSize: .init(width: 402, height: 820), safeAreaTop: 62, isForYou: true, additionalHeaderHeight: 56)
        XCTAssertEqual(search.fullBleedHeight, original.fullBleedHeight)
        XCTAssertEqual(search.utilityLaunchInset - original.utilityLaunchInset, 56)
        XCTAssertEqual(search.layout.pinnedTitleTop - original.layout.pinnedTitleTop, 56)
    }
}
