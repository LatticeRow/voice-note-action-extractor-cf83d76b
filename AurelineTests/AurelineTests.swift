import SwiftData
import XCTest
@testable import Aureline

@MainActor
final class AurelineTests: XCTestCase {
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
        context.repository.addPlaceholderExtraction(to: memo)

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

        coordinator.resumePendingJobsIfNeeded()
        try await Task.sleep(nanoseconds: 200_000_000)

        let updatedMemo = try XCTUnwrap(context.repository.fetchMemo(id: memo.id))
        XCTAssertEqual(updatedMemo.transcriptionStatus, .completed)
        XCTAssertFalse(updatedMemo.transcriptSegments.isEmpty)
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
