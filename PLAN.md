# Voice Note Action Extractor Implementation Plan

## Product Summary
Build a native iPhone app that helps consultants, freelancers, and tradespeople turn voice memos into usable work items. The MVP must let users record or import audio, transcribe it on-device, extract action items plus dates and contacts, then export results to Reminders or share them into Notes. Keep the product local-first and privacy-forward.

This is an iPhone-only App Store style app. Do not introduce a web frontend, server API, or generic backend unless a later requirement makes that unavoidable. For MVP, there should be no remote service dependency.

## MVP Scope
In scope:
- Record a new memo inside the app.
- Import an existing audio file from Files.
- Run on-device speech-to-text.
- Extract action items, dates, and contact-like entities from transcript text.
- Let the user review and edit extracted results.
- Export selected tasks to Reminders.
- Share transcript plus summary into Notes via the iOS share sheet.

Out of scope for MVP:
- Direct browsing of the Apple Voice Memos library.
- iCloud sync, accounts, or multi-device sync.
- A direct Apple Notes database integration.
- Team collaboration or sharing features.
- Android, web, or desktop clients.
- Server-side transcription or LLM-based extraction.

## Platform Constraints and Design Decisions
- Target iOS 18+ to align with improved on-device speech capabilities.
- Use SwiftUI for UI, SwiftData for local structured storage, and AVFoundation/Speech/NaturalLanguage/EventKit for system capabilities.
- The iOS sandbox does not allow direct access to the system Voice Memos database or library. Import must happen by recording in-app or by selecting/share-opening an audio file the app is allowed to read.
- Apple Notes does not offer a public CRUD API. Notes export must be implemented as a share action with a generated text payload, not as direct note creation.
- Core user value should survive offline. Do not silently fall back to cloud recognition.
- The first release can be English-first for extraction heuristics, but the transcription layer should be locale-aware when the device supports it.

## Architecture Overview
Use a single native app target plus unit and UI test targets. Keep logic separated by feature folders and a small internal service layer. There is no separate backend.

Recommended app layers:
- `App`: app entry point, root navigation, dependency assembly, model container setup.
- `Domain`: SwiftData models, enums, lightweight protocols, processing status types.
- `Infrastructure`: file storage, permission coordination, persistence helpers.
- `Services`: recording, import, transcription, extraction, export, processing coordination.
- `Features`: SwiftUI screens and view models/state adapters.
- `Tests`: unit tests for business logic and UI smoke tests for navigation and review flows.

Suggested Xcode/file layout:

```text
VoiceNoteActionExtractor/
  App/
    VoiceNoteActionExtractorApp.swift
    AppEnvironment.swift
    RootView.swift
  Domain/
    Models/
      VoiceMemo.swift
      TranscriptSegment.swift
      ExtractedActionItem.swift
      ExtractedMention.swift
    Types/
      MemoSource.swift
      ProcessingStatus.swift
      ExportStatus.swift
  Infrastructure/
    Persistence/
      ModelContainerProvider.swift
      VoiceMemoRepository.swift
    Storage/
      AudioFileStore.swift
    Permissions/
      PermissionCoordinator.swift
  Services/
    Recording/
      AudioRecorderService.swift
    Import/
      AudioImportService.swift
    Transcription/
      TranscriptionService.swift
      SpeechTranscriptionService.swift
    Extraction/
      ActionExtractionService.swift
      DateEntityParser.swift
      ContactEntityParser.swift
    Export/
      ReminderExportService.swift
      NotesShareComposer.swift
    Processing/
      ProcessingQueueCoordinator.swift
  Features/
    Inbox/
      InboxView.swift
      MemoRowView.swift
    Capture/
      RecordMemoView.swift
    Import/
      ImportButton.swift
    Detail/
      MemoDetailView.swift
      TranscriptSectionView.swift
    Extraction/
      ExtractionReviewView.swift
      ActionItemEditorView.swift
    Export/
      ExportSheetPresenter.swift
    Settings/
      SettingsView.swift
      OnboardingView.swift
  Resources/
    SampleAudio/
VoiceNoteActionExtractorTests/
VoiceNoteActionExtractorUITests/
```

## Data Model Notes
Use SwiftData for structured records and keep binary audio files in Application Support.

### `VoiceMemo`
Suggested fields:
- `id: UUID`
- `createdAt: Date`
- `updatedAt: Date`
- `title: String`
- `sourceRaw: String` for recorded vs imported
- `audioRelativePath: String`
- `originalFilename: String?`
- `durationSeconds: Double`
- `localeIdentifier: String?`
- `transcriptText: String?`
- `transcriptionStatusRaw: String`
- `extractionStatusRaw: String`
- `lastProcessingError: String?`
- relationships to transcript segments, extracted action items, and extracted mentions

### `TranscriptSegment`
Optional but useful if the speech API returns timed segments.
Suggested fields:
- `id: UUID`
- `memo: VoiceMemo`
- `startSeconds: Double`
- `durationSeconds: Double`
- `text: String`

### `ExtractedActionItem`
Suggested fields:
- `id: UUID`
- `memo: VoiceMemo`
- `rawText: String`
- `normalizedText: String`
- `dueDate: Date?`
- `contactName: String?`
- `contactMethod: String?`
- `confidence: Double`
- `isSelectedForExport: Bool`
- `exportStatusRaw: String`

### `ExtractedMention`
Use this for non-task entities the user may still want to review.
Suggested fields:
- `id: UUID`
- `memo: VoiceMemo`
- `kindRaw: String` for date/contact/other
- `displayText: String`
- `normalizedValue: String?`
- `confidence: Double`

Implementation notes:
- Persist enums as raw strings to reduce SwiftData migration friction.
- Save relative paths when possible so the app can relocate its container cleanly.
- Deleting a memo must cascade through segments and extracted entities and also remove the copied audio file.

## Core User Flows
### 1. Record memo
1. User opens the app and taps Record.
2. App requests microphone permission if needed.
3. `AudioRecorderService` records to a temporary local file.
4. On save, `AudioFileStore` moves the file into Application Support and a `VoiceMemo` record is created.
5. The inbox shows the new memo with `Not Transcribed` status.

### 2. Import existing audio
1. User taps Import.
2. Present `fileImporter` for supported audio UTTypes.
3. Copy the selected file into app storage immediately so future access does not depend on a security-scoped URL.
4. Create a `VoiceMemo` record with source `imported` and discovered duration metadata.
5. Show the imported memo in the inbox.

### 3. Transcribe on-device
1. User opens a memo detail screen and taps Transcribe.
2. `SpeechTranscriptionService` checks device capability and locale availability.
3. If on-device recognition is supported, process the local audio file and persist transcript text and optional segments.
4. If unsupported, set a clear error state and stop. Do not silently send audio to a server.
5. The memo detail screen updates to show transcript text and status.

### 4. Extract actions, dates, and contacts
1. User taps Extract.
2. `ActionExtractionService` splits transcript text into sentences.
3. Apply heuristic action detection, date parsing, and contact/entity parsing.
4. Persist extracted action items and mentions.
5. Present an editable review UI so the user can fix low-confidence items before export.

### 5. Export results
1. User selects extracted tasks and taps Export to Reminders.
2. `ReminderExportService` requests reminders permission if needed.
3. Create reminder records with title, due date, and memo context.
4. For Notes, generate a plain text or markdown summary and present `UIActivityViewController`.
5. Let the user choose Notes or another share destination.

## Implementation Phases

### Phase 1: Project foundation
Create the project shell first and keep it buildable after every task.

Files/modules to create early:
- `App/VoiceNoteActionExtractorApp.swift`
- `App/RootView.swift`
- `Infrastructure/Persistence/ModelContainerProvider.swift`
- `Infrastructure/Permissions/PermissionCoordinator.swift`
- basic placeholder views under `Features/`

Implementation notes:
- Add usage descriptions for microphone and speech recognition at the start.
- Set up a single `ModelContainer` and inject it from the app entry point.
- Add preview/sample data builders so UI work does not depend on live services.

### Phase 2: Persistence and audio storage
Implement the local-first data backbone before wiring live speech or export.

Files/modules:
- `Domain/Models/VoiceMemo.swift`
- `Domain/Models/TranscriptSegment.swift`
- `Domain/Models/ExtractedActionItem.swift`
- `Domain/Models/ExtractedMention.swift`
- `Infrastructure/Storage/AudioFileStore.swift`
- `Infrastructure/Persistence/VoiceMemoRepository.swift`

Implementation notes:
- Store binary audio in Application Support, not in SwiftData blobs.
- Use deterministic filenames such as memo UUID plus original extension.
- Centralize delete behavior so records and files cannot drift out of sync.

### Phase 3: Capture and import
Build the two ingestion paths next.

Files/modules:
- `Services/Recording/AudioRecorderService.swift`
- `Services/Import/AudioImportService.swift`
- `Features/Capture/RecordMemoView.swift`
- `Features/Import/ImportButton.swift`

Implementation notes:
- Use AVAudioSession plus AVAudioRecorder for simple MVP capture.
- Record to m4a for broad compatibility.
- On import, copy the selected file immediately and stop depending on the external URL.
- Handle permission denial and malformed file imports visibly.

### Phase 4: On-device transcription
Wrap the speech framework behind a protocol so tests can mock it.

Files/modules:
- `Services/Transcription/TranscriptionService.swift`
- `Services/Transcription/SpeechTranscriptionService.swift`
- `Features/Detail/TranscriptSectionView.swift`
- `Services/Processing/ProcessingQueueCoordinator.swift`

Implementation notes:
- Prefer the newer iOS 18 on-device speech APIs when practical.
- Keep a fallback path to legacy Speech APIs only if on-device recognition can still be enforced.
- Persist transcription state so interrupted jobs can be retried.
- Do not implement a cloud fallback in MVP.

### Phase 5: Extraction pipeline
Keep extraction deterministic and explainable for MVP.

Files/modules:
- `Services/Extraction/ActionExtractionService.swift`
- `Services/Extraction/DateEntityParser.swift`
- `Services/Extraction/ContactEntityParser.swift`
- `Features/Extraction/ExtractionReviewView.swift`
- `Features/Extraction/ActionItemEditorView.swift`

Implementation notes:
- Use sentence tokenization to avoid treating the transcript as one large blob.
- Start with explicit action cues such as `call`, `email`, `send`, `schedule`, `follow up`, `remember to`, and `need to`.
- Use `NSDataDetector` for dates, times, phone numbers, email addresses, and links.
- Use on-device NLP tagging for names where available, but keep the review UI editable because confidence will vary.
- Keep extraction output stable and testable; avoid nondeterministic model calls for MVP.

### Phase 6: Main UI
Once data flows work, build the actual user-facing screens.

Files/modules:
- `Features/Inbox/InboxView.swift`
- `Features/Inbox/MemoRowView.swift`
- `Features/Detail/MemoDetailView.swift`
- `Features/Settings/SettingsView.swift`
- `Features/Settings/OnboardingView.swift`

Implementation notes:
- Inbox should show source, created date, duration, and processing badges.
- Memo detail should expose transcript and extraction actions in a single place.
- Review screens should favor clarity over density. Users need to understand what will be exported.
- Add clear empty states for first launch and error states for unsupported speech capability.

### Phase 7: Export integrations
Deliver the user payoff after review is stable.

Files/modules:
- `Services/Export/ReminderExportService.swift`
- `Services/Export/NotesShareComposer.swift`
- `Features/Export/ExportSheetPresenter.swift`

Implementation notes:
- Reminders export should map one extracted task to one reminder.
- Include memo context in reminder notes so the source is not lost.
- Notes export should create a clean summary text block containing memo title, transcript, and extracted actions.
- Label this action as `Share to Notes` or `Share Summary`, not `Sync to Notes`.

### Phase 8: Lifecycle resilience and polish
Use this phase to harden the app rather than adding unrelated scope.

Recommended work:
- Resume unfinished processing on relaunch.
- Add a settings screen with permission status and privacy explanation.
- Add optional Core Spotlight indexing only if the main flow is already stable.
- Tighten copy around sandbox limitations and local-only processing.

Do not add during MVP unless time remains:
- Share extensions.
- Cloud sync.
- Team features.
- Complex background transcription scheduling.

## API and Framework Notes
### Speech
- Hide framework specifics behind `TranscriptionService`.
- Require on-device recognition.
- If a locale is unsupported, surface a user-visible error and let the user keep the memo for later retry.

### Extraction
- `NLTokenizer` or equivalent sentence splitting for transcript normalization.
- `NSDataDetector` for dates and structured contact-like data.
- `NLTagger` or similar for name/entity hints.
- Action scoring should be heuristic and deterministic so it is easy to test.

### Reminders
- Use EventKit with explicit permission prompts.
- Export only after the user selects the action items they want.

### Notes export
- Use a SwiftUI wrapper around `UIActivityViewController`.
- Generate plain text or markdown; avoid complex document formats unless a real need emerges.

## Test Strategy
### Unit tests
Cover:
- SwiftData repository behavior.
- `AudioFileStore` copy/delete behavior.
- action extraction heuristics on fixed transcript fixtures.
- date/contact parsing logic.
- reminder export mapping from `ExtractedActionItem` to reminder payload.

### Integration tests
Cover:
- creating a memo record from an imported fixture audio file.
- running a mocked transcription service and persisting transcript text.
- running extraction and verifying linked action items/mentions are stored.

### UI tests
Cover:
- app launch into empty inbox.
- opening a sample memo detail screen.
- viewing transcript and extraction review states.
- basic export UI presentation.

### Manual device QA
Check:
- microphone permission denied then granted.
- speech permission denied then granted.
- reminders permission denied then granted.
- unsupported locale handling.
- airplane mode behavior.
- long audio files and app relaunch during processing.

Important testing constraint:
- Do not rely on live microphone input or live speech recognition in CI. Abstract those services and use fixtures/mocks for automated tests.

## Acceptance Criteria
- User can record and save a memo on iPhone.
- User can import an audio file from Files.
- Audio is copied into the app sandbox for offline reuse.
- Transcript can be generated on-device and persisted.
- Action items, dates, and contacts are extracted from transcript text.
- User can edit extracted items before export.
- Selected tasks can be exported to Reminders.
- Transcript and summary can be shared to Notes through the share sheet.
- Core flow works without a backend.
- Test coverage exists for core persistence and extraction logic.

## Risk Mitigations
- Transcription quality varies: keep transcript editable, preserve source audio, and expose retry/error states.
- Voice Memos import is constrained: explain the limitation early and design around file import/in-app recording.
- Notes API is limited: implement share-based export and set product copy accordingly.
- Long files may be slow: persist job state, resume after relaunch, and keep MVP expectations clear.

## Branch Handoff Instructions For The Downstream Agent
- Execute on a Mac with Xcode and iPhone simulator access.
- Use git branch handoff from the start. Suggested branches: `feat/ios-foundation`, `feat/audio-ingest`, `feat/transcription`, `feat/extraction`, `feat/export`, `feat/qa-hardening`.
- Keep each task independently buildable before moving on.
- After each branch, run a simulator build and the available unit/UI test subset.
- Do not introduce a backend to work around local platform limitations. Solve within native iOS constraints unless explicitly redirected.
- If you hit a hard blocker on speech APIs, keep the protocol abstraction and ship the rest of the app with graceful unsupported states rather than widening scope.
