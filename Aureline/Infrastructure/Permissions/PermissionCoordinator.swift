import AVFAudio
import EventKit
import Observation
import Speech
import SwiftUI

enum AppPermissionKind: String, CaseIterable, Hashable {
    case microphone
    case speech
    case reminders

    var title: String {
        switch self {
        case .microphone:
            return "Microphone"
        case .speech:
            return "Speech"
        case .reminders:
            return "Reminders"
        }
    }

    var symbolName: String {
        switch self {
        case .microphone:
            return "mic.fill"
        case .speech:
            return "waveform"
        case .reminders:
            return "checklist"
        }
    }
}

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

extension AppPermissionState {
    var tint: Color {
        switch self {
        case .authorized:
            return AurelinePalette.positive
        case .notDetermined:
            return AurelinePalette.caution
        case .denied, .restricted, .unavailable:
            return AurelinePalette.negative
        }
    }
}

struct AppPermissionSnapshot {
    var microphone: AppPermissionState
    var speech: AppPermissionState
    var reminders: AppPermissionState

    static let onboardingPreview = AppPermissionSnapshot(
        microphone: .notDetermined,
        speech: .notDetermined,
        reminders: .notDetermined
    )
}

@MainActor
@Observable
final class PermissionCoordinator {
    private var simulatedStatuses: AppPermissionSnapshot?
    private let eventStore: EKEventStore

    var microphoneStatus: AppPermissionState = .notDetermined
    var speechStatus: AppPermissionState = .notDetermined
    var remindersStatus: AppPermissionState = .notDetermined

    init(
        simulatedStatuses: AppPermissionSnapshot? = nil,
        eventStore: EKEventStore = EKEventStore()
    ) {
        self.simulatedStatuses = simulatedStatuses
        self.eventStore = eventStore

        if let simulatedStatuses {
            microphoneStatus = simulatedStatuses.microphone
            speechStatus = simulatedStatuses.speech
            remindersStatus = simulatedStatuses.reminders
        }
    }

    func refreshStatuses() {
        if let simulatedStatuses {
            microphoneStatus = simulatedStatuses.microphone
            speechStatus = simulatedStatuses.speech
            remindersStatus = simulatedStatuses.reminders
            return
        }

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

    func status(for permission: AppPermissionKind) -> AppPermissionState {
        switch permission {
        case .microphone:
            return microphoneStatus
        case .speech:
            return speechStatus
        case .reminders:
            return remindersStatus
        }
    }

    func requestAccess(for permission: AppPermissionKind) async -> AppPermissionState {
        switch permission {
        case .microphone:
            return await requestMicrophoneAccess()
        case .speech:
            return await requestSpeechAccess()
        case .reminders:
            return await requestRemindersAccess()
        }
    }

    func requestMicrophoneAccess() async -> AppPermissionState {
        if simulatedStatuses != nil {
            simulatedStatuses?.microphone = .authorized
            microphoneStatus = .authorized
            return .authorized
        }

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
        if simulatedStatuses != nil {
            simulatedStatuses?.speech = .authorized
            speechStatus = .authorized
            return .authorized
        }

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

    func requestRemindersAccess() async -> AppPermissionState {
        if simulatedStatuses != nil {
            simulatedStatuses?.reminders = .authorized
            remindersStatus = .authorized
            return .authorized
        }

        let currentStatus = remindersStatusFromSystem()
        guard currentStatus == .notDetermined else {
            remindersStatus = currentStatus
            return currentStatus
        }

        do {
            let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                eventStore.requestFullAccessToReminders { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }

            let updatedStatus: AppPermissionState = granted ? .authorized : .denied
            remindersStatus = updatedStatus
            return updatedStatus
        } catch {
            refreshStatuses()
            return remindersStatus
        }
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

    private func remindersStatusFromSystem() -> AppPermissionState {
        switch EKEventStore.authorizationStatus(for: .reminder) {
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
