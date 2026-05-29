import Foundation

enum DraftValidationError: Error, Equatable {
    case emptyReminderList
    case emptyTitle
    case invalidDueDate(String)
    case invalidRecurrence(String)
    case invalidPriority(String)
}

struct ValidatedDraft: Equatable {
    var parserVersion: String
    var reminders: [ReminderDraft]
    var group: DraftGroup?
    var rawParserResponse: String?
}

struct DraftValidator {
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    private let fractionalISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

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

            let parsedDueDate: (date: Date, hasTime: Bool)?
            if let dueDateString = parsed.dueDate {
                guard let dueDate = parseDueDate(dueDateString) else {
                    throw DraftValidationError.invalidDueDate(dueDateString)
                }
                parsedDueDate = dueDate
            } else {
                parsedDueDate = nil
            }

            let recurrence: RecurrenceRule?
            if let recurrenceString = parsed.recurrence?.nilIfBlank {
                guard let parsedRecurrence = RecurrenceRule(rawValue: recurrenceString) else {
                    throw DraftValidationError.invalidRecurrence(parsed.recurrence ?? recurrenceString)
                }
                recurrence = parsedRecurrence
            } else {
                recurrence = nil
            }

            let priorityString = parsed.priority.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let priority = ReminderPriority(rawValue: priorityString) else {
                throw DraftValidationError.invalidPriority(parsed.priority)
            }

            drafts.append(ReminderDraft(
                id: UUID(),
                title: title,
                notes: parsed.notes?.nilIfBlank,
                dueDate: parsedDueDate?.date,
                hasTime: parsed.hasTime && (parsedDueDate?.hasTime ?? false),
                recurrence: recurrence,
                priority: priority,
                targetList: parsed.targetList?.nilIfBlank,
                labels: parsed.labels.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
                confidence: min(max(parsed.confidence, 0), 1),
                ambiguityFlags: parsed.ambiguityFlags,
                isUndated: parsedDueDate == nil
            ))
        }

        let group: DraftGroup?
        if let parsedGroup = response.group, let groupTitle = parsedGroup.title.nilIfBlank {
            group = DraftGroup(
                id: UUID(),
                title: groupTitle,
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

    private func parseDueDate(_ dueDateString: String) -> (date: Date, hasTime: Bool)? {
        if let date = fractionalISOFormatter.date(from: dueDateString) {
            return (date, true)
        }

        if let date = isoFormatter.date(from: dueDateString) {
            return (date, true)
        }

        if let date = dateOnlyFormatter.date(from: dueDateString) {
            return (date, false)
        }

        return nil
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
