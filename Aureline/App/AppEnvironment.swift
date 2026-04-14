import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppEnvironment {
    let router = AppRouter()
    let permissions: PermissionCoordinator
    let processingQueue: ProcessingQueueCoordinator
    let reminderExporter: any ReminderExporting
    let notesShareComposer = NotesShareComposer()

    init(modelContainer: ModelContainer, launchArguments: [String] = ProcessInfo.processInfo.arguments) {
        let transcriptionService: any TranscriptionService
        if launchArguments.contains("-uiTestingOnDeviceUnavailable") {
            transcriptionService = MockTranscriptionService(mode: .onDeviceUnavailable)
        } else if launchArguments.contains("-uiTestingUnsupportedLocale") {
            transcriptionService = MockTranscriptionService(mode: .unsupportedLocale)
        } else if launchArguments.contains("-uiTesting") {
            transcriptionService = MockTranscriptionService()
        } else {
            transcriptionService = SpeechTranscriptionService()
        }

        if launchArguments.contains("-uiTesting") {
            reminderExporter = MockReminderExportService()
        } else {
            reminderExporter = ReminderExportService()
        }

        if launchArguments.contains("-uiTesting") {
            permissions = PermissionCoordinator(simulatedStatuses: .onboardingPreview)
        } else {
            permissions = PermissionCoordinator()
        }

        processingQueue = ProcessingQueueCoordinator(
            modelContainer: modelContainer,
            transcriptionService: transcriptionService,
            actionExtractionService: ActionExtractionService()
        )
    }
}
