import XCTest

final class ChineseChroniclesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testPrimaryTabsExposeDistinctContent() {
        XCTAssertTrue(app.otherElements["overview-hero"].waitForExistence(timeout: 8))

        app.buttons["tab-timeline"].tap()
        XCTAssertTrue(app.otherElements["timeline-header"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.scrollViews["timeline-scroll"].exists)

        app.buttons["tab-index"].tap()
        XCTAssertTrue(app.otherElements["search-empty"].waitForExistence(timeout: 4))
    }

    func testSearchOpensDynastyDetail() {
        app.buttons["tab-index"].tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 4))
        searchField.tap()
        searchField.typeText("秦")

        let qinResult = app.buttons["search-dynasty-qin"]
        XCTAssertTrue(qinResult.waitForExistence(timeout: 4))
        qinResult.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["dynasty-detail-qin"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["秦"].exists)
    }

    func testTimelineContainsParallelRegimes() {
        app.buttons["tab-timeline"].tap()

        XCTAssertTrue(app.buttons["timeline-dynasty-liao"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["timeline-dynasty-northern-song"].exists)
        XCTAssertTrue(app.buttons["timeline-dynasty-western-xia"].exists)
    }
}
