import Foundation
import Speech

final class SpeechTranscriptionService: TranscriptionService, @unchecked Sendable {
    func authorizationStatus() -> TranscriptionAuthorizationState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .unavailable
        }
    }

    func requestAuthorizationIfNeeded() async -> TranscriptionAuthorizationState {
        let currentStatus = authorizationStatus()
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: self.mapAuthorizationStatus(status))
            }
        }
    }

    func transcribeAudio(at fileURL: URL, localeIdentifier: String?) async throws -> TranscriptionPayload {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw TranscriptionError.audioFileMissing
        }

        switch authorizationStatus() {
        case .authorized:
            break
        case .denied:
            throw TranscriptionError.authorizationDenied
        case .restricted:
            throw TranscriptionError.authorizationRestricted
        case .notDetermined:
            throw TranscriptionError.authorizationUnavailable
        case .unavailable:
            throw TranscriptionError.authorizationUnavailable
        }

        let resolvedLocale = try resolveLocale(from: localeIdentifier)
        let localeName = localizedName(for: resolvedLocale)

        guard let recognizer = SFSpeechRecognizer(locale: resolvedLocale) else {
            throw TranscriptionError.unsupportedLocale(localeName)
        }

        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.onDeviceModelUnavailable(localeName)
        }

        guard recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            let finish: (Result<TranscriptionPayload, Error>) -> Void = { result in
                guard !didResume else { return }
                didResume = true

                switch result {
                case let .success(payload):
                    continuation.resume(returning: payload)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }

            let task = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    finish(.failure(self.mapRecognitionError(error)))
                    return
                }

                guard let result, result.isFinal else {
                    return
                }

                let transcriptText = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !transcriptText.isEmpty else {
                    finish(.failure(TranscriptionError.noSpeechDetected))
                    return
                }

                let segments = result.bestTranscription.segments.map {
                    TranscriptionSegmentPayload(
                        startSeconds: $0.timestamp,
                        durationSeconds: $0.duration,
                        text: $0.substring
                    )
                }

                let payload = TranscriptionPayload(
                    transcriptText: transcriptText,
                    localeIdentifier: resolvedLocale.identifier,
                    segments: segments
                )
                finish(.success(payload))
            }

            _ = task
        }
    }

    private func resolveLocale(from localeIdentifier: String?) throws -> Locale {
        let requestedIdentifier = (localeIdentifier?.isEmpty == false ? localeIdentifier : Locale.current.identifier)
            ?? Locale.current.identifier
        let requestedLocale = Locale(identifier: requestedIdentifier)

        if SFSpeechRecognizer.supportedLocales().contains(where: { $0.identifier == requestedLocale.identifier }) {
            return requestedLocale
        }

        let requestedLanguageCode = requestedLocale.language.languageCode?.identifier
        if let requestedLanguageCode,
           let compatibleLocale = SFSpeechRecognizer.supportedLocales().first(where: {
               Locale(identifier: $0.identifier).language.languageCode?.identifier == requestedLanguageCode
           }) {
            return compatibleLocale
        }

        throw TranscriptionError.unsupportedLocale(localizedName(for: requestedLocale))
    }

    private func localizedName(for locale: Locale) -> String {
        Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }

    private func mapAuthorizationStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> TranscriptionAuthorizationState {
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .unavailable
        }
    }

    private func mapRecognitionError(_ error: Error) -> TranscriptionError {
        let nsError = error as NSError

        if nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .recognizerUnavailable
        }

        return .failed(nsError.localizedDescription)
    }
}
