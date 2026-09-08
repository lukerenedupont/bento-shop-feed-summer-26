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

    func testSwapAndAlternateCompositionRetainSelection() {
        let app = launchCard(0)
        app.buttons["generative.primaryAction"].tap()
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
        app.buttons["Remove Chair #1 - Camel Nubuck from shortlist"].tap()
        XCTAssertTrue(app.staticTexts["2 on your shortlist"].exists)
        app.buttons["Reset shortlist"].tap()
        XCTAssertTrue(app.staticTexts["3 on your shortlist"].exists)
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
        XCTAssertTrue(app.staticTexts["Chair #1 - Black Leather"].exists)
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
        app.buttons["generative.primaryAction"].tap()
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
        action.tap()
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
        action.tap()
        XCTAssertTrue(app.staticTexts["2 of 2"].exists)
    }
}
