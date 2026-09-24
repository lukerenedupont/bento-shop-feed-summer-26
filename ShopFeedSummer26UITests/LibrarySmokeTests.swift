import XCTest

final class LibrarySmokeTests: XCTestCase {
    @MainActor
    func testPriceResearchOpensFirstWithOffersAndPreservesNativeJourney() {
        let app = XCUIApplication()
        app.launch()
        let card = app.buttons["Your trail-running price edit"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        XCTAssertTrue(card.isHittable)
        XCTAssertEqual(card.value as? String, "Cover film")
        XCTAssertFalse(app.staticTexts["SHOP AGENT  /  PRICE SNAPSHOT"].exists)
        let nav = app.descendants(matching: .any)["navigation-tab-surface"]
        let originalWidth = nav.frame.width
        capture(app, name: "Shop Agent — first feed card")
        // The card continues under Julian's dock. Tap the visible title, not
        // XCTest's full-card center inside the dock's touch surface.
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.25)).tap()
        XCTAssertTrue(app.staticTexts["Find your Norda."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["YOUR PRICE FINDINGS"].exists)
        XCTAssertFalse(app.buttons["research.save-search"].exists)
        XCTAssertFalse(app.buttons["Save search"].exists)
        if !app.buttons["All models"].exists {
            app.buttons["research.model-filter"].tap()
            app.buttons["All Norda models"].tap()
        }
        XCTAssertFalse(app.buttons["research.market-filter"].exists)
        XCTAssertFalse(app.staticTexts["Price snapshot. Check your size at the shop."].exists)
        let hero = app.descendants(matching: .any)["world.transition-hero"]
        XCTAssertLessThan(hero.frame.height, app.frame.height * 0.5)
        XCTAssertEqual(hero.value as? String, "Cover film")
        XCTAssertLessThan(nav.frame.width, originalWidth * 0.5)
        let composer = app.descendants(matching: .any)["DYNAMIC_TYPEAHEAD_TEXT_INPUT"]
        XCTAssertTrue(composer.exists)
        let product = app.buttons["research.product.9258627334445"].firstMatch
        XCTAssertTrue(product.isHittable)
        XCTAssertLessThan(product.frame.maxY, composer.frame.minY)
        capture(app, name: "Shop Agent — offers on arrival")
        product.tap()
        XCTAssertTrue(app.buttons["Visit shop"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["ADD_CONTEXT_BUTTON"].label.contains("Men's 003"))
        capture(app, name: "Research product — before Back")
        app.buttons["Back"].firstMatch.tap()
        capture(app, name: "Research product — after Back")
        XCTAssertTrue(app.staticTexts["Find your Norda."].waitForExistence(timeout: 10))
        scrollTo(app.buttons["Best price"], in: app, attempts: 4)
        app.buttons["Best price"].tap()
        XCTAssertTrue(app.staticTexts["Lowest observed item price"].firstMatch.waitForExistence(timeout: 5))
        capture(app, name: "Comparison before merchant tap")
        let merchant = app.descendants(matching: .any)["research.merchant.9258627334445"].firstMatch
        XCTAssertTrue(merchant.waitForExistence(timeout: 5))
        scrollTo(merchant, in: app, attempts: 4)
        merchant.tap()
        XCTAssertTrue(app.staticTexts["US men's 9"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Free US shipping over $180"].exists)
        app.buttons["Done"].tap()
        scrollTo(app.buttons["Fastest shipping"], in: app, attempts: 3)
        app.buttons["Fastest shipping"].tap()
        XCTAssertTrue(app.staticTexts["Delivery dates aren't verified yet. These shops aren't ranked by speed."].waitForExistence(timeout: 5))
        app.buttons["Highest rated"].tap()
        XCTAssertTrue(app.staticTexts["Comparable ratings aren't available yet. No rating winner selected."].waitForExistence(timeout: 5))
        capture(app, name: "Shop Agent — honest merchant comparison")
        scrollTo(app.buttons["The wider kit"], in: app, attempts: 8)
        app.buttons["The wider kit"].tap()
        let shirt = app.buttons["research.product.10193085464904"]
        let shorts = app.buttons["research.product.15337452142967"]
        XCTAssertTrue(shirt.waitForExistence(timeout: 5))
        XCTAssertEqual(shirt.frame.width, shorts.frame.width, accuracy: 1)
        XCTAssertEqual(shirt.frame.height, shorts.frame.height, accuracy: 1)
        XCTAssertEqual(shirt.frame.width, shirt.frame.height, accuracy: 1)
        XCTAssertFalse(app.staticTexts["Compared with shop reference prices."].exists)
        capture(app, name: "Shop Agent — consistent wider kit cards")
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(nav.frame.width, originalWidth * 0.9)
    }

    // Build-12 approximation coverage retained for provenance, replaced by JulianShellUITests.
    #if LEGACY_LIBRARY_NAVIGATION
    @MainActor
    func testPersistentSearchAndNewNavigation() {
        let app = XCUIApplication()
        app.launch()
        let search = app.buttons["library.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 30))
        let startY = search.frame.minY
        XCTAssertTrue(app.scrollViews["home.utility-belt"].firstMatch.exists)
        capture(app, name: "New shell — search, categories, utility and navigation")
        app.swipeUp()
        XCTAssertTrue(search.isHittable)
        XCTAssertEqual(search.frame.minY, startY, accuracy: 2)
        capture(app, name: "New shell — search stays pinned over the feed")
        search.tap()
        let input = app.textFields["library.search.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("zzzznotacatalogitem")
        XCTAssertTrue(app.staticTexts["No matching products"].waitForExistence(timeout: 10))
        app.buttons["Clear search"].tap()
        input.typeText("linen tablecloth")
        let result = app.staticTexts["Linen Tablecloth"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        capture(app, name: "Search — curated catalog results")
        result.tap()
        XCTAssertTrue(app.staticTexts["Not reverified; reference only"].waitForExistence(timeout: 10))
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        XCTAssertEqual(input.value as? String, "linen tablecloth")
        app.buttons["library.sheet.done"].tap()
        app.buttons["tab.4"].tap()
        XCTAssertTrue(app.staticTexts["Your cart is empty"].waitForExistence(timeout: 10))
        app.buttons["tab.5"].tap()
        XCTAssertTrue(app.staticTexts["No favorites yet"].waitForExistence(timeout: 10))
        app.buttons["tab.1"].tap()
        XCTAssertTrue(app.staticTexts["Orders"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["tab.0"].tap()
        XCTAssertTrue(search.waitForExistence(timeout: 10))
    }

    @MainActor
    func testAskKeepsWorldDraftAndRestoresContextAfterProductBack() {
        let app = XCUIApplication()
        openHost(app)
        let ask = app.buttons["library.ask"]
        XCTAssertTrue(ask.label.contains("For the thoughtful host"))
        ask.tap()
        XCTAssertTrue(app.staticTexts["Demo · On-device catalog only"].waitForExistence(timeout: 10))
        let input = app.textFields["library.ask.input"].exists
            ? app.textFields["library.ask.input"] : app.textViews["library.ask.input"]
        input.tap()
        input.typeText("Linen for the table")
        app.buttons["library.sheet.done"].tap()
        XCTAssertTrue(ask.waitForExistence(timeout: 10))
        ask.tap()
        XCTAssertTrue(app.buttons["library.sheet.done"].waitForExistence(timeout: 10))
        XCTAssertEqual(input.value as? String, "Linen for the table")
        capture(app, name: "Ask — World draft survives dismissal")
        app.buttons["library.sheet.done"].tap()
        let product = app.staticTexts["Kitchen Apron Lemonade"].firstMatch
        product.tap()
        XCTAssertTrue(app.staticTexts["Not reverified; reference only"].waitForExistence(timeout: 10))
        XCTAssertTrue(ask.label.contains("Kitchen Apron Lemonade"))
        ask.tap()
        XCTAssertTrue(app.buttons["Show product details"].waitForExistence(timeout: 10))
        XCTAssertNotEqual(input.value as? String, "Linen for the table")
        app.buttons["Show product details"].tap()
        capture(app, name: "Ask — product-scoped catalog response")
        app.buttons["library.sheet.done"].tap()
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(ask.waitForExistence(timeout: 10))
        XCTAssertTrue(ask.label.contains("For the thoughtful host"))
        ask.tap()
        XCTAssertTrue(app.buttons["library.sheet.done"].waitForExistence(timeout: 10))
        XCTAssertEqual(input.value as? String, "Linen for the table")
        app.buttons["library.sheet.done"].tap()
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(ask.waitForExistence(timeout: 10))
        XCTAssertTrue(ask.label.contains("The curated library"))
    }

    #endif

    @MainActor
    func testLibraryUtilityBeltCanBeHiddenAndItsCardsSelected() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["More"].firstMatch.waitForExistence(timeout: 30))
        let more = app.coordinate(withNormalizedOffset: CGVector(dx: 0.91, dy: 0.095))
        more.tap()
        if !app.buttons["utility-belt-visibility"].waitForExistence(timeout: 2) {
            app.buttons["Utility belt"].tap()
        }

        // Editorial cards have one fixed presentation; prototype product-row
        // customization is intentionally no longer exposed.
        XCTAssertFalse(app.switches["feed-card-product-carousels"].exists)

        var beltToggle = app.buttons["utility-belt-visibility"]
        XCTAssertTrue(beltToggle.waitForExistence(timeout: 10))
        if beltToggle.value as? String == "Off" { beltToggle.tap() }
        XCTAssertTrue(app.staticTexts["Orders"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Buy again"].exists)
        XCTAssertFalse(app.staticTexts["Start a gift guide"].exists)
        app.buttons["Done"].tap()
        if app.buttons["search-toolbar-close"].exists { app.buttons["search-toolbar-close"].tap() }

        let belt = app.scrollViews["home.utility-belt"].firstMatch
        XCTAssertTrue(belt.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Find a gift")).firstMatch.exists)
        capture(app, name: "Library For You — configurable utility belt")

        more.tap()
        if !app.buttons["utility-belt-visibility"].waitForExistence(timeout: 2) {
            app.buttons["Utility belt"].tap()
        }
        beltToggle = app.buttons["utility-belt-visibility"]
        XCTAssertEqual(beltToggle.value as? String, "On")
        beltToggle.tap()
        XCTAssertEqual(beltToggle.value as? String, "Off")
        app.buttons["Done"].tap()
        if app.buttons["search-toolbar-close"].exists { app.buttons["search-toolbar-close"].tap() }
        XCTAssertTrue(belt.waitForNonExistence(timeout: 10))

        // Leave the demo in its visible default for subsequent walkthroughs.
        more.tap()
        if !app.buttons["utility-belt-visibility"].waitForExistence(timeout: 2) {
            app.buttons["Utility belt"].tap()
        }
        beltToggle = app.buttons["utility-belt-visibility"]
        beltToggle.tap()
        app.buttons["Done"].tap()
        if app.buttons["search-toolbar-close"].exists { app.buttons["search-toolbar-close"].tap() }
        XCTAssertTrue(belt.waitForExistence(timeout: 15))
    }

    @MainActor
    func testChromeUsesOneSchemeAcrossMediaAndSearch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["More"].firstMatch.waitForExistence(timeout: 30))
        app.swipeUp()
        capture(app, name: "Chrome — media uses one dark scheme")
        let search = app.textFields["search-toolbar-input"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        capture(app, name: "Chrome — search results use one light scheme")
    }

    @MainActor
    func testNikeSkimsRichWorldKeepsCampaignMediaEditorialAndProductsNative() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["More"].firstMatch.waitForExistence(timeout: 30))
        let world = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "For your self-care reset")).firstMatch
        scrollTo(world, in: app, attempts: 4)
        XCTAssertTrue(world.exists)
        capture(app, name: "Self-care World — consistent editorial title")
        world.tap()

        XCTAssertTrue(app.staticTexts["The collection"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Meet the collections"].exists)
        capture(app, name: "NikeSKIMS World — opening film and Shop shelf")
        let product = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "nikeskims.product.")).firstMatch
        XCTAssertTrue(product.exists)
        product.tap()
        XCTAssertTrue(app.buttons["Back"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Back"].firstMatch.tap()

        let fabricCard = app.staticTexts["Studio Stretch"].firstMatch
        for _ in 0..<12 where !fabricCard.isHittable {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(fabricCard.isHittable)
        XCTAssertTrue(app.staticTexts["A study in fabric"].exists)
        capture(app, name: "NikeSKIMS World — interactive fabric collection films")
    }

    @MainActor
    func testThoughtfulHostEditorialWalkthrough() {
        let app = XCUIApplication()
        openHost(app)
        let openingProduct = app.staticTexts["Camilla Vase"].firstMatch
        XCTAssertTrue(openingProduct.waitForExistence(timeout: 10))
        openingProduct.tap()
        XCTAssertTrue(app.staticTexts["Not reverified; reference only"].waitForExistence(timeout: 10))
        app.buttons["Back"].firstMatch.tap()

        let merchant = app.buttons["host.explore-porta"]
        scrollTo(merchant, in: app, attempts: 5)
        capture(app, name: "Host World — shared merchant card")
        merchant.tap()
        XCTAssertTrue(app.staticTexts["Follow"].waitForExistence(timeout: 10))
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Close"].firstMatch.waitForExistence(timeout: 10))
        let detail = app.buttons["host.linen-detail"].firstMatch
        scrollTo(detail, in: app, attempts: 4)
        XCTAssertTrue(app.staticTexts["Linen, up close"].exists)
        XCTAssertFalse(app.staticTexts["View at shop"].exists)
        capture(app, name: "Host World — linen detail diptych")
        detail.tap()
        XCTAssertTrue(app.staticTexts["Linen Tablecloth"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Back"].firstMatch.tap()
    }

    @MainActor
    func testOpeningCardsKeepAnEdgeToEdgeEditorialComposition() {
        let app = XCUIApplication()
        app.launch()
        let firstCover = app.buttons["Your trail-running price edit"].firstMatch
        XCTAssertTrue(firstCover.waitForExistence(timeout: 30))
        XCTAssertEqual(firstCover.value as? String, "Cover film")
        // The real poster must load too: otherwise reduced-motion/offline
        // openings become black even though normal video playback works.
        XCTAssertTrue(app.images["Editorial cover: Your trail-running price edit"].firstMatch.waitForExistence(timeout: 10))
        // The first upward swipe now lets the lead card take over from the belt.
        app.swipeUp()
        for title in ["Gifts for him", "Eckhaus Latta", "Objects with character"] {
            let cover = app.images["Editorial cover: \(title)"].firstMatch
            scrollTo(cover, in: app, attempts: 8)
            XCTAssertGreaterThan(cover.frame.intersection(app.frame).height, app.frame.height * 0.6)
            capture(app, name: "Editorial feed — \(title)")
        }
    }

    @MainActor
    func testLibraryProductAndMerchantUseReferencesWithoutInventedCommerce() {
        let app = XCUIApplication()
        openHost(app)
        let product = app.staticTexts["Camilla Vase"].firstMatch
        XCTAssertTrue(product.waitForExistence(timeout: 10))
        product.tap()
        XCTAssertTrue(app.staticTexts["Not reverified; reference only"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Buy now"].exists)
        XCTAssertFalse(app.staticTexts["$0.00"].exists)
        XCTAssertFalse(app.staticTexts["djerfavenue.com"].exists)
        let merchant = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Porta")).firstMatch
        XCTAssertTrue(merchant.exists)
        merchant.tap()
        XCTAssertTrue(app.staticTexts["Follow"].waitForExistence(timeout: 10))
        capture(app, name: "Current library merchant branding")
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Not reverified; reference only"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testLibraryFeedAndCollectionUseTheNewContent() {
        let app = XCUIApplication()
        app.launch()
        let artwork = app.images["Editorial cover: For the thoughtful host"].firstMatch
        scrollTo(artwork, in: app, attempts: 8)
        XCTAssertTrue(artwork.waitForExistence(timeout: 30))
        XCTAssertGreaterThanOrEqual(artwork.frame.width, app.frame.width * 0.95)
        XCTAssertGreaterThan(artwork.frame.height, app.frame.height * 0.8)
        XCTAssertFalse(app.staticTexts["View at shop"].exists)
        XCTAssertFalse(app.staticTexts["17 selected finds"].exists)
        let navigationSurface = app.descendants(matching: .any)["navigation-tab-surface"]
        XCTAssertTrue(navigationSurface.waitForExistence(timeout: 10))
        let feedNavigationWidth = navigationSurface.frame.width
        app.buttons["For the thoughtful host"].firstMatch.tap()
        let transitionHero = app.descendants(matching: .any)["world.transition-hero"]
        XCTAssertTrue(transitionHero.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(transitionHero.frame.height, app.frame.height * 0.55)
        XCTAssertLessThan(transitionHero.frame.height, app.frame.height * 0.8)
        XCTAssertLessThan(navigationSurface.frame.width, feedNavigationWidth * 0.5)
        XCTAssertTrue(app.descendants(matching: .any)["DYNAMIC_TYPEAHEAD_TEXT_INPUT"].exists)
        XCTAssertTrue(app.staticTexts["Warm, design-minded pieces for a table—and a home—that feels genuinely inviting."].exists)
        let openingSection = app.staticTexts["From the edit"]
        XCTAssertTrue(openingSection.waitForExistence(timeout: 10))
        XCTAssertLessThan(openingSection.frame.minY, app.frame.height * 0.78)
        XCTAssertTrue(app.staticTexts["Price at shop"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Like"].exists)
        XCTAssertFalse(app.buttons["Thread"].exists)
        XCTAssertFalse(app.buttons["Share"].exists)
        let composer = app.descendants(matching: .any)["DYNAMIC_TYPEAHEAD_TEXT_INPUT"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        let openingProduct = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Camilla Vase")
        ).allElementsBoundByIndex.first { $0.frame.intersects(app.frame) }
        XCTAssertNotNil(openingProduct)
        if let openingProduct {
            XCTAssertLessThan(openingProduct.frame.maxY, composer.frame.minY)
        }
        XCTAssertTrue(app.staticTexts["Porta"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["djerfavenue.com"].exists)
        XCTAssertFalse(app.staticTexts["View at shop"].exists)
        capture(app, name: "World — clean labels")
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["From the shops"].waitForExistence(timeout: 5))
        capture(app, name: "World — simplified blocks")
        let compactNavigationWidth = navigationSurface.frame.width
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertGreaterThan(navigationSurface.frame.width, compactNavigationWidth * 2)
    }

    @MainActor
    private func openHost(_ app: XCUIApplication) {
        app.launch()
        let card = app.buttons["For the thoughtful host"].firstMatch
        scrollTo(card, in: app, attempts: 8)
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        card.tap()
        XCTAssertTrue(app.staticTexts["From the edit"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, attempts: Int) {
        for _ in 0..<attempts {
            // UIKit's floating composer can cover the center of a partially visible SwiftUI card.
            // Scroll the actual tap point clear of both persistent chrome regions.
            if element.exists && element.isHittable,
               element.frame.midY < app.frame.maxY - 120,
               element.frame.midY > app.frame.minY + 110 { break }
            if element.exists && element.frame.midY <= app.frame.minY + 110 {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
        XCTAssertTrue(element.isHittable)
    }

    private func waitForValueChange(_ element: XCUIElement, from value: String?) -> Bool {
        let predicate = NSPredicate { object, _ in
            (object as? XCUIElement)?.value as? String != value
        }
        return XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: element)],
            timeout: 3
        ) == .completed
    }

    private func waitForValue(_ element: XCUIElement, equalTo value: String?) -> Bool {
        let predicate = NSPredicate { object, _ in
            (object as? XCUIElement)?.value as? String == value
        }
        return XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: element)],
            timeout: 3
        ) == .completed
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
