import XCTest

final class InteractionUITests: XCTestCase {
    private func tab(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons["tab-" + name]
    }

    private func launch(
        additionalEnvironment: [String: String] = [:]
    ) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["WHALE_DEMO_HOME"] = "1"
        app.launchEnvironment["WHALE_DEMO_INITIAL_CHANNEL"] = "ai"
        app.launchEnvironment["WHALE_DEMO_PALETTE"] = "seaSalt"
        app.launchEnvironment["WHALE_DEMO_VOICE"] = "1"
        for (key, value) in additionalEnvironment {
            app.launchEnvironment[key] = value
        }
        app.launch()
        return app
    }

    private func chatSurface(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "whale-agent-chat-surface")
            .firstMatch
    }

    private func openChat(_ app: XCUIApplication) {
        let start = app.buttons["home-start-conversation"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        XCTAssertTrue(chatSurface(app).waitForExistence(timeout: 10))
    }

    func testHomeIsDefaultAndChatCanReturnHome() {
        let app = launch()
        XCTAssertTrue(
            app.buttons["home-start-conversation"].waitForExistence(timeout: 10)
        )
        XCTAssertFalse(chatSurface(app).exists)

        openChat(app)
        tab(app, "conversation").tap()

        XCTAssertTrue(
            app.buttons["home-start-conversation"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(chatSurface(app).exists)
    }

    func testHomeRendersCurrentLandingContent() {
        let app = launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["home-inspiration-card"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["home-today-card"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.buttons["home-start-conversation"].exists)
    }

    func testThreeTabsKeepDiscoverySeparateFromTheAssistant() {
        let app = launch()
        XCTAssertTrue(tab(app, "conversation").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["home-start-conversation"].exists)
        openChat(app)
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "我是鲸鱼")
            ).firstMatch.exists
        )
        XCTAssertTrue(app.descendants(matching: .any)["agent-welcome-header"].exists)
        XCTAssertFalse(app.staticTexts["常用操作"].exists)
        attach("life-agent-chat")
        XCTAssertTrue(tab(app, "records").exists)
        XCTAssertTrue(tab(app, "discover").exists)
        let composer = chatComposer(app)
        XCTAssertTrue(composer.exists)
        XCTAssertLessThanOrEqual(composer.frame.maxY, tab(app, "conversation").frame.minY + 2)
        XCTAssertLessThan(tab(app, "conversation").frame.midX, tab(app, "discover").frame.midX)
        XCTAssertLessThan(tab(app, "discover").frame.midX, tab(app, "records").frame.midX)
        tab(app, "records").tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["workspace-tasks-overview"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["workspace-section-inbox"].exists)
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
        XCTAssertTrue(chatSurface(app).waitForExistence(timeout: 5))
    }

    func testWorkspaceRootCombinesTasksAndWorkspaceContent() {
        let app = launch()
        tab(app, "records").tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["workspace-tasks-overview"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(
            app.buttons["workspace-section-inbox"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.buttons["workspace-open-todo"].exists)
        attach("workspace-tasks-and-content")
    }

    func testWorkspaceTodoPageCanReturnToWorkspaceOverview() {
        let app = launch()
        tab(app, "records").tap()

        let openAll = app.buttons["workspace-open-todo"]
        XCTAssertTrue(openAll.waitForExistence(timeout: 10))
        openAll.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["workspace-todo-list"]
                .waitForExistence(timeout: 10)
        )

        let navigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
        navigationBar.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["workspace-tasks-overview"]
                .waitForExistence(timeout: 5)
        )
    }

    func testTodoCompletionRefreshesHomeAndWorkspaceSummary() {
        let app = launch(additionalEnvironment: [
            "WHALE_DEMO_TODO_SYNC": "1"
        ])

        tab(app, "records").tap()
        XCTAssertTrue(
            app.staticTexts["验证跨页面同步"].waitForExistence(timeout: 10)
        )
        app.buttons["完成 验证跨页面同步"].tap()

        tab(app, "conversation").tap()
        XCTAssertFalse(app.staticTexts["验证跨页面同步"].exists)

        tab(app, "records").tap()
        XCTAssertTrue(app.staticTexts["目前没有未完成事项。"].exists)
    }

    func testWorkspaceSectionsKeepIndependentScrollPositions() {
        let app = launch()
        tab(app, "records").tap()

        let inbox = app.buttons["workspace-section-inbox"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 10))
        app.swipeUp()
        app.swipeUp()

        let reading = app.buttons["workspace-section-reading"]
        if !reading.isHittable {
            app.swipeDown()
        }
        reading.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["workspace-section-content-reading"]
                .waitForExistence(timeout: 5)
        )

        inbox.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["workspace-section-content-inbox"]
                .waitForExistence(timeout: 5)
        )
    }

    func testWorkspaceEditorRejectsAccidentalSwipeDismiss() {
        let app = launch()
        tab(app, "records").tap()
        app.buttons["workspace-section-inbox"].tap()
        app.buttons["workspace-open-capture-editor"].tap()

        let editor = app.textViews["workspace-capture-body"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("未保存内容")

        app.swipeDown()
        XCTAssertTrue(editor.exists)
    }

    func testHomeDoesNotRepeatWorkspaceEntryWhenWorkspaceIsEmpty() {
        let app = launch(additionalEnvironment: [
            "WHALE_DEMO_WORKSPACE_EMPTY": "1"
        ])

        XCTAssertTrue(
            app.descendants(matching: .any)["home-inspiration-card"].exists
        )
        XCTAssertFalse(app.buttons["home-workspace"].exists)
        XCTAssertTrue(app.buttons["home-start-conversation"].exists)
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
            XCTAssertFalse(chatComposer(app).isHittable)
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
        XCTAssertTrue(
            app.buttons["home-start-conversation"]
                .waitForExistence(timeout: 10)
        )
        tab(app, "discover").tap()
        XCTAssertTrue(app.otherElements["discover-content-ai"].waitForExistence(timeout: 10))
    }
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func openSettings(_ app: XCUIApplication) {
        if !app.buttons["assistant-settings"].exists {
            openChat(app)
        }
        let more = app.buttons["assistant-settings"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        let settings = app.buttons["设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
    }
    func testDraftSurvivesTabSwitchAndAppRelaunchWithoutSending() {
        let app = launch()
        openChat(app)
        let composer = chatComposer(app)
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap()
        composer.typeText("draft preserved without sending")
        app.scrollViews.firstMatch.tap()
        tab(app, "discover").tap()
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "draft-after-discovery-tab"; capture.lifetime = .keepAlways; add(capture)
        XCTAssertTrue(app.buttons["discover-channel-music"].waitForExistence(timeout: 10))
        tab(app, "conversation").tap()
        XCTAssertTrue((chatComposer(app).value as? String ?? "").contains("draft preserved"))
        app.terminate()
        app.launch()
        openChat(app)
        let restored = chatComposer(app)
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
        openSettings(app)
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
        openSettings(relaunched)
        let restored = relaunched.buttons["appearance-palette-gilded"]
        if !restored.waitForExistence(timeout: 5) {
            relaunched.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(restored.waitForExistence(timeout: 5))
        XCTAssertTrue(restored.isSelected)
    }

    func testEveryAppearancePaletteUpdatesInPlace() {
        let app = launch()
        openSettings(app)

        let paletteNames = ["seaSalt": "海盐", "nightSea": "夜海", "gilded": "鎏金"]
        let current = app.staticTexts["appearance-current"]
        XCTAssertTrue(current.waitForExistence(timeout: 5))

        for palette in ["seaSalt", "nightSea", "gilded"] {
            let option = app.buttons["appearance-palette-" + palette]
            if !option.waitForExistence(timeout: 5) {
                app.scrollViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.tap()
            XCTAssertTrue(option.isSelected)
            let expected = "当前 " + (paletteNames[palette] ?? "")
            let updated = NSPredicate(format: "label == %@", expected)
            expectation(for: updated, evaluatedWith: current)
            waitForExpectations(timeout: 5)
            // Screenshot capture can otherwise read the previous compositor
            // frame even though the accessibility selected state has updated.
            Thread.sleep(forTimeInterval: 2)
            attach("appearance-live-" + palette)
        }

        app.buttons["关闭设置"].tap()
        XCTAssertTrue(tab(app, "conversation").waitForExistence(timeout: 10))
        attach("home-live-gilded")
    }

    func testLifeAgentSuggestionPrefillsDraft() {
        let app = launch()
        openChat(app)
        let prompt = app.buttons["agent-prompt-今天怎么安排？"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10))
        prompt.tap()
        let composer = chatComposer(app)
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "value CONTAINS %@", "今天怎么安排")
        expectation(for: predicate, evaluatedWith: composer)
        waitForExpectations(timeout: 5)
        attach("life-agent-prompt-prefilled")
    }

    func testVoiceExperienceUsesOneSharedSheet() {
        let app = launch()
        openChat(app)
        let voice = app.buttons["whale-chat-voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 10))
        voice.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["whale-voice-capture-sheet"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["whale-voice-cancel"].exists)
        app.buttons["whale-voice-cancel"].tap()
        XCTAssertTrue(chatComposer(app).waitForExistence(timeout: 5))
    }

    private func chatComposer(_ app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(
            format: "placeholderValue == %@ OR label == %@",
            "给鲸鱼发消息",
            "给鲸鱼发消息"
        )
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

}
