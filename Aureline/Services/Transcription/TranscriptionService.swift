import Foundation

struct TranscriptionSegmentPayload: Sendable, Equatable {
    let startSeconds: Double
    let durationSeconds: Double
    let text: String
}

struct TranscriptionPayload: Sendable, Equatable {
    let transcriptText: String
    let localeIdentifier: String
    let segments: [TranscriptionSegmentPayload]
}

enum TranscriptionAuthorizationState: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable
}

enum TranscriptionError: LocalizedError, Equatable, Sendable {
    case authorizationDenied
    case authorizationRestricted
    case authorizationUnavailable
    case audioFileMissing
    case unsupportedLocale(String)
    case onDeviceModelUnavailable(String)
    case recognizerUnavailable
    case noSpeechDetected
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Allow Speech Recognition in Settings to transcribe notes."
        case .authorizationRestricted:
            return "Speech Recognition isn’t available on this device right now."
        case .authorizationUnavailable:
            return "Speech Recognition isn’t available right now."
        case .audioFileMissing:
            return "The audio file for this note is missing."
        case let .unsupportedLocale(localeName):
            return "This note’s language, \(localeName), isn’t supported for transcription on this device."
        case let .onDeviceModelUnavailable(localeName):
            return "Offline transcription for \(localeName) isn’t available on this device."
        case .recognizerUnavailable:
            return "Offline transcription isn’t available right now."
        case .noSpeechDetected:
            return "No spoken words were detected in this recording."
        case let .failed(message):
            return message
        }
    }
}

protocol TranscriptionService: Sendable {
    func authorizationStatus() -> TranscriptionAuthorizationState
    func requestAuthorizationIfNeeded() async -> TranscriptionAuthorizationState
    func transcribeAudio(at fileURL: URL, localeIdentifier: String?) async throws -> TranscriptionPayload
}

struct MockTranscriptionService: TranscriptionService {
    enum Mode: Sendable {
        case success
        case unsupportedLocale
        case onDeviceUnavailable
    }

    let mode: Mode

    init(mode: Mode = .success) {
        self.mode = mode
    }

    func authorizationStatus() -> TranscriptionAuthorizationState {
        .authorized
    }

    func requestAuthorizationIfNeeded() async -> TranscriptionAuthorizationState {
        .authorized
    }

    func transcribeAudio(at fileURL: URL, localeIdentifier: String?) async throws -> TranscriptionPayload {
        let localeIdentifier = localeIdentifier ?? Locale.current.identifier
        let localeName = Locale.current.localizedString(forIdentifier: localeIdentifier) ?? localeIdentifier

        switch mode {
        case .success:
            let transcriptText = "Call Jordan tomorrow about the lighting quote. Send the revised site plan before Friday."
            return TranscriptionPayload(
                transcriptText: transcriptText,
                localeIdentifier: localeIdentifier,
                segments: [
                    TranscriptionSegmentPayload(startSeconds: 0, durationSeconds: 3.4, text: "Call Jordan tomorrow about the lighting quote."),
                    TranscriptionSegmentPayload(startSeconds: 3.4, durationSeconds: 3.1, text: "Send the revised site plan before Friday."),
                ]
            )
        case .unsupportedLocale:
            throw TranscriptionError.unsupportedLocale(localeName)
        case .onDeviceUnavailable:
            throw TranscriptionError.onDeviceModelUnavailable(localeName)
        }
    }
}
