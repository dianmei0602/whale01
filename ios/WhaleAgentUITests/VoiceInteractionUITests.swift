import XCTest

final class VoiceInteractionUITests: XCTestCase {
    func testMicrophonePresentsVoiceSheet() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["WHALE_DEMO_HOME"] = "1"
        app.launch()

        let microphone = app.buttons["语音输入"]
        XCTAssertTrue(microphone.waitForExistence(timeout: 15))
        microphone.tap()

        XCTAssertTrue(app.otherElements["voice-sheet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["语音对话"].exists)
    }
}
