import AVFAudio
import EventKit
import Observation
import Speech

enum AppPermissionState: String {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable

    var title: String {
        switch self {
        case .notDetermined:
            return "Not asked"
        case .authorized:
            return "Allowed"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .unavailable:
            return "Unavailable"
        }
    }

    var needsSettingsRecovery: Bool {
        switch self {
        case .denied, .restricted:
            return true
        case .authorized, .notDetermined, .unavailable:
            return false
        }
    }
}

@MainActor
@Observable
final class PermissionCoordinator {
    var microphoneStatus: AppPermissionState = .notDetermined
    var speechStatus: AppPermissionState = .notDetermined
    var remindersStatus: AppPermissionState = .notDetermined

    func refreshStatuses() {
        microphoneStatus = currentMicrophoneStatus()

        speechStatus = switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .notDetermined:
            .notDetermined
        @unknown default:
            .unavailable
        }

        remindersStatus = switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess, .writeOnly:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .notDetermined:
            .notDetermined
        @unknown default:
            .unavailable
        }
    }

    func requestMicrophoneAccess() async -> AppPermissionState {
        let currentStatus = currentMicrophoneStatus()
        guard currentStatus == .notDetermined else {
            microphoneStatus = currentStatus
            return currentStatus
        }

        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        let updatedStatus: AppPermissionState = granted ? .authorized : .denied
        microphoneStatus = updatedStatus
        return updatedStatus
    }

    func requestSpeechAccess() async -> AppPermissionState {
        let currentStatus = speechStatusFromSystem()
        guard currentStatus == .notDetermined else {
            speechStatus = currentStatus
            return currentStatus
        }

        let updatedStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authorizationStatus in
                continuation.resume(returning: Self.mapSpeechAuthorizationStatus(authorizationStatus))
            }
        }

        speechStatus = updatedStatus
        return updatedStatus
    }

    private func currentMicrophoneStatus() -> AppPermissionState {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            .authorized
        case .denied:
            .denied
        case .undetermined:
            .notDetermined
        @unknown default:
            .unavailable
        }
    }

    private func speechStatusFromSystem() -> AppPermissionState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .notDetermined:
            .notDetermined
        @unknown default:
            .unavailable
        }
    }

    private static func mapSpeechAuthorizationStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> AppPermissionState {
        switch status {
        case .authorized:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .notDetermined:
            .notDetermined
        @unknown default:
            .unavailable
        }
    }
}
