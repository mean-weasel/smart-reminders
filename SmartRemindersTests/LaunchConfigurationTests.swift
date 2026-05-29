import XCTest
@testable import SmartReminders

final class LaunchConfigurationTests: XCTestCase {
    func testInitialIntentTextUsesDebugEnvironmentValue() {
        let text = LaunchConfiguration.initialIntentText(
            environment: ["SMART_REMINDERS_INITIAL_TEXT": "Make smoothies this week"]
        )

        XCTAssertEqual(text, "Make smoothies this week")
    }
}
