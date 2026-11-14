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
        attachScreenshot(named: "01-overview")

        app.buttons["tab-timeline"].tap()
        XCTAssertTrue(app.buttons["timeline-dynasty-liao"].waitForExistence(timeout: 8))
        attachScreenshot(named: "02-timeline")

        app.buttons["tab-index"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 8))
        attachScreenshot(named: "03-search")
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
        attachScreenshot(named: "04-dynasty-detail")
    }

    func testTimelineContainsParallelRegimes() {
        app.buttons["tab-timeline"].tap()

        XCTAssertTrue(app.buttons["timeline-dynasty-liao"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["timeline-dynasty-northern-song"].exists)
        XCTAssertTrue(app.buttons["timeline-dynasty-western-xia"].exists)
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
