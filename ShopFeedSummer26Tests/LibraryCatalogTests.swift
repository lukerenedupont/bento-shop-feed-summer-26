import XCTest
import UIKit
@testable import ShopFeedSummer26

final class LibraryCatalogTests: XCTestCase {
    func testResearchSnapshotPublishesResolvableProductsAndAgentContext() throws {
        let world = ShoppingResearchCatalog.norda
        XCTAssertEqual(world.story.resolvedProducts(from: ShopCanvasLibrary.merchants).count, 19)
        XCTAssertEqual(LibraryAskContext.world(world.story).products.count, 19)
        XCTAssertEqual(FeedCardPresentation.resolve(story: world.story).kind, .researchSummary)
        XCTAssertTrue(ShoppingResearchCatalog.validationIssues(ShoppingResearchCatalog.snapshot).isEmpty)
        XCTAssertEqual(LibraryCatalogSearch.results(for: "norda").count, 9)
        XCTAssertEqual(world.researchedMerchantCount, 6)
        XCTAssertEqual(world.models, ["001A", "003", "005", "055"])
        XCTAssertEqual(world.observedDate, "2026-09-24")
        XCTAssertEqual(world.headline, "Research complete.\nYour trail edit is ready.")
        XCTAssertTrue(world.deck.contains("19 sourced offers"))
        XCTAssertFalse(world.prompt.isEmpty)
        XCTAssertTrue(world.offers.allSatisfy { $0.currency == "USD" })
        let hoka = world.offers.filter { $0.brand.caseInsensitiveCompare("Hoka") == .orderedSame }
        XCTAssertEqual(hoka.count, 2)
        XCTAssertTrue(hoka.allSatisfy { $0.merchantName == "Renegade Running" && $0.section == "alternatives" })
    }

    func testResearchCoverUsesShortFirstPartyFilmAndItsRealLocalPoster() throws {
        let world = ShoppingResearchCatalog.norda
        let film = try XCTUnwrap(world.coverFilm)
        XCTAssertEqual(film.sourcePage.absoluteString, "https://nordarun.com/products/055-m-strato")
        XCTAssertEqual(film.videoURL.host(), "player.vimeo.com")
        XCTAssertTrue(film.videoURL.path.contains("1206594829"))
        XCTAssertEqual(film.loopDuration, 8)
        XCTAssertLessThan(film.loopDuration, film.sourceDuration)
        XCTAssertEqual(film.sourceWidth, 1280)
        XCTAssertEqual(film.sourceHeight, 720)
        XCTAssertEqual(film.sourceMerchantID, "gid://shopify/Shop/82070208817")
        XCTAssertTrue(world.offers.contains { $0.merchantID == film.sourceMerchantID })
        XCTAssertEqual(world.cover.path, film.posterPath)
        XCTAssertNotNil(UIImage(contentsOfFile: film.posterURL.path))
        XCTAssertTrue(film.rightsStatus.contains("Permission for production reuse is not established"))
    }

    func testResearchMerchantAndMotionSectionsUsePublishedExactJoins() {
        let world = ShoppingResearchCatalog.norda
        var merchantIDs: [String] = []
        var stories: [ResearchMotionStory] = []
        for section in world.sections {
            if case .runningShops(let ids) = section { merchantIDs = ids }
            if case .motionStories(let items) = section { stories = items }
        }
        XCTAssertEqual(Set(merchantIDs), [
            "gid://shopify/Shop/7546175546",
            "gid://shopify/Shop/46461485224",
            "gid://shopify/Shop/27527348310",
        ])
        XCTAssertTrue(merchantIDs.allSatisfy { ShopCanvasLibrary.merchantsByID[$0] != nil })
        XCTAssertEqual(stories.count, 3)
        XCTAssertTrue(stories.allSatisfy { story in
            world.offers.contains { $0.id == story.offerID }
                && URL(string: story.videoURL)?.scheme == "https"
        })
        XCTAssertEqual(world.alternativeNotes.count, 4)
        XCTAssertTrue(world.alternativeNotes.allSatisfy { note in
            world.offers.contains { $0.id == note.offerID && $0.section == "alternatives" }
                && !note.useCase.isEmpty && !note.distinction.isEmpty
        })
    }

    func testResearchPriceComparisonMatchesModelColorCurrencyAndAvailableUSSize() throws {
        let world = ShoppingResearchCatalog.norda
        let match = ResearchShoeMatch(model: "003", color: "Cinder")
        let result = world.comparison(match: match, size: "9", criterion: .price)
        XCTAssertEqual(result.offers.map(\.displayPrice), ["$220", "$295"])
        XCTAssertEqual(result.offers.map(\.merchantName), ["Renegade Running", "norda"])
        XCTAssertEqual(result.lowestOfferIDs, ["research:27527348310:9258627334445"])
        let norda = try XCTUnwrap(result.offers.last)
        XCTAssertEqual(norda.observedImageID, 57650898600241)
        XCTAssertTrue(try XCTUnwrap(norda.productURL(usMensSize: "9")).absoluteString.contains("variant=47845318394161"))
        XCTAssertNil(norda.productURL(usMensSize: "15"))
        let oneOffer = world.comparison(match: match, size: "12", criterion: .price)
        XCTAssertEqual(oneOffer.offers.count, 1)
        XCTAssertTrue(oneOffer.lowestOfferIDs.isEmpty)
        XCTAssertTrue(world.comparison(match: .init(model: "003", color: "Lichen"), size: "9", criterion: .price).offers.isEmpty)
        XCTAssertTrue(world.shoeOffers(currency: "EUR").isEmpty)
    }

    func testResearchDoesNotInventDeliveryOrRatingWinners() {
        let world = ShoppingResearchCatalog.norda
        for criterion in [ResearchComparisonCriterion.shipping, .rating] {
            let result = world.comparison(match: .init(model: "003", color: "Cinder"), size: "9", criterion: criterion)
            XCTAssertEqual(result.offers.count, 2)
            XCTAssertTrue(result.lowestOfferIDs.isEmpty)
            XCTAssertNotNil(result.notice)
        }
        let tie = world.comparison(match: .init(model: "055", color: "Strato"), size: "9", criterion: .price)
        XCTAssertEqual(tie.offers.map(\.displayPrice), ["$325", "$325"])
        XCTAssertEqual(tie.lowestOfferIDs.count, 2)
    }

    func testResearchMarkdownUsesSuppliedReferenceRatherThanPriceHistory() throws {
        let offer = try XCTUnwrap(ShoppingResearchCatalog.norda.offers.first { $0.nativeID == 9160693481690 })
        XCTAssertEqual(offer.displayPrice, "$80")
        XCTAssertEqual(offer.displayReference, "$160")
        XCTAssertEqual(offer.markdownPercent, 50)
        XCTAssertEqual(offer.availableVariants, ["Obsidian / L", "Obsidian / XL"])
        XCTAssertNil(ShoppingResearchCatalog.norda.offers.first { $0.title == "TheROCKER" }?.markdownPercent)
    }

    func testNikeSkimsWorldUsesTheCompleteApprovedSelfCareEditAndBundledReferenceMedia() throws {
        let story = try XCTUnwrap(ShopCanvasLibrary.stories.first { $0.id == NikeSkimsWorldMedia.storyID })
        XCTAssertEqual(story.resolvedProducts(from: ShopCanvasLibrary.merchants).count, 11)
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
            if url.isFileURL {
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            } else {
                XCTAssertEqual(url.scheme, "https")
                XCTAssertNotNil(ShoppingResearchCatalog.world(for: story.id)?.heroSource)
                XCTAssertNotNil(cover.sourceMerchantID)
            }
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
        XCTAssertEqual(selfCare.blocks.map(\.title), [
            "The collection", "Meet the collections", "Soft structure",
            "Light study", "A study in fabric", "Support in motion",
            "Explore by color", "Body in motion", "Built to move",
            "Build the look", "Material study", "Movement studies",
            "The full edit",
        ])
        XCTAssertTrue(selfCare.validationIssues.isEmpty)

        let host = try XCTUnwrap(EditorialWorldRecipeCatalog.recipe(for: "library-edit-0"))
        XCTAssertEqual(host.family, .merchant)
        XCTAssertEqual(host.blocks.first?.kind, .productRail)
        XCTAssertEqual(host.blocks.last?.kind, .relatedWorlds)
        XCTAssertEqual(host.blocks.map(\.id), [
            "opening-products", "statement", "scene-gallery", "table-look",
            "merchant-feature", "material-detail",
            "image-pause", "ask", "merchant-spotlights", "categories",
            "merchants", "makers", "bento", "selection", "related",
        ])
        let statement = try XCTUnwrap(host.blocks.first { $0.kind == .statement })
        guard case .statement(let body) = statement.content else {
            return XCTFail("Thoughtful Host statement must carry typed copy")
        }
        XCTAssertEqual(body, "Warm materials, useful objects, and small details for hosting that feels personal rather than perfect.")
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
            "statement block requires statement content",
        ])
    }

    func testPublishedLibraryContainsOnlyConfirmedShopifyMerchants() {
        XCTAssertEqual(ShopCanvasLibrary.merchants.count, 83)
        XCTAssertTrue(ShopCanvasLibrary.merchants.allSatisfy { $0.id.hasPrefix("gid://shopify/Shop/") })
        XCTAssertTrue(ShopCanvasLibrary.curatedProducts.allSatisfy {
            !$0.merchantIDs.isEmpty && $0.merchantIDs.allSatisfy { $0.hasPrefix("gid://shopify/Shop/") }
        })
        XCTAssertFalse(ShopCanvasLibrary.stories.contains { $0.title == "Nordic Knots" })
        XCTAssertTrue(ShopCanvasLibrary.stories.flatMap(\.products).allSatisfy {
            $0.merchantID.hasPrefix("gid://shopify/Shop/")
        })
    }

    func testCuratedSelectionAndAllCollectionPreserveExactEditorialOrder() {
        let confirmedIDs = Set(ShopCanvasLibrary.confirmedMerchantRecords.map(\.id))
        let productsByID = Dictionary(uniqueKeysWithValues: ShopCanvasLibrary.manifest.products.map { ($0.id, $0) })
        let expectedIDs = ShopCanvasLibrary.manifest.selectedIds.filter { id in
            productsByID[id].map { !$0.merchantIDs.filter(confirmedIDs.contains).isEmpty } == true
        }
        XCTAssertEqual(ShopCanvasLibrary.curatedProducts.count, 232)
        XCTAssertEqual(ShopCanvasLibrary.curatedProducts.map(\.id), expectedIDs + ShoppingResearchCatalog.snapshot.offers.map(\.id))
        let all = ShopCanvasLibrary.stories.first { $0.id == "library-edit-all" }!
        XCTAssertEqual(all.products.map(\.productID), ShopCanvasLibrary.curatedProducts.map(\.nativeID))
        XCTAssertEqual(ShopCanvasLibrary.merchants.count, 83)
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
            guard let story = ShopCanvasLibrary.stories.first(where: { LibraryArtDirection.group(for: $0) == group }) else {
                continue
            }
            XCTAssertEqual(LibraryWordmarkCatalog.key(for: story), key)
            let url = try XCTUnwrap(LibraryWordmarkCatalog.sources(for: key, onDark: true).first)
            let image = try XCTUnwrap(UIImage(contentsOfFile: url.path))
            XCTAssertNotNil(LibraryWordmarkMatte.prepare(image, onDark: true))
            XCTAssertTrue(story.products.allSatisfy { $0.merchantID.hasPrefix("gid://shopify/Shop/") })
        }
        XCTAssertFalse(ShopCanvasLibrary.stories.contains { $0.title == "Dries Van Noten" })
    }

    func testMerchantDisplayLabelsAndWorldSubtitlesStayQuiet() throws {
        let merchant = try XCTUnwrap(ShopCanvasLibrary.merchants.first { $0.id == "gid://shopify/Shop/1964605539" })
        XCTAssertEqual(merchant.name, "Veark")
        XCTAssertEqual(ShopCanvasLibrary.merchantsByID[merchant.id]?.name, "Veark")
        XCTAssertTrue(ShopCanvasLibrary.stories.allSatisfy { $0.subtitle.isEmpty })
    }

    func testUnknownPriceIsNotFreeAndRecordedCurrencyIsRetained() throws {
        XCTAssertEqual(formatPrice("", currencyCode: ""), "")
        XCTAssertEqual(formatPrice("340.00", currencyCode: "USD"), "$340.00")
        XCTAssertTrue(formatPrice("340.00", currencyCode: "TRY").contains("TRY"))

        let products = ShopCanvasLibrary.merchants.flatMap(\.products)
        let unknown = try XCTUnwrap(products.first { $0.price.isEmpty })
        let priced = try XCTUnwrap(products.first { !$0.price.isEmpty })
        XCTAssertEqual(productCardPriceBadge(unknown), "Price at shop")
        XCTAssertEqual(productCardPriceBadge(priced), formatPrice(priced))
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
