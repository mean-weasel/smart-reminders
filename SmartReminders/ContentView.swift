import SwiftUI

struct ContentView: View {
    @State private var inputText = LaunchConfiguration.initialIntentText()
    @State private var reviewViewModel: ReviewViewModel?
    @State private var errorMessage: String?

    private let validator = DraftValidator()
    private let localStore = LocalStore()
    private let reminderWriter = EventKitReminderWriter()

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder intent") {
                    TextEditor(text: $inputText)
                        .frame(minHeight: 180)
                        .accessibilityIdentifier("intentTextEditor")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Button("Parse reminder draft") {
                    parseDraft()
                }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("parseReminderDraftButton")
            }
            .navigationTitle("Smart Reminders")
            .sheet(item: $reviewViewModel) { viewModel in
                ReviewSheet(viewModel: viewModel)
            }
        }
    }

    private func parseDraft() {
        do {
            let response = PreviewParser.sampleResponse(for: inputText)
            let draft = try validator.validate(response)
            reviewViewModel = ReviewViewModel(
                originalText: inputText,
                validatedDraft: draft,
                reminderWriter: reminderWriter,
                localStore: localStore
            )
            errorMessage = nil
        } catch {
            errorMessage = "The parser result could not be turned into reminder drafts."
        }
    }
}

extension ReviewViewModel: Identifiable {
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }
}

// Local parser fixture used until endpoint and API key configuration are wired.
enum PreviewParser {
    static func sampleResponse(for text: String) -> ParserResponse {
        ParserResponse(
            parserVersion: "preview-parser",
            reminders: [
                ParsedReminderDraft(
                    title: "Make a fruit protein smoothie",
                    notes: "Original intent: \(text)",
                    dueDate: nil,
                    hasTime: false,
                    recurrence: nil,
                    priority: "medium",
                    targetList: nil,
                    labels: ["smoothies", "grocery"],
                    confidence: 0.85,
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
                    confidence: 0.72,
                    ambiguityFlags: []
                )
            ],
            group: ParsedDraftGroup(title: "Fruit protein smoothies this week", mode: "grouped"),
            rawJSON: nil
        )
    }
}

#Preview {
    ContentView()
}
