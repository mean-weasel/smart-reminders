import XCTest
@testable import SmartReminders

@MainActor
final class ReviewViewModelTests: XCTestCase {
    func testDeletesReminderAndKeepsGroupIdsInSync() {
        let first = ReminderDraft.fixture(title: "Make smoothie")
        let second = ReminderDraft.fixture(title: "Buy raspberries")
        let viewModel = ReviewViewModel(
            originalText: "Smoothie supplies",
            validatedDraft: ValidatedDraft(
                parserVersion: "test-parser",
                reminders: [first, second],
                group: DraftGroup(id: UUID(), title: "Smoothies", mode: .grouped, reminderDraftIds: [first.id, second.id]),
                rawParserResponse: nil
            ),
            reminderWriter: MockReminderWriter(resultIDs: []),
            localStore: LocalStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        )

        viewModel.deleteReminder(id: first.id)

        XCTAssertEqual(viewModel.reminders.map(\.id), [second.id])
        XCTAssertEqual(viewModel.group?.reminderDraftIds, [second.id])
    }

    func testSwitchesGroupMode() {
        let draft = ReminderDraft.fixture(title: "Make smoothie")
        let viewModel = ReviewViewModel(
            originalText: "Smoothie supplies",
            validatedDraft: ValidatedDraft(
                parserVersion: "test-parser",
                reminders: [draft],
                group: DraftGroup(id: UUID(), title: "Smoothies", mode: .grouped, reminderDraftIds: [draft.id]),
                rawParserResponse: nil
            ),
            reminderWriter: MockReminderWriter(resultIDs: []),
            localStore: LocalStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        )

        viewModel.setGroupMode(.separate)

        XCTAssertEqual(viewModel.group?.mode, .separate)
    }

    func testApproveCreatesRemindersAndStoresSession() async throws {
        let draft = ReminderDraft.fixture(title: "Make smoothie")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalStore(directory: directory)
        let viewModel = ReviewViewModel(
            originalText: "Smoothie supplies",
            validatedDraft: ValidatedDraft(parserVersion: "test-parser", reminders: [draft], group: nil, rawParserResponse: "{\"ok\":true}"),
            reminderWriter: MockReminderWriter(resultIDs: ["apple-1"]),
            localStore: store
        )

        try await viewModel.approve()

        let sessions = try store.loadSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].status, .approved)
        XCTAssertEqual(sessions[0].createdReminderLinks.first?.appleReminderId, "apple-1")
    }
}

private extension ReminderDraft {
    static func fixture(title: String) -> ReminderDraft {
        ReminderDraft(
            id: UUID(),
            title: title,
            notes: nil,
            dueDate: nil,
            hasTime: false,
            recurrence: nil,
            priority: .none,
            targetList: nil,
            labels: [],
            confidence: 1,
            ambiguityFlags: [],
            isUndated: true
        )
    }
}
