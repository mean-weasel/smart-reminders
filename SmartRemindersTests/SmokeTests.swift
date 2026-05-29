import XCTest
@testable import SmartReminders

final class SmokeTests: XCTestCase {
    func testAppTypesLoad() {
        XCTAssertNotNil(ContentView())
    }
}
