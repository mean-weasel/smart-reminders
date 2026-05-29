import SwiftUI

struct ContentView: View {
    @State private var inputText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder intent") {
                    TextEditor(text: $inputText)
                        .frame(minHeight: 180)
                        .accessibilityIdentifier("intentTextEditor")
                }

                Button("Parse reminder draft") {}
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("parseReminderDraftButton")
            }
            .navigationTitle("Smart Reminders")
        }
    }
}

#Preview {
    ContentView()
}
