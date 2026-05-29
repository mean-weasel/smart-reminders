import XCTest
@testable import SmartReminders

final class DraftValidatorTests: XCTestCase {
    func testValidatesSmoothieBundleWithUndatedRestock() throws {
        let response = ParserResponse(
            parserVersion: "test-parser",
            reminders: [
                ParsedReminderDraft(
                    title: "Make a fruit protein smoothie",
                    notes: "Use high-protein milk, frozen blueberries, and frozen raspberries.",
                    dueDate: "2026-06-01T08:00:00Z",
                    hasTime: true,
                    recurrence: nil,
                    priority: "medium",
                    targetList: "Reminders",
                    labels: ["grocery", "smoothies"],
                    confidence: 0.92,
                    ambiguityFlags: ["date_inferred"]
                ),
                ParsedReminderDraft(
                    title: "Buy raspberries again",
                    notes: "Restock when raspberries run out.",
                    dueDate: nil,
                    hasTime: false,
                    recurrence: nil,
                    priority: "none",
                    targetList: "Groceries",
                    labels: ["grocery"],
                    confidence: 0.7,
                    ambiguityFlags: []
                )
            ],
            group: ParsedDraftGroup(title: "Fruit protein smoothies this week", mode: "grouped"),
            rawJSON: "{\"ok\":true}"
        )

        let validated = try DraftValidator().validate(response)

        XCTAssertEqual(validated.reminders.count, 2)
        XCTAssertEqual(validated.group?.title, "Fruit protein smoothies this week")
        XCTAssertEqual(validated.group?.mode, .grouped)
        XCTAssertFalse(validated.reminders[0].isUndated)
        XCTAssertTrue(validated.reminders[1].isUndated)
        XCTAssertEqual(validated.reminders[0].priority, .medium)
    }

    func testRejectsEmptyReminderTitle() {
        let response = ParserResponse(
            parserVersion: "test-parser",
            reminders: [
                ParsedReminderDraft(
                    title: " ",
                    notes: nil,
                    dueDate: nil,
                    hasTime: false,
                    recurrence: nil,
                    priority: "none",
                    targetList: nil,
                    labels: [],
                    confidence: 0.5,
                    ambiguityFlags: []
                )
            ],
            group: nil,
            rawJSON: nil
        )

        XCTAssertThrowsError(try DraftValidator().validate(response)) { error in
            XCTAssertEqual(error as? DraftValidationError, .emptyTitle)
        }
    }

    func testRejectsImpossibleDateString() {
        let response = ParserResponse(
            parserVersion: "test-parser",
            reminders: [
                ParsedReminderDraft(
                    title: "Make smoothie",
                    notes: nil,
                    dueDate: "next blursday",
                    hasTime: false,
                    recurrence: nil,
                    priority: "none",
                    targetList: nil,
                    labels: [],
                    confidence: 0.9,
                    ambiguityFlags: []
                )
            ],
            group: nil,
            rawJSON: nil
        )

        XCTAssertThrowsError(try DraftValidator().validate(response)) { error in
            XCTAssertEqual(error as? DraftValidationError, .invalidDueDate("next blursday"))
        }
    }
}
