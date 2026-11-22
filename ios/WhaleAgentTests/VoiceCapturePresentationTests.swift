import XCTest
@testable import WhaleAgent

final class VoiceCapturePresentationTests: XCTestCase {
    func testChatListeningCopyIsConsistent() {
        let value = VoiceCapturePresentation.content(
            target: .chat,
            phase: .listening,
            transcript: ""
        )
        XCTAssertEqual(value.title, "给鲸鱼说")
        XCTAssertEqual(value.actionTitle, "完成")
        XCTAssertTrue(value.showsWaveform)
    }

    func testReviewDoesNotAutoCommit() {
        let value = VoiceCapturePresentation.content(
            target: .todo,
            phase: .review("明天下午提醒我取快递"),
            transcript: "明天下午提醒我取快递"
        )
        XCTAssertEqual(value.actionTitle, "填入待办")
        XCTAssertFalse(value.showsWaveform)
        XCTAssertTrue(value.actionEnabled)
    }

    func testFailureOffersOneRetryAction() {
        let value = VoiceCapturePresentation.content(
            target: .workspace,
            phase: .failed("没有收到最终结果"),
            transcript: ""
        )
        XCTAssertEqual(value.actionTitle, "再试一次")
        XCTAssertFalse(value.showsWaveform)
    }
}
