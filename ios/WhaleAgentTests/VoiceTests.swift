import XCTest
@testable import WhaleAgent

final class VoiceTests: XCTestCase {
    func testXfyunTTSRequestUsesX4YeziVoice() throws {
        let payload = XfyunTTSRequest.payload(appId: "app-123", text: "你好，鲸鱼")
        let business = try XCTUnwrap(payload["business"] as? [String: Any])
        let data = try XCTUnwrap(payload["data"] as? [String: Any])

        XCTAssertEqual(business["vcn"] as? String, "x4_yezi")
        XCTAssertEqual(business["aue"] as? String, "lame")
        XCTAssertEqual(data["status"] as? Int, 2)
        XCTAssertEqual(
            data["text"] as? String,
            Data("你好，鲸鱼".utf8).base64EncodedString()
        )
    }
}
