import AVFoundation
import Observation

struct RecordedAudioDraft {
    let fileURL: URL
    let suggestedTitle: String
    let durationSeconds: Double
}

enum AudioRecorderError: LocalizedError {
    case alreadyRecording
    case notRecording
    case unavailable
    case failedToStart
    case failedToFinish

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "A recording is already in progress."
        case .notRecording:
            return "Start a recording first."
        case .unavailable:
            return "Recording isn’t available on this device right now."
        case .failedToStart:
            return "Aureline couldn’t start recording."
        case .failedToFinish:
            return "Aureline couldn’t save that recording."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .alreadyRecording:
            return "Finish or discard the current recording first."
        case .notRecording:
            return "Tap Record to begin a new note."
        case .unavailable:
            return "Try again, or check microphone access in Settings."
        case .failedToStart, .failedToFinish:
            return "Try again in a moment."
        }
    }
}

@MainActor
@Observable
final class AudioRecorderService: NSObject {
    private(set) var isRecording = false
    private(set) var elapsedDuration: TimeInterval = 0

    private let fileManager: FileManager
    private let usesSimulatedRecording: Bool
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var startedAt: Date?
    private var tickerTask: Task<Void, Never>?

    init(
        fileManager: FileManager = .default,
        usesSimulatedRecording: Bool = ProcessInfo.processInfo.arguments.contains("-uiTesting")
    ) {
        self.fileManager = fileManager
        self.usesSimulatedRecording = usesSimulatedRecording
    }

    func startRecording() throws {
        guard !isRecording else {
            throw AudioRecorderError.alreadyRecording
        }

        if usesSimulatedRecording {
            beginRecordingState()
            return
        }

        do {
            try configureSession()
            let url = try makeTemporaryRecordingURL()
            let recorder = try AVAudioRecorder(url: url, settings: Self.recordingSettings)
            recorder.prepareToRecord()

            guard recorder.record() else {
                throw AudioRecorderError.failedToStart
            }

            self.recorder = recorder
            recordingURL = url
            beginRecordingState()
        } catch let error as AudioRecorderError {
            throw error
        } catch {
            throw AudioRecorderError.unavailable
        }
    }

    func saveRecording() throws -> RecordedAudioDraft {
        guard isRecording else {
            throw AudioRecorderError.notRecording
        }

        let measuredDuration = max(recorder?.currentTime ?? elapsedDuration, 1)
        let fileURL: URL
        defer { resetState(removeTemporaryFile: false) }

        if usesSimulatedRecording {
            fileURL = try DemoAudioFileFactory.makeTemporaryAudioFile(
                source: .recorded,
                fileManager: fileManager,
                durationSeconds: Int(ceil(measuredDuration))
            )
        } else {
            guard let recorder, let recordingURL else {
                resetState(removeTemporaryFile: false)
                throw AudioRecorderError.failedToFinish
            }

            recorder.stop()
            fileURL = recordingURL
        }

        do {
            try deactivateSessionIfNeeded()
        } catch {
            throw AudioRecorderError.failedToFinish
        }

        return RecordedAudioDraft(
            fileURL: fileURL,
            suggestedTitle: Self.defaultTitleFormatter.string(from: .now),
            durationSeconds: measuredDuration
        )
    }

    func discardRecording() {
        recorder?.stop()
        try? deactivateSessionIfNeeded()
        resetState(removeTemporaryFile: true)
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true, options: [])
    }

    private func deactivateSessionIfNeeded() throws {
        guard !usesSimulatedRecording else { return }
        try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func beginRecordingState() {
        isRecording = true
        elapsedDuration = 0
        startedAt = .now
        startTicker()
    }

    private func resetState(removeTemporaryFile: Bool) {
        tickerTask?.cancel()
        tickerTask = nil

        let urlToRemove = removeTemporaryFile ? recordingURL : nil
        recorder = nil
        recordingURL = nil
        startedAt = nil
        isRecording = false
        elapsedDuration = 0

        if let urlToRemove {
            try? fileManager.removeItem(at: urlToRemove.deletingLastPathComponent())
        }
    }

    private func startTicker() {
        tickerTask?.cancel()
        tickerTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                if let startedAt = self.startedAt {
                    self.elapsedDuration = Date().timeIntervalSince(startedAt)
                }

                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func makeTemporaryRecordingURL() throws -> URL {
        let directoryURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent("Aureline Recording.m4a", isDirectory: false)
    }

    private static let recordingSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]

    private static let defaultTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
}
