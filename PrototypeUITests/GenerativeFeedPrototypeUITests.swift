import XCTest

/// Small simulator acceptance check for the prototype's review loop.
final class GenerativeFeedPrototypeUITests: XCTestCase {
    private func launchCard(_ index: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-nextGenerationGallery", String(index), "-feedDesignMode"]
        app.launch()
        XCTAssertTrue(app.staticTexts["generative.heading"].waitForExistence(timeout: 10))
        return app
    }

    func testSixCardsHaveBoundedHeadingsAndReachableActions() {
        for index in 0..<6 {
            let app = launchCard(index)
            let heading = app.staticTexts["generative.heading"]
            XCTAssertTrue(heading.exists)
            XCTAssertGreaterThanOrEqual(heading.frame.minX, 0)
            XCTAssertLessThanOrEqual(heading.frame.maxX, app.frame.maxX)
            if index == 4 {
                XCTAssertTrue(app.buttons["generative.direction.counter"].isHittable)
                XCTAssertTrue(app.buttons["generative.direction.commute"].isHittable)
            } else if index == 5 {
                XCTAssertTrue(app.buttons["Explore Forom"].isHittable)
                XCTAssertTrue(app.buttons["Explore Lichen"].isHittable)
            } else {
                XCTAssertTrue(app.buttons["generative.primaryAction"].isHittable)
            }
            let capture = XCTAttachment(screenshot: app.screenshot())
            capture.name = "Shopping job \(index + 1)"
            capture.lifetime = .keepAlways
            add(capture)
            app.terminate()
        }
    }

    private func swipePants(in app: XCUIApplication) {
        let carousel = app.scrollViews["generative.pantsCarousel"].firstMatch
        XCTAssertTrue(carousel.isHittable)
        carousel.swipeLeft()
        XCTAssertTrue(app.staticTexts["2 of 2"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["generative.primaryAction"].firstMatch.label, "Buy pants")
        XCTAssertEqual(app.buttons["generative.primaryAction"].firstMatch.value as? String,
            "https://feature.com/products/nike-nike-x-stussy-stone-washed-fleece-pant-black")
    }

    func testSwapAndAlternateCompositionRetainSelection() {
        let app = launchCard(0)
        swipePants(in: app)
        XCTAssertTrue(app.staticTexts["2 of 2"].exists)
        app.buttons["generative.inspector"].tap()
        XCTAssertTrue(app.navigationBars["Design inspector"].waitForExistence(timeout: 5))
        app.buttons["generative.composition"].tap()
        XCTAssertTrue(app.buttons["Hero"].waitForExistence(timeout: 5))
        app.buttons["Hero"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["2 of 2"].exists)
        XCTAssertTrue(app.staticTexts["Your anchor"].exists)
    }

    func testShortlistRemovalAndReset() {
        let app = launchCard(1)
        app.buttons["Shortlist options"].tap()
        app.buttons["Remove Chair #1 - Camel Nubuck from shortlist"].tap()
        XCTAssertEqual(app.buttons["Shortlist options"].value as? String, "2 on your shortlist")
        app.buttons["Reset shortlist"].tap()
        XCTAssertEqual(app.buttons["Shortlist options"].value as? String, "3 on your shortlist")
    }

    func testRoomPlanSelectionReturnsToFeedCard() {
        let app = launchCard(3)
        app.buttons["Select Chair #1 - Black Leather"].tap()
        app.buttons["generative.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Your living room"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Chair #1 - Black Leather"].exists)
        let choice = app.buttons.matching(identifier: "Select Papa Teddy Chair - White Boucle")
            .allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(choice)
        choice?.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Papa Teddy Chair - White Boucle"].exists)
        XCTAssertTrue(app.staticTexts["3 of 3"].exists)
    }

    func testConsumerPreviewDisclosesFixturesThenHidesDesignChrome() {
        let app = XCUIApplication()
        app.launchArguments = ["-nextGenerationGallery", "0"]
        app.launch()
        XCTAssertTrue(app.buttons["generative.previewConsumer"].waitForExistence(timeout: 10))
        app.buttons["generative.previewConsumer"].tap()
        XCTAssertTrue(app.staticTexts["generative.heading"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["generative.inspector"].exists)
        XCTAssertFalse(app.staticTexts["Demo context"].exists)
        app.staticTexts["generative.heading"].press(forDuration: 0.8)
        XCTAssertTrue(app.navigationBars["Design inspector"].waitForExistence(timeout: 5))
    }

    func testDirectionGatesInventoryAndSurvivesRegeneration() {
        let app = launchCard(4)
        app.buttons["generative.direction.commute"].tap()
        XCTAssertTrue(app.staticTexts["Carter Move Mug"].exists)
        XCTAssertFalse(app.staticTexts["Aiden Precision Coffee Maker"].exists)
        app.buttons["generative.inspector"].tap()
        app.buttons["generative.regenerateCard"].tap()
        XCTAssertTrue(app.staticTexts["Revision 1"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Carter Move Mug"].exists)
        XCTAssertFalse(app.staticTexts["Aiden Precision Coffee Maker"].exists)
        app.buttons["generative.primaryAction"].tap()
        app.buttons["generative.direction.counter"].tap()
        XCTAssertTrue(app.buttons["Select Aiden Precision Coffee Maker"].exists)
        XCTAssertFalse(app.staticTexts["Carter Move Mug"].exists)
    }

    func testMerchantSelectionKeepsIdentityAndInventoryTogether() {
        let app = launchCard(5)
        app.buttons["Explore Lichen"].tap()
        XCTAssertTrue(app.staticTexts["Lichen"].exists)
        XCTAssertTrue(app.staticTexts["Floyd Shelf"].exists)
        XCTAssertFalse(app.staticTexts["Elyse Wall Mirror - Mahogany"].exists)
        app.buttons["generative.primaryAction"].tap()
        app.buttons["Explore Forom"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Elyse Wall Mirror - Mahogany"].exists)
        XCTAssertFalse(app.staticTexts["Floyd Shelf"].exists)
    }

    func testSignalAndJobChangeRebuildTheSameCard() {
        let app = launchCard(1)
        app.buttons["Select Chair #1 - Black Leather"].tap()
        app.buttons["generative.inspector"].tap()
        app.buttons["generative.sourceSignal"].tap()
        app.buttons["Saved chair shortlist"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Back to your chair shortlist"].exists)
        XCTAssertTrue(app.staticTexts["Chair #1 - Black Leather"].exists)
        app.buttons["generative.inspector"].tap()
        app.buttons["generative.job"].tap()
        app.buttons["Compare a shortlist"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Still considering these chairs?"].exists)
        XCTAssertTrue(app.buttons["Select Chair #1 - Black Leather"].exists)
    }

    func testSavedLookKeepsExactPairAfterSwapAndRegeneration() {
        let app = launchCard(0)
        app.buttons["generative.saveSelection"].tap()
        XCTAssertTrue(app.buttons["Saved looks (1)"].exists)
        swipePants(in: app)
        XCTAssertEqual(app.buttons["generative.saveSelection"].label, "Save this look")
        app.buttons["generative.inspector"].tap()
        app.buttons["generative.regenerateCard"].tap()
        app.buttons["Done"].tap()
        app.buttons["generative.savedLooks"].tap()
        XCTAssertTrue(app.navigationBars["Saved looks"].waitForExistence(timeout: 5))
        let saved = app.buttons["View Nike x Stüssy Fleece Pant - Grey Heather"]
        XCTAssertTrue(saved.isHittable)
        XCTAssertFalse(app.buttons["View Nike x Stüssy Stone Washed Fleece Pant - Black"].isHittable)
        saved.tap()
        XCTAssertTrue(app.staticTexts["generative.productTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["generative.productTitle"].label, "Nike x Stüssy Fleece Pant - Grey Heather")
        XCTAssertEqual(app.descendants(matching: .any)["generative.merchantDestination"].firstMatch.value as? String,
            "https://feature.com/products/nike-nike-x-stussy-fleece-pant-grey-heather")
        app.navigationBars["Product details"].buttons["Done"].tap()
        app.navigationBars["Saved looks"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Saved looks (1)"].exists)
    }

    func testComparisonKeepsFocusedChairAndUsesCanonicalPriceDifference() {
        let app = launchCard(1)
        XCTAssertTrue(app.buttons["Select Chair #1 - Camel Nubuck"].isHittable)
        XCTAssertTrue(app.buttons["Select Chair #1 - Black Leather"].isHittable)
        XCTAssertEqual(app.staticTexts["generative.priceComparison"].label, "Black Leather is $300.00 less.")
        app.buttons["Select Chair #1 - Black Leather"].tap()
        app.buttons["generative.compareAlternative"].tap()
        XCTAssertTrue(app.buttons["Select Chair #1 - Black Leather"].isHittable)
        XCTAssertTrue(app.buttons["Select Papa Teddy Chair - White Boucle"].isHittable)
        XCTAssertFalse(app.buttons["Select Chair #1 - Camel Nubuck"].exists)
        app.buttons["generative.saveSelection"].tap()
        app.buttons["generative.inspector"].tap()
        app.buttons["generative.regenerateCard"].tap()
        app.buttons["Done"].tap()
        XCTAssertEqual(app.buttons["generative.saveSelection"].label, "Unsave this chair")
        app.buttons["generative.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["generative.productTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["generative.productTitle"].label, "Papa Teddy Chair - White Boucle")
        XCTAssertEqual(app.descendants(matching: .any)["generative.merchantDestination"].firstMatch.value as? String,
            "https://houseofleon.com/products/papa-teddy-chair-white-boucle")
    }

    func testFirstCardsInConsumerFeedHaveClearNavigationAndReachableDecisions() {
        let app = XCUIApplication()
        app.launchArguments = ["-openNextGenerationCard", "0"]
        app.launch()
        XCTAssertTrue(app.buttons["generative.previewConsumer"].waitForExistence(timeout: 10))
        app.buttons["generative.previewConsumer"].tap()
        for index in 0..<2 {
            let heading = app.staticTexts.matching(identifier: "generative.heading").allElementsBoundByIndex.first { $0.isHittable }
            XCTAssertNotNil(heading)
            XCTAssertGreaterThan(heading?.frame.minY ?? 0, 120)
            let action = app.buttons.matching(identifier: "generative.primaryAction").allElementsBoundByIndex.first { $0.isHittable }
            XCTAssertNotNil(action)
            XCTAssertLessThan(action?.frame.maxY ?? 9999, app.frame.height - 100)
            let capture = XCTAttachment(screenshot: app.screenshot())
            capture.name = "Consumer feed decision \(index)"
            capture.lifetime = .keepAlways
            add(capture)
            if index == 0 {
                app.buttons["generative.saveSelection"].firstMatch.tap()
                swipePants(in: app)
                app.swipeUp()
                XCTAssertTrue(app.buttons["Select Chair #1 - Black Leather"].waitForExistence(timeout: 5))
            } else {
                app.buttons.matching(identifier: "Select Chair #1 - Black Leather")
                    .allElementsBoundByIndex.first { $0.isHittable }?.tap()
                app.buttons.matching(identifier: "generative.primaryAction").allElementsBoundByIndex.first { $0.isHittable }?.tap()
                XCTAssertTrue(app.staticTexts["generative.productTitle"].waitForExistence(timeout: 5))
                XCTAssertEqual(app.staticTexts["generative.productTitle"].label, "Chair #1 - Black Leather")
                app.buttons["Done"].tap()
                app.swipeDown()
                XCTAssertTrue(app.buttons["Saved looks (1)"].isHittable)
            }
        }
    }

    func testFeedControlsCanRemoveAllSignalsAndRecover() {
        let app = launchCard(0)
        app.buttons["generative.inspector"].tap()
        app.buttons["generative.editFeed"].tap()
        XCTAssertTrue(app.navigationBars["Direct the feed"].waitForExistence(timeout: 5))
        for id in ["complete-jacket", "compare-chairs", "merchant-books", "living-room", "coffee-direction", "home-merchants"] {
            let toggle = app.switches["generative.signal.\(id)"]
            // Edit-mode rows have drag handles; hit the switch itself rather
            // than the row's label, which intentionally doesn't toggle it.
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.5)).tap()
            XCTAssertEqual(toggle.value as? String, "0")
        }
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Edit demo feed"].waitForExistence(timeout: 5))
        app.buttons["Edit demo feed"].tap()
        app.buttons["Show all signals"].tap()
        app.buttons["generative.regenerateFeed"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["generative.heading"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["generative.primaryAction"].isHittable)
    }

    func testFeedOrderChangesWithoutLosingCurrentCard() {
        let app = launchCard(0)
        swipePants(in: app)
        app.buttons["generative.inspector"].tap()
        app.buttons["generative.editFeed"].tap()
        XCTAssertTrue(app.navigationBars["Direct the feed"].waitForExistence(timeout: 5))
        let from = app.switches["generative.signal.home-merchants"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5))
        let to = app.switches["generative.signal.complete-jacket"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.25))
        from.press(forDuration: 0.6, thenDragTo: to)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["2 of 2"].exists)
        app.buttons["Previous experience"].tap()
        XCTAssertTrue(app.staticTexts["Three shops for your home"].exists)
    }

    func testFeedScrollKeepsCardSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["-feedDesignMode", "-openNextGenerationCard", "0"]
        app.launch()
        let action = app.buttons["generative.primaryAction"].firstMatch
        XCTAssertTrue(action.waitForExistence(timeout: 10))
        swipePants(in: app)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Still considering these chairs?"].isHittable)
        app.swipeDown()
        XCTAssertTrue(app.staticTexts["2 of 2"].isHittable)
    }

    func testFeedShellSwapIsReachableAboveNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["-feedDesignMode", "-openNextGenerationCard", "0"]
        app.launch()
        let action = app.buttons["generative.primaryAction"].firstMatch
        XCTAssertTrue(action.waitForExistence(timeout: 10))
        XCTAssertTrue(action.isHittable)
        let inspector = app.buttons["generative.inspector"].firstMatch
        XCTAssertGreaterThan(inspector.frame.minY, 120)
        XCTAssertTrue(inspector.isHittable)
        swipePants(in: app)
        XCTAssertTrue(app.staticTexts["2 of 2"].exists)
    }
}
