import Observation
import Foundation
import SwiftData

private enum ProcessingRecoveryError: LocalizedError {
    case transcriptMissing

    var errorDescription: String? {
        switch self {
        case .transcriptMissing:
            return "Review stopped before the transcript was ready. Try again."
        }
    }
}

@MainActor
@Observable
final class ProcessingQueueCoordinator {
    private let modelContainer: ModelContainer
    private let audioFileStore: AudioFileStore
    private let transcriptionService: any TranscriptionService
    private let actionExtractionService: ActionExtractionService

    private var activeTranscriptionTasks: [UUID: Task<Void, Never>] = [:]
    private var activeExtractionTasks: [UUID: Task<Void, Never>] = [:]
    private var recoveryTask: Task<Void, Never>?

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

    func resumePendingJobsIfNeeded() async {
        if let recoveryTask {
            await recoveryTask.value
            return
        }

        let task: Task<Void, Never> = Task { [weak self] in
            await self?.resumePendingJobs()
        }
        recoveryTask = task
        await task.value
        recoveryTask = nil
    }

    private func resumePendingJobs() async {
        let repository = makeRepository()
        let transcriptionIDs = Set((try? repository.fetchMemoIDs(withTranscriptionStatus: .processing)) ?? [])
        let extractionIDs = Set((try? repository.fetchMemoIDs(withExtractionStatus: .processing)) ?? [])

        await withTaskGroup(of: Void.self) { taskGroup in
            for memoID in transcriptionIDs {
                taskGroup.addTask { [weak self] in
                    await self?.transcribeMemo(id: memoID, allowAuthorizationPrompt: false)
                }
            }

            for memoID in extractionIDs.subtracting(transcriptionIDs) {
                taskGroup.addTask { [weak self] in
                    await self?.resumeExtractionIfPossible(for: memoID)
                }
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

            let authorizationStatus = allowAuthorizationPrompt
                ? await transcriptionService.requestAuthorizationIfNeeded()
                : transcriptionService.authorizationStatus()
            try handleAuthorizationStatus(authorizationStatus)

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

    private func resumeExtractionIfPossible(for memoID: UUID) async {
        let repository = makeRepository()

        do {
            guard let memo = try repository.fetchMemo(id: memoID) else { return }

            let transcriptText = (memo.transcriptText ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !transcriptText.isEmpty else {
                try repository.failExtraction(for: memo, error: ProcessingRecoveryError.transcriptMissing)
                return
            }
        } catch {
            handleExtractionFailure(error, memoID: memoID)
            return
        }

        await extractMemo(id: memoID)
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
