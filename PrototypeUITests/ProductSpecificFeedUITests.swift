import XCTest

final class ProductSpecificFeedUITests: XCTestCase {
    func testOliveAndJuneSelectorsUpdateThePreview() {
        let app = XCUIApplication()
        app.launchArguments = ["-productSpecificFeedGallery", "-productSpecificCard", "0"]
        app.launch()

        XCTAssertTrue(app.buttons["Actually Dramatic polish"].waitForExistence(timeout: 5))
        app.buttons["Deep skin tone"].tap()
        XCTAssertTrue(app.buttons["Deep skin tone"].isSelected)

        app.buttons["Unbothered Energy polish"].tap()
        XCTAssertTrue(app.buttons["Unbothered Energy polish"].isSelected)
        XCTAssertTrue(app.buttons["View Unbothered Energy, $10"].exists)
    }

    func testGrazaGameScoresAnswersAndAdvances() {
        let app = XCUIApplication()
        app.launchArguments = ["-productSpecificFeedGallery", "-productSpecificCard", "1"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Juicy roasted chicken with vegetables."].waitForExistence(timeout: 5))
        app.buttons["Choose Sizzle"].tap()
        XCTAssertTrue(app.staticTexts["You got it."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["1 right"].exists)

        app.buttons["Next question"].tap()
        XCTAssertTrue(app.staticTexts["A piping-hot stir fry with crispy tofu."].waitForExistence(timeout: 2))
        app.buttons["Choose Drizzle"].tap()
        XCTAssertTrue(app.staticTexts["Frizzle is the move."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["View Frizzle, $14"].exists)
    }

    func testUgmonkCompletesAndMakesTheListAnalog() {
        let app = XCUIApplication()
        app.launchArguments = ["-productSpecificFeedGallery", "-productSpecificCard", "6"]
        app.launch()

        let firstTask = app.buttons["Complete Review the next feed card."]
        XCTAssertTrue(firstTask.waitForExistence(timeout: 5))
        firstTask.tap()
        XCTAssertTrue(app.buttons["Mark incomplete Review the next feed card."].waitForExistence(timeout: 2))

        app.buttons["Make it analog"].tap()
        XCTAssertTrue(app.buttons["Back to the live list"].waitForExistence(timeout: 2))

        app.buttons["Back to the live list"].tap()
        XCTAssertTrue(app.buttons["Mark incomplete Review the next feed card."].waitForExistence(timeout: 2))
    }

    func testFellowBuildsTheCoffeeRitual() {
        let app = XCUIApplication()
        app.launchArguments = ["-productSpecificFeedGallery", "-productSpecificCard", "5"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Start with the grind."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Change drink, currently Espresso"].exists)
        app.buttons["Change drink, currently Espresso"].tap()
        XCTAssertTrue(app.buttons["Change drink, currently Long black"].waitForExistence(timeout: 2))

        app.buttons["Next ritual step"].tap()
        XCTAssertTrue(app.staticTexts["Find your espresso."].waitForExistence(timeout: 2))
        app.buttons["Next ritual step"].tap()
        XCTAssertTrue(app.staticTexts["Make it your morning."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["View Pirch Espresso Glasses, $38.20"].exists)
    }

    func testDSDurgaExploresEachScentLayer() {
        let app = XCUIApplication()
        app.launchArguments = ["-productSpecificFeedGallery", "-productSpecificCard", "4"]
        app.launch()

        XCTAssertTrue(app.staticTexts["The air, just after."].waitForExistence(timeout: 5))
        app.buttons["Explore Eucalyptus"].tap()
        XCTAssertTrue(app.staticTexts["Through the grove."].waitForExistence(timeout: 2))
        app.buttons["Explore Wet wood"].tap()
        XCTAssertTrue(app.staticTexts["The trail underfoot."].waitForExistence(timeout: 2))
        app.buttons["Explore Coastal rain"].tap()
        XCTAssertTrue(app.staticTexts["The air, just after."].waitForExistence(timeout: 2))
    }

    func testTaylorStitchCyclesThroughThreeLooks() {
        let app = XCUIApplication()
        app.launchArguments = ["-productSpecificFeedGallery", "-productSpecificCard", "3"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Coffee, then wherever."].waitForExistence(timeout: 5))
        app.buttons["Next look"].tap()
        XCTAssertTrue(app.staticTexts["A little more put together."].waitForExistence(timeout: 2))
        app.buttons["Next look"].tap()
        XCTAssertTrue(app.staticTexts["Stay for dinner."].waitForExistence(timeout: 2))
        app.buttons["Previous look"].tap()
        XCTAssertTrue(app.staticTexts["A little more put together."].waitForExistence(timeout: 2))
    }

    func testCotopaxiItemsCanBePackedAndRemoved() {
        let app = XCUIApplication()
        app.launchArguments = ["-productSpecificFeedGallery", "-productSpecificCard", "2"]
        app.launch()

        XCTAssertTrue(app.buttons["Pack Pop Cable"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Pack Daily SPF"].exists)
        XCTAssertTrue(app.buttons["Pack Layflat notebook"].exists)

        app.buttons["Pack Pop Cable"].tap()
        XCTAssertTrue(app.buttons["Unpack Pop Cable"].waitForExistence(timeout: 2))

        app.buttons["Pack Daily SPF"].tap()
        XCTAssertTrue(app.buttons["Unpack Daily SPF"].waitForExistence(timeout: 2))

        app.buttons["Unpack Pop Cable"].tap()
        XCTAssertTrue(app.buttons["Pack Pop Cable"].waitForExistence(timeout: 2))
    }
}
