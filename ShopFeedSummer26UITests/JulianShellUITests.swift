import XCTest

/// App integration checks. Geometry/motion invariants are tested separately using Julian's tests.
final class JulianShellUITests: XCTestCase {
    @MainActor
    func testLongPressSettingsSwitchBothNavigationLayoutsAndSearchPlacements() {
        let app = XCUIApplication()
        app.launch()
        resetDefaults(app)
        let home = app.buttons["Home"]
        let pistonsX = home.frame.minX
        capture(app, "Julian — Pistons and full search")
        openSettings(app)
        app.buttons["Rodeo"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(home.frame.minX, pistonsX + 30)
        capture(app, "Julian — Rodeo")

        openSettings(app)
        app.buttons["Search chip"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["home-search-chip"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["search-toolbar-input"].exists)
        capture(app, "Julian — search chip")

        openSettings(app)
        app.buttons["Floating search button"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["home-floating-search"].waitForExistence(timeout: 10))
        capture(app, "Julian — floating search")

        openSettings(app)
        app.buttons["Search in tab bar"].tap()
        app.buttons["Done"].tap()
        XCTAssertFalse(app.textFields["search-toolbar-input"].exists)
        XCTAssertFalse(app.buttons["home-floating-search"].exists)
        capture(app, "Julian — search in tab bar")
        resetDefaults(app)
        XCTAssertTrue(app.textFields["search-toolbar-input"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        XCTAssertEqual(home.frame.minX, pistonsX, accuracy: 2)
    }

    @MainActor
    func testOriginalComposerKeepsDraftAndUsesOriginalFollowUpInput() {
        let app = XCUIApplication()
        app.launchArguments = ["-library.julian.navigation-style", "pistons", "-shop.prototype.home-search-layout", "full"]
        app.launch()
        let toggle = app.buttons["navigation-composer-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.tap()
        let input = app.textViews["DYNAMIC_TYPEAHEAD_TEXT_INPUT"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("Linen for the table")
        XCTAssertTrue(app.buttons["ask-close"].waitForExistence(timeout: 10))
        capture(app, "Julian — original focused composer and keyboard")
        app.buttons["ask-close"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.tap()
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        XCTAssertEqual(input.value as? String, "Linen for the table")
        app.buttons["DYNAMIC_TYPEAHEAD_SUBMIT_BUTTON"].tap()
        // UI tests run signed out: submission is retained and offers the real OAuth
        // boundary. A signed-in build mounts the live stream in this same surface.
        XCTAssertTrue(app.staticTexts["Sign in to Shop Agent"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["agent-sign-in"].exists)
        XCTAssertTrue(app.textViews["agent-follow-up-text-input"].exists)
        capture(app, "Julian — original follow-up composer, Shop sign-in boundary")
        app.buttons["toolbar-back-button"].tap()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testPersistentSourceSearchFindsTheExactLibraryProduct() {
        let app = XCUIApplication()
        app.launchArguments = ["-library.julian.navigation-style", "pistons", "-shop.prototype.home-search-layout", "full"]
        app.launch()
        let input = app.textFields["search-toolbar-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        let top = input.frame.minY
        app.swipeUp()
        XCTAssertEqual(input.frame.minY, top, accuracy: 2)
        input.tap()
        input.typeText("zzzznotacatalogitem")
        XCTAssertTrue(app.staticTexts["No matching products"].waitForExistence(timeout: 10))
        app.buttons["search-toolbar-clear"].tap()
        input.typeText("linen tablecloth")
        let product = app.staticTexts["Linen Tablecloth"].firstMatch
        XCTAssertTrue(product.waitForExistence(timeout: 10))
        capture(app, "Julian — original inline search with library results")
        product.tap()
        XCTAssertTrue(app.staticTexts["Not reverified; reference only"].waitForExistence(timeout: 10))
        capture(app, "Julian — product dock with exact library context")
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(input.waitForExistence(timeout: 10))
    }

    @MainActor private func openSettings(_ app: XCUIApplication) {
        let home = app.buttons["Home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        home.press(forDuration: 0.8)
        XCTAssertTrue(app.navigationBars["Bottom navigation"].waitForExistence(timeout: 10))
    }

    @MainActor private func resetDefaults(_ app: XCUIApplication) {
        openSettings(app)
        let reset = app.buttons["prototype-reset-defaults"]
        for _ in 0..<3 where !reset.isHittable { app.swipeUp() }
        XCTAssertTrue(reset.isHittable)
        reset.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
