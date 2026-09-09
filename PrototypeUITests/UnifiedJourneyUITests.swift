import XCTest

final class UnifiedJourneyUITests: XCTestCase {
    private func launch(_ index: Int, reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-quietFeedReview", "-bentoMediaReview", "-nextGeneration20", "-buyerPreviewProfileID", "luke",
                               "-nextGenerationGallery", String(index), "-feedDesignMode", "-journeyUITestStorage"]
        if reset { app.launchArguments.append("-resetJourneyUITestStorage") }
        app.launch()
        XCTAssertTrue(app.buttons["ng20.primary"].waitForExistence(timeout: 20))
        return app
    }
    private func tapInReview(_ element: XCUIElement, app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<5 where !element.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(element.isHittable)
        element.tap()
    }
    private func waitUntilHittable(_ element: XCUIElement) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in element.exists && element.isHittable }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testRoomComparisonReturnsToNativeCardAndKeepsSelection() {
        let app = launch(1)
        app.buttons["ng20.primary"].tap()
        tapInReview(app.buttons["journey.compareRoom"], app: app)
        XCTAssertTrue(app.staticTexts["Choose a chair for your room"].waitForExistence(timeout: 8))
        app.buttons["ng20.primary"].tap()
        app.buttons["ng20.primary"].tap()
        let use = app.buttons["journey.useChair.house-of-leon-7873592688813"]
        tapInReview(use, app: app)
        XCTAssertTrue(app.staticTexts["Around this lamp"].waitForExistence(timeout: 8))
        app.buttons["ng20.primary"].tap()
        XCTAssertTrue(app.staticTexts["Chair #1 - Camel Nubuck"].waitForExistence(timeout: 5))
        tapInReview(app.buttons["journey.keepSelection"], app: app)
        XCTAssertTrue(app.buttons["Kept on this device"].exists)
        capture(app, "room-kept-selection")
    }
    func testFootwearLookAndKeptSelectionSurviveRelaunch() {
        var app = launch(9)
        app.buttons["ng20.choice.trail"].tap()
        app.buttons["ng20.primary"].tap()
        tapInReview(app.buttons["journey.buildLook"], app: app)
        XCTAssertTrue(app.staticTexts["Build around this pair"].waitForExistence(timeout: 8))
        capture(app, "canonical-shoe-continuation")
        app.buttons["ng20.primary"].tap()
        tapInReview(app.buttons["journey.keepSelection"], app: app)
        app.terminate()
        app = launch(9, reset: false)
        XCTAssertTrue(app.staticTexts["Build around this pair"].waitForExistence(timeout: 8))
        app.buttons["Card options"].tap()
        app.buttons["Kept selections"].tap()
        XCTAssertTrue(app.navigationBars["Kept selections"].waitForExistence(timeout: 5))
        let resume = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'journey.resume.'")).firstMatch
        tapInReview(resume, app: app)
        XCTAssertTrue(app.staticTexts["Build around this pair"].waitForExistence(timeout: 8))
        capture(app, "resumed-footwear-look")
    }
    func testRoomJourneyUsesActualFeedNavigationAndClearsBottomChrome() {
        let app = XCUIApplication()
        app.launchArguments = ["-quietFeedReview", "-bentoMediaReview", "-nextGeneration20", "-buyerPreviewProfileID", "luke",
                               "-startDemoJourney", "room", "-feedDesignMode", "-journeyUITestStorage", "-resetJourneyUITestStorage"]
        app.launch()
        let initialAction = app.otherElements["ng20.card.ng20-woven-room"].buttons["ng20.primary"]
        XCTAssertTrue(initialAction.waitForExistence(timeout: 20))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in initialAction.isHittable }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
        let menu = app.buttons.matching(identifier: "Card options").allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(menu); menu?.tap()
        app.buttons["Inspect specification"].tap()
        app.buttons["generative.editFeed"].tap()
        app.buttons["Finish a room"].tap()
        let room = app.otherElements["ng20.card.ng20-woven-room"]
        let primary = room.buttons["ng20.primary"]
        waitUntilHittable(primary)
        XCTAssertLessThan(primary.frame.maxY, app.frame.maxY - 60)
        capture(app, "room-in-native-feed")
        primary.tap()
        tapInReview(app.buttons["journey.compareRoom"], app: app)
        let comparison = app.otherElements["ng20.card.ng20-journey-room-comparison"].buttons["ng20.primary"]
        waitUntilHittable(comparison)
        comparison.tap(); comparison.tap()
        tapInReview(app.buttons["journey.useChair.house-of-leon-7873592688813"], app: app)
        waitUntilHittable(primary)
        capture(app, "room-returned-in-native-feed")
        app.swipeUp()
        let nextCard = app.otherElements["ng20.card.ng20-vomero-kit"]
        let next = nextCard.buttons["ng20.primary"]
        let flicked = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            next.exists && next.isHittable && nextCard.value as? String == "Current experience"
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [flicked], timeout: 8), .completed, "An explicit journey target must release when the shopper flicks")
    }

    func testConsumerRelaunchKeepsActionsAboveNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["-quietFeedReview", "-bentoMediaReview", "-nextGeneration20", "-buyerPreviewProfileID", "luke",
                               "-startDemoJourney", "room", "-journeyUITestStorage", "-resetJourneyUITestStorage"]
        app.launch()
        let preview = app.buttons["generative.previewConsumer"]
        XCTAssertTrue(preview.waitForExistence(timeout: 20))
        preview.tap()
        waitUntilHittable(app.otherElements["ng20.card.ng20-woven-room"].buttons["ng20.primary"])
        app.terminate()
        app.launchArguments.removeAll { $0 == "-resetJourneyUITestStorage" }
        app.launch()
        let primary = app.otherElements["ng20.card.ng20-woven-room"].buttons["ng20.primary"]
        waitUntilHittable(primary)
        XCTAssertFalse(preview.exists)
        let nav = app.buttons["navigation-home-filled"]
        XCTAssertTrue(nav.exists)
        XCTAssertLessThan(primary.frame.maxY, nav.frame.minY - 12)
        capture(app, "consumer-room-clearance-after-relaunch")
        primary.tap()
        XCTAssertTrue(app.navigationBars["Around this lamp"].waitForExistence(timeout: 5))
    }

    func testLibraryProductCanBeInspectedAndKept() {
        let app = launch(14)
        app.buttons["ng20.primary"].tap()
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Focus '")).allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(tile)
        guard let tile else { return }
        tile.tap(); tile.tap()
        XCTAssertTrue(app.buttons["journey.keepProduct"].waitForExistence(timeout: 8))
        app.buttons["journey.keepProduct"].tap()
        XCTAssertTrue(app.buttons["Kept on this device"].exists)
        capture(app, "kept-canonical-book")
    }
}
