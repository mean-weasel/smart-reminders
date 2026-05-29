import XCTest
@testable import SmartReminders

final class LocalStoreTests: XCTestCase {
    func testSavesAndLoadsParseSessions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalStore(directory: directory)
        let session = ParseSession(
            id: UUID(),
            originalText: "Make smoothies this week",
            createdAt: Date(timeIntervalSince1970: 100.25),
            parserVersion: "test-parser",
            status: .draft,
            rawParserResponse: "{\"reminders\":[]}",
            finalApprovedDraft: nil,
            createdReminderLinks: []
        )

        try store.save(session)
        let loaded = try store.loadSessions()

        XCTAssertEqual(loaded, [session])
    }

    func testUpdatesExistingParseSession() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalStore(directory: directory)
        let sessionID = UUID()
        let draft = ParseSession(
            id: sessionID,
            originalText: "Buy raspberries",
            createdAt: Date(timeIntervalSince1970: 100.25),
            parserVersion: "test-parser",
            status: .draft,
            rawParserResponse: nil,
            finalApprovedDraft: nil,
            createdReminderLinks: []
        )
        let approved = ParseSession(
            id: sessionID,
            originalText: "Buy raspberries",
            createdAt: Date(timeIntervalSince1970: 100.25),
            parserVersion: "test-parser",
            status: .approved,
            rawParserResponse: nil,
            finalApprovedDraft: ApprovedDraft(reminders: [], group: nil),
            createdReminderLinks: []
        )

        try store.save(draft)
        try store.save(approved)

        XCTAssertEqual(try store.loadSessions(), [approved])
    }
}
