import XCTest

/// Small simulator acceptance check for the prototype's review loop.
final class GenerativeFeedPrototypeUITests: XCTestCase {
    private func launchCard(_ index: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-nextGenerationGallery", String(index), "-feedDesignMode"]
        app.launch()
        XCTAssertTrue(app.buttons["generative.primaryAction"].waitForExistence(timeout: 10))
        return app
    }

    func testFourCardsHaveBoundedHeadingsAndReachableActions() {
        for index in 0..<4 {
            let app = launchCard(index)
            let heading = app.staticTexts["generative.heading"]
            XCTAssertTrue(heading.exists)
            XCTAssertGreaterThanOrEqual(heading.frame.minX, 0)
            XCTAssertLessThanOrEqual(heading.frame.maxX, app.frame.maxX)
            XCTAssertTrue(app.buttons["generative.primaryAction"].isHittable)
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
        app.buttons["Hero"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["2 of 2"].exists)
        XCTAssertTrue(app.staticTexts["Your anchor"].exists)
    }

    func testShortlistRemovalAndReset() {
        let app = launchCard(1)
        app.buttons["Remove Chair #1 - Camel Nubuck from shortlist"].tap()
        XCTAssertTrue(app.staticTexts["2 on your shortlist"].exists)
        app.buttons["generative.primaryAction"].tap()
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
