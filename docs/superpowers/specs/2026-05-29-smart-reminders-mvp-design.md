# Smart Reminders MVP Design

## Purpose

Smart Reminders is an iOS app that turns messy user intent into editable reminder drafts, then writes approved reminders into Apple Reminders. The first version focuses on parsing quality and review UX, not voice capture, photo parsing, long-term preference learning, or owning the full reminder lifecycle.

The motivating example is:

> I bought high-protein milk, frozen blueberries, and frozen raspberries because I want to make fruit protein smoothies this week.

The app should parse that input into useful reminder suggestions, let the user revise them, and create Apple Reminders only after explicit approval.

## Scope

### In Scope

- Text-only input.
- Cloud/API-based parsing.
- Structured reminder draft generation.
- Overlay or sheet-style form editor for reviewing parse results.
- User edits before approval.
- User choice between grouped and independent reminders when a parse contains related items.
- Approved reminders are created in Apple Reminders using EventKit.
- Local parse history that stores original input, final approved draft, and Apple Reminder identifiers.
- Undated reminders are allowed when approved by the user.
- Lightweight labels or categories may be suggested by the parser and shown as editable hints.

### Out of Scope

- Voice capture.
- Photo or screenshot parsing.
- Preference memory or personalized parsing rules.
- Automatic creation of reminders without approval.
- A full companion reminder system that owns edits, completion, snoozing, or recurrence after reminders are created.
- Sync or reconciliation of later Apple Reminders edits back into the app.

## Product Flow

1. The user enters or pastes natural language text into the app.
2. The app sends the text to a cloud parser.
3. The parser returns structured draft data: reminders, optional group, optional labels, inferred dates, recurrence hints, notes, and ambiguity flags.
4. Local validation checks the parser output before showing it to the user.
5. The user reviews the result in an overlay or sheet-style form editor.
6. The user may edit fields, delete reminders, add dates, keep reminders undated, change grouping, or discard the draft.
7. On approval, the app creates the selected reminders in Apple Reminders.
8. The app stores local parse history and links each approved draft reminder to its Apple Reminder ID.
9. After creation, Apple Reminders owns ongoing editing and lifecycle.

## UX Model

The review UI is the heart of the MVP. It should feel like an editor for the parser's interpretation, not a chat transcript.

The review sheet includes:

- The original text for context.
- A group header when the parser detects a related set of reminders.
- A grouped/separate choice when grouping is applicable.
- Editable reminder rows with title, notes, due date/time, recurrence, priority, target list, and labels/categories.
- Clear markings for inferred or ambiguous fields.
- Delete controls for unwanted suggestions.
- Approve and discard actions.

For grouped reminders, the group exists primarily in the review UI and local parse history. Apple Reminders representation should stay simple in the MVP, such as using the same target list and context in notes. The MVP should not depend on complex Apple Reminders grouping behavior.

## Architecture

### ParserClient

Sends the user's text to the cloud/API parser and expects strict structured JSON in response. The parser client should be replaceable so future versions can use a different provider or an on-device model.

### DraftValidator

Validates and normalizes parser output before the UI sees it. It rejects invalid structures, flags impossible or ambiguous dates, fills safe defaults, and ensures parser output cannot pass directly into Apple Reminders without local checks.

### ReviewEditor

Presents the overlay/form editor. It owns draft editing, grouping/separation choice, deletion, approval, and discard behavior. It should make undated reminders valid but explicit.

### ReminderWriter

Owns the EventKit boundary. It requests Reminders access, maps approved drafts into Apple Reminders, creates reminders only after user approval, and returns created reminder identifiers.

### LocalStore

Stores parse history and reminder links. It does not act as the source of truth for active reminders after creation.

## Data Model

### ParseSession

- `id`
- `originalText`
- `createdAt`
- `parserVersion`
- `status`: `draft`, `approved`, or `discarded`
- `rawParserResponse` for development/debugging
- `finalApprovedDraft`

### ReminderDraft

- `id`
- `title`
- `notes`
- `dueDate`
- `hasTime`
- `recurrence`
- `priority`
- `targetList`
- `labels`
- `confidence`
- `ambiguityFlags`
- `isUndated`

### DraftGroup

- `id`
- `title`
- `mode`: `grouped` or `separate`
- `reminderDraftIds`

### CreatedReminderLink

- `id`
- `parseSessionId`
- `reminderDraftId`
- `appleCalendarId`
- `appleReminderId`
- `createdAt`
- `lastKnownTitle`
- `lastKnownStatus`

## Parser Contract

The parser should return a strict schema rather than prose. At minimum, it should include:

- One or more reminder drafts.
- Optional group title and grouping recommendation.
- Optional labels/categories.
- Optional due dates and recurrence.
- Notes or rationale when useful.
- Ambiguity flags for uncertain dates, vague intent, or low-confidence suggestions.

The parser must not be treated as trusted. The app validates all output locally and requires user approval before EventKit writes.

## Apple Reminders Integration

The app uses EventKit as the integration layer. Apple Reminders is the user-visible source of truth after approval.

The app should request Reminders access only when needed for creation or list lookup. On iOS versions that require full Reminders access, the app should include the relevant usage description and explain that reminders are only created after approval.

The MVP should support:

- Creating reminders.
- Setting title, notes, due date/time, recurrence, priority, and target list where supported.
- Creating undated reminders.
- Storing Apple Reminder identifiers after creation.

The MVP should not support:

- Continuous sync from Apple Reminders.
- Conflict resolution.
- Automatic updates to existing Apple Reminders.

## Error Handling And Trust Rules

- No reminder is created unless the user approves the visible draft.
- If parsing fails, show the original text and a retry option.
- If parser output is invalid, keep the user on the draft screen and mark the problematic fields.
- If inferred dates are vague or questionable, show them as editable and marked as inferred.
- If Reminders permission is denied, keep the approved draft locally but do not create Apple Reminders.
- If some reminders are created and others fail, show exactly which reminders succeeded and keep failed reminders as drafts.
- The app should avoid hiding parser uncertainty.

## Testing Strategy

Parser and validation tests should carry most of the automated coverage:

- Fixed natural language examples, including the smoothie example.
- Mocked valid API responses.
- Invalid JSON responses.
- Missing fields.
- Ambiguous dates.
- Grouped and independent reminder suggestions.
- Undated reminder suggestions.

Review editor tests should cover:

- Editing fields.
- Deleting suggestions.
- Switching grouped/separate mode.
- Approving valid drafts.
- Blocking or marking invalid drafts.

Reminder writer tests should mock EventKit where practical. Real Apple Reminders permission and creation behavior should be verified with a small manual simulator/device checklist.

## Acceptance Criteria

- The smoothie example produces an editable draft with a sensible group option.
- The user can choose grouped or independent reminders.
- The user can approve undated reminders.
- The app never creates Apple Reminders before approval.
- Approved drafts create Apple Reminders with expected title, notes, due date/time, recurrence, priority, and target list when provided.
- The app stores parse history and links created reminders to Apple Reminder identifiers.
- Later edits in Apple Reminders do not need to sync back into the app in the MVP.
