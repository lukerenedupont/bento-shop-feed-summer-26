import XCTest

final class DemoSmokeTests: XCTestCase {
    @MainActor
    func testVisibleNavigationTabsNeverLeadToABlankDestination() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["tab.0"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Warm designer lighting"].firstMatch.waitForExistence(timeout: 15))

        app.buttons["tab.4"].tap()
        XCTAssertTrue(app.staticTexts["Your cart is empty"].waitForExistence(timeout: 5))

        app.buttons["tab.5"].tap()
        XCTAssertTrue(app.staticTexts["No favorites yet"].waitForExistence(timeout: 5))

        app.buttons["tab.0"].tap()
        XCTAssertTrue(app.staticTexts["Warm designer lighting"].firstMatch.waitForExistence(timeout: 10))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Home after tab round trip"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testSecondVideoWorldCanOpenAndClose() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["tab.0"].waitForExistence(timeout: 30))
        let title = app.staticTexts["Streetwear staples from caps to tees"].firstMatch
        for _ in 0..<4 {
            if title.exists && title.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(title.isHittable)
        title.tap()
        let close = app.buttons["Close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Second video World destination"
        attachment.lifetime = .keepAlways
        add(attachment)
        close.tap()
        XCTAssertTrue(app.buttons["tab.0"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testLeadCollectionCanOpenAndClose() throws {
        let app = XCUIApplication()
        app.launch()
        let title = app.staticTexts["Warm designer lighting"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 30))
        title.tap()
        let close = app.buttons["Close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Lead collection destination"
        attachment.lifetime = .keepAlways
        add(attachment)
        close.tap()
        XCTAssertTrue(app.buttons["tab.0"].waitForExistence(timeout: 10))
        XCTAssertTrue(title.exists)
    }
}
