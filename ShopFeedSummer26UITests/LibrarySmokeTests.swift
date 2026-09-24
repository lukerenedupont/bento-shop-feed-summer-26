import XCTest

final class LibrarySmokeTests: XCTestCase {
    @MainActor
    func testCornerCardCanBeLiftedAndThrownVerticallyWithoutScrollingWorld() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewStory", "library-edit-oblist-reading-corner"]
        app.launch()
        let card = app.buttons["corner.product.chair"]
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        scrollTo(card, in: app, attempts: 4)
        let original = Int((card.value as? String ?? "1").prefix(1)) ?? 1
        let next = original % 5 + 1
        let initialY = card.frame.minY
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let end = card.coordinate(withNormalizedOffset: CGVector(dx: 0.64, dy: 0.22))
        start.press(forDuration: 0.25, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(waitForValue(card, equalTo: "\(next) of 5"), "A lifted card can be thrown up, not only paged horizontally")
        XCTAssertEqual(card.frame.minY, initialY, accuracy: 3, "The grabbed card must own the gesture, not scroll the World")
        capture(app, name: "Oblist — physical card throw")
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            .press(forDuration: 0.25, thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.68)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(waitForValue(card, equalTo: "\(original) of 5"))
    }

    @MainActor
    func testCornerDeckFillsSpaceAndSwipingLightUpdatesTotal() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewStory", "library-edit-oblist-reading-corner"]
        app.launch()
        let chair = app.buttons["corner.product.chair"]
        XCTAssertTrue(chair.waitForExistence(timeout: 30))
        XCTAssertGreaterThanOrEqual(chair.frame.width, app.frame.width - 56)
        XCTAssertEqual(chair.frame.height / chair.frame.width, 4.0 / 3.0, accuracy: 0.02)
        XCTAssertLessThan(app.descendants(matching: .any)["corner.request"].frame.maxY, chair.frame.minY)
        XCTAssertFalse(app.buttons["corner.swap.chair"].exists)
        let lightRole = app.buttons["corner.role.light"]
        scrollTo(lightRole, in: app, attempts: 3)
        XCTAssertFalse(app.staticTexts["Swipe to choose · Tap for details"].exists)
        XCTAssertFalse(app.staticTexts["USD · Tax & shipping extra"].exists)
        capture(app, name: "Oblist — actual product cutout controls")
        lightRole.tap()
        let light = app.buttons["corner.product.light"]
        scrollTo(light, in: app, attempts: 3)
        if light.value as? String != "1 of 2" { light.swipeRight(); XCTAssertTrue(waitForValue(light, equalTo: "1 of 2")) }
        let baseline = cornerAmount(app.staticTexts["corner.subtotal"].label)
        let before = light.value as? String
        app.swipeUp()
        XCTAssertEqual(light.value as? String, before, "Vertical scrolling cannot select another piece")
        scrollTo(light, in: app, attempts: 3)
        light.swipeLeft()
        XCTAssertTrue(waitForValue(light, equalTo: "2 of 2"))
        XCTAssertEqual(cornerAmount(app.staticTexts["corner.subtotal"].label), baseline - 943)
        capture(app, name: "Oblist — selected light stack and updated total")
        light.swipeRight()
        XCTAssertTrue(waitForValue(light, equalTo: "1 of 2"))
        XCTAssertEqual(cornerAmount(app.staticTexts["corner.subtotal"].label), baseline)
        let tableRole = app.buttons["corner.role.table"]
        scrollTo(tableRole, in: app, attempts: 3)
        tableRole.tap()
        XCTAssertTrue(app.buttons["corner.product.table"].waitForExistence(timeout: 5))
        app.buttons["corner.role.chair"].tap()
        XCTAssertTrue(chair.waitForExistence(timeout: 5))
        XCTAssertEqual(cornerAmount(app.staticTexts["corner.subtotal"].label), baseline, "Changing the active role does not change the set")
    }

    @MainActor
    func testRoomCutoutsDragIndependentlyAndKeepTheSelectedSet() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewStory", "library-edit-oblist-reading-corner"]
        app.launch()
        let room = app.buttons["corner.room"]
        XCTAssertTrue(room.waitForExistence(timeout: 30))
        let total = app.staticTexts["corner.subtotal"].label
        scrollTo(room, in: app, attempts: 6)
        room.tap()
        XCTAssertTrue(app.descendants(matching: .any)["corner.room-board"].waitForExistence(timeout: 5))
        let board = app.descendants(matching: .any)["corner.room-board"].firstMatch
        let chair = board.descendants(matching: .any)["corner.room-piece.chair"].firstMatch
        let table = board.descendants(matching: .any)["corner.room-piece.table"].firstMatch
        let before = chair.frame.midX
        let tableBefore = table.frame.midX
        let grab = chair.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        grab.press(forDuration: 0.2, thenDragTo: grab.withOffset(CGVector(dx: 50, dy: -10)))
        XCTAssertGreaterThan(chair.frame.midX, before + 25)
        XCTAssertEqual(table.frame.midX, tableBefore, accuracy: 1)
        XCTAssertTrue(app.staticTexts[total].exists)
        capture(app, name: "Oblist — freely arranged product cutouts")
        app.buttons["Done"].tap()
    }

    @MainActor
    func testCornerStyleDirectionsAndCategoriesStayShoppable() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewStory", "library-edit-oblist-reading-corner"]
        app.launch()
        XCTAssertTrue(app.buttons["corner.product.chair"].waitForExistence(timeout: 30))
        let soft = app.buttons["corner.direction.soft"]
        scrollTo(soft, in: app, attempts: 8)
        soft.tap()
        XCTAssertTrue(app.staticTexts["Soft & sculptural"].waitForExistence(timeout: 5))
        scrollTo(app.staticTexts["Soft & sculptural"], in: app, attempts: 3)
        XCTAssertTrue(app.staticTexts["Brasilia Lounge Chair, Textile"].exists)
        capture(app, name: "Oblist — soft direction and grouped products")
        let tables = app.buttons["corner.category.tables"]
        scrollTo(tables, in: app, attempts: 4)
        capture(app, name: "Oblist — visual shopping categories")
        tables.tap()
        XCTAssertTrue(app.navigationBars["Side tables"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cubo Side Table"].exists)
        XCTAssertTrue(app.staticTexts["Rivet Side Table | Aluminum"].exists)
        capture(app, name: "Oblist — side-table assortment")
        app.navigationBars["Side tables"].buttons["Close"].tap()
        XCTAssertTrue(app.navigationBars["Side tables"].waitForNonExistence(timeout: 5))
        let frama = app.buttons["corner.shop.gid://shopify/Shop/83980288319"]
        scrollTo(frama, in: app, attempts: 4)
        capture(app, name: "Oblist — home merchants and related stories")
        XCTAssertTrue(frama.isHittable)
    }

    @MainActor
    func testOblistChairDeckCyclesPersistsAndCarriesSetIntoRoomBoard() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewStory", "library-edit-oblist-reading-corner"]
        app.launch()
        let subtotal = app.staticTexts["corner.subtotal"]
        XCTAssertTrue(subtotal.waitForExistence(timeout: 30))
        capture(app, name: "Oblist — inspiration hero and selected products")
        let chair = app.buttons["corner.product.chair"]
        scrollTo(chair, in: app, attempts: 4)
        for _ in 0..<5 {
            if chair.value as? String == "1 of 5" { break }
            let before = chair.value as? String
            chair.swipeRight()
            XCTAssertTrue(waitForValueChange(chair, from: before))
        }
        let originalTotal = subtotal.label
        capture(app, name: "Oblist — swipeable chair pile")
        for next in [2, 3, 4, 5, 1, 2] {
            chair.swipeLeft()
            XCTAssertTrue(waitForValue(chair, equalTo: "\(next) of 5"))
        }
        capture(app, name: "Oblist — second chair selected from five")
        let expectedTotal = subtotal.label
        XCTAssertEqual(cornerAmount(expectedTotal), cornerAmount(originalTotal) - 536)
        let room = app.buttons["corner.room"]
        scrollTo(room, in: app, attempts: 4)
        capture(app, name: "Oblist — selected set and room next step")
        room.tap()
        XCTAssertTrue(app.descendants(matching: .any)["corner.room-board"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Small Palma Chair"].exists)
        XCTAssertTrue(app.staticTexts[expectedTotal].exists)
        XCTAssertTrue(app.buttons["Add your room photo"].exists)
        XCTAssertTrue(app.buttons["About this room preview"].exists)
        capture(app, name: "Oblist — same product cutouts in perspective room")
        let roomChair = app.descendants(matching: .any)["corner.room-board"].firstMatch
            .descendants(matching: .any)["corner.room-piece.chair"].firstMatch
        XCTAssertTrue(roomChair.exists)
        let previousX = roomChair.frame.midX
        let grab = roomChair.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        grab.press(forDuration: 0.15, thenDragTo: grab.withOffset(CGVector(dx: 50, dy: -10)))
        XCTAssertGreaterThan(roomChair.frame.midX, previousX + 25)
        app.buttons["About this room preview"].tap()
        XCTAssertTrue(app.alerts["About this preview"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        app.buttons["Done"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(subtotal.waitForExistence(timeout: 20))
        XCTAssertEqual(subtotal.label, expectedTotal)
        scrollTo(chair, in: app, attempts: 4)
        XCTAssertEqual(chair.value as? String, "2 of 5")
        chair.swipeRight()
        XCTAssertTrue(waitForValue(chair, equalTo: "1 of 5"))
        XCTAssertEqual(subtotal.label, originalTotal)
    }

    private func cornerAmount(_ label: String) -> Double {
        Double(label.filter { "0123456789.".contains($0) }) ?? -.infinity
    }

    @MainActor
    func testOblistFeedOpensWorldAndNativeProductReturnsToSet() {
        let app = XCUIApplication()
        app.launch()
        let first = app.buttons["Your trail-running price edit"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 30))
        let card = app.buttons["A corner to get lost in."].firstMatch
        scrollTo(card, in: app, attempts: 4)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "over your")).count, 0)
        capture(app, name: "Oblist — shared living-room feed cover")
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.25)).tap()
        let product = app.buttons["corner.product.chair"]
        XCTAssertTrue(product.waitForExistence(timeout: 10))
        scrollTo(product, in: app, attempts: 3)
        product.tap()
        XCTAssertTrue(app.buttons["Back"].firstMatch.waitForExistence(timeout: 10))
        capture(app, name: "Oblist — canonical chair product")
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["corner.subtotal"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["corner.product.chair"].exists)
        XCTAssertFalse(app.buttons["corner.swap.chair"].exists)
    }

    @MainActor
    func testResearchBuyingAdviceOpensContextualDraft() {
        let app = XCUIApplication()
        app.launchArguments = ["-previewStory", "library-edit-norda-price-research"]
        app.launch()
        let advice = app.buttons["research.buying-advice"]
        XCTAssertTrue(advice.waitForExistence(timeout: 30))
        scrollTo(advice, in: app, attempts: 10)
        capture(app, name: "Norda — waiting for a better price")
        advice.tap()
        let input = app.descendants(matching: .any)["DYNAMIC_TYPEAHEAD_TEXT_INPUT"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertTrue((input.value as? String ?? "").contains("Should I buy Norda"))
        capture(app, name: "Norda — unsent buying question")
    }

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
        XCTAssertTrue(app.staticTexts["Built from your request."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Source-checked snapshot"].exists)
        XCTAssertTrue(app.staticTexts["19 sourced offers"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["research.sent-request"].exists)
        XCTAssertTrue(app.staticTexts["Thumbs up reaction"].exists)
        let personalize = app.buttons["research.personalize-brief"]
        XCTAssertTrue(personalize.exists)
        scrollTo(personalize, in: app, attempts: 3)
        capture(app, name: "Shop Agent — built from your request")
        personalize.tap()
        XCTAssertTrue(app.navigationBars["Your running brief"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["City or ZIP code"].exists)
        XCTAssertTrue(app.textFields["Fit, colors or aesthetic"].exists)
        XCTAssertFalse(app.textFields["Race and date"].exists)
        app.buttons["Done"].tap()
        let racePicker = app.buttons["research.race-picker"]
        XCTAssertTrue(racePicker.waitForExistence(timeout: 5))
        racePicker.tap()
        XCTAssertTrue(app.navigationBars["Choose a race"].waitForExistence(timeout: 5))
        capture(app, name: "Shop Agent — sourced race picker")
        app.buttons["research.race.runsignup-4-in-the-forest"].tap()
        XCTAssertTrue(app.staticTexts["Irvington, New York · October 4, 2026"].waitForExistence(timeout: 5))
        scrollTo(racePicker, in: app, attempts: 2)
        capture(app, name: "Shop Agent — selected upcoming race")
        XCTAssertTrue(app.staticTexts["Find your Norda."].exists)
        XCTAssertFalse(app.staticTexts["YOUR PRICE FINDINGS"].exists)
        XCTAssertFalse(app.buttons["research.save-search"].exists)
        XCTAssertFalse(app.buttons["Save search"].exists)
        XCTAssertTrue(app.buttons["research.model.003"].exists)
        XCTAssertTrue(app.buttons["research.model.001A"].exists)
        XCTAssertTrue(app.buttons["research.model.005"].exists)
        XCTAssertTrue(app.buttons["research.model.055"].exists)
        scrollTo(app.buttons["research.model.003"], in: app, attempts: 3)
        app.buttons["research.model.003"].tap()
        XCTAssertTrue(app.staticTexts["Renegade Running"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Norda"].exists)
        XCTAssertFalse(app.buttons["research.model-filter"].exists)
        XCTAssertFalse(app.buttons["research.market-filter"].exists)
        XCTAssertFalse(app.staticTexts["Price snapshot. Check your size at the shop."].exists)
        let hero = app.descendants(matching: .any)["world.transition-hero"]
        XCTAssertGreaterThan(hero.frame.height, app.frame.height * 0.55)
        XCTAssertLessThan(hero.frame.height, app.frame.height * 0.62)
        XCTAssertEqual(hero.value as? String, "Cover film")
        XCTAssertLessThan(nav.frame.width, originalWidth * 0.5)
        let composer = app.descendants(matching: .any)["DYNAMIC_TYPEAHEAD_TEXT_INPUT"]
        XCTAssertTrue(composer.exists)
        let product = app.buttons["research.product.9258627334445"].firstMatch
        scrollTo(product, in: app, attempts: 3)
        if product.frame.maxY >= composer.frame.minY { app.swipeUp(velocity: .slow) }
        XCTAssertLessThan(product.frame.maxY, composer.frame.minY)
        capture(app, name: "Shop Agent — offers on arrival")
        product.tap()
        XCTAssertTrue(app.buttons["Visit shop"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["ADD_CONTEXT_BUTTON"].label.contains("Men's 003"))
        capture(app, name: "Research product — before Back")
        app.buttons["Back"].firstMatch.tap()
        capture(app, name: "Research product — after Back")
        XCTAssertTrue(app.staticTexts["Find your Norda."].waitForExistence(timeout: 10))
        scrollTo(app.staticTexts["Where to buy it."], in: app, attempts: 4)
        XCTAssertTrue(app.staticTexts["Norda 003 · Cinder"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Best observed price"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["$75 below the next observed item price"].exists)
        XCTAssertTrue(app.staticTexts["Also available"].exists)
        XCTAssertFalse(app.buttons["Best price"].exists)
        XCTAssertFalse(app.buttons["Fastest shipping"].exists)
        XCTAssertFalse(app.buttons["Highest rated"].exists)
        capture(app, name: "Buying-guide merchant comparison")
        let merchant = app.descendants(matching: .any)["research.merchant.9258627334445"].firstMatch
        XCTAssertTrue(merchant.waitForExistence(timeout: 5))
        scrollTo(merchant, in: app, attempts: 4)
        merchant.tap()
        XCTAssertTrue(app.staticTexts["US men's 9"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Free US shipping over $180"].exists)
        app.buttons["Done"].tap()
        scrollTo(app.buttons["research.buying-advice"], in: app, attempts: 4)
        XCTAssertTrue(app.staticTexts["Waiting for a better price?"].exists)
        XCTAssertTrue(app.staticTexts["Opens Ask · No price alerts are active"].exists)
        capture(app, name: "Shop Agent — buying advice card")
        scrollTo(app.staticTexts["The rest of your run."], in: app, attempts: 8)
        XCTAssertTrue(app.descendants(matching: .any)["research.kit-merchant.gid://shopify/Shop/46461485224"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["3 sale finds · from $80"].exists)
        XCTAssertFalse(app.staticTexts["Compared with shop reference prices."].exists)
        capture(app, name: "Shop Agent — kit grouped by merchant")
        scrollTo(app.staticTexts["How they compare."], in: app, attempts: 6)
        XCTAssertTrue(app.staticTexts["Your Norda"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Race-day alternative"].exists)
        capture(app, name: "Shop Agent — this versus that")
        let satisfyLogo = app.descendants(matching: .any)["research.merchant-card.gid://shopify/Shop/7546175546"]
        scrollTo(satisfyLogo, in: app, attempts: 6)
        XCTAssertTrue(satisfyLogo.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["More from running shops."].exists)
        capture(app, name: "Shop Agent — running shop logos")
        scrollTo(app.staticTexts["Running, in motion."], in: app, attempts: 8)
        XCTAssertTrue(app.descendants(matching: .any)["research.motion.norda-055-motion"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["research.motion.satisfy-rocker-motion"].exists)
        capture(app, name: "Shop Agent — exact product films")
        scrollTo(app.staticTexts["About these prices"], in: app, attempts: 12)
        XCTAssertTrue(app.staticTexts["About these prices"].waitForExistence(timeout: 5))
        capture(app, name: "Shop Agent — dark finish behind navigation")
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
