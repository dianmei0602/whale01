import XCTest
@testable import WhaleAgent

final class IMessageHomeTests: XCTestCase {
    private let quote = DailyQuoteCorpus.Item(
        id: "test-quote",
        theme: "测试",
        text: "知之为知之，不知为不知。",
        source: "《论语》",
        locator: "论语·为政",
        tone: "克制"
    )

    func testStarterDoesNotInventCalendarEntriesWhenCalendarIsEmpty() throws {
        let items = WhaleIMessageStarterBuilder.items(
            now: Date(timeIntervalSince1970: 1_800_000_000),
            events: [],
            quote: quote
        )
        let summary = try XCTUnwrap(items.first?.detail)
        XCTAssertEqual(summary, "今天暂时没有日程。直接告诉我想做什么。")
        XCTAssertFalse(items.contains { $0.kind == .calendar })
        XCTAssertFalse(items.contains { $0.kind == .music })
        XCTAssertFalse(items.contains { $0.kind == .pending })
    }

    func testStarterUsesRealCalendarTitleInsteadOfGenericAssistantCopy() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let event = try XCTUnwrap(
            CalendarEventPreview(
                json: .object([
                    "eventId": .string("event-1"),
                    "title": .string("牙医复诊"),
                    "startAt": .string(ToolDate.iso(start)),
                    "endAt": .string(ToolDate.iso(start.addingTimeInterval(1_800))),
                    "calendarTitle": .string("个人")
                ])
            )
        )
        let items = WhaleIMessageStarterBuilder.items(
            now: start.addingTimeInterval(-3_600),
            events: [event],
            quote: quote
        )
        XCTAssertTrue(items.first?.detail?.contains("牙医复诊") == true)
    }

    func testStarterAddsMusicAndPendingOnlyWhenTheyExist() throws {
        let track = try XCTUnwrap(
            MusicTrackItem(
                json: .object([
                    "trackId": .string("track-1"),
                    "title": .string("海边的风"),
                    "artist": .string("测试歌手"),
                    "source": .string("local")
                ])
            )
        )
        let playback = PlaybackSnapshot(
            json: .object([
                "state": .string("playing"),
                "track": .object([
                    "trackId": .string("track-1"),
                    "title": .string("海边的风"),
                    "artist": .string("测试歌手"),
                    "source": .string("local")
                ])
            ])
        )
        let items = WhaleIMessageStarterBuilder.items(
            events: [],
            quote: quote,
            playback: playback,
            pendingCount: 2
        )
        XCTAssertEqual(track.title, "海边的风")
        XCTAssertTrue(items.contains { $0.kind == .music })
        XCTAssertTrue(items.contains { $0.kind == .pending })
    }

    func testStarterUsesOnlyTheNearestUpcomingEventAndIgnoresPastEvents() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func event(id: String, title: String, offset: TimeInterval) throws -> CalendarEventPreview {
            try XCTUnwrap(
                CalendarEventPreview(
                    json: .object([
                        "eventId": .string(id),
                        "title": .string(title),
                        "startAt": .string(ToolDate.iso(now.addingTimeInterval(offset))),
                        "endAt": .string(ToolDate.iso(now.addingTimeInterval(offset + 900))),
                        "calendarTitle": .string("个人")
                    ])
                )
            )
        }
        let past = try event(id: "past", title: "已经结束", offset: -3_600)
        let later = try event(id: "later", title: "下午散步", offset: 7_200)
        let next = try event(id: "next", title: "打电话给妈妈", offset: 1_800)

        let items = WhaleIMessageStarterBuilder.items(
            now: now,
            events: [past, later, next],
            quote: quote
        )
        XCTAssertTrue(items.first?.detail?.contains("打电话给妈妈") == true)
        XCTAssertFalse(items.first?.detail?.contains("已经结束") == true)
        XCTAssertFalse(items.first?.detail?.contains("下午散步") == true)
    }

    func testMessageSpacingGroupsConsecutiveRepliesAndSeparatesSpeakerChanges() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let user = ChatMessage(role: .user, text: "你好", createdAt: base)
        let assistant = ChatMessage(role: .assistant, text: "在", createdAt: base.addingTimeInterval(30))
        let assistantLater = ChatMessage(role: .assistant, text: "继续", createdAt: base.addingTimeInterval(70))
        let nextDay = ChatMessage(role: .assistant, text: "第二天", createdAt: base.addingTimeInterval(86_400))

        XCTAssertEqual(WhaleIMessageLayout.verticalSpacing(previous: nil, current: user), 2)
        XCTAssertEqual(WhaleIMessageLayout.verticalSpacing(previous: user, current: assistant), 10)
        XCTAssertEqual(WhaleIMessageLayout.verticalSpacing(previous: assistant, current: assistantLater), 3)
        XCTAssertEqual(WhaleIMessageLayout.verticalSpacing(previous: assistantLater, current: nextDay), 18)
        XCTAssertFalse(WhaleIMessageLayout.isSameGroup(previous: user, current: assistant))
        XCTAssertTrue(WhaleIMessageLayout.isSameGroup(previous: assistant, current: assistantLater))
        XCTAssertFalse(WhaleIMessageLayout.isSameGroup(previous: assistantLater, current: nextDay))
    }

    func testAgentDraftPlanKeepsTextAndPrefersDocumentLabel() {
        let document = URL(fileURLWithPath: "/tmp/report.pdf")
        let image = URL(fileURLWithPath: "/tmp/photo.jpg")
        let plan = WhaleAgentDraftPlan(
            text: "看看这个",
            documentURL: document,
            documentLabel: "PDF",
            imageURL: image,
            unsupportedVideoCount: 1
        )
        XCTAssertFalse(plan.isEmpty)
        XCTAssertEqual(plan.text, "看看这个")
        XCTAssertEqual(plan.primaryAttachmentDescription, "PDF")
        XCTAssertEqual(plan.unsupportedVideoCount, 1)
    }

    func testAgentDraftPlanRecognizesEmptyDraft() {
        let plan = WhaleAgentDraftPlan(
            text: "  ",
            documentURL: nil,
            documentLabel: nil,
            imageURL: nil,
            unsupportedVideoCount: 0
        )
        XCTAssertTrue(plan.isEmpty)
        XCTAssertNil(plan.primaryAttachmentDescription)
    }
}
