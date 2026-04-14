# Aureline Device QA Checklist

## Scope
- Build: `Aureline`
- Platform: iPhone, iOS 18+
- Goal: verify recording/import, transcription, review, export, privacy copy, and failure handling on device

## Preflight
- Install a fresh build on a physical iPhone.
- Confirm the app launches in dark mode with readable contrast.
- Confirm the launch screen and app icon show the `Aureline` branding.
- Prepare sample audio files:
  - short English memo
  - long memo (10+ minutes)
  - memo in an unsupported locale for the device
  - silent or near-silent clip

## Onboarding And Navigation
- Launch with no existing notes and confirm the empty inbox copy is clear.
- Open `Capture`, `Inbox`, and `Settings` from the tab bar.
- From empty inbox, use `Open Capture` and `Review Access`.
- Confirm search works once sample notes exist.

## Permissions
- Microphone denied:
  - Deny microphone access on first record attempt.
  - Confirm recording is blocked with a clear recovery message.
  - Use the in-app Settings path and verify recording works after enabling access.
- Speech denied:
  - Deny speech recognition when adding a transcript.
  - Confirm the note stays saved and the failure message is clear.
  - Re-enable access in Settings and confirm retry works.
- Reminders denied:
  - Deny Reminders access on export.
  - Confirm export fails cleanly without losing the selected tasks.
  - Re-enable access and confirm export succeeds.

## Offline And Locale Handling
- Airplane mode:
  - Enable Airplane Mode before launching the app.
  - Import or record a note and confirm the note is still saved locally.
  - Try transcription and confirm behavior stays local with a clear unsupported/offline message if needed.
- Unsupported locale:
  - Import or record a memo whose locale is unsupported on the test device.
  - Confirm the note remains in the inbox.
  - Confirm the error message explains that transcription is unavailable on this device for that language.
- Silent audio:
  - Import a silent clip.
  - Confirm transcription fails with a clear no-speech message.

## Recording And Import
- Record a short note, save it, and confirm it appears in the inbox with the correct source badge.
- Start recording, then discard it, and confirm no extra note is created.
- Import supported `m4a`, `mp3`, and `wav` files from Files.
- Try importing an unsupported file type and confirm the app shows a visible error.

## Transcript And Review
- Transcribe a short English note and confirm transcript text appears in detail view.
- Review extracted tasks and mentions, edit at least one field, save, and confirm the changes persist after leaving and reopening the note.
- Confirm notes with no transcript show the empty transcript and review states correctly.
- Confirm a previously failed transcript or review shows a readable failure state and can be retried.

## Long Audio And Relaunch
- Import or record a 10+ minute memo.
- Start transcription, background the app, then reopen it.
- Force-quit during processing, relaunch, and confirm pending work resumes or fails into a recoverable state.
- Confirm the app stays responsive while the long memo is being processed.

## Export
- Review a memo with extracted tasks and export selected tasks to Reminders.
- Confirm reminder title, due date, and note context match the reviewed task.
- Deselect all tasks and confirm Reminders export is blocked until at least one task is selected.
- Use `Share Summary` and confirm the generated text includes the memo title, selected tasks, mentions, and transcript.
- Confirm Notes/share export does not happen automatically without explicit user action.

## Privacy And Data Handling
- Confirm privacy copy in onboarding, settings, and capture is readable and consistent.
- Confirm imported and recorded notes remain available after going offline.
- Delete a note and confirm its transcript/review state is removed from the inbox.
- Reinstall only if required by the release checklist, then confirm first-launch behavior is still correct.

## Release Signoff
- Record result for each section as `Pass`, `Fail`, or `Needs follow-up`.
- Capture screenshots for any failure state that blocks ship.
- Log exact device model, iOS version, build number, and locale used for the test run.
