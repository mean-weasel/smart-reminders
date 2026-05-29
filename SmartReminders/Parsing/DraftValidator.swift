import Foundation

enum DraftValidationError: Error, Equatable {
    case emptyReminderList
    case emptyTitle
    case invalidDueDate(String)
}

struct ValidatedDraft: Equatable {
    var parserVersion: String
    var reminders: [ReminderDraft]
    var group: DraftGroup?
    var rawParserResponse: String?
}

struct DraftValidator {
    private let isoFormatter = ISO8601DateFormatter()

    func validate(_ response: ParserResponse) throws -> ValidatedDraft {
        guard !response.reminders.isEmpty else {
            throw DraftValidationError.emptyReminderList
        }

        var drafts: [ReminderDraft] = []
        for parsed in response.reminders {
            let title = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else {
                throw DraftValidationError.emptyTitle
            }

            let dueDate: Date?
            if let dueDateString = parsed.dueDate {
                guard let parsedDate = isoFormatter.date(from: dueDateString) else {
                    throw DraftValidationError.invalidDueDate(dueDateString)
                }
                dueDate = parsedDate
            } else {
                dueDate = nil
            }

            drafts.append(ReminderDraft(
                id: UUID(),
                title: title,
                notes: parsed.notes?.nilIfBlank,
                dueDate: dueDate,
                hasTime: parsed.hasTime && dueDate != nil,
                recurrence: RecurrenceRule(rawValue: parsed.recurrence ?? ""),
                priority: ReminderPriority(rawValue: parsed.priority) ?? .none,
                targetList: parsed.targetList?.nilIfBlank,
                labels: parsed.labels.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
                confidence: min(max(parsed.confidence, 0), 1),
                ambiguityFlags: parsed.ambiguityFlags,
                isUndated: dueDate == nil
            ))
        }

        let group: DraftGroup?
        if let parsedGroup = response.group {
            group = DraftGroup(
                id: UUID(),
                title: parsedGroup.title.trimmingCharacters(in: .whitespacesAndNewlines),
                mode: DraftGroupMode(rawValue: parsedGroup.mode) ?? .separate,
                reminderDraftIds: drafts.map(\.id)
            )
        } else {
            group = nil
        }

        return ValidatedDraft(
            parserVersion: response.parserVersion,
            reminders: drafts,
            group: group,
            rawParserResponse: response.rawJSON
        )
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
