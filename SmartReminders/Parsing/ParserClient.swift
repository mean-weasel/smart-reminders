import Foundation

protocol ParserClient {
    func parse(text: String) async throws -> ParserResponse
}

struct ParserResponse: Codable, Equatable {
    var parserVersion: String
    var reminders: [ParsedReminderDraft]
    var group: ParsedDraftGroup?
    var rawJSON: String?
}

struct ParsedReminderDraft: Codable, Equatable {
    var title: String
    var notes: String?
    var dueDate: String?
    var hasTime: Bool
    var recurrence: String?
    var priority: String
    var targetList: String?
    var labels: [String]
    var confidence: Double
    var ambiguityFlags: [String]
}

struct ParsedDraftGroup: Codable, Equatable {
    var title: String
    var mode: String
}
