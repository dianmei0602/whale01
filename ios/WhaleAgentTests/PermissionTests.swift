import EventKit
import XCTest
@testable import WhaleAgent

@MainActor
final class PermissionTests: XCTestCase {
    func testReminderWriteOnlyStateRemainsDistinctFromDenied() {
        XCTAssertEqual(PermissionCenter.reminderState(for: .fullAccess), .granted)
        XCTAssertEqual(PermissionCenter.reminderState(for: .writeOnly), .addOnly)
        XCTAssertEqual(PermissionCenter.reminderState(for: .denied), .denied)
        XCTAssertEqual(PermissionCenter.reminderState(for: .restricted), .restricted)
        XCTAssertEqual(PermissionCenter.reminderState(for: .notDetermined), .notDetermined)
    }
}
