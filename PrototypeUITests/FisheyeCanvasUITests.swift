import XCTest

final class FisheyeCanvasUITests: XCTestCase {
    private func visibleButton(_ id: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons.matching(identifier: id).allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(button, "Expected a reachable \(id)")
        return button ?? app.buttons[id].firstMatch
    }

    private func chooseCanvas(in app: XCUIApplication) {
        visibleButton("generative.inspector", in: app).tap()
        app.buttons["generative.composition"].tap()
        app.buttons["Fisheye canvas"].tap()
        app.buttons["Done"].tap()
    }

    func testCanvasPansSelectsAndRestoresAcrossCompositions() {
        let app = XCUIApplication()
        app.launchArguments = ["-nextGenerationGallery", "2", "-feedDesignMode", "-fisheyeCanvas"]
        app.launch()
        let canvas = app.otherElements["fisheye.canvas"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["20 items"].exists)
        let originalSelection = app.buttons["generative.canvasProductDetails"].label
        visibleButton("generative.primaryAction", in: app).tap()
        XCTAssertEqual(app.buttons["generative.primaryAction"].label, "Done exploring")
        let tile = app.buttons["fisheye.tile.1.1"]
        XCTAssertTrue(tile.isHittable)
        let initialX = tile.frame.midX
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.45)))
        XCTAssertGreaterThan(abs(tile.frame.midX - initialX), 10)
        XCTAssertEqual(app.buttons["generative.canvasProductDetails"].label, originalSelection)
        let selectedTitle = String(tile.label.dropFirst("Select ".count))
        tile.tap()
        XCTAssertEqual(app.buttons["generative.canvasProductDetails"].label, "View \(selectedTitle)")
        let pannedFrame = app.buttons["fisheye.tile.1.1"].frame
        app.buttons["generative.primaryAction"].tap()
        visibleButton("generative.inspector", in: app).tap()
        app.buttons["generative.regenerateCard"].tap()
        app.buttons["generative.composition"].tap()
        app.buttons["Hero"].tap()
        app.buttons["Done"].tap()
        chooseCanvas(in: app)
        XCTAssertEqual(app.buttons["generative.canvasProductDetails"].label, "View \(selectedTitle)")
        // Verify the visible surface, not an inspector's formatted state text.
        let restoredFrame = app.buttons["fisheye.tile.1.1"].frame
        XCTAssertEqual(restoredFrame.midX, pannedFrame.midX, accuracy: 1)
        XCTAssertEqual(restoredFrame.midY, pannedFrame.midY, accuracy: 1)
        app.buttons["generative.canvasProductDetails"].tap()
        XCTAssertTrue(app.staticTexts["generative.productTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["generative.productTitle"].label, selectedTitle)
    }

    func testInlineCanvasDoesNotTrapFeedScrolling() {
        let app = XCUIApplication()
        app.launchArguments = ["-openNextGenerationCard", "0", "-feedDesignMode"]
        app.launch()
        XCTAssertTrue(app.staticTexts["generative.heading"].firstMatch.waitForExistence(timeout: 10))
        // The inherited launch shortcut can settle on the utility takeover
        // slot. Navigate by the visible card, not a fixed swipe count.
        for _ in 0..<5 {
            if app.staticTexts["Standards Manual"].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Standards Manual"].isHittable)
        chooseCanvas(in: app)
        let canvas = app.otherElements["fisheye.canvas"].firstMatch
        XCTAssertTrue(canvas.isHittable)
        XCTAssertGreaterThan(canvas.frame.height, 200)
        // Passive canvas yields vertical swipes to the feed.
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["For your living room"].isHittable)
        app.swipeDown()
        visibleButton("generative.primaryAction", in: app).tap()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.4)))
        XCTAssertTrue(app.staticTexts["Standards Manual"].isHittable)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Inline fisheye after pan"
        capture.lifetime = .keepAlways
        add(capture)
        // The outer gutter still scrolls the feed while exploration is active.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.75))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.25)))
        XCTAssertTrue(app.staticTexts["For your living room"].isHittable)
        app.swipeDown()
        XCTAssertEqual(visibleButton("generative.primaryAction", in: app).label, "Explore library")
        visibleButton("generative.primaryAction", in: app).tap()
        visibleButton("generative.primaryAction", in: app).tap()
        XCTAssertEqual(visibleButton("generative.primaryAction", in: app).label, "Explore library")
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["For your living room"].isHittable)
    }
}
