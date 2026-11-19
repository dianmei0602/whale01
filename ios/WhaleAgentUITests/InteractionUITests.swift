import XCTest

final class InteractionUITests: XCTestCase {
    private func tab(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons["tab-" + name]
    }

    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["WHALE_DEMO_HOME"] = "1"
        app.launchEnvironment["WHALE_DEMO_INITIAL_CHANNEL"] = "ai"
        app.launchEnvironment["WHALE_DEMO_PALETTE"] = "seaSalt"
        app.launch()
        return app
    }
    func testThreeTabsKeepDiscoverySeparateFromTheAssistant() {
        let app = launch()
        XCTAssertTrue(tab(app, "conversation").waitForExistence(timeout: 10))
        let inspiration = app.buttons["home-inspiration-card"]
        XCTAssertTrue(inspiration.waitForExistence(timeout: 10))
        let today = app.otherElements["home-today-card"]
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        XCTAssertLessThanOrEqual(inspiration.frame.maxY, today.frame.minY + 1)
        XCTAssertTrue(today.buttons["home-today-weather"].exists)
        XCTAssertFalse(app.staticTexts["今天想做点什么？"].exists)
        XCTAssertFalse(app.staticTexts["有一件事需要核对"].exists)
        XCTAssertFalse(app.staticTexts["天气暂未更新"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "BOSS")).firstMatch.exists)
        attach("home-inspiration-weather")
        XCTAssertTrue(tab(app, "records").exists)
        XCTAssertTrue(tab(app, "discover").exists)
        let composer = app.descendants(matching: .any).matching(identifier: "assistant-composer").firstMatch
        XCTAssertTrue(composer.exists)
        XCTAssertLessThanOrEqual(composer.frame.maxY, tab(app, "conversation").frame.minY + 2)
        XCTAssertLessThan(tab(app, "conversation").frame.midX, tab(app, "discover").frame.midX)
        XCTAssertLessThan(tab(app, "discover").frame.midX, tab(app, "records").frame.midX)
        tab(app, "records").tap()
        XCTAssertTrue(app.buttons["回到对话"].waitForExistence(timeout: 5))
        tab(app, "discover").tap()
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "discovery-after-tab-tap"; capture.lifetime = .keepAlways; add(capture)
        XCTAssertTrue(app.buttons["discover-channel-game"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["discover-channel-weibo"].exists)
        app.buttons["discover-channel-game"].tap()
        XCTAssertTrue(app.otherElements["discover-content-game"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["discover-game-steamDeals"].exists)
        XCTAssertFalse(app.buttons["Steam折扣"].exists)
        app.buttons["discover-game-news"].tap()
        XCTAssertFalse(app.buttons["国内"].exists)
        XCTAssertFalse(app.buttons["国际"].exists)
        XCTAssertTrue(tab(app, "discover").isHittable)
        XCTAssertFalse(app.buttons["返回发现"].exists)
        tab(app, "conversation").tap()
        XCTAssertTrue(app.staticTexts["常用操作"].waitForExistence(timeout: 5))
    }
    func testChannelSwitchesKeepNavigationAndSelectorFramesFixed() {
        let app = launch()
        tab(app, "discover").tap()
        let navigation = app.otherElements["discover-fixed-header"]
        XCTAssertTrue(navigation.waitForExistence(timeout: 10))
        let navFrame = navigation.frame
        let tabsFrame = tab(app, "conversation").frame
        let selectorY = app.buttons["discover-channel-ai"].frame.minY
        for channel in ["game", "headline", "market", "ai"] {
            app.buttons["discover-channel-" + channel].tap()
            XCTAssertTrue(app.otherElements["discover-content-" + channel].waitForExistence(timeout: 10))
            XCTAssertEqual(navigation.frame.minY, navFrame.minY, accuracy: 1)
            XCTAssertEqual(navigation.frame.height, navFrame.height, accuracy: 1)
            XCTAssertEqual(tab(app, "conversation").frame.minY, tabsFrame.minY, accuracy: 1)
            XCTAssertEqual(app.buttons["discover-channel-ai"].frame.minY, selectorY, accuracy: 1)
            // The root keeps all three pages mounted, so the composer still
            // exists in the tree; it must not be reachable while Discover is
            // the visible page.
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "assistant-composer").firstMatch.isHittable)
            attach("fixed-shell-" + channel)
        }
    }
    func testUnifiedFeedsHaveNoCategoryControlsAndKeepChannelBarPinned() {
        let app = launch()
        tab(app, "discover").tap()
        for channel in ["ai", "headline"] {
            app.buttons["discover-channel-" + channel].tap()
            let content = app.otherElements["discover-content-" + channel]
            XCTAssertTrue(content.waitForExistence(timeout: 10))
            // SwiftUI may omit the custom inner identifier when news is still
            // loading. Locate the real scroll viewport inside the fixed page.
            let reading = content.scrollViews.firstMatch
            XCTAssertTrue(reading.waitForExistence(timeout: 10))
            XCTAssertFalse(app.buttons["discover-section-" + channel + "-all"].exists)
            let selector = app.buttons["discover-channel-ai"]
            XCTAssertGreaterThanOrEqual(reading.frame.minY, selector.frame.maxY - 1)
            let baseline = selector.frame.minY
            reading.swipeUp()
            XCTAssertEqual(selector.frame.minY, baseline, accuracy: 1)
            XCTAssertFalse(app.staticTexts["更多动态"].exists)
            XCTAssertFalse(app.staticTexts["公开 RSS · 阅读全文请跳转原文"].exists)
            attach("unified-feed-" + channel)
        }
        tab(app, "conversation").tap()
        let homeScroll = app.scrollViews.firstMatch
        for channel in ["ai", "market", "game", "music", "headline", "weibo"] {
            if !app.buttons["home-channel-" + channel].exists { homeScroll.swipeUp() }
            XCTAssertTrue(app.buttons["home-channel-" + channel].exists)
        }
        for _ in 0..<3 {
            if app.buttons["home-channel-ai"].isHittable { break }
            homeScroll.swipeDown()
        }
        app.buttons["home-channel-ai"].tap()
        XCTAssertTrue(app.otherElements["discover-content-ai"].waitForExistence(timeout: 10))
    }
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testDraftSurvivesTabSwitchAndAppRelaunchWithoutSending() {
        let app = launch()
        let composer = app.descendants(matching: .any).matching(identifier: "assistant-composer").firstMatch
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap()
        composer.typeText("draft preserved without sending")
        app.buttons["收起键盘"].tap()
        tab(app, "discover").tap()
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "draft-after-discovery-tab"; capture.lifetime = .keepAlways; add(capture)
        XCTAssertTrue(app.buttons["discover-channel-music"].waitForExistence(timeout: 10))
        tab(app, "conversation").tap()
        XCTAssertTrue((app.descendants(matching: .any).matching(identifier: "assistant-composer").firstMatch.value as? String ?? "").contains("draft preserved"))
        app.terminate()
        app.launch()
        let restored = app.descendants(matching: .any).matching(identifier: "assistant-composer").firstMatch
        XCTAssertTrue(restored.waitForExistence(timeout: 10))
        XCTAssertTrue((restored.value as? String ?? "").contains("draft preserved"))
    }

    func testNightSeaAndGildedAppearancePalettesRender() {
        for palette in ["nightSea", "gilded"] {
            let app = XCUIApplication()
            app.launchEnvironment["WHALE_DEMO_HOME"] = "1"
            app.launchEnvironment["WHALE_DEMO_PALETTE"] = palette
            app.launch()
            XCTAssertTrue(tab(app, "conversation").waitForExistence(timeout: 30))
            attach("home-palette-" + palette)
            app.terminate()
        }
    }

    func testAppearancePaletteChoicePersistsAcrossRelaunch() {
        let app = launch()
        app.buttons["assistant-settings"].tap()
        let gilded = app.buttons["appearance-palette-gilded"]
        if !gilded.waitForExistence(timeout: 5) {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(gilded.waitForExistence(timeout: 5))
        gilded.tap()
        XCTAssertTrue(gilded.isSelected)
        app.terminate()

        let relaunched = XCUIApplication()
        relaunched.launchEnvironment["WHALE_DEMO_HOME"] = "1"
        relaunched.launch()
        XCTAssertTrue(relaunched.buttons["assistant-settings"].waitForExistence(timeout: 30))
        relaunched.buttons["assistant-settings"].tap()
        let restored = relaunched.buttons["appearance-palette-gilded"]
        if !restored.waitForExistence(timeout: 5) {
            relaunched.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(restored.waitForExistence(timeout: 5))
        XCTAssertTrue(restored.isSelected)
    }

}
