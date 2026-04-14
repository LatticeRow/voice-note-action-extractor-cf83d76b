import SwiftData
import SwiftUI

@main
struct AurelineApp: App {
    @State private var appEnvironment: AppEnvironment
    private let modelContainer: ModelContainer

    init() {
        let launchArguments = ProcessInfo.processInfo.arguments
        let usesInMemoryStore = launchArguments.contains("-uiTesting")
        modelContainer = ModelContainerProvider.makeDefaultContainer(inMemory: usesInMemoryStore)
        UITestSeedLoader.loadIfNeeded(modelContainer: modelContainer, launchArguments: launchArguments)
        _appEnvironment = State(initialValue: AppEnvironment(modelContainer: modelContainer, launchArguments: launchArguments))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appEnvironment)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}

@MainActor
private enum UITestSeedLoader {
    static func loadIfNeeded(modelContainer: ModelContainer, launchArguments: [String]) {
        guard launchArguments.contains("-uiTestingSeedInbox") else { return }

        let modelContext = ModelContext(modelContainer)
        let repository = VoiceMemoRepository(modelContext: modelContext)

        guard (try? repository.fetchMemos().isEmpty) != false else { return }

        do {
            let pendingMemo = try repository.createDemoMemo(source: .recorded)
            pendingMemo.title = "Morning brief"
            pendingMemo.touch()

            let transcribedMemo = try repository.createDemoMemo(source: .recorded)
            transcribedMemo.title = "Site recap"
            try repository.applyTranscription(sampleTranscription, to: transcribedMemo)

            let reviewedMemo = try repository.createDemoMemo(source: .imported)
            reviewedMemo.title = "Client estimate"
            try repository.applyTranscription(sampleTranscription, to: reviewedMemo)
            try repository.applyExtraction(
                try ActionExtractionService().extract(
                    from: sampleTranscription.transcriptText,
                    localeIdentifier: sampleTranscription.localeIdentifier,
                    referenceDate: reviewedMemo.createdAt
                ),
                to: reviewedMemo
            )

            let failedTranscriptMemo = try repository.createDemoMemo(source: .imported)
            failedTranscriptMemo.title = "Service call"
            try repository.failTranscription(
                for: failedTranscriptMemo,
                error: UITestSeedError(message: "Offline transcription isn’t available on this device.")
            )

            let failedReviewMemo = try repository.createDemoMemo(source: .recorded)
            failedReviewMemo.title = "Quote follow up"
            try repository.applyTranscription(sampleTranscription, to: failedReviewMemo)
            try repository.failExtraction(
                for: failedReviewMemo,
                error: UITestSeedError(message: "Review couldn’t finish for this note.")
            )

            try modelContext.save()
        } catch {
            assertionFailure("Unable to seed UI test data: \(error.localizedDescription)")
        }
    }

    private static let sampleTranscription = TranscriptionPayload(
        transcriptText: "Call Jordan tomorrow about the lighting quote. Send the revised site plan before Friday.",
        localeIdentifier: "en_US",
        segments: [
            TranscriptionSegmentPayload(startSeconds: 0, durationSeconds: 3.4, text: "Call Jordan tomorrow about the lighting quote."),
            TranscriptionSegmentPayload(startSeconds: 3.4, durationSeconds: 3.1, text: "Send the revised site plan before Friday."),
        ]
    )
}

private struct UITestSeedError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
