import SwiftData
import XCTest
@testable import Aureline

@MainActor
final class AurelineTests: XCTestCase {
    func testActionExtractionServiceProducesDeterministicOutputForFixtureTranscript() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let referenceDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 13, hour: 10)))

        let service = ActionExtractionService(
            dateParser: DateEntityParser(calendar: calendar),
            contactParser: ContactEntityParser()
        )

        let payload = try service.extract(
            from: """
            Call Jordan tomorrow about the lighting quote. Send the revised site plan before Friday.
            FYI the permit packet is already filed.
            """,
            localeIdentifier: "en_US",
            referenceDate: referenceDate
        )

        XCTAssertEqual(payload.actionItems.count, 2)
        XCTAssertEqual(payload.actionItems.map(\.normalizedText), [
            "Call Jordan tomorrow about the lighting quote",
            "Send the revised site plan before Friday",
        ])
        XCTAssertEqual(payload.actionItems.first?.contactName, "Jordan")
        XCTAssertEqual(payload.actionItems.first?.contactMethod, "Phone")
        XCTAssertEqual(payload.actionItems.first?.dueDate, calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate)))
        XCTAssertEqual(payload.actionItems.last?.contactMethod, "Email")
        XCTAssertEqual(payload.actionItems.last?.dueDate, calendar.date(from: DateComponents(year: 2026, month: 4, day: 17, hour: 9)))
        XCTAssertEqual(payload.mentions.map(\.displayText), ["Jordan", "tomorrow", "before Friday"])
    }

    func testContactEntityParserFindsStructuredContacts() {
        let contacts = ContactEntityParser().parse(
            in: "Email Priya at priya@example.com. Call (415) 555-0199 when the truck arrives."
        )

        XCTAssertTrue(contacts.contains(where: { $0.kind == .emailAddress && ($0.normalizedValue ?? "").contains("priya@example.com") }))
        XCTAssertTrue(contacts.contains(where: { $0.kind == .phoneNumber && ($0.normalizedValue ?? "").contains("415") }))
    }

    func testDateEntityParserFindsRelativeAndAbsoluteDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let referenceDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 13, hour: 10)))

        let dates = DateEntityParser(calendar: calendar).parse(
            in: "Call Jordan tomorrow. Send the update before Friday. Meet again on April 21, 2026 at 9 AM.",
            referenceDate: referenceDate
        )

        XCTAssertTrue(dates.contains(where: { $0.sourceText == "tomorrow" }))
        XCTAssertTrue(dates.contains(where: { $0.sourceText == "before Friday" }))
        XCTAssertTrue(dates.contains(where: { $0.sourceText == "April 21, 2026 at 9 AM" }))
    }

    func testCreateMemoPersistsStoredAudioAndFetchesByID() throws {
        let context = try makeModelContext()
        let audioSourceURL = try DemoAudioFileFactory.makeTemporaryAudioFile(source: .recorded)
        defer { try? FileManager.default.removeItem(at: audioSourceURL) }

        let memo = try context.repository.createMemo(
            title: "Site recap",
            source: .recorded,
            audioSourceURL: audioSourceURL
        )
        let fetchedMemo = try context.repository.fetchMemo(id: memo.id)
        let allMemos = try context.repository.fetchMemos()
        let storedAudioURL = try context.audioFileStore.fileURL(for: memo.audioRelativePath)

        XCTAssertNotNil(fetchedMemo)
        XCTAssertEqual(allMemos.count, 1)
        XCTAssertEqual(memo.source, .recorded)
        XCTAssertEqual(fetchedMemo?.title, "Site recap")
        XCTAssertEqual(memo.audioRelativePath, "Audio/\(memo.id.uuidString.lowercased()).wav")
        XCTAssertTrue(FileManager.default.fileExists(atPath: storedAudioURL.path))
        XCTAssertGreaterThan(memo.durationSeconds, 0)
    }

    func testDeletingMemoRemovesStoredAudioAndCascadeRecords() throws {
        let context = try makeModelContext()
        let audioSourceURL = try DemoAudioFileFactory.makeTemporaryAudioFile(source: .imported)
        defer { try? FileManager.default.removeItem(at: audioSourceURL) }

        let memo = try context.repository.createMemo(
            title: "Client estimate",
            source: .imported,
            audioSourceURL: audioSourceURL
        )
        try context.repository.applyTranscription(
            TranscriptionPayload(
                transcriptText: "Call Jordan tomorrow about the lighting quote. Send the revised site plan before Friday.",
                localeIdentifier: "en_US",
                segments: [
                    TranscriptionSegmentPayload(startSeconds: 0, durationSeconds: 3.0, text: "Call Jordan tomorrow about the lighting quote."),
                    TranscriptionSegmentPayload(startSeconds: 3.0, durationSeconds: 2.8, text: "Send the revised site plan before Friday."),
                ]
            ),
            to: memo
        )
        try context.repository.applyExtraction(
            ActionExtractionService().extract(
                from: try XCTUnwrap(memo.transcriptText),
                localeIdentifier: memo.localeIdentifier,
                referenceDate: memo.createdAt
            ),
            to: memo
        )

        let storedAudioURL = try context.audioFileStore.fileURL(for: memo.audioRelativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storedAudioURL.path))

        try context.repository.deleteMemo(memo)

        let remainingMemos = try context.repository.fetchMemos()
        let remainingSegments = try context.modelContext.fetch(FetchDescriptor<TranscriptSegment>())
        let remainingActionItems = try context.modelContext.fetch(FetchDescriptor<ExtractedActionItem>())
        let remainingMentions = try context.modelContext.fetch(FetchDescriptor<ExtractedMention>())

        XCTAssertTrue(remainingMemos.isEmpty)
        XCTAssertTrue(remainingSegments.isEmpty)
        XCTAssertTrue(remainingActionItems.isEmpty)
        XCTAssertTrue(remainingMentions.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storedAudioURL.path))
    }

    func testImportServiceCreatesMemoAndNormalizesTitle() throws {
        let context = try makeModelContext()
        let originalAudioURL = try DemoAudioFileFactory.makeTemporaryAudioFile(source: .imported)
        let renamedAudioURL = originalAudioURL.deletingLastPathComponent()
            .appendingPathComponent("client_follow-up copy.wav")

        try FileManager.default.moveItem(at: originalAudioURL, to: renamedAudioURL)
        defer { try? FileManager.default.removeItem(at: renamedAudioURL.deletingLastPathComponent()) }

        let memo = try AudioImportService().importAudio(
            from: [renamedAudioURL],
            repository: context.repository
        )

        XCTAssertEqual(memo.source, .imported)
        XCTAssertEqual(memo.title, "Client follow up copy")
        XCTAssertTrue(memo.durationSeconds > 0)
    }

    func testImportServiceRejectsUnsupportedFiles() throws {
        let context = try makeModelContext()
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("notes.txt")

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data("not audio".utf8).write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        XCTAssertThrowsError(
            try AudioImportService().importAudio(
                from: [fileURL],
                repository: context.repository
            )
        ) { error in
            XCTAssertEqual(error as? AudioImportError, .unsupportedType)
        }
    }

    func testProcessingQueuePersistsTranscriptAndSegments() async throws {
        let context = try makeModelContext()
        let audioSourceURL = try DemoAudioFileFactory.makeTemporaryAudioFile(source: .recorded)
        defer { try? FileManager.default.removeItem(at: audioSourceURL.deletingLastPathComponent()) }

        let memo = try context.repository.createMemo(
            title: "Job walk",
            source: .recorded,
            audioSourceURL: audioSourceURL
        )
        let coordinator = ProcessingQueueCoordinator(
            modelContainer: context.modelContainer,
            audioFileStore: context.audioFileStore,
            transcriptionService: MockTranscriptionService()
        )

        await coordinator.transcribeMemo(id: memo.id)

        let updatedMemo = try XCTUnwrap(context.repository.fetchMemo(id: memo.id))
        XCTAssertEqual(updatedMemo.transcriptionStatus, .completed)
        XCTAssertEqual(
            updatedMemo.transcriptText,
            "Call Jordan tomorrow about the lighting quote. Send the revised site plan before Friday."
        )
        XCTAssertEqual(updatedMemo.transcriptSegments.count, 2)
        XCTAssertNil(updatedMemo.lastProcessingError)
    }

    func testProcessingQueuePersistsExplicitOnDeviceFailure() async throws {
        let context = try makeModelContext()
        let audioSourceURL = try DemoAudioFileFactory.makeTemporaryAudioFile(source: .imported)
        defer { try? FileManager.default.removeItem(at: audioSourceURL.deletingLastPathComponent()) }

        let memo = try context.repository.createMemo(
            title: "Client follow-up",
            source: .imported,
            audioSourceURL: audioSourceURL
        )
        let coordinator = ProcessingQueueCoordinator(
            modelContainer: context.modelContainer,
            audioFileStore: context.audioFileStore,
            transcriptionService: MockTranscriptionService(mode: .onDeviceUnavailable)
        )

        await coordinator.transcribeMemo(id: memo.id)

        let updatedMemo = try XCTUnwrap(context.repository.fetchMemo(id: memo.id))
        XCTAssertEqual(updatedMemo.transcriptionStatus, .failed)
        XCTAssertEqual(
            updatedMemo.lastProcessingError,
            "Offline transcription for English (United States) isn’t available on this device."
        )
    }

    func testResumePendingTranscriptionCompletesAfterRelaunch() async throws {
        let context = try makeModelContext()
        let audioSourceURL = try DemoAudioFileFactory.makeTemporaryAudioFile(source: .recorded)
        defer { try? FileManager.default.removeItem(at: audioSourceURL.deletingLastPathComponent()) }

        let memo = try context.repository.createMemo(
            title: "Project recap",
            source: .recorded,
            audioSourceURL: audioSourceURL
        )
        try context.repository.prepareForTranscription(memo)

        let coordinator = ProcessingQueueCoordinator(
            modelContainer: context.modelContainer,
            audioFileStore: context.audioFileStore,
            transcriptionService: MockTranscriptionService()
        )

        await coordinator.resumePendingJobsIfNeeded()

        let updatedMemo = try XCTUnwrap(context.repository.fetchMemo(id: memo.id))
        XCTAssertEqual(updatedMemo.transcriptionStatus, .completed)
        XCTAssertFalse(updatedMemo.transcriptSegments.isEmpty)
    }

    func testResumePendingExtractionCompletesAfterRelaunch() async throws {
        let context = try makeModelContext()
        let audioSourceURL = try DemoAudioFileFactory.makeTemporaryAudioFile(source: .recorded)
        defer { try? FileManager.default.removeItem(at: audioSourceURL.deletingLastPathComponent()) }

        let memo = try context.repository.createMemo(
            title: "Project recap",
            source: .recorded,
            audioSourceURL: audioSourceURL
        )
        memo.createdAt = ISO8601DateFormatter().date(from: "2026-04-13T10:00:00Z") ?? memo.createdAt
        try context.repository.applyTranscription(
            TranscriptionPayload(
                transcriptText: "Call Jordan tomorrow about the lighting quote. Send the revised site plan before Friday.",
                localeIdentifier: "en_US",
                segments: []
            ),
            to: memo
        )
        try context.repository.prepareForExtraction(memo)

        let coordinator = ProcessingQueueCoordinator(
            modelContainer: context.modelContainer,
            audioFileStore: context.audioFileStore,
            transcriptionService: MockTranscriptionService(),
            actionExtractionService: ActionExtractionService()
        )

        await coordinator.resumePendingJobsIfNeeded()

        let updatedMemo = try XCTUnwrap(context.repository.fetchMemo(id: memo.id))
        XCTAssertEqual(updatedMemo.extractionStatus, .completed)
        XCTAssertEqual(updatedMemo.actionItems.count, 2)
        XCTAssertTrue(updatedMemo.mentions.contains(where: { $0.displayText == "Jordan" }))
    }

    func testPendingExtractionWithoutTranscriptBecomesRecoverableFailureAfterRelaunch() async throws {
        let context = try makeModelContext()
        let audioSourceURL = try DemoAudioFileFactory.makeTemporaryAudioFile(source: .recorded)
        defer { try? FileManager.default.removeItem(at: audioSourceURL.deletingLastPathComponent()) }

        let memo = try context.repository.createMemo(
            title: "Project recap",
            source: .recorded,
            audioSourceURL: audioSourceURL
        )
        try context.repository.prepareForExtraction(memo)

        let coordinator = ProcessingQueueCoordinator(
            modelContainer: context.modelContainer,
            audioFileStore: context.audioFileStore,
            transcriptionService: MockTranscriptionService(),
            actionExtractionService: ActionExtractionService()
        )

        await coordinator.resumePendingJobsIfNeeded()

        let updatedMemo = try XCTUnwrap(context.repository.fetchMemo(id: memo.id))
        XCTAssertEqual(updatedMemo.extractionStatus, .failed)
        XCTAssertEqual(updatedMemo.lastProcessingError, "Review stopped before the transcript was ready. Try again.")
    }

    func testExtractionCoordinatorPersistsLinkedActionItemsAndMentionsWithoutSpeechAPIs() async throws {
        let context = try makeModelContext()
        let audioSourceURL = try DemoAudioFileFactory.makeTemporaryAudioFile(source: .recorded)
        defer { try? FileManager.default.removeItem(at: audioSourceURL.deletingLastPathComponent()) }

        let memo = try context.repository.createMemo(
            title: "Project recap",
            source: .recorded,
            audioSourceURL: audioSourceURL
        )
        memo.createdAt = ISO8601DateFormatter().date(from: "2026-04-13T10:00:00Z") ?? memo.createdAt
        try context.repository.applyTranscription(
            TranscriptionPayload(
                transcriptText: "Call Jordan tomorrow about the lighting quote. Send the revised site plan before Friday.",
                localeIdentifier: "en_US",
                segments: []
            ),
            to: memo
        )

        let coordinator = ProcessingQueueCoordinator(
            modelContainer: context.modelContainer,
            audioFileStore: context.audioFileStore,
            transcriptionService: MockTranscriptionService(),
            actionExtractionService: ActionExtractionService()
        )

        await coordinator.extractMemo(id: memo.id)

        let updatedMemo = try XCTUnwrap(context.repository.fetchMemo(id: memo.id))
        XCTAssertEqual(updatedMemo.extractionStatus, .completed)
        XCTAssertEqual(updatedMemo.actionItems.count, 2)
        XCTAssertTrue(updatedMemo.actionItems.allSatisfy { $0.memo?.id == memo.id })
        XCTAssertTrue(updatedMemo.mentions.contains(where: { $0.kind == .contact && $0.displayText == "Jordan" }))
        XCTAssertTrue(updatedMemo.mentions.contains(where: { $0.kind == .date }))
    }

    func testReminderExportDraftsIncludeDueDateMemoTitleAndContext() throws {
        let calendar = Calendar(identifier: .gregorian)
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-04-13T10:00:00Z"))
        let dueDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 14, hour: 9)))

        let memo = VoiceMemo(
            createdAt: createdAt,
            updatedAt: createdAt,
            title: "Client estimate",
            source: .imported,
            audioRelativePath: "Audio/client-estimate.m4a",
            transcriptText: "Call Jordan tomorrow about the lighting quote."
        )
        let actionItem = ExtractedActionItem(
            rawText: "Call Jordan tomorrow about the lighting quote",
            normalizedText: "Call Jordan about the lighting quote",
            dueDate: dueDate,
            contactName: "Jordan",
            contactMethod: "Phone",
            memo: memo
        )
        memo.actionItems.append(actionItem)

        let drafts = ReminderExportService.makeDrafts(for: memo, actionItems: [actionItem])

        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts.first?.title, "Call Jordan about the lighting quote")
        XCTAssertEqual(drafts.first?.dueDate, dueDate)
        XCTAssertTrue(drafts.first?.notes.contains("From Client estimate") ?? false)
        XCTAssertTrue(drafts.first?.notes.contains("Due") ?? false)
        XCTAssertTrue(drafts.first?.notes.contains("Jordan") ?? false)
        XCTAssertTrue(drafts.first?.notes.contains("Call Jordan tomorrow about the lighting quote") ?? false)
    }

    func testNotesShareComposerBuildsMarkdownSummaryFromSelectedTasksAndTranscript() throws {
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-04-13T10:00:00Z"))
        let memo = VoiceMemo(
            createdAt: createdAt,
            updatedAt: createdAt,
            title: "Client estimate",
            source: .imported,
            audioRelativePath: "Audio/client-estimate.m4a",
            transcriptText: "Call Jordan tomorrow about the lighting quote. Send the revised site plan before Friday."
        )
        let selectedTask = ExtractedActionItem(
            rawText: "Call Jordan tomorrow about the lighting quote",
            normalizedText: "Call Jordan about the lighting quote",
            dueDate: createdAt.addingTimeInterval(86_400),
            contactName: "Jordan",
            contactMethod: "Phone",
            memo: memo
        )
        let unselectedTask = ExtractedActionItem(
            rawText: "Send the revised site plan before Friday",
            normalizedText: "Send the revised site plan",
            dueDate: nil,
            contactName: nil,
            contactMethod: "Email",
            confidence: 0.82,
            isSelectedForExport: false,
            memo: memo
        )
        let mention = ExtractedMention(
            kind: .contact,
            displayText: "Jordan",
            normalizedValue: nil,
            confidence: 0.91,
            memo: memo
        )
        memo.actionItems.append(selectedTask)
        memo.actionItems.append(unselectedTask)
        memo.mentions.append(mention)

        let document = NotesShareComposer().makeDocument(for: memo)

        XCTAssertEqual(document.subject, "Client estimate")
        XCTAssertTrue(document.body.contains("# Client estimate"))
        XCTAssertTrue(document.body.contains("## Tasks"))
        XCTAssertTrue(document.body.contains("Call Jordan about the lighting quote"))
        XCTAssertFalse(document.body.contains("- [ ] Send the revised site plan"))
        XCTAssertTrue(document.body.contains("## Mentions"))
        XCTAssertTrue(document.body.contains("Jordan"))
        XCTAssertTrue(document.body.contains("## Transcript"))
        XCTAssertTrue(document.body.contains("Send the revised site plan before Friday."))
    }

    private func makeModelContext() throws -> RepositoryTestContext {
        let container = ModelContainerProvider.makeDefaultContainer(inMemory: true)
        let modelContext = ModelContext(container)
        let applicationSupportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)

        let audioFileStore = AudioFileStore(applicationSupportDirectory: applicationSupportDirectory)
        let repository = VoiceMemoRepository(modelContext: modelContext, audioFileStore: audioFileStore)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: applicationSupportDirectory)
        }

        return RepositoryTestContext(
            modelContainer: container,
            modelContext: modelContext,
            repository: repository,
            audioFileStore: audioFileStore
        )
    }
}

private struct RepositoryTestContext {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    let repository: VoiceMemoRepository
    let audioFileStore: AudioFileStore
}
