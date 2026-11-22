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
        XCTAssertEqual(dark[.background], 0x22292B)
        XCTAssertEqual(dark[.ink], 0xFFF8E7)
        XCTAssertEqual(dark[.danger], 0xEF858C)
    }

    func testGildedPaletteKeepsGoldBrownAndJadeDistinct() {
        let light = WhalePaletteResolver.lightValues(.gilded)
        XCTAssertEqual(light[.accent], 0x0D4D76)
        XCTAssertEqual(light[.accentSoft], 0xFBDC92)
        XCTAssertEqual(light[.coral], 0x944523)

        let dark = WhalePaletteResolver.darkValues(.gilded)
        XCTAssertEqual(dark[.background], 0x2A241B)
        XCTAssertEqual(dark[.ink], 0xFFF0C9)
        XCTAssertEqual(dark[.accent], 0xFFE4A1)
        XCTAssertEqual(dark[.accentDeep], 0x72B4DA)
    }

    func testAppearancePreviewsUseTheColorsActuallyRendered() {
        for palette in WhalePaletteStyle.allCases {
            let light = palette.previewValues(isDark: false)
            let lightTokens = WhalePaletteResolver.lightValues(palette)
            XCTAssertEqual(light.background, lightTokens[.background])
            XCTAssertEqual(light.card, lightTokens[.card])
            XCTAssertEqual(light.accent, lightTokens[.accent])
            XCTAssertEqual(light.notice, lightTokens[.danger])
            XCTAssertEqual(light.ink, lightTokens[.ink])

            let dark = palette.previewValues(isDark: true)
            let darkTokens = WhalePaletteResolver.darkValues(palette)
            XCTAssertEqual(dark.background, darkTokens[.background])
            XCTAssertEqual(dark.card, darkTokens[.card])
            XCTAssertEqual(dark.accent, darkTokens[.accent])
            XCTAssertEqual(dark.notice, darkTokens[.danger])
            XCTAssertEqual(dark.ink, darkTokens[.ink])
        }
    }

    @MainActor
    func testAppearanceStorePublishesAndPersistsTheSelectedPalette() {
        let suite = "whale.appearance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = WhaleAppearanceStore(defaults: defaults)
        XCTAssertEqual(store.palette, .seaSalt)
        store.select(.nightSea)
        XCTAssertEqual(store.palette, .nightSea)
        XCTAssertEqual(
            defaults.string(forKey: WhalePaletteStyle.storageKey),
            WhalePaletteStyle.nightSea.rawValue
        )

        let restored = WhaleAppearanceStore(defaults: defaults)
        XCTAssertEqual(restored.palette, .nightSea)
    }

    @MainActor
    func testHomeShortcutLayoutMovesDraggedChannelBeforeTargetAndPersists() {
        let suite = "whale.home.shortcuts.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let layout = HomeShortcutLayoutStore(defaults: defaults)
        XCTAssertEqual(layout.visibleChannels, DiscoverChannel.allCases)

        layout.move(.weibo, before: .ai)
        XCTAssertEqual(layout.visibleChannels.first, .weibo)

        let restored = HomeShortcutLayoutStore(defaults: defaults)
        XCTAssertEqual(restored.visibleChannels.first, .weibo)
    }

    @MainActor
    func testHomeShortcutLayoutHidesAndRestoresEveryChannel() {
        let suite = "whale.home.shortcuts.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let layout = HomeShortcutLayoutStore(defaults: defaults)
        layout.hide(.music)
        XCTAssertFalse(layout.visibleChannels.contains(.music))

        layout.restoreAll()
        XCTAssertEqual(layout.visibleChannels, DiscoverChannel.allCases)
    }

    @MainActor
    func testSpeechPlaybackRejectsMissingXfyunInsteadOfUsingSystemVoice() {
        let speech = SpeechPlaybackController(configProvider: { nil })
        XCTAssertFalse(speech.speak("这段内容只能用讯飞小露朗读"))

        XCTAssertFalse(speech.isSpeaking)
        XCTAssertEqual(
            speech.lastErrorText,
            "未配置讯飞小露 x4_yezi，App 朗读暂不可用"
        )
    }

    func testAppearancePalettesKeepKeyTextAboveAccessibilityContrast() {
        let checks: [(String, WhalePaletteStyle, WhalePaletteToken, WhalePaletteToken)] = [
            ("night ink", .nightSea, .ink, .background),
            ("night muted", .nightSea, .muted, .background),
            ("night button", .nightSea, .onAccent, .accent),
            ("gilded ink", .gilded, .ink, .background),
            ("gilded muted", .gilded, .muted, .background),
            ("gilded jade", .gilded, .accent, .background),
            ("gilded dark gold", .gilded, .ink, .background)
        ]
        for (name, style, foreground, background) in checks {
            let values = name.hasPrefix("gilded dark")
                ? WhalePaletteResolver.darkValues(style)
                : WhalePaletteResolver.lightValues(style)
            let ratio = contrast(values[foreground]!, values[background]!)
            XCTAssertGreaterThanOrEqual(ratio, 4.5, name)
        }
    }

    func testWorkingContextPersistsAndExpiresWithoutLeakingOldTasks() {
        let suite = "whale.working.context.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AgentWorkingContextStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        store.save(
            AgentWorkingContext(
                goal: "整理周报",
                status: .awaitingConfirmation,
                summary: "等待确认创建日程",
                sourceMessageId: "message-1",
                updatedAt: now
            )
        )
        XCTAssertEqual(store.load(now: now.addingTimeInterval(60))?.goal, "整理周报")
        XCTAssertNil(store.load(now: now.addingTimeInterval(25 * 60 * 60)))
        XCTAssertNil(store.load(now: now.addingTimeInterval(26 * 60 * 60)))
    }

    func testSharedOperationPreviewShowsEveryTodoDecision() {
        let preview = OperationPreview.todo(
            TodoQuickPreview(
                title: "整理周报",
                dueAt: Date(timeIntervalSince1970: 1_800_000_000),
                project: "工作",
                estimatedMinutes: 45,
                originalText: "明天下午三点整理周报 #工作 预计45分钟"
            )
        )
        XCTAssertEqual(preview.kind, .create)
        XCTAssertEqual(preview.title, "新建待办")
        XCTAssertEqual(Set(preview.rows.map(\.label)), ["时间", "项目", "预计"])
        XCTAssertEqual(preview.confirmLabel, "确认添加")
    }

    func testPendingToolPreviewUsesTheSameOperationContract() {
        let pending = PendingTool(
            tool: "create_reminder",
            toolCallId: "call-preview",
            operationId: "operation-preview",
            arguments: [
                "title": .string("取快递"),
                "dueAt": .string("2026-11-20T15:00:00+08:00")
            ],
            requiresConfirmation: true
        )
        let preview = OperationPreview.pending(pending)
        XCTAssertEqual(preview.kind, .create)
        XCTAssertEqual(preview.title, "创建提醒")
        XCTAssertTrue(preview.rows.contains { $0.label == "内容" && $0.value == "取快递" })
        XCTAssertFalse(preview.note.isEmpty)
    }

    func testHomePlannerDoesNotPromoteEmptyStates() {
        let empty = AssistantCommandPlanner.items(
            now: Date(),
            events: [],
            todos: [],
            records: [],
            pendingConfirmation: nil
        )
        XCTAssertTrue(empty.allSatisfy { !$0.isActionable })

        let pending = PendingTool(
            tool: "create_reminder",
            toolCallId: "call-1",
            operationId: "op-1",
            arguments: ["title": .string("取快递")],
            requiresConfirmation: true
        )
        let actionable = AssistantCommandPlanner.items(
            now: Date(),
            events: [],
            todos: [],
            records: [],
            pendingConfirmation: pending
        )
        XCTAssertTrue(actionable.contains { $0.kind == .needsYou && $0.isActionable && $0.isWarning })
    }

    func testHomePlannerDoesNotUseAllDayCalendarEntriesAsPrimaryTask() throws {
        let now = Date()
        let allDay = try XCTUnwrap(CalendarEventPreview(json: .object([
            "eventId": .string("solar-term"),
            "title": .string("小雪"),
            "startAt": .string(ToolDate.iso(now)),
            "endAt": .string(ToolDate.iso(now.addingTimeInterval(86_400))),
            "isAllDay": .bool(true),
            "calendarTitle": .string("节假日")
        ])))
        let items = AssistantCommandPlanner.items(
            now: now,
            events: [allDay],
            todos: [],
            records: [],
            pendingConfirmation: nil
        )
        XCTAssertFalse(items.contains { $0.kind == .next && $0.isActionable })
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
        XCTAssertTrue(clusters.allSatisfy { $0.sourceCount >= 2 && $0.itemIDs.count >= 2 })
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

    func testLegacySavedArticleDecodesIntoReadingQueue() throws {
        let json = """
        {"id":"article-1","title":"旧收藏","summary":"摘要","source":"来源","link":"https://example.com","channel":"ai","savedAt":0,"isReadLater":true}
        """
        let article = try JSONDecoder().decode(SavedArticle.self, from: Data(json.utf8))
        XCTAssertEqual(article.status, .toRead)
        XCTAssertEqual(article.progress, 0)
    }

    private func contrast(_ foreground: UInt32, _ background: UInt32) -> Double {
        let lighter = max(luminance(foreground), luminance(background))
        let darker = min(luminance(foreground), luminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func luminance(_ value: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let raw = Double((value >> shift) & 0xFF) / 255
            return raw <= 0.04045 ? raw / 12.92 : pow((raw + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }
}
