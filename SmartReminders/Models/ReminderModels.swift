import Foundation

enum ParseSessionStatus: String, Codable, Equatable {
    case draft
    case approved
    case discarded
}

enum ReminderPriority: String, Codable, Equatable, CaseIterable {
    case none
    case low
    case medium
    case high
}

enum RecurrenceRule: String, Codable, Equatable, CaseIterable {
    case daily
    case weekly
    case monthly
    case yearly
}

enum DraftGroupMode: String, Codable, Equatable {
    case grouped
    case separate
}

enum ReminderLinkStatus: String, Codable, Equatable {
    case incomplete
    case completed
    case unknown
}

struct ReminderDraft: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var notes: String?
    var dueDate: Date?
    var hasTime: Bool
    var recurrence: RecurrenceRule?
    var priority: ReminderPriority
    var targetList: String?
    var labels: [String]
    var confidence: Double
    var ambiguityFlags: [String]
    var isUndated: Bool
}

struct DraftGroup: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var mode: DraftGroupMode
    var reminderDraftIds: [UUID]
}

struct ApprovedDraft: Codable, Equatable {
    var reminders: [ReminderDraft]
    var group: DraftGroup?
}

struct CreatedReminderLink: Identifiable, Codable, Equatable {
    var id: UUID
    var parseSessionId: UUID
    var reminderDraftId: UUID
    var appleCalendarId: String
    var appleReminderId: String
    var createdAt: Date
    var lastKnownTitle: String
    var lastKnownStatus: ReminderLinkStatus
}

struct ParseSession: Identifiable, Codable, Equatable {
    var id: UUID
    var originalText: String
    var createdAt: Date
    var parserVersion: String
    var status: ParseSessionStatus
    var rawParserResponse: String?
    var finalApprovedDraft: ApprovedDraft?
    var createdReminderLinks: [CreatedReminderLink]
}

extension JSONEncoder {
    static var smartReminders: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var smartReminders: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
