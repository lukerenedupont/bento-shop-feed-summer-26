import XCTest
import UIKit
@testable import ShopFeedSummer26

final class ReadingCornerTests: XCTestCase {
    private func isolatedDefaults() throws -> UserDefaults {
        let name = "ReadingCornerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testWorkingBudgetIsRefinedWithoutRewritingOriginalRequest() throws {
        let set = ReadingCornerSelection(defaults: try isolatedDefaults())
        XCTAssertEqual(set.selected.map(\.role), [.chair, .table, .light])
        XCTAssertEqual(set.subtotalCents, 389_400)
        XCTAssertEqual(set.budgetCents, 300_000)
        XCTAssertEqual(set.budgetCents - set.subtotalCents, -89_400)
        XCTAssertTrue(set.budgetStatus.contains("over"))
        XCTAssertTrue(ReadingCornerCatalog.prompt.contains("$600"))
    }

    func testChairSwapQuotesWholeSetAndPreservesOtherPiecesAcrossRelaunch() throws {
        let defaults = try isolatedDefaults()
        let set = ReadingCornerSelection(defaults: defaults)
        let original = set.selected
        let alternate = try XCTUnwrap(set.pieces.first { $0.handle == "161659-small-palma" })
        XCTAssertEqual(set.total(replacing: alternate), 335_800)
        XCTAssertEqual(set.subtotalCents, 389_400, "Previewing must not select")
        set.select(alternate)
        XCTAssertEqual(set.subtotalCents, 335_800)
        XCTAssertEqual(Array(set.selected.dropFirst()).map(\.id), Array(original.dropFirst()).map(\.id))
        let restored = ReadingCornerSelection(defaults: defaults)
        XCTAssertEqual(restored.selected.map(\.id), set.selected.map(\.id))
        XCTAssertEqual(restored.budgetCents, 300_000)
    }

    func testLightTradeoffAndExplicitBudgetChange() throws {
        let defaults = try isolatedDefaults()
        let set = ReadingCornerSelection(defaults: defaults)
        let tableLamp = try XCTUnwrap(set.pieces.first { $0.handle == "la-lampe-bien-faite-taupe" })
        XCTAssertTrue(tableLamp.note.contains("table space"))
        XCTAssertEqual(set.total(replacing: tableLamp), 295_100)
        set.setBudget(cents: 400_000)
        XCTAssertEqual(set.subtotalCents, 389_400)
        XCTAssertTrue(set.budgetStatus.contains("under"))
        set.setBudget(cents: -1)
        XCTAssertEqual(set.budgetCents, 400_000)
        set.select(tableLamp)
        let restored = ReadingCornerSelection(defaults: defaults)
        XCTAssertEqual(restored.subtotalCents, 295_100)
        XCTAssertEqual(restored.budgetCents, 400_000)
        XCTAssertTrue(ReadingCornerCatalog.prompt.contains("$600"), "Original request is immutable")
    }

    func testDeckCyclesBothWaysAndOnlyChangesItsRole() throws {
        let defaults = try isolatedDefaults()
        let set = ReadingCornerSelection(defaults: defaults)
        XCTAssertEqual(set.choices(for: .chair).count, 5)
        XCTAssertEqual(set.choices(for: .table).count, 2)
        XCTAssertEqual(set.choices(for: .light).count, 2)
        let original = set.selected.map(\.id)
        set.advance(.chair, by: 1)
        XCTAssertEqual(set.subtotalCents, 335_800)
        XCTAssertEqual(Array(set.selected.dropFirst()).map(\.id), Array(original.dropFirst()))
        set.advance(.chair, by: -1)
        XCTAssertEqual(set.selected.map(\.id), original)
        set.advance(.chair, by: -1)
        XCTAssertEqual(set.selected.first?.handle, "447110-fish-chair")
        set.advance(.chair, by: 1)
        XCTAssertEqual(set.selected.map(\.id), original)
        set.advance(.light, by: 1)
        XCTAssertEqual(set.subtotalCents, 295_100)
        XCTAssertEqual(ReadingCornerSelection(defaults: defaults).selected.map(\.id), set.selected.map(\.id))
        set.advance(.light, by: 1)
        XCTAssertEqual(set.selected.map(\.id), original)
    }

    func testBudgetRefinementMigratesOnceAndPreservesSelectionsAndLaterChoices() throws {
        let defaults = try isolatedDefaults()
        let legacy = ReadingCornerSelection(defaults: defaults)
        legacy.advance(.chair, by: 1)
        legacy.setBudget(cents: 60_000)
        defaults.removeObject(forKey: "reading-corner.selection.v1.budget-refinement-v2")
        let refined = ReadingCornerSelection(defaults: defaults)
        XCTAssertEqual(refined.budgetCents, 300_000)
        XCTAssertEqual(refined.selected.map(\.id), legacy.selected.map(\.id))
        refined.setBudget(cents: 60_000)
        XCTAssertEqual(ReadingCornerSelection(defaults: defaults).budgetCents, 60_000, "Do not override a later explicit change")
        refined.setBudget(cents: 400_000)
        defaults.removeObject(forKey: "reading-corner.selection.v1.budget-refinement-v2")
        XCTAssertEqual(ReadingCornerSelection(defaults: defaults).budgetCents, 400_000, "Preserve previously personalized budgets")
    }

    @MainActor
    func testEverySelectedVariantHasADecodableTransparentCutout() throws {
        for piece in ReadingCornerCatalog.snapshot.pieces {
            let url = try XCTUnwrap(ReadingCornerCutout.imageURL(for: piece))
            let image = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage, piece.handle)
            XCTAssertTrue([CGImageAlphaInfo.first, .last, .premultipliedFirst, .premultipliedLast].contains(image.alphaInfo), piece.handle)
            XCTAssertGreaterThan(image.height, 100)
            XCTAssertLessThanOrEqual(max(image.width, image.height), 480)
            var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
            try pixels.withUnsafeMutableBytes { bytes in
                let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                                                      bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                                      space: CGColorSpaceCreateDeviceRGB(),
                                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
            XCTAssertTrue(alpha.contains(0), "Must actually remove background: \(piece.handle)")
            XCTAssertTrue(alpha.contains(255), "Must retain opaque furniture: \(piece.handle)")
        }
    }

    func testRemovedSelectionFallsBackWithinItsRole() throws {
        let defaults = try isolatedDefaults()
        let set = ReadingCornerSelection(defaults: defaults)
        let alternate = try XCTUnwrap(set.pieces.first { $0.handle == "161659-small-palma" })
        set.select(alternate)
        let refreshed = ReadingCornerSelection(defaults: defaults, pieces: set.pieces.filter { $0.id != alternate.id })
        XCTAssertEqual(refreshed.selected.count, 3)
        XCTAssertEqual(refreshed.subtotalCents, 389_400)
    }

    @MainActor
    func testDiscoveryHasVerifiedSourcesAndResolvableProducts() throws {
        XCTAssertEqual(ReadingCornerDiscoveryCatalog.directions.count, 3)
        for direction in ReadingCornerDiscoveryCatalog.directions {
            let source = try XCTUnwrap(direction.source)
            XCTAssertNotNil(direction.imageURL)
            XCTAssertTrue(source.images.contains(try XCTUnwrap(direction.imageURL).absoluteString))
            XCTAssertEqual(ReadingCornerDiscoveryCatalog.products(direction.productIDs).count, direction.productIDs.count)
            XCTAssertTrue(direction.productIDs.contains(source.id))
        }
        for category in ReadingCornerDiscoveryCatalog.categories {
            XCTAssertGreaterThanOrEqual(category.productIDs.count, 3)
            XCTAssertEqual(ReadingCornerDiscoveryCatalog.products(category.productIDs).count, category.productIDs.count)
        }
        for id in ReadingCornerDiscoveryCatalog.relatedStoryIDs {
            XCTAssertTrue(ShopCanvasLibrary.stories.contains { $0.id == id })
        }
        for id in ReadingCornerDiscoveryCatalog.merchantIDs {
            XCTAssertEqual(ShopCanvasLibrary.merchantsByID[id]?.platformOutcome, "confirmed_shopify")
        }
    }

    func testSourceAspectRatiosAndTableSwapStayExact() throws {
        let set = ReadingCornerSelection(defaults: try isolatedDefaults())
        for piece in set.pieces { XCTAssertTrue((0.7...0.8).contains(piece.imageAspectRatio)) }
        let table = try XCTUnwrap(set.pieces.first { $0.handle == "633555-figure-side-table-4" })
        XCTAssertEqual(set.total(replacing: table), 395_200)
        let otherRoles = set.selected.filter { $0.role != .table }.map(\.id)
        set.select(table)
        XCTAssertEqual(set.selected.filter { $0.role != .table }.map(\.id), otherRoles)
    }

    @MainActor
    func testSetJoinsCanonicalLibraryAndReviewedSharedCover() throws {
        let story = try XCTUnwrap(ShopCanvasLibrary.stories.first { $0.id == ReadingCornerCatalog.storyID })
        let merchant = try XCTUnwrap(ShopCanvasLibrary.merchantsByID[ReadingCornerCatalog.merchantID])
        XCTAssertEqual(merchant.platformOutcome, "confirmed_shopify")
        XCTAssertEqual(story.products.count, 17)
        XCTAssertEqual(Set(story.products.map { "\($0.merchantID):\($0.productID)" }).count, story.products.count)
        for piece in ReadingCornerCatalog.snapshot.pieces {
            XCTAssertEqual(ShopCanvasLibrary.productsByID[piece.id]?.nativeID, piece.product.nativeID)
            XCTAssertTrue(story.products.contains { $0.productID == piece.product.nativeID && $0.merchantID == merchant.id })
            XCTAssertTrue(piece.product.url?.contains("variant=\(piece.variantID)") == true)
            XCTAssertEqual(piece.product.currency, "USD")
            XCTAssertEqual(Decimal(string: piece.product.price).map { $0 * 100 }, Decimal(piece.amountCents))
        }
        let cover = try XCTUnwrap(LibraryArtDirection.cover(for: story))
        XCTAssertEqual(cover.sourceMerchantID, merchant.id)
        XCTAssertNil(cover.sourceProductID, "Inspiration cannot be attributed to a selected item")
        XCTAssertTrue(cover.note.contains("not the selected products"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(cover.url).path))
        let presentation = FeedCardPresentation.resolve(story: story)
        XCTAssertEqual(presentation.kind, .editorial)
        XCTAssertEqual(presentation.actions, [.overflow])
        XCTAssertTrue(presentation.deck.contains("inspiration"))
    }
}
