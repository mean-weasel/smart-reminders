# Smart Reminders MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an iOS MVP that parses text into editable reminder drafts, lets the user approve them, creates Apple Reminders via EventKit, and stores local parse history.

**Architecture:** The app is a SwiftUI iOS app generated reproducibly with XcodeGen. Core reminder draft models, parser validation, and local history live in focused Swift types that are easy to unit test. EventKit is isolated behind a `ReminderWriting` protocol so most tests do not require real Reminders access.

**Tech Stack:** Swift 5.10+, SwiftUI, EventKit, XCTest, XcodeGen, iOS 17+.

---

## File Structure

- Create `project.yml`: XcodeGen project definition for the app and test target.
- Create `SmartReminders/SmartRemindersApp.swift`: SwiftUI app entry point.
- Create `SmartReminders/ContentView.swift`: Root text input surface that opens the review sheet.
- Create `SmartReminders/Info.plist`: Reminders access usage description.
- Create `SmartReminders/Models/ReminderModels.swift`: `ParseSession`, `ReminderDraft`, `DraftGroup`, `CreatedReminderLink`, and related enums.
- Create `SmartReminders/Parsing/ParserClient.swift`: parser protocol plus cloud parser request/response types.
- Create `SmartReminders/Parsing/DraftValidator.swift`: local validation and normalization.
- Create `SmartReminders/Review/ReviewViewModel.swift`: editable draft state and approval orchestration.
- Create `SmartReminders/Review/ReviewSheet.swift`: overlay/form editor for draft reminders.
- Create `SmartReminders/Reminders/ReminderWriter.swift`: `ReminderWriting` protocol and EventKit implementation.
- Create `SmartReminders/Storage/LocalStore.swift`: JSON-backed local parse history storage.
- Create `SmartRemindersTests/ReminderModelsTests.swift`: model encoding and helper tests.
- Create `SmartRemindersTests/DraftValidatorTests.swift`: parser validation tests.
- Create `SmartRemindersTests/ReviewViewModelTests.swift`: edit/delete/group/approval tests.
- Create `SmartRemindersTests/ReminderWriterTests.swift`: EventKit mapping tests using mocks.
- Create `SmartRemindersTests/LocalStoreTests.swift`: local parse history tests.
- Create `docs/manual-testing/reminders-permissions.md`: manual checklist for simulator/device EventKit permission and real reminder creation.

## Task 1: Reproducible iOS Project Scaffold

**Files:**
- Create: `project.yml`
- Create: `SmartReminders/SmartRemindersApp.swift`
- Create: `SmartReminders/ContentView.swift`
- Create: `SmartReminders/Info.plist`
- Create: `SmartRemindersTests/SmokeTests.swift`

- [ ] **Step 1: Install or verify XcodeGen**

Run:

```bash
command -v xcodegen || brew install xcodegen
```

Expected: `xcodegen` is available on `PATH`.

- [ ] **Step 2: Create `project.yml`**

```yaml
name: SmartReminders
options:
  bundleIdPrefix: com.meanweasel
  deploymentTarget:
    iOS: "17.0"
settings:
  base:
    SWIFT_VERSION: "5.10"
targets:
  SmartReminders:
    type: application
    platform: iOS
    sources:
      - SmartReminders
    info:
      path: SmartReminders/Info.plist
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.meanweasel.smartreminders
  SmartRemindersTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - SmartRemindersTests
    dependencies:
      - target: SmartReminders
```

- [ ] **Step 3: Create the app entry point**

Create `SmartReminders/SmartRemindersApp.swift`:

```swift
import SwiftUI

@main
struct SmartRemindersApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 4: Create the initial root view**

Create `SmartReminders/ContentView.swift`:

```swift
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
```

- [ ] **Step 5: Add Reminders usage description**

Create `SmartReminders/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSRemindersFullAccessUsageDescription</key>
    <string>Smart Reminders creates Apple Reminders only after you approve the parsed draft.</string>
</dict>
</plist>
```

- [ ] **Step 6: Add a smoke test**

Create `SmartRemindersTests/SmokeTests.swift`:

```swift
import XCTest
@testable import SmartReminders

final class SmokeTests: XCTestCase {
    func testAppTypesLoad() {
        XCTAssertNotNil(ContentView())
    }
}
```

- [ ] **Step 7: Generate and test the project**

Run:

```bash
xcodegen generate
xcodebuild test -project SmartReminders.xcodeproj -scheme SmartReminders -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: build succeeds and `SmokeTests.testAppTypesLoad` passes.

- [ ] **Step 8: Commit**

```bash
git add project.yml SmartReminders SmartRemindersTests
git commit -m "chore: scaffold iOS app"
```

## Task 2: Core Draft Models

**Files:**
- Create: `SmartReminders/Models/ReminderModels.swift`
- Create: `SmartRemindersTests/ReminderModelsTests.swift`

- [ ] **Step 1: Write model encoding tests**

Create `SmartRemindersTests/ReminderModelsTests.swift`:

```swift
import XCTest
@testable import SmartReminders

final class ReminderModelsTests: XCTestCase {
    func testReminderDraftSupportsUndatedReminder() throws {
        let draft = ReminderDraft(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Buy raspberries",
            notes: "Restock for smoothies",
            dueDate: nil,
            hasTime: false,
            recurrence: nil,
            priority: .none,
            targetList: "Groceries",
            labels: ["grocery"],
            confidence: 0.8,
            ambiguityFlags: [],
            isUndated: true
        )

        let data = try JSONEncoder.smartReminders.encode(draft)
        let decoded = try JSONDecoder.smartReminders.decode(ReminderDraft.self, from: data)

        XCTAssertEqual(decoded.title, "Buy raspberries")
        XCTAssertTrue(decoded.isUndated)
        XCTAssertNil(decoded.dueDate)
        XCTAssertEqual(decoded.labels, ["grocery"])
    }

    func testParseSessionStoresApprovedDraftAndLinks() {
        let sessionID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let draftID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let session = ParseSession(
            id: sessionID,
            originalText: "Make fruit protein smoothies this week",
            createdAt: Date(timeIntervalSince1970: 100),
            parserVersion: "test-parser",
            status: .approved,
            rawParserResponse: nil,
            finalApprovedDraft: ApprovedDraft(reminders: [
                ReminderDraft(
                    id: draftID,
                    title: "Make a fruit protein smoothie",
                    notes: nil,
                    dueDate: nil,
                    hasTime: false,
                    recurrence: nil,
                    priority: .none,
                    targetList: nil,
                    labels: ["smoothies"],
                    confidence: 0.9,
                    ambiguityFlags: [],
                    isUndated: true
                )
            ], group: DraftGroup(id: UUID(), title: "Fruit protein smoothies this week", mode: .grouped, reminderDraftIds: [draftID])),
            createdReminderLinks: [
                CreatedReminderLink(
                    id: UUID(),
                    parseSessionId: sessionID,
                    reminderDraftId: draftID,
                    appleCalendarId: "calendar-1",
                    appleReminderId: "reminder-1",
                    createdAt: Date(timeIntervalSince1970: 120),
                    lastKnownTitle: "Make a fruit protein smoothie",
                    lastKnownStatus: .incomplete
                )
            ]
        )

        XCTAssertEqual(session.status, .approved)
        XCTAssertEqual(session.finalApprovedDraft?.group?.mode, .grouped)
        XCTAssertEqual(session.createdReminderLinks.first?.appleReminderId, "reminder-1")
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project SmartReminders.xcodeproj -scheme SmartReminders -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SmartRemindersTests/ReminderModelsTests
```

Expected: FAIL because model types do not exist.

- [ ] **Step 3: Implement core models**

Create `SmartReminders/Models/ReminderModels.swift`:

```swift
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
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var smartReminders: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
```

- [ ] **Step 4: Run model tests**

Run:

```bash
xcodebuild test -project SmartReminders.xcodeproj -scheme SmartReminders -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SmartRemindersTests/ReminderModelsTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add SmartReminders/Models/ReminderModels.swift SmartRemindersTests/ReminderModelsTests.swift
git commit -m "feat: add reminder draft models"
```

## Task 3: Parser Contract And Draft Validation

**Files:**
- Create: `SmartReminders/Parsing/ParserClient.swift`
- Create: `SmartReminders/Parsing/DraftValidator.swift`
- Create: `SmartRemindersTests/DraftValidatorTests.swift`

- [ ] **Step 1: Write validation tests**

Create `SmartRemindersTests/DraftValidatorTests.swift`:

```swift
import XCTest
@testable import SmartReminders

final class DraftValidatorTests: XCTestCase {
    func testValidatesSmoothieBundleWithUndatedRestock() throws {
        let response = ParserResponse(
            parserVersion: "test-parser",
            reminders: [
                ParsedReminderDraft(
                    title: "Make a fruit protein smoothie",
                    notes: "Use high-protein milk, frozen blueberries, and frozen raspberries.",
                    dueDate: "2026-06-01T08:00:00Z",
                    hasTime: true,
                    recurrence: nil,
                    priority: "medium",
                    targetList: "Reminders",
                    labels: ["grocery", "smoothies"],
                    confidence: 0.92,
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
                    confidence: 0.7,
                    ambiguityFlags: []
                )
            ],
            group: ParsedDraftGroup(title: "Fruit protein smoothies this week", mode: "grouped"),
            rawJSON: "{\"ok\":true}"
        )

        let validated = try DraftValidator().validate(response)

        XCTAssertEqual(validated.reminders.count, 2)
        XCTAssertEqual(validated.group?.title, "Fruit protein smoothies this week")
        XCTAssertEqual(validated.group?.mode, .grouped)
        XCTAssertFalse(validated.reminders[0].isUndated)
        XCTAssertTrue(validated.reminders[1].isUndated)
        XCTAssertEqual(validated.reminders[0].priority, .medium)
    }

    func testRejectsEmptyReminderTitle() {
        let response = ParserResponse(
            parserVersion: "test-parser",
            reminders: [
                ParsedReminderDraft(
                    title: " ",
                    notes: nil,
                    dueDate: nil,
                    hasTime: false,
                    recurrence: nil,
                    priority: "none",
                    targetList: nil,
                    labels: [],
                    confidence: 0.5,
                    ambiguityFlags: []
                )
            ],
            group: nil,
            rawJSON: nil
        )

        XCTAssertThrowsError(try DraftValidator().validate(response)) { error in
            XCTAssertEqual(error as? DraftValidationError, .emptyTitle)
        }
    }

    func testRejectsImpossibleDateString() {
        let response = ParserResponse(
            parserVersion: "test-parser",
            reminders: [
                ParsedReminderDraft(
                    title: "Make smoothie",
                    notes: nil,
                    dueDate: "next blursday",
                    hasTime: false,
                    recurrence: nil,
                    priority: "none",
                    targetList: nil,
                    labels: [],
                    confidence: 0.9,
                    ambiguityFlags: []
                )
            ],
            group: nil,
            rawJSON: nil
        )

        XCTAssertThrowsError(try DraftValidator().validate(response)) { error in
            XCTAssertEqual(error as? DraftValidationError, .invalidDueDate("next blursday"))
        }
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project SmartReminders.xcodeproj -scheme SmartReminders -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SmartRemindersTests/DraftValidatorTests
```

Expected: FAIL because parser and validator types do not exist.

- [ ] **Step 3: Implement parser response types**

Create `SmartReminders/Parsing/ParserClient.swift`:

```swift
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
```

- [ ] **Step 4: Implement validator**

Create `SmartReminders/Parsing/DraftValidator.swift`:

```swift
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
```

- [ ] **Step 5: Run validation tests**

Run:

```bash
xcodebuild test -project SmartReminders.xcodeproj -scheme SmartReminders -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SmartRemindersTests/DraftValidatorTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add SmartReminders/Parsing SmartRemindersTests/DraftValidatorTests.swift
git commit -m "feat: validate parsed reminder drafts"
```

## Task 4: Local Parse History Store

**Files:**
- Create: `SmartReminders/Storage/LocalStore.swift`
- Create: `SmartRemindersTests/LocalStoreTests.swift`

- [ ] **Step 1: Write local store tests**

Create `SmartRemindersTests/LocalStoreTests.swift`:

```swift
import XCTest
@testable import SmartReminders

final class LocalStoreTests: XCTestCase {
    func testSavesAndLoadsParseSessions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalStore(directory: directory)
        let session = ParseSession(
            id: UUID(),
            originalText: "Make smoothies this week",
            createdAt: Date(timeIntervalSince1970: 100),
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
            createdAt: Date(timeIntervalSince1970: 100),
            parserVersion: "test-parser",
            status: .draft,
            rawParserResponse: nil,
            finalApprovedDraft: nil,
            createdReminderLinks: []
        )
        let approved = ParseSession(
            id: sessionID,
            originalText: "Buy raspberries",
            createdAt: Date(timeIntervalSince1970: 100),
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
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project SmartReminders.xcodeproj -scheme SmartReminders -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SmartRemindersTests/LocalStoreTests
```

Expected: FAIL because `LocalStore` does not exist.

- [ ] **Step 3: Implement local store**

Create `SmartReminders/Storage/LocalStore.swift`:

```swift
import Foundation

struct LocalStore {
    private let fileURL: URL

    init(directory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.fileURL = directory.appendingPathComponent("parse-sessions.json")
    }

    func loadSessions() throws -> [ParseSession] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.smartReminders.decode([ParseSession].self, from: data)
    }

    func save(_ session: ParseSession) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var sessions = try loadSessions()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        let data = try JSONEncoder.smartReminders.encode(sessions)
        try data.write(to: fileURL, options: [.atomic])
    }
}
```

- [ ] **Step 4: Run local store tests**

Run:

```bash
xcodebuild test -project SmartReminders.xcodeproj -scheme SmartReminders -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SmartRemindersTests/LocalStoreTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add SmartReminders/Storage/LocalStore.swift SmartRemindersTests/LocalStoreTests.swift
git commit -m "feat: persist parse history locally"
```

## Task 5: Reminder Writer Boundary And EventKit Mapping

**Files:**
- Create: `SmartReminders/Reminders/ReminderWriter.swift`
- Create: `SmartRemindersTests/ReminderWriterTests.swift`

- [ ] **Step 1: Write writer mapping tests**

Create `SmartRemindersTests/ReminderWriterTests.swift`:

```swift
import XCTest
@testable import SmartReminders

final class ReminderWriterTests: XCTestCase {
    func testMockWriterReturnsLinksForApprovedDrafts() async throws {
        let sessionID = UUID()
        let draftID = UUID()
        let draft = ReminderDraft(
            id: draftID,
            title: "Make a fruit protein smoothie",
            notes: "Use frozen berries.",
            dueDate: Date(timeIntervalSince1970: 200),
            hasTime: true,
            recurrence: .weekly,
            priority: .medium,
            targetList: "Reminders",
            labels: ["smoothies"],
            confidence: 0.9,
            ambiguityFlags: ["date_inferred"],
            isUndated: false
        )
        let writer = MockReminderWriter(resultIDs: ["apple-1"])

        let links = try await writer.createReminders(from: [draft], parseSessionId: sessionID)

        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].parseSessionId, sessionID)
        XCTAssertEqual(links[0].reminderDraftId, draftID)
        XCTAssertEqual(links[0].appleReminderId, "apple-1")
        XCTAssertEqual(links[0].lastKnownTitle, "Make a fruit protein smoothie")
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project SmartReminders.xcodeproj -scheme SmartReminders -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SmartRemindersTests/ReminderWriterTests
```

Expected: FAIL because `ReminderWriting` and `MockReminderWriter` do not exist.

- [ ] **Step 3: Implement reminder writer protocol, mock, and EventKit writer**

Create `SmartReminders/Reminders/ReminderWriter.swift`:

```swift
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
        let labels = draft.labels.isEmpty ? nil : "Labels: \(draft.labels.joined(separator: \", \"))"
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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
```

- [ ] **Step 4: Run writer tests**

Run:

```bash
xcodebuild test -project SmartReminders.xcodeproj -scheme SmartReminders -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SmartRemindersTests/ReminderWriterTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add SmartReminders/Reminders/ReminderWriter.swift SmartRemindersTests/ReminderWriterTests.swift
git commit -m "feat: add reminder writer boundary"
```

## Task 6: Review View Model

**Files:**
- Create: `SmartReminders/Review/ReviewViewModel.swift`
- Create: `SmartRemindersTests/ReviewViewModelTests.swift`

- [ ] **Step 1: Write review view model tests**

Create `SmartRemindersTests/ReviewViewModelTests.swift`:

```swift
import XCTest
@testable import SmartReminders

@MainActor
final class ReviewViewModelTests: XCTestCase {
    func testDeletesReminderAndKeepsGroupIdsInSync() {
        let first = ReminderDraft.fixture(title: "Make smoothie")
        let second = ReminderDraft.fixture(title: "Buy raspberries")
        let viewModel = ReviewViewModel(
            originalText: "Smoothie supplies",
            validatedDraft: ValidatedDraft(
                parserVersion: "test-parser",
                reminders: [first, second],
                group: DraftGroup(id: UUID(), title: "Smoothies", mode: .grouped, reminderDraftIds: [first.id, second.id]),
                rawParserResponse: nil
            ),
            reminderWriter: MockReminderWriter(resultIDs: []),
            localStore: LocalStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        )

        viewModel.deleteReminder(id: first.id)

        XCTAssertEqual(viewModel.reminders.map(\.id), [second.id])
        XCTAssertEqual(viewModel.group?.reminderDraftIds, [second.id])
    }

    func testSwitchesGroupMode() {
        let draft = ReminderDraft.fixture(title: "Make smoothie")
        let viewModel = ReviewViewModel(
            originalText: "Smoothie supplies",
            validatedDraft: ValidatedDraft(
                parserVersion: "test-parser",
                reminders: [draft],
                group: DraftGroup(id: UUID(), title: "Smoothies", mode: .grouped, reminderDraftIds: [draft.id]),
                rawParserResponse: nil
            ),
            reminderWriter: MockReminderWriter(resultIDs: []),
            localStore: LocalStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        )

        viewModel.setGroupMode(.separate)

        XCTAssertEqual(viewModel.group?.mode, .separate)
    }

    func testApproveCreatesRemindersAndStoresSession() async throws {
        let draft = ReminderDraft.fixture(title: "Make smoothie")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalStore(directory: directory)
        let viewModel = ReviewViewModel(
            originalText: "Smoothie supplies",
            validatedDraft: ValidatedDraft(parserVersion: "test-parser", reminders: [draft], group: nil, rawParserResponse: "{\"ok\":true}"),
            reminderWriter: MockReminderWriter(resultIDs: ["apple-1"]),
            localStore: store
        )

        try await viewModel.approve()

        let sessions = try store.loadSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].status, .approved)
        XCTAssertEqual(sessions[0].createdReminderLinks.first?.appleReminderId, "apple-1")
    }
}

private extension ReminderDraft {
    static func fixture(title: String) -> ReminderDraft {
        ReminderDraft(
            id: UUID(),
            title: title,
            notes: nil,
            dueDate: nil,
            hasTime: false,
            recurrence: nil,
            priority: .none,
            targetList: nil,
            labels: [],
            confidence: 1,
            ambiguityFlags: [],
            isUndated: true
        )
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project SmartReminders.xcodeproj -scheme SmartReminders -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SmartRemindersTests/ReviewViewModelTests
```

Expected: FAIL because `ReviewViewModel` does not exist.

- [ ] **Step 3: Implement review view model**

Create `SmartReminders/Review/ReviewViewModel.swift`:

```swift
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
```

- [ ] **Step 4: Run review view model tests**

Run:

```bash
xcodebuild test -project SmartReminders.xcodeproj -scheme SmartReminders -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SmartRemindersTests/ReviewViewModelTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add SmartReminders/Review/ReviewViewModel.swift SmartRemindersTests/ReviewViewModelTests.swift
git commit -m "feat: manage reminder draft review"
```

## Task 7: Review Sheet UI And Root Flow

**Files:**
- Modify: `SmartReminders/ContentView.swift`
- Create: `SmartReminders/Review/ReviewSheet.swift`

- [ ] **Step 1: Replace root view with parse trigger and review sheet**

Modify `SmartReminders/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @State private var inputText = ""
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
```

- [ ] **Step 2: Create review sheet UI**

Create `SmartReminders/Review/ReviewSheet.swift`:

```swift
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

                if let group = viewModel.group {
                    Section("Group") {
                        TextField("Group title", text: Binding(
                            get: { viewModel.group?.title ?? "" },
                            set: { viewModel.group?.title = $0 }
                        ))

                        Picker("Mode", selection: Binding(
                            get: { group.mode },
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
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Title", text: $draft.title)
                            TextField("Notes", text: Binding($draft.notes, replacingNilWith: ""))
                            Toggle("Undated", isOn: $draft.isUndated)
                            Picker("Priority", selection: $draft.priority) {
                                ForEach(ReminderPriority.allCases, id: \.self) { priority in
                                    Text(priority.rawValue.capitalized).tag(priority)
                                }
                            }
                            TextField("List", text: Binding($draft.targetList, replacingNilWith: ""))
                            TextField("Labels", text: Binding(
                                get: { draft.labels.joined(separator: ", ") },
                                set: { draft.labels = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
                            ))
                            if !draft.ambiguityFlags.isEmpty {
                                Text("Inferred: \(draft.ambiguityFlags.joined(separator: \", \"))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button("Delete", role: .destructive) {
                                viewModel.deleteReminder(id: draft.id)
                            }
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

private extension Binding where Value == String? {
    init(_ source: Binding<String?>, replacingNilWith fallback: String) {
        self.init(
            get: { source.wrappedValue ?? fallback },
            set: { source.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}
```

- [ ] **Step 3: Build the app**

Run:

```bash
xcodebuild build -project SmartReminders.xcodeproj -scheme SmartReminders -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add SmartReminders/ContentView.swift SmartReminders/Review/ReviewSheet.swift
git commit -m "feat: add reminder draft review sheet"
```

## Task 8: Cloud Parser Adapter

**Files:**
- Modify: `SmartReminders/Parsing/ParserClient.swift`
- Modify: `SmartReminders/ContentView.swift`

- [ ] **Step 1: Add cloud parser client**

Append to `SmartReminders/Parsing/ParserClient.swift`:

```swift
struct CloudParserClient: ParserClient {
    var endpoint: URL
    var apiKey: String
    var urlSession: URLSession = .shared

    func parse(text: String) async throws -> ParserResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["text": text])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw ParserClientError.requestFailed
        }

        return try JSONDecoder().decode(ParserResponse.self, from: data)
    }
}

enum ParserClientError: Error {
    case requestFailed
}
```

- [ ] **Step 2: Keep preview parser as default until endpoint configuration exists**

Leave `PreviewParser` in `ContentView.swift` for local MVP development. Add this comment above `PreviewParser`:

```swift
// Local parser fixture used until endpoint and API key configuration are wired.
```

- [ ] **Step 3: Build and test**

Run:

```bash
xcodebuild test -project SmartReminders.xcodeproj -scheme SmartReminders -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add SmartReminders/Parsing/ParserClient.swift SmartReminders/ContentView.swift
git commit -m "feat: add cloud parser adapter"
```

## Task 9: Manual EventKit Verification Checklist

**Files:**
- Create: `docs/manual-testing/reminders-permissions.md`

- [ ] **Step 1: Write manual checklist**

Create `docs/manual-testing/reminders-permissions.md`:

```markdown
# Reminders Permission And Creation Checklist

Use this checklist on a simulator or device after the review sheet flow builds.

## Permission

- Launch Smart Reminders.
- Enter: `I bought high-protein milk, frozen blueberries, and frozen raspberries because I want to make fruit protein smoothies this week.`
- Tap `Parse reminder draft`.
- Tap `Create`.
- Confirm iOS shows the Reminders full access prompt.
- Deny access once and verify the app does not create reminders.
- Re-run, allow access, and continue.

## Creation

- Verify Apple Reminders contains `Make a fruit protein smoothie`.
- Verify Apple Reminders contains `Buy raspberries again`.
- Verify notes include the original context or labels where provided.
- Verify undated reminders appear without an alarm.
- Verify the app only creates reminders after tapping `Create`.

## Failure Recovery

- Disable Reminders access in Settings.
- Attempt creation again.
- Verify the draft is not silently discarded.
```

- [ ] **Step 2: Commit**

```bash
git add docs/manual-testing/reminders-permissions.md
git commit -m "docs: add reminders manual test checklist"
```

## Task 10: Final Verification

**Files:**
- Review all files changed by Tasks 1-9.

- [ ] **Step 1: Run full test suite**

Run:

```bash
xcodebuild test -project SmartReminders.xcodeproj -scheme SmartReminders -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

- [ ] **Step 2: Run app in simulator**

Run:

```bash
xcodebuild build -project SmartReminders.xcodeproj -scheme SmartReminders -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

- [ ] **Step 3: Confirm spec acceptance criteria**

Check:

- Smoothie example produces a reviewable draft with a group option.
- User can switch grouped/separate.
- User can keep an undated reminder.
- Apple Reminders are not created before approval.
- Approved reminders create via EventKit.
- Parse history is stored locally.
- Later Apple Reminders edits are not synced back in the MVP.

- [ ] **Step 4: Commit any final fixes**

```bash
git status --short
git add SmartReminders SmartRemindersTests docs project.yml
git commit -m "chore: verify smart reminders MVP"
```

Only create this commit if there are final verification fixes or documentation updates.

## Self-Review

- Spec coverage: The plan covers text input, cloud/API parsing boundary, strict parser contract, validation, review overlay, grouped/separate choice, EventKit creation after approval, local parse history, undated reminders, labels, error handling boundaries, tests, and manual EventKit verification.
- Scope check: The plan does not include voice capture, image parsing, preference memory, automatic creation, sync reconciliation, or a full companion reminder system.
- Type consistency: `ReminderDraft`, `DraftGroup`, `ParseSession`, `CreatedReminderLink`, `ValidatedDraft`, `ParserResponse`, `ReviewViewModel`, `ReminderWriting`, `EventKitReminderWriter`, and `LocalStore` are introduced before use in later tasks.
- Completeness scan: No plan step uses vague fill-in language; implementation snippets include concrete types, commands, and expected results.
