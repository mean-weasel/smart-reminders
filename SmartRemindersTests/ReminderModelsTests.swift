import XCTest
@testable import SmartReminders

final class ReminderModelsTests: XCTestCase {
    func testReminderDraftSupportsUndatedReminder() throws {
        let draft = ReminderDraft(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Buy raspberries",
            notes: "Restock for smoothies",
            dueDate: nil,
            hasTime: false,
            recurrence: nil,
            priority: .none,
            targetList: "Groceries",
            labels: ["grocery"],
            confidence: 0.8,
            ambiguityFlags: [],
            isUndated: true
        )

        let data = try JSONEncoder.smartReminders.encode(draft)
        let decoded = try JSONDecoder.smartReminders.decode(ReminderDraft.self, from: data)

        XCTAssertEqual(decoded.title, "Buy raspberries")
        XCTAssertTrue(decoded.isUndated)
        XCTAssertNil(decoded.dueDate)
        XCTAssertEqual(decoded.labels, ["grocery"])
    }

    func testParseSessionStoresApprovedDraftAndLinks() {
        let sessionID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let draftID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let session = ParseSession(
            id: sessionID,
            originalText: "Make fruit protein smoothies this week",
            createdAt: Date(timeIntervalSince1970: 100),
            parserVersion: "test-parser",
            status: .approved,
            rawParserResponse: nil,
            finalApprovedDraft: ApprovedDraft(reminders: [
                ReminderDraft(
                    id: draftID,
                    title: "Make a fruit protein smoothie",
                    notes: nil,
                    dueDate: nil,
                    hasTime: false,
                    recurrence: nil,
                    priority: .none,
                    targetList: nil,
                    labels: ["smoothies"],
                    confidence: 0.9,
                    ambiguityFlags: [],
                    isUndated: true
                )
            ], group: DraftGroup(id: UUID(), title: "Fruit protein smoothies this week", mode: .grouped, reminderDraftIds: [draftID])),
            createdReminderLinks: [
                CreatedReminderLink(
                    id: UUID(),
                    parseSessionId: sessionID,
                    reminderDraftId: draftID,
                    appleCalendarId: "calendar-1",
                    appleReminderId: "reminder-1",
                    createdAt: Date(timeIntervalSince1970: 120),
                    lastKnownTitle: "Make a fruit protein smoothie",
                    lastKnownStatus: .incomplete
                )
            ]
        )

        XCTAssertEqual(session.status, .approved)
        XCTAssertEqual(session.finalApprovedDraft?.group?.mode, .grouped)
        XCTAssertEqual(session.createdReminderLinks.first?.appleReminderId, "reminder-1")
    }
}
