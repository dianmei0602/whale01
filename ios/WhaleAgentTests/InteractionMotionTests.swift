import XCTest
@testable import WhaleAgent

final class InteractionMotionTests: XCTestCase {
    func testReducedMotionUsesNoPageAnimation() {
        XCTAssertNil(
            InteractionMotion.page(reduceMotion: true)
        )
    }

    func testNormalMotionUsesShortPageAnimation() {
        XCTAssertNotNil(
            InteractionMotion.page(reduceMotion: false)
        )
    }

    func testWaveformPausesForReducedMotion() {
        XCTAssertFalse(
            InteractionMotion.waveformEnabled(reduceMotion: true)
        )
        XCTAssertTrue(
            InteractionMotion.waveformEnabled(reduceMotion: false)
        )
    }

    func testSheetAnimationHonorsReducedMotion() {
        XCTAssertNil(InteractionMotion.sheet(reduceMotion: true))
        XCTAssertNotNil(InteractionMotion.sheet(reduceMotion: false))
    }

    func testPressAnimationHonorsReducedMotion() {
        XCTAssertNil(InteractionMotion.press(reduceMotion: true))
        XCTAssertNotNil(InteractionMotion.press(reduceMotion: false))
    }
}
