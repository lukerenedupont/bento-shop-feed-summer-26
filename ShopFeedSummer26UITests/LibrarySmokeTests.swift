import XCTest

final class LibrarySmokeTests: XCTestCase {
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
        XCTAssertTrue(app.images["Editorial cover: For the thoughtful host"].firstMatch.waitForExistence(timeout: 30))
        // The first upward swipe now lets the lead card take over from the belt.
        app.swipeUp()
        for title in ["Gifts for him", "Eckhaus Latta", "Objects with character"] {
            let cover = app.images["Editorial cover: \(title)"].firstMatch
            scrollTo(cover, in: app, attempts: 3)
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
        XCTAssertTrue(artwork.waitForExistence(timeout: 30))
        XCTAssertGreaterThanOrEqual(artwork.frame.width, app.frame.width * 0.95)
        XCTAssertGreaterThan(artwork.frame.height, app.frame.height * 0.8)
        XCTAssertFalse(app.staticTexts["View at shop"].exists)
        XCTAssertFalse(app.staticTexts["17 selected finds"].exists)
        app.buttons["For the thoughtful host"].firstMatch.tap()
        let transitionHero = app.descendants(matching: .any)["world.transition-hero"]
        XCTAssertTrue(transitionHero.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(transitionHero.frame.height, app.frame.height * 0.9)
        XCTAssertTrue(app.staticTexts["Warm, design-minded pieces for a table—and a home—that feels genuinely inviting."].exists)
        app.swipeUp()
        let openingSection = app.staticTexts["From the edit"]
        XCTAssertTrue(openingSection.waitForExistence(timeout: 10))
        XCTAssertLessThan(openingSection.frame.minY, app.frame.height * 0.70)
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
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func openHost(_ app: XCUIApplication) {
        app.launch()
        let card = app.buttons["For the thoughtful host"].firstMatch
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
            app.swipeUp()
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
