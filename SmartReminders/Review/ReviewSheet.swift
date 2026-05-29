import SwiftUI

struct ReviewSheet: View {
    @ObservedObject var viewModel: ReviewViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isApproving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Original text") {
                    Text(viewModel.originalText)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if viewModel.group != nil {
                    Section("Group") {
                        TextField("Group title", text: Binding(
                            get: { viewModel.group?.title ?? "" },
                            set: { viewModel.group?.title = $0 }
                        ))

                        Picker("Mode", selection: Binding(
                            get: { viewModel.group?.mode ?? .separate },
                            set: { viewModel.setGroupMode($0) }
                        )) {
                            Text("Grouped").tag(DraftGroupMode.grouped)
                            Text("Separate").tag(DraftGroupMode.separate)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Reminders") {
                    ForEach($viewModel.reminders) { $draft in
                        ReminderDraftEditor(draft: $draft) {
                            viewModel.deleteReminder(id: draft.id)
                        }
                    }
                }
            }
            .navigationTitle("Review Draft")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isApproving ? "Creating..." : "Create") {
                        approve()
                    }
                    .disabled(isApproving || viewModel.reminders.isEmpty)
                }
            }
        }
    }

    private func approve() {
        isApproving = true
        Task {
            do {
                try await viewModel.approve()
                dismiss()
            } catch {
                viewModel.errorMessage = "Could not create Apple Reminders."
                isApproving = false
            }
        }
    }
}

private struct ReminderDraftEditor: View {
    @Binding var draft: ReminderDraft
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $draft.title)
            TextField("Notes", text: optionalString($draft.notes))

            Toggle("Due date", isOn: Binding(
                get: { draft.dueDate != nil },
                set: { enabled in
                    draft.dueDate = enabled ? (draft.dueDate ?? Date()) : nil
                    draft.isUndated = !enabled
                    if !enabled {
                        draft.hasTime = false
                    }
                }
            ))

            if draft.dueDate != nil {
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { draft.dueDate ?? Date() },
                        set: { draft.dueDate = $0 }
                    ),
                    displayedComponents: draft.hasTime ? [.date, .hourAndMinute] : [.date]
                )

                Toggle("Time", isOn: $draft.hasTime)
            }

            Picker("Recurrence", selection: Binding(
                get: { draft.recurrence },
                set: { draft.recurrence = $0 }
            )) {
                Text("None").tag(Optional<RecurrenceRule>.none)
                ForEach(RecurrenceRule.allCases, id: \.self) { recurrence in
                    Text(recurrence.rawValue.capitalized).tag(Optional(recurrence))
                }
            }

            Picker("Priority", selection: $draft.priority) {
                ForEach(ReminderPriority.allCases, id: \.self) { priority in
                    Text(priority.rawValue.capitalized).tag(priority)
                }
            }

            TextField("List", text: optionalString($draft.targetList))
            TextField("Labels", text: Binding(
                get: { draft.labels.joined(separator: ", ") },
                set: { draft.labels = labels(from: $0) }
            ))

            if !draft.ambiguityFlags.isEmpty {
                Text("Inferred: \(draft.ambiguityFlags.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Delete", role: .destructive, action: onDelete)
        }
        .padding(.vertical, 6)
    }

    private func optionalString(_ source: Binding<String?>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue ?? "" },
            set: { source.wrappedValue = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }

    private func labels(from text: String) -> [String] {
        text.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

#Preview {
    let draft = ValidatedDraft(
        parserVersion: "preview",
        reminders: [
            ReminderDraft(
                id: UUID(),
                title: "Make a fruit protein smoothie",
                notes: "Use frozen berries.",
                dueDate: nil,
                hasTime: false,
                recurrence: nil,
                priority: .medium,
                targetList: nil,
                labels: ["smoothies", "grocery"],
                confidence: 0.9,
                ambiguityFlags: ["date_inferred"],
                isUndated: true
            )
        ],
        group: nil,
        rawParserResponse: nil
    )

    ReviewSheet(viewModel: ReviewViewModel(
        originalText: "Make smoothies this week",
        validatedDraft: draft,
        reminderWriter: MockReminderWriter(resultIDs: []),
        localStore: LocalStore()
    ))
}
