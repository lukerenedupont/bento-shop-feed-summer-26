import XCTest

final class EditorialFeedUITests: XCTestCase {
    private let titles = [
        "A different perspective", "Take the long way", "Graphic standards", "Make room for coffee",
        "Not your usual vase", "Sunday, slowed down", "Look a little closer", "Objects with a point of view",
        "One quiet cup", "The chair makes the room", "Good times, by design", "Letters worth studying",
        "Room for a new chapter", "Different routes. Same instinct.", "Keep it simple",
        "A place for the things you keep", "Pull up a little chair", "A sunny disposition",
        "Your coffee has plans", "Everyday, less ordinary"
    ]

    func testTwentyCardsRemainReachableInTheNativeFeed() {
        let app = XCUIApplication()
        app.launchArguments = ["-openNextGenerationCard", "0", "-feedDesignMode"]
        app.launch()
        XCTAssertTrue(app.staticTexts[titles[0]].waitForExistence(timeout: 10))
        // The inherited shortcut may settle on the neighboring snap slot.
        for _ in 0..<3 {
            let first = app.staticTexts[titles[0]]
            if first.isHittable { break }
            if first.exists && first.frame.minY > app.frame.height * 0.5 { app.swipeUp() }
            else { app.swipeDown() }
        }
        for (index, title) in titles.enumerated() {
            let heading = app.staticTexts[title]
            XCTAssertTrue(heading.waitForExistence(timeout: 5), title)
            XCTAssertTrue(heading.isHittable, "Unreachable heading: \(title)")
            XCTAssertGreaterThan(heading.frame.minY, 120, title)
            XCTAssertLessThan(heading.frame.maxX, app.frame.width, title)
            if ![2, 12].contains(index) { // Books retained; Babyletto uses plain attribution.
                let mark = app.descendants(matching: .any).matching(identifier: "editorial.wordmark")
                    .allElementsBoundByIndex.first { $0.isHittable }
                XCTAssertNotNil(mark, "Missing official wordmark: \(title)")
            }
            let action = app.buttons.matching(identifier: "generative.primaryAction")
                .allElementsBoundByIndex.first { $0.isHittable }
            XCTAssertNotNil(action, "Missing action: \(title)")
            XCTAssertLessThan(action?.frame.maxY ?? 9999, app.frame.height - 100, title)
            let capture = XCTAttachment(screenshot: app.screenshot())
            capture.name = "Editorial native \(index + 1) — \(title)"
            capture.lifetime = .keepAlways
            add(capture)
            if index < titles.count - 1 { app.swipeUp() }
        }
    }

    func testRelatedMirrorKeepsThePicturedAnchor() {
        let app = XCUIApplication()
        app.launchArguments = ["-nextGenerationGallery", "0", "-feedDesignMode"]
        app.launch()
        let choice = app.buttons["View Elyse Wall Mirror - Mahogany"]
        XCTAssertTrue(choice.waitForExistence(timeout: 10))
        let picturedProduct = app.buttons["generative.primaryAction"].label
        choice.tap()
        XCTAssertTrue(app.staticTexts["generative.productTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["generative.productTitle"].label, "Elyse Wall Mirror - Mahogany")
        XCTAssertEqual(app.descendants(matching: .any)["generative.merchantDestination"].firstMatch.value as? String,
                       "https://foromshop.com/products/elyse-wall-mirror-mahogany")
        app.navigationBars.buttons["Done"].tap()
        XCTAssertEqual(app.buttons["generative.primaryAction"].label, picturedProduct)
    }

    func testOpticsSelectionSurvivesBrowsingAwayAndBack() {
        let app = XCUIApplication()
        app.launchArguments = ["-nextGenerationGallery", "6", "-feedDesignMode"]
        app.launch()
        let zoom = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Select Zoom Tube")).firstMatch
        XCTAssertTrue(zoom.waitForExistence(timeout: 10))
        zoom.tap()
        let selected = app.buttons["generative.primaryAction"].label
        XCTAssertTrue(selected.contains("Zoom Tube"))
        XCTAssertEqual(app.buttons["editorial.photo.0"].label, selected)
        app.buttons["Next experience"].tap()
        app.buttons["Previous experience"].tap()
        XCTAssertEqual(app.buttons["generative.primaryAction"].label, selected)
        XCTAssertEqual(app.buttons["editorial.photo.0"].label, selected)
    }

    func testBookInteriorIsARealProductGalleryView() {
        let app = XCUIApplication()
        app.launchArguments = ["-nextGenerationGallery", "11", "-feedDesignMode"]
        app.launch()
        XCTAssertTrue(app.buttons["See inside"].waitForExistence(timeout: 10))
        app.buttons["See inside"].tap()
        XCTAssertTrue(app.buttons["See the cover"].exists)
        app.buttons["editorial.photo.0"].tap()
        XCTAssertTrue(app.staticTexts["generative.productTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["generative.productTitle"].label, "Theory of Type Design")
        XCTAssertEqual(app.descendants(matching: .any)["generative.merchantDestination"].firstMatch.value as? String,
                       "https://draw-down.com/products/theory-of-type-design")
    }
}
