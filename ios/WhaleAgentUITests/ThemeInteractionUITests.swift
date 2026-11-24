import XCTest

final class ThemeInteractionUITests: XCTestCase {
    func testThemeStyleCanSwitchBetweenFlatAndPremium() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["WHALE_DEMO_SETTINGS"] = "1"
        app.launch()

        let flat = app.buttons["扁平主题"]
        XCTAssertTrue(flat.waitForExistence(timeout: 15))

        let settingsScroll = app.scrollViews.firstMatch
        for _ in 0..<6 where !flat.isHittable {
            settingsScroll.swipeUp()
        }
        XCTAssertTrue(flat.isHittable)
        flat.tap()

        let flatSelected = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "当前：扁平")
        ).firstMatch
        XCTAssertTrue(flatSelected.waitForExistence(timeout: 5))

        let premium = app.buttons["有质感主题"]
        XCTAssertTrue(premium.waitForExistence(timeout: 5))
        if !premium.isHittable {
            settingsScroll.swipeUp()
        }
        XCTAssertTrue(premium.isHittable)
        premium.tap()

        let premiumSelected = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "当前：有质感")
        ).firstMatch
        XCTAssertTrue(premiumSelected.waitForExistence(timeout: 5))

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "premium-theme-selected"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
