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

    func testAcceptsDateOnlyDueDateAtStartOfDay() throws {
        let response = ParserResponse(
            parserVersion: "test-parser",
            reminders: [
                ParsedReminderDraft(
                    title: "Make smoothie",
                    notes: nil,
                    dueDate: "2026-06-01",
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

        let validated = try DraftValidator().validate(response)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let expectedDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))
        XCTAssertEqual(validated.reminders[0].dueDate, expectedDate)
        XCTAssertFalse(validated.reminders[0].hasTime)
    }

    func testAcceptsFractionalSecondDueDate() throws {
        let response = ParserResponse(
            parserVersion: "test-parser",
            reminders: [
                ParsedReminderDraft(
                    title: "Make smoothie",
                    notes: nil,
                    dueDate: "2026-06-01T08:00:00.123Z",
                    hasTime: true,
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

        let validated = try DraftValidator().validate(response)

        XCTAssertNotNil(validated.reminders[0].dueDate)
        XCTAssertTrue(validated.reminders[0].hasTime)
    }

    func testRejectsUnknownRecurrence() {
        let response = ParserResponse(
            parserVersion: "test-parser",
            reminders: [
                ParsedReminderDraft(
                    title: "Make smoothie",
                    notes: nil,
                    dueDate: nil,
                    hasTime: false,
                    recurrence: "fortnightly",
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
            XCTAssertEqual(error as? DraftValidationError, .invalidRecurrence("fortnightly"))
        }
    }

    func testRejectsUnknownPriority() {
        let response = ParserResponse(
            parserVersion: "test-parser",
            reminders: [
                ParsedReminderDraft(
                    title: "Make smoothie",
                    notes: nil,
                    dueDate: nil,
                    hasTime: false,
                    recurrence: nil,
                    priority: "urgent",
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
            XCTAssertEqual(error as? DraftValidationError, .invalidPriority("urgent"))
        }
    }

    func testDropsBlankGroupTitle() throws {
        let response = ParserResponse(
            parserVersion: "test-parser",
            reminders: [
                ParsedReminderDraft(
                    title: "Make smoothie",
                    notes: nil,
                    dueDate: nil,
                    hasTime: false,
                    recurrence: nil,
                    priority: "none",
                    targetList: nil,
                    labels: [],
                    confidence: 0.9,
                    ambiguityFlags: []
                )
            ],
            group: ParsedDraftGroup(title: "  ", mode: "grouped"),
            rawJSON: nil
        )

        let validated = try DraftValidator().validate(response)

        XCTAssertNil(validated.group)
        XCTAssertEqual(validated.reminders.count, 1)
    }
}
