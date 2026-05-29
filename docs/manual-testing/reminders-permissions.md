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
