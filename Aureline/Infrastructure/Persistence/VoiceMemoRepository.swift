import Foundation
import SwiftData

@MainActor
struct VoiceMemoRepository {
    let modelContext: ModelContext
    let audioFileStore: AudioFileStore

    init(
        modelContext: ModelContext,
        audioFileStore: AudioFileStore = AudioFileStore()
    ) {
        self.modelContext = modelContext
        self.audioFileStore = audioFileStore
    }

    @discardableResult
    func createMemo(
        title: String,
        source: MemoSource,
        audioSourceURL: URL,
        localeIdentifier: String? = Locale.current.identifier
    ) throws -> VoiceMemo {
        let memo = VoiceMemo(
            id: UUID(),
            title: title,
            source: source,
            audioRelativePath: "",
            originalFilename: nil,
            durationSeconds: 0,
            localeIdentifier: localeIdentifier
        )

        let storedAudio = try audioFileStore.importAudio(from: audioSourceURL, memoID: memo.id)
        memo.audioRelativePath = storedAudio.relativePath
        memo.originalFilename = storedAudio.originalFilename
        memo.durationSeconds = storedAudio.durationSeconds

        modelContext.insert(memo)

        do {
            try modelContext.save()
            return memo
        } catch {
            modelContext.rollback()
            try? audioFileStore.deleteAudio(atRelativePath: storedAudio.relativePath)
            throw error
        }
    }

    @discardableResult
    func createDemoMemo(source: MemoSource) throws -> VoiceMemo {
        let demoAudioURL = try DemoAudioFileFactory.makeTemporaryAudioFile(source: source)
        defer { try? FileManager.default.removeItem(at: demoAudioURL.deletingLastPathComponent()) }

        let title: String
        switch source {
        case .recorded:
            title = "Project follow-up"
        case .imported:
            title = "Client estimate"
        }

        return try createMemo(
            title: title,
            source: source,
            audioSourceURL: demoAudioURL,
            localeIdentifier: source == .recorded ? Locale.current.identifier : nil
        )
    }

    func fetchMemo(id: UUID) throws -> VoiceMemo? {
        let descriptor = FetchDescriptor<VoiceMemo>(
            predicate: #Predicate { memo in
                memo.id == id
            }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchMemos() throws -> [VoiceMemo] {
        let descriptor = FetchDescriptor<VoiceMemo>(
            sortBy: [SortDescriptor(\VoiceMemo.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchMemoIDs(withTranscriptionStatus status: ProcessingStatus) throws -> [UUID] {
        let descriptor = FetchDescriptor<VoiceMemo>(
            predicate: #Predicate { memo in
                memo.transcriptionStatusRaw == status.rawValue
            }
        )
        return try modelContext.fetch(descriptor).map(\.id)
    }

    func fetchMemoIDs(withExtractionStatus status: ProcessingStatus) throws -> [UUID] {
        let descriptor = FetchDescriptor<VoiceMemo>(
            predicate: #Predicate { memo in
                memo.extractionStatusRaw == status.rawValue
            }
        )
        return try modelContext.fetch(descriptor).map(\.id)
    }

    func audioFileURL(for memo: VoiceMemo) throws -> URL {
        try audioFileStore.fileURL(for: memo.audioRelativePath)
    }

    func deleteMemo(_ memo: VoiceMemo) throws {
        let pendingDeletion = try audioFileStore.prepareForDeletion(atRelativePath: memo.audioRelativePath)
        modelContext.delete(memo)

        do {
            try modelContext.save()
            try audioFileStore.commitDeletion(pendingDeletion)
        } catch {
            modelContext.rollback()
            try? audioFileStore.rollbackDeletion(pendingDeletion)
            throw error
        }
    }

    func deleteMemo(id: UUID) throws {
        guard let memo = try fetchMemo(id: id) else { return }
        try deleteMemo(memo)
    }

    func prepareForTranscription(_ memo: VoiceMemo) throws {
        memo.transcriptionStatus = .processing
        memo.lastProcessingError = nil
        memo.touch()
        try modelContext.save()
    }

    func prepareForExtraction(_ memo: VoiceMemo) throws {
        memo.extractionStatus = .processing
        memo.lastProcessingError = nil
        memo.touch()
        try modelContext.save()
    }

    func applyTranscription(_ transcription: TranscriptionPayload, to memo: VoiceMemo) throws {
        clearSegments(for: memo)
        clearActionItems(for: memo)
        clearMentions(for: memo)

        memo.transcriptText = transcription.transcriptText
        memo.localeIdentifier = transcription.localeIdentifier
        memo.transcriptionStatus = .completed
        memo.extractionStatus = .notStarted
        memo.lastProcessingError = nil
        memo.touch()

        for segment in transcription.segments {
            memo.transcriptSegments.append(
                TranscriptSegment(
                    startSeconds: segment.startSeconds,
                    durationSeconds: segment.durationSeconds,
                    text: segment.text,
                    memo: memo
                )
            )
        }

        try modelContext.save()
    }

    func applyExtraction(_ extraction: ActionExtractionPayload, to memo: VoiceMemo) throws {
        clearActionItems(for: memo)
        clearMentions(for: memo)

        for candidate in extraction.actionItems {
            let actionItem = ExtractedActionItem(
                rawText: candidate.rawText,
                normalizedText: candidate.normalizedText,
                dueDate: candidate.dueDate,
                contactName: candidate.contactName,
                contactMethod: candidate.contactMethod,
                confidence: candidate.confidence,
                memo: memo
            )
            actionItem.memo = memo
            memo.actionItems.append(actionItem)
        }

        for candidate in extraction.mentions {
            let mention = ExtractedMention(
                kind: candidate.kind,
                displayText: candidate.displayText,
                normalizedValue: candidate.normalizedValue,
                confidence: candidate.confidence,
                memo: memo
            )
            mention.memo = memo
            memo.mentions.append(mention)
        }

        memo.extractionStatus = .completed
        memo.lastProcessingError = nil
        memo.touch()
        try modelContext.save()
    }

    func failTranscription(for memo: VoiceMemo, error: Error) throws {
        memo.transcriptionStatus = .failed
        memo.lastProcessingError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        memo.touch()
        try modelContext.save()
    }

    func failExtraction(for memo: VoiceMemo, error: Error) throws {
        memo.extractionStatus = .failed
        memo.lastProcessingError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        memo.touch()
        try modelContext.save()
    }

    private func clearSegments(for memo: VoiceMemo) {
        for segment in memo.transcriptSegments {
            modelContext.delete(segment)
        }
        memo.transcriptSegments.removeAll()
    }

    private func clearActionItems(for memo: VoiceMemo) {
        for actionItem in memo.actionItems {
            modelContext.delete(actionItem)
        }
        memo.actionItems.removeAll()
    }

    private func clearMentions(for memo: VoiceMemo) {
        for mention in memo.mentions {
            modelContext.delete(mention)
        }
        memo.mentions.removeAll()
    }
}
