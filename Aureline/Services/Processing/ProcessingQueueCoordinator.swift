import Observation
import Foundation
import SwiftData

@MainActor
@Observable
final class ProcessingQueueCoordinator {
    private let modelContainer: ModelContainer
    private let audioFileStore: AudioFileStore
    private let transcriptionService: any TranscriptionService
    private let actionExtractionService: ActionExtractionService

    private var activeTranscriptionTasks: [UUID: Task<Void, Never>] = [:]
    private var activeExtractionTasks: [UUID: Task<Void, Never>] = [:]
    private var resumedPendingJobs = false

    init(
        modelContainer: ModelContainer,
        audioFileStore: AudioFileStore = AudioFileStore(),
        transcriptionService: any TranscriptionService,
        actionExtractionService: ActionExtractionService = ActionExtractionService()
    ) {
        self.modelContainer = modelContainer
        self.audioFileStore = audioFileStore
        self.transcriptionService = transcriptionService
        self.actionExtractionService = actionExtractionService
    }

    func transcribeMemo(id memoID: UUID, allowAuthorizationPrompt: Bool = true) async {
        if let existingTask = activeTranscriptionTasks[memoID] {
            await existingTask.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.runTranscription(for: memoID, allowAuthorizationPrompt: allowAuthorizationPrompt)
        }
        activeTranscriptionTasks[memoID] = task
        await task.value
    }

    func extractMemo(id memoID: UUID) async {
        if let existingTask = activeExtractionTasks[memoID] {
            await existingTask.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.runExtraction(for: memoID)
        }
        activeExtractionTasks[memoID] = task
        await task.value
    }

    func resumePendingJobsIfNeeded() {
        guard !resumedPendingJobs else { return }
        resumedPendingJobs = true

        Task { [weak self] in
            await self?.resumePendingJobs()
        }
    }

    private func resumePendingJobs() async {
        let repository = makeRepository()

        guard let memoIDs = try? repository.fetchMemoIDs(withTranscriptionStatus: .processing) else {
            return
        }

        for memoID in memoIDs {
            Task { [weak self] in
                await self?.transcribeMemo(id: memoID, allowAuthorizationPrompt: false)
            }
        }

        guard let extractionIDs = try? repository.fetchMemoIDs(withExtractionStatus: .processing) else {
            return
        }

        for memoID in extractionIDs {
            Task { [weak self] in
                await self?.extractMemo(id: memoID)
            }
        }
    }

    private func runTranscription(for memoID: UUID, allowAuthorizationPrompt: Bool) async {
        defer {
            activeTranscriptionTasks[memoID] = nil
        }

        let repository = makeRepository()

        do {
            guard let memo = try repository.fetchMemo(id: memoID) else { return }

            if allowAuthorizationPrompt {
                let authorizationStatus = await transcriptionService.requestAuthorizationIfNeeded()
                try handleAuthorizationStatus(authorizationStatus)
            }

            let audioFileURL = try repository.audioFileURL(for: memo)
            let localeIdentifier = memo.localeIdentifier

            try repository.prepareForTranscription(memo)

            let transcription = try await transcriptionService.transcribeAudio(
                at: audioFileURL,
                localeIdentifier: localeIdentifier
            )

            guard let refreshedMemo = try repository.fetchMemo(id: memoID) else { return }
            try repository.applyTranscription(transcription, to: refreshedMemo)
        } catch {
            handleFailure(error, memoID: memoID)
        }
    }

    private func runExtraction(for memoID: UUID) async {
        defer {
            activeExtractionTasks[memoID] = nil
        }

        let repository = makeRepository()

        do {
            guard let memo = try repository.fetchMemo(id: memoID) else { return }
            let transcriptText = memo.transcriptText ?? ""
            try repository.prepareForExtraction(memo)

            let extraction = try actionExtractionService.extract(
                from: transcriptText,
                localeIdentifier: memo.localeIdentifier,
                referenceDate: memo.createdAt
            )

            guard let refreshedMemo = try repository.fetchMemo(id: memoID) else { return }
            try repository.applyExtraction(extraction, to: refreshedMemo)
        } catch {
            handleExtractionFailure(error, memoID: memoID)
        }
    }

    private func handleAuthorizationStatus(_ status: TranscriptionAuthorizationState) throws {
        switch status {
        case .authorized:
            break
        case .notDetermined:
            throw TranscriptionError.authorizationUnavailable
        case .denied:
            throw TranscriptionError.authorizationDenied
        case .restricted:
            throw TranscriptionError.authorizationRestricted
        case .unavailable:
            throw TranscriptionError.authorizationUnavailable
        }
    }

    private func handleFailure(_ error: Error, memoID: UUID) {
        do {
            let repository = makeRepository()
            guard let memo = try repository.fetchMemo(id: memoID) else { return }
            try repository.failTranscription(for: memo, error: error)
        } catch {
            assertionFailure("Unable to persist transcription failure: \(error.localizedDescription)")
        }
    }

    private func handleExtractionFailure(_ error: Error, memoID: UUID) {
        do {
            let repository = makeRepository()
            guard let memo = try repository.fetchMemo(id: memoID) else { return }
            try repository.failExtraction(for: memo, error: error)
        } catch {
            assertionFailure("Unable to persist extraction failure: \(error.localizedDescription)")
        }
    }

    private func makeRepository() -> VoiceMemoRepository {
        VoiceMemoRepository(
            modelContext: ModelContext(modelContainer),
            audioFileStore: audioFileStore
        )
    }
}
