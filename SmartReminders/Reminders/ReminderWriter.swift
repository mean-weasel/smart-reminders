import EventKit
import Foundation

protocol ReminderWriting {
    func createReminders(from drafts: [ReminderDraft], parseSessionId: UUID) async throws -> [CreatedReminderLink]
}

enum ReminderWriterError: Error, Equatable {
    case accessDenied
    case missingCalendar
}

struct MockReminderWriter: ReminderWriting {
    var resultIDs: [String]

    func createReminders(from drafts: [ReminderDraft], parseSessionId: UUID) async throws -> [CreatedReminderLink] {
        drafts.enumerated().map { index, draft in
            CreatedReminderLink(
                id: UUID(),
                parseSessionId: parseSessionId,
                reminderDraftId: draft.id,
                appleCalendarId: draft.targetList ?? "mock-calendar",
                appleReminderId: resultIDs.indices.contains(index) ? resultIDs[index] : UUID().uuidString,
                createdAt: Date(),
                lastKnownTitle: draft.title,
                lastKnownStatus: .incomplete
            )
        }
    }
}

final class EventKitReminderWriter: ReminderWriting {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    func createReminders(from drafts: [ReminderDraft], parseSessionId: UUID) async throws -> [CreatedReminderLink] {
        let granted = try await requestAccess()
        guard granted else {
            throw ReminderWriterError.accessDenied
        }

        var links: [CreatedReminderLink] = []
        for draft in drafts {
            let calendar = calendar(named: draft.targetList) ?? eventStore.defaultCalendarForNewReminders()
            guard let calendar else {
                throw ReminderWriterError.missingCalendar
            }

            let reminder = EKReminder(eventStore: eventStore)
            reminder.title = draft.title
            reminder.notes = noteText(for: draft)
            reminder.calendar = calendar

            if let dueDate = draft.dueDate {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    draft.hasTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day],
                    from: dueDate
                )
                reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
            }

            if let recurrence = draft.recurrence {
                reminder.addRecurrenceRule(EKRecurrenceRule(
                    recurrenceWith: ekFrequency(for: recurrence),
                    interval: 1,
                    end: nil
                ))
            }

            reminder.priority = ekPriority(for: draft.priority)
            try eventStore.save(reminder, commit: true)

            links.append(CreatedReminderLink(
                id: UUID(),
                parseSessionId: parseSessionId,
                reminderDraftId: draft.id,
                appleCalendarId: calendar.calendarIdentifier,
                appleReminderId: reminder.calendarItemIdentifier,
                createdAt: Date(),
                lastKnownTitle: draft.title,
                lastKnownStatus: .incomplete
            ))
        }

        return links
    }

    private func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await eventStore.requestFullAccessToReminders()
        } else {
            return try await eventStore.requestAccess(to: .reminder)
        }
    }

    private func calendar(named name: String?) -> EKCalendar? {
        guard let name else {
            return nil
        }
        return eventStore.calendars(for: .reminder).first { $0.title == name }
    }

    private func noteText(for draft: ReminderDraft) -> String? {
        let labels = draft.labels.isEmpty ? nil : "Labels: \(draft.labels.joined(separator: ", "))"
        return [draft.notes, labels].compactMap { $0 }.joined(separator: "\n\n").nilIfEmpty
    }

    private func ekPriority(for priority: ReminderPriority) -> Int {
        switch priority {
        case .none: return 0
        case .low: return 9
        case .medium: return 5
        case .high: return 1
        }
    }

    private func ekFrequency(for recurrence: RecurrenceRule) -> EKRecurrenceFrequency {
        switch recurrence {
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .yearly: return .yearly
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
