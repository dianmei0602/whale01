import XCTest
@testable import WhaleAgent

final class ThemeTests: XCTestCase {
    private let storeKey = "whale.theme.style.v1"

    func testThemeStylePersistsAndIsAvailableInPalette() {
        let manager = ThemeManager.shared
        let originalStyle = manager.style
        let originalRaw = UserDefaults.standard.string(forKey: storeKey)
        defer {
            manager.style = originalStyle
            UserDefaults.standard.set(originalRaw, forKey: storeKey)
        }

        manager.style = .premium

        XCTAssertEqual(UserDefaults.standard.string(forKey: storeKey), WhaleThemeStyle.premium.rawValue)
        XCTAssertEqual(manager.palette.style, .premium)
        XCTAssertTrue(WhaleThemeStyle.allCases.contains(.flat))
        XCTAssertTrue(WhaleThemeStyle.allCases.contains(.premium))
    }
}
