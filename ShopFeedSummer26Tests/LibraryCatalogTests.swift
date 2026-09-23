import XCTest
import UIKit
@testable import ShopFeedSummer26

final class LibraryCatalogTests: XCTestCase {
    func testNikeSkimsWorldUsesTheCompleteApprovedSelfCareEditAndBundledReferenceMedia() throws {
        let story = try XCTUnwrap(ShopCanvasLibrary.stories.first { $0.id == NikeSkimsWorldMedia.storyID })
        XCTAssertEqual(story.resolvedProducts(from: ShopCanvasLibrary.merchants).count, 18)
        XCTAssertEqual(NikeSkimsWorldMedia.fabrics.count, 7)
        XCTAssertEqual(NikeSkimsWorldMedia.collectionGallery.count, 9)
        XCTAssertEqual(NikeSkimsWorldMedia.colorGallery.count, 5)
        XCTAssertEqual(NikeSkimsWorldMedia.buildGallery.count, 7)
        XCTAssertEqual(NikeSkimsWorldMedia.movementGallery.count, 3)
        XCTAssertNotNil(NikeSkimsWorldMedia.coverFilmURL)
        XCTAssertNotNil(NikeSkimsWorldMedia.bodyFilmURL)
    }

    func testLibraryUtilityBeltUsesTheSharedOrdersFixtureWithoutInventedBuyerSignals() {
        XCTAssertTrue(ShopCanvasLibrary.profile.showsUtilityShelf)
        XCTAssertTrue(ShopCanvasLibrary.profile.utility.showsOrders)
        XCTAssertFalse(ShopCanvasLibrary.profile.utility.showsCart)
        XCTAssertNil(ShopCanvasLibrary.profile.utility.buyAgainStoryID)
        XCTAssertNil(ShopCanvasLibrary.profile.utility.recentlyViewedStoryID)
    }

    func testGiftBriefOpensAResolvableLibraryWorld() {
        let brief = GiftGuideBrief(recipientName: "Alex", relationship: "Friend", occasion: "Birthday",
                                  interests: [.food, .home, .books])
        let guide = ShopCanvasLibrary.giftGuide(for: brief)
        XCTAssertEqual(guide.title, "Gifts for Alex")
        XCTAssertTrue(ShopCanvasLibrary.isLibraryStory(guide))
        XCTAssertFalse(guide.products.isEmpty)
        XCTAssertEqual(guide.resolvedProducts(from: ShopCanvasLibrary.merchants).count, guide.products.count)
        XCTAssertTrue(guide.products.allSatisfy { ShopCanvasLibrary.productsByNativeID[$0.productID]?.curated == true })
        XCTAssertNotNil(LibraryArtDirection.cover(for: guide))
    }

    func testEveryEditHasAnExplicitReviewedCoverAndHeroItemsAreNotRepeatedInItsRail() throws {
        for story in ShopCanvasLibrary.stories {
            let cover = try XCTUnwrap(LibraryArtDirection.cover(for: story))
            XCTAssertFalse(cover.note.isEmpty)
            let url = try XCTUnwrap(cover.url)
            XCTAssertTrue(url.isFileURL)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            let products = story.resolvedProducts(from: ShopCanvasLibrary.merchants)
            if let productID = cover.sourceProductID {
                XCTAssertTrue(products.contains { $0.product.sourceProductID == productID })
                XCTAssertFalse(LibraryArtDirection.railProducts(products, for: story).contains { $0.product.sourceProductID == productID })
            }
            if let merchantID = cover.sourceMerchantID {
                XCTAssertTrue(products.contains { $0.product.associatedMerchantIDs?.contains(merchantID) == true })
            }
        }
    }

    func testEveryLibraryWorldHasAuthoredEditorialDeckCopy() throws {
        for story in ShopCanvasLibrary.stories {
            let deck = try XCTUnwrap(LibraryArtDirection.editorialDeck(for: story))
            XCTAssertFalse(deck.isEmpty)
            XCTAssertFalse(deck.contains("selected finds from"))
        }
        let selfCare = try XCTUnwrap(ShopCanvasLibrary.stories.first { $0.id == NikeSkimsWorldMedia.storyID })
        XCTAssertEqual(
            LibraryArtDirection.editorialDeck(for: selfCare),
            "A movement study for training, recovery, and the quieter rituals in between."
        )
    }

    func testSelfCareUsesTheCanonicalEditorialFeedPresentation() throws {
        let story = try XCTUnwrap(ShopCanvasLibrary.stories.first { $0.id == NikeSkimsWorldMedia.storyID })

        let presentation = FeedCardPresentation.resolve(story: story)

        XCTAssertEqual(presentation.kind, .editorial)
        XCTAssertEqual(presentation.deck, "A movement study for training, recovery, and the quieter rituals in between.")
        XCTAssertEqual(presentation.cta, "Explore")
        XCTAssertEqual(presentation.actions, [.overflow])
        XCTAssertFalse(presentation.showsProducts)
    }

    func testEditorialWorldRecipesOwnTheTwoRichDestinations() throws {
        let selfCare = try XCTUnwrap(EditorialWorldRecipeCatalog.recipe(for: NikeSkimsWorldMedia.storyID))
        XCTAssertEqual(selfCare.family, .campaign)
        XCTAssertEqual(selfCare.blocks.first?.kind, .productRail)
        XCTAssertEqual(selfCare.blocks.last?.kind, .exploreGrid)
        XCTAssertGreaterThanOrEqual(selfCare.blocks.count, 10)
        XCTAssertTrue(selfCare.validationIssues.isEmpty)

        let host = try XCTUnwrap(EditorialWorldRecipeCatalog.recipe(for: "library-edit-0"))
        XCTAssertEqual(host.family, .merchant)
        XCTAssertEqual(host.blocks.first?.kind, .productRail)
        XCTAssertEqual(host.blocks.last?.kind, .relatedWorlds)
        XCTAssertGreaterThanOrEqual(host.blocks.count, 12)
        XCTAssertTrue(host.validationIssues.isEmpty)
    }

    func testEditorialWorldRecipeValidationRejectsMissingAndDuplicateBlockIdentity() {
        let recipe = EditorialWorldRecipe(
            storyID: "",
            family: .merchant,
            blocks: [
                .init(id: "repeat", kind: .statement, title: ""),
                .init(id: "repeat", kind: .film, title: "Film"),
            ]
        )

        XCTAssertEqual(recipe.validationIssues, [
            "story ID must not be empty",
            "block IDs must be unique",
            "block identity and title must not be empty",
        ])
    }

    func testCuratedSelectionAndAllCollectionPreserveExactEditorialOrder() {
        XCTAssertEqual(ShopCanvasLibrary.curatedProducts.count, 328)
        XCTAssertEqual(ShopCanvasLibrary.curatedProducts.map(\.id), ShopCanvasLibrary.manifest.selectedIds)
        let all = ShopCanvasLibrary.stories.first { $0.id == "library-edit-all" }!
        XCTAssertEqual(all.products.map(\.productID), ShopCanvasLibrary.curatedProducts.map(\.nativeID))
        XCTAssertEqual(ShopCanvasLibrary.merchants.count, 114)
        XCTAssertTrue(ShopCanvasLibrary.manifest.products.allSatisfy(\.curated))
    }

    func testLocalAssetsResolveAgainstLibraryRootAndOriginalURLsStayExternal() throws {
        let first = try XCTUnwrap(ShopCanvasLibrary.curatedProducts.first)
        let thumbnail = try XCTUnwrap(ShopCanvasLibrary.resolve(first.image))
        XCTAssertTrue(thumbnail.isFileURL)
        XCTAssertTrue(thumbnail.path.contains("/LibraryAssets/catalog/images/"))
        XCTAssertFalse(thumbnail.path.contains("/catalog/catalog/"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbnail.path))
        XCTAssertFalse(try XCTUnwrap(ShopCanvasLibrary.resolve(first.originalImage)).isFileURL)
        XCTAssertNil(ShopCanvasLibrary.resolve("../merchant-review/cover.png"))
        XCTAssertNil(ShopCanvasLibrary.resolve("./merchant-review/cover.png"))
    }

    func testEveryExactMerchantAssociationIsRetained() {
        for product in ShopCanvasLibrary.curatedProducts {
            for merchantID in product.merchantIDs {
                let merchant = ShopCanvasLibrary.merchants.first { $0.id == merchantID }
                XCTAssertNotNil(merchant)
                XCTAssertEqual(merchant?.products.first { $0.id == product.nativeID }?.sourceProductID, product.id)
            }
        }
    }

    func testSuppliedReviewedWhiteWordmarkOverridesWithoutMutatingTheDirectory() throws {
        let merchant = try XCTUnwrap(ShopCanvasLibrary.merchantsByID["gid://shopify/Shop/1964605539"])
        XCTAssertEqual(merchant.wordmarkWhite, "./cosmos-brand-assets/veark/mark-white.svg")
        let first = try XCTUnwrap(ShopCanvasLibrary.wordmarkSources(for: merchant.id, onDark: true).first)
        XCTAssertTrue(first.path.hasSuffix("merchant-assets/imported-wordmarks/launch-approved/veark-white.png"))
    }

    func testOnlyExplicitBrandEditsGetCollectionWordmarks() throws {
        let mixed = try XCTUnwrap(ShopCanvasLibrary.stories.first { $0.title == "For the thoughtful host" })
        XCTAssertNil(LibraryWordmarkCatalog.key(for: mixed))
        let eckhaus = try XCTUnwrap(ShopCanvasLibrary.stories.first { $0.title == "Eckhaus Latta" })
        XCTAssertEqual(LibraryWordmarkCatalog.key(for: eckhaus), "cosmos-profile:1784728528")
        XCTAssertEqual(LibraryWordmarkCatalog.manifest.groupKeys.count, 10)
        for (group, key) in LibraryWordmarkCatalog.manifest.groupKeys {
            let story = try XCTUnwrap(ShopCanvasLibrary.stories.first { LibraryArtDirection.group(for: $0) == group })
            XCTAssertEqual(LibraryWordmarkCatalog.key(for: story), key)
            let url = try XCTUnwrap(LibraryWordmarkCatalog.sources(for: key, onDark: true).first)
            let image = try XCTUnwrap(UIImage(contentsOfFile: url.path))
            XCTAssertNotNil(LibraryWordmarkMatte.prepare(image, onDark: true))
        }
        let dries = try XCTUnwrap(ShopCanvasLibrary.stories.first { $0.title == "Dries Van Noten" })
        XCTAssertEqual(LibraryWordmarkCatalog.key(for: dries), "gid://shopify/Shop/58974732484")
        XCTAssertTrue(dries.products.allSatisfy { reference in
            ShopCanvasLibrary.productsByNativeID[reference.productID]?.merchantIDs.first == reference.merchantID
        }, "The displayed brand mark must retain each product's original primary retailer")
    }

    func testMerchantDisplayLabelsAndWorldSubtitlesStayQuiet() throws {
        let merchant = try XCTUnwrap(ShopCanvasLibrary.merchants.first { $0.id == "domain:djerfavenue.com" })
        XCTAssertEqual(merchant.name, "Djerf Avenue")
        XCTAssertEqual(merchant.id, "domain:djerfavenue.com")
        XCTAssertEqual(ShopCanvasLibrary.merchantsByID[merchant.id]?.name, "djerfavenue.com",
            "Presentation cleanup must not rewrite source directory records")
        XCTAssertTrue(ShopCanvasLibrary.stories.allSatisfy { $0.subtitle.isEmpty })
    }

    func testUnknownPriceIsNotFreeAndRecordedCurrencyIsRetained() {
        XCTAssertEqual(formatPrice("", currencyCode: ""), "")
        XCTAssertEqual(formatPrice("340.00", currencyCode: "USD"), "$340.00")
        XCTAssertTrue(formatPrice("340.00", currencyCode: "TRY").contains("TRY"))
    }

    func testWordmarkMatteRemovesOpaqueWhiteRectangle() throws {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16), format: format).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
            UIColor.black.setFill(); ctx.fill(CGRect(x: 4, y: 4, width: 8, height: 8))
        }
        let prepared = try XCTUnwrap(LibraryWordmarkMatte.prepare(image, onDark: true)?.cgImage)
        var data = [UInt8](repeating: 0, count: 16 * 16 * 4)
        data.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: 16, height: 16, bitsPerComponent: 8,
                bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(prepared, in: CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        XCTAssertEqual(data[3], 0)
        XCTAssertGreaterThan(data[(8 * 16 + 8) * 4 + 3], 240)
        XCTAssertGreaterThan(data[(8 * 16 + 8) * 4], 240)
    }
}
