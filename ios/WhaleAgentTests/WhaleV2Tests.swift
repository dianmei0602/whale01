import XCTest
@testable import WhaleAgent

final class WhaleV2Tests: XCTestCase {
    func testInteractionPhaseKeepsTerminalStatesDistinct() {
        XCTAssertTrue(AgentInteractionPhase.listening.isActive)
        XCTAssertTrue(AgentInteractionPhase.awaitingConfirmation.isActive)
        XCTAssertFalse(AgentInteractionPhase.completed.isActive)
        XCTAssertFalse(AgentInteractionPhase.failed.isActive)
        XCTAssertFalse(AgentInteractionPhase.cancelled.isActive)
        XCTAssertEqual(AgentInteractionPhase.executing.title, "正在执行")
    }

    func testVersionedSkillManifestSeparatesToolsAndThinkingSkills() throws {
        let manifest = try XCTUnwrap(AgentSkillManifestStore.load())
        XCTAssertEqual(manifest.version, "2.0")
        XCTAssertTrue(manifest.isValid)
        XCTAssertEqual(manifest.definition(for: .schedule)?.kind, .tool)
        XCTAssertEqual(manifest.definition(for: .writing)?.kind, .thinking)
        XCTAssertTrue(manifest.definition(for: .research)?.tools.contains("research_web") == true)
        XCTAssertTrue(manifest.definition(for: .general)?.tools.isEmpty == true)
    }

    func testNightSeaPaletteUsesReferenceColorsAcrossBothModes() {
        let light = WhalePaletteResolver.lightValues(.nightSea)
        XCTAssertEqual(light[.accent], 0x0E4258)
        XCTAssertEqual(light[.danger], 0x992E34)
        XCTAssertEqual(light[.background], 0xF9F6E5)

        let dark = WhalePaletteResolver.darkValues(.nightSea)
        XCTAssertEqual(dark[.background], 0x090C0E)
        XCTAssertEqual(dark[.ink], 0xF9F6E5)
        XCTAssertEqual(dark[.danger], 0xEF858C)
    }

    func testGildedPaletteKeepsGoldBrownAndJadeDistinct() {
        let light = WhalePaletteResolver.lightValues(.gilded)
        XCTAssertEqual(light[.accent], 0x0D4D76)
        XCTAssertEqual(light[.accentSoft], 0xFBDC92)
        XCTAssertEqual(light[.coral], 0x944523)

        let dark = WhalePaletteResolver.darkValues(.gilded)
        XCTAssertEqual(dark[.background], 0x090807)
        XCTAssertEqual(dark[.ink], 0xFBDC92)
        XCTAssertEqual(dark[.accent], 0xFBDC92)
        XCTAssertEqual(dark[.accentDeep], 0x4F91B8)
    }

    func testVoiceCorrectionUsesOnlyExplainableTermsAndKeepsIntentOrder() {
        let analysis = VoiceDraftAnalyzer.analyze(
            "deepseek 帮我看看明天安排，然后提醒我取快递",
            engine: "讯飞语音",
            elapsed: 4.9,
            personalTerms: ["小陆": "小露"]
        )
        XCTAssertTrue(analysis.correctedText.contains("DeepSeek"))
        XCTAssertEqual(analysis.intents.count, 2)
        XCTAssertTrue(analysis.intents[0].contains("看看明天安排"))
        XCTAssertTrue(analysis.intents[1].contains("提醒我取快递"))
        XCTAssertTrue(analysis.diagnostics.contains { $0.label == "听写" })
        XCTAssertTrue(analysis.corrections.allSatisfy { !$0.reason.isEmpty })
    }

    func testPersonalLanguageStoreIsScopedToInjectedDefaults() {
        let suite = "whale.voice.terms.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PersonalLanguageStore(defaults: defaults)
        store.set(spoken: "鲸鱼零零一", intended: "鲸鱼001")
        XCTAssertEqual(store.terms()["鲸鱼零零一"], "鲸鱼001")
        store.remove(spoken: "鲸鱼零零一")
        XCTAssertNil(store.terms()["鲸鱼零零一"])
    }

    func testNewsTopicsAreGroupedFromRealHeadlines() {
        let rows = [
            NewsItem(id: "1", title: "国产大模型推出新版本", summary: "摘要内容足够长，用于测试。", source: "A", link: "https://example.com/1", publishedAt: nil, channel: "ai", rank: nil),
            NewsItem(id: "2", title: "国产大模型开放新能力", summary: "摘要内容足够长，用于测试。", source: "B", link: "https://example.com/2", publishedAt: nil, channel: "ai", rank: nil),
            NewsItem(id: "3", title: "游戏公司公布季度业绩", summary: "摘要内容足够长，用于测试。", source: "C", link: "https://example.com/3", publishedAt: nil, channel: "game", rank: nil)
        ]
        let clusters = NewsTopicClusterer.clusters(rows)
        XCTAssertTrue(clusters.contains { $0.count >= 2 })
        XCTAssertTrue(clusters.allSatisfy { $0.itemIDs.count == $0.count || $0.count > 5 })
    }

    func testTodoRichPreviewExtractsProjectTimeAndEstimate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 10))!
        let preview = TodoQuickParser.parsePreview(
            "明天下午三点整理周报 #工作 预计45分钟",
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(preview.project, "工作")
        XCTAssertEqual(preview.estimatedMinutes, 45)
        XCTAssertEqual(calendar.component(.day, from: preview.dueAt!), 20)
        XCTAssertEqual(calendar.component(.hour, from: preview.dueAt!), 15)
        XCTAssertTrue(preview.title.contains("整理周报"))
        XCTAssertFalse(preview.title.contains("工作"))
        XCTAssertFalse(preview.title.contains("45分钟"))
    }

    func testTodoMetadataPersistsWithoutChangingEventKitIdentity() throws {
        let suite = "whale.todo.metadata.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = TodoMetadataStore(defaults: defaults)
        store.set(
            TodoMetadata(project: "鲸鱼 2.0", priority: 1, estimatedMinutes: 30, source: "local"),
            for: "reminder-1"
        )
        XCTAssertEqual(store.metadata(for: "reminder-1").project, "鲸鱼 2.0")
        XCTAssertEqual(store.metadata(for: "reminder-1").priority, 1)
        store.remove("reminder-1")
        XCTAssertNil(store.metadata(for: "reminder-1").project)
    }

    func testTodoBoardUsesDueDateAndInboxSemantics() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 10))!
        let today = try XCTUnwrap(TodoReminder(json: .object([
            "recordId": .string("today"),
            "title": .string("今天的任务"),
            "dueAt": .string(ToolDate.iso(calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 17))!)),
            "completed": .bool(false)
        ])))
        let inbox = try XCTUnwrap(TodoReminder(json: .object([
            "recordId": .string("inbox"),
            "title": .string("无日期任务"),
            "completed": .bool(false)
        ])))
        XCTAssertTrue(TodoBoard.today.includes(today, now: now, calendar: calendar))
        XCTAssertFalse(TodoBoard.planned.includes(today, now: now, calendar: calendar))
        XCTAssertTrue(TodoBoard.inbox.includes(inbox, now: now, calendar: calendar))
    }

    func testSchedulePlannerAvoidsRealCalendarEvents() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 8))!
        let event = try XCTUnwrap(CalendarEventPreview(json: .object([
            "eventId": .string("event-1"),
            "title": .string("晨会"),
            "startAt": .string(ToolDate.iso(calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 9))!)),
            "endAt": .string(ToolDate.iso(calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 10))!)),
            "calendarTitle": .string("工作")
        ])))
        let item = try XCTUnwrap(TodoReminder(json: .object([
            "recordId": .string("focus"),
            "title": .string("写方案"),
            "completed": .bool(false),
            "notes": .string("预计 30 分钟")
        ])))
        let candidates = TodoSchedulePlanner.candidates(
            for: item,
            events: [event],
            now: now,
            calendar: calendar
        )
        XCTAssertFalse(candidates.isEmpty)
        XCTAssertTrue(candidates.allSatisfy { candidate in
            candidate.end <= event.startAt || candidate.start >= event.endAt
        })
    }
}
