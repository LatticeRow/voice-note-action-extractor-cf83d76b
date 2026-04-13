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
}

@MainActor
@Observable
final class PermissionCoordinator {
    var microphoneStatus: AppPermissionState = .notDetermined
    var speechStatus: AppPermissionState = .notDetermined
    var remindersStatus: AppPermissionState = .notDetermined

    func refreshStatuses() {
        microphoneStatus = switch AVAudioApplication.shared.recordPermission {
        case .granted:
            .authorized
        case .denied:
            .denied
        case .undetermined:
            .notDetermined
        @unknown default:
            .unavailable
        }

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
}
