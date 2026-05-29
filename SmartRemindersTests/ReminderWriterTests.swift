import XCTest
@testable import SmartReminders

final class ReminderWriterTests: XCTestCase {
    func testMockWriterReturnsLinksForApprovedDrafts() async throws {
        let sessionID = UUID()
        let draftID = UUID()
        let draft = ReminderDraft(
            id: draftID,
            title: "Make a fruit protein smoothie",
            notes: "Use frozen berries.",
            dueDate: Date(timeIntervalSince1970: 200),
            hasTime: true,
            recurrence: .weekly,
            priority: .medium,
            targetList: "Reminders",
            labels: ["smoothies"],
            confidence: 0.9,
            ambiguityFlags: ["date_inferred"],
            isUndated: false
        )
        let writer = MockReminderWriter(resultIDs: ["apple-1"])

        let links = try await writer.createReminders(from: [draft], parseSessionId: sessionID)

        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].parseSessionId, sessionID)
        XCTAssertEqual(links[0].reminderDraftId, draftID)
        XCTAssertEqual(links[0].appleReminderId, "apple-1")
        XCTAssertEqual(links[0].lastKnownTitle, "Make a fruit protein smoothie")
    }
}
