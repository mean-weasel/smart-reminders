import Foundation

@MainActor
final class ReviewViewModel: ObservableObject {
    let originalText: String
    let parserVersion: String
    let rawParserResponse: String?

    @Published var reminders: [ReminderDraft]
    @Published var group: DraftGroup?
    @Published var errorMessage: String?

    private let reminderWriter: ReminderWriting
    private let localStore: LocalStore

    init(originalText: String, validatedDraft: ValidatedDraft, reminderWriter: ReminderWriting, localStore: LocalStore) {
        self.originalText = originalText
        self.parserVersion = validatedDraft.parserVersion
        self.rawParserResponse = validatedDraft.rawParserResponse
        self.reminders = validatedDraft.reminders
        self.group = validatedDraft.group
        self.reminderWriter = reminderWriter
        self.localStore = localStore
    }

    func deleteReminder(id: UUID) {
        reminders.removeAll { $0.id == id }
        group?.reminderDraftIds.removeAll { $0 == id }
    }

    func setGroupMode(_ mode: DraftGroupMode) {
        group?.mode = mode
    }

    func approve() async throws {
        let sessionID = UUID()
        let links = try await reminderWriter.createReminders(from: reminders, parseSessionId: sessionID)
        let session = ParseSession(
            id: sessionID,
            originalText: originalText,
            createdAt: Date(),
            parserVersion: parserVersion,
            status: .approved,
            rawParserResponse: rawParserResponse,
            finalApprovedDraft: ApprovedDraft(reminders: reminders, group: group),
            createdReminderLinks: links
        )
        try localStore.save(session)
    }
}
