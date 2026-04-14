import SwiftData
import SwiftUI
import UIKit

private struct CaptureAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let showsSettingsAction: Bool
}

struct RecordImportView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var recorderService = AudioRecorderService()
    @State private var statusMessage = "Save a new note to your inbox."
    @State private var activeAlert: CaptureAlert?

    private let audioImportService = AudioImportService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Capture")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("Record or import audio.")
                    .foregroundStyle(AurelinePalette.secondaryText)

                summaryCard
                recordingCard

                if !recorderService.isRecording {
                    importCard
                }

                if appEnvironment.permissions.microphoneStatus.needsSettingsRecovery {
                    microphoneRecoveryCard
                }
            }
            .padding(20)
        }
        .screenBackground()
        .navigationTitle("Capture")
        .navigationBarTitleDisplayMode(.large)
        .task {
            appEnvironment.permissions.refreshStatuses()
        }
        .alert(item: $activeAlert) { alert in
            if alert.showsSettingsAction {
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("Open Settings"), action: openAppSettings),
                    secondaryButton: .cancel(Text("Not Now"))
                )
            }

            return Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .cancel(Text("OK"))
            )
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Private on this iPhone", systemImage: "lock.shield.fill")
                .font(.headline)
                .foregroundStyle(Color.white)

            Text(statusMessage)
                .foregroundStyle(AurelinePalette.secondaryText)
        }
        .aurelineCard()
    }

    private var recordingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Record")
                    .font(.headline)
                    .foregroundStyle(Color.white)

                Spacer()

                if recorderService.isRecording {
                    AurelineBadge(title: "Recording", tint: AurelinePalette.negative)
                }
            }

            Text(recorderService.isRecording ? Self.durationFormatter.string(from: recorderService.elapsedDuration) ?? "0:00" : "Tap Record when you’re ready.")
                .foregroundStyle(AurelinePalette.secondaryText)
                .monospacedDigit()

            if recorderService.isRecording {
                Button("Save Recording", action: saveRecording)
                    .buttonStyle(AurelinePrimaryButtonStyle())
                    .accessibilityIdentifier("capture.saveRecording")

                Button("Discard", action: discardRecording)
                    .buttonStyle(AurelineSecondaryButtonStyle())
                    .accessibilityIdentifier("capture.discardRecording")
            } else {
                Button("Record", action: requestRecording)
                    .buttonStyle(AurelinePrimaryButtonStyle())
                    .accessibilityIdentifier("capture.startRecording")
            }
        }
        .aurelineCard()
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Import")
                .font(.headline)
                .foregroundStyle(Color.white)

            Text("Supports m4a, mp3, and wav.")
                .foregroundStyle(AurelinePalette.secondaryText)

            ImportButton(
                title: "Import from Files",
                supportedContentTypes: AudioImportService.supportedContentTypes,
                accessibilityIdentifier: "capture.importFile",
                action: importAudio,
                failure: handleImportFailure
            )
            .buttonStyle(AurelineSecondaryButtonStyle())
        }
        .aurelineCard()
    }

    private var microphoneRecoveryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Microphone access is off.")
                .font(.headline)
                .foregroundStyle(Color.white)

            Text("Turn it on in Settings to record new notes.")
                .foregroundStyle(AurelinePalette.secondaryText)

            Button("Open Settings", action: openAppSettings)
                .buttonStyle(AurelineSecondaryButtonStyle())
                .accessibilityIdentifier("capture.openSettings")
        }
        .aurelineCard()
    }

    private func requestRecording() {
        Task {
            if Self.usesSimulatorRecordingFlow {
                do {
                    try recorderService.startRecording()
                    statusMessage = "Recording in progress."
                } catch {
                    presentAlert(
                        title: "Couldn’t start recording",
                        error: error,
                        showsSettingsAction: false
                    )
                }
                return
            }

            let permission = await appEnvironment.permissions.requestMicrophoneAccess()

            guard permission == .authorized else {
                presentMicrophoneAlert(for: permission)
                return
            }

            do {
                try recorderService.startRecording()
                statusMessage = "Recording in progress."
            } catch {
                presentAlert(
                    title: "Couldn’t start recording",
                    error: error,
                    showsSettingsAction: true
                )
            }
        }
    }

    private func saveRecording() {
        do {
            let draft = try recorderService.saveRecording()
            defer { removeTemporaryAudio(at: draft.fileURL) }

            let memo = try VoiceMemoRepository(modelContext: modelContext).createMemo(
                title: draft.suggestedTitle,
                source: .recorded,
                audioSourceURL: draft.fileURL
            )

            statusMessage = "Saved to your inbox."
            appEnvironment.router.openDetail(memo.id)
        } catch {
            presentAlert(title: "Couldn’t save recording", error: error, showsSettingsAction: false)
        }
    }

    private func discardRecording() {
        recorderService.discardRecording()
        statusMessage = "Recording discarded."
    }

    private func importAudio(_ urls: [URL]) {
        do {
            let memo = try audioImportService.importAudio(
                from: urls,
                repository: VoiceMemoRepository(modelContext: modelContext)
            )

            statusMessage = "Imported to your inbox."
            appEnvironment.router.openDetail(memo.id)
        } catch {
            presentAlert(title: "Couldn’t import file", error: error, showsSettingsAction: false)
        }
    }

    private func handleImportFailure(_ error: Error) {
        guard !isUserCancellation(error) else { return }
        presentAlert(title: "Couldn’t open Files", error: error, showsSettingsAction: false)
    }

    private func presentMicrophoneAlert(for permission: AppPermissionState) {
        let message: String
        switch permission {
        case .denied:
            message = "Allow microphone access in Settings to record a note."
        case .restricted:
            message = "This device can’t grant microphone access right now."
        case .unavailable:
            message = "Recording isn’t available right now."
        case .notDetermined, .authorized:
            message = "Try again."
        }

        activeAlert = CaptureAlert(
            title: "Microphone Access Needed",
            message: message,
            showsSettingsAction: permission.needsSettingsRecovery
        )
    }

    private func presentAlert(title: String, error: Error, showsSettingsAction: Bool) {
        let description = (error as? LocalizedError)?.errorDescription ?? "Try again."
        let recovery = (error as? LocalizedError)?.recoverySuggestion

        activeAlert = CaptureAlert(
            title: title,
            message: [description, recovery].compactMap { $0 }.joined(separator: " "),
            showsSettingsAction: showsSettingsAction
        )
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }

    private func removeTemporaryAudio(at fileURL: URL) {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    private static let usesSimulatorRecordingFlow = ProcessInfo.processInfo.arguments.contains("-uiTesting")
}
