import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.openURL) private var openURL
    @State private var activePermission: AppPermissionKind?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("Review access and privacy.")
                    .foregroundStyle(AurelinePalette.secondaryText)

                overviewCard
                permissionCard

                recoveryCard
            }
            .padding(20)
        }
        .screenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .task {
            appEnvironment.permissions.refreshStatuses()
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Using Aureline")
                .font(.headline)
                .foregroundStyle(Color.white)

            settingsFact(
                title: "Private by default",
                message: "Audio and text stay on this iPhone until you share or export them.",
                symbolName: "lock.shield.fill"
            )

            settingsFact(
                title: "Import Voice Memos",
                message: "Use Share or Files to bring them in. Aureline can’t browse the Voice Memos app.",
                symbolName: "square.and.arrow.down.on.square.fill"
            )
        }
        .aurelineCard()
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Access")
                .font(.headline)
                .foregroundStyle(Color.white)

            permissionRow(
                permission: .microphone,
                value: appEnvironment.permissions.microphoneStatus,
                detail: "Needed only when you record."
            )
            permissionRow(
                permission: .speech,
                value: appEnvironment.permissions.speechStatus,
                detail: "Needed to add a transcript."
            )
            permissionRow(
                permission: .reminders,
                value: appEnvironment.permissions.remindersStatus,
                detail: "Needed to save tasks to Reminders."
            )

            Button("Refresh Access") {
                appEnvironment.permissions.refreshStatuses()
            }
            .buttonStyle(AurelineSecondaryButtonStyle())
            .accessibilityIdentifier("settings.refresh")
        }
        .aurelineCard()
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Need to change access?")
                .font(.headline)
                .foregroundStyle(Color.white)

            Text("If access is off, turn it back on in Settings.")
                .foregroundStyle(AurelinePalette.secondaryText)

            Button("Open Settings", action: openAppSettings)
                .buttonStyle(AurelineSecondaryButtonStyle())
                .accessibilityIdentifier("settings.openAppSettings")
        }
        .aurelineCard()
    }

    private func settingsFact(title: String, message: String, symbolName: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(AurelinePalette.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)

                Text(message)
                    .foregroundStyle(AurelinePalette.secondaryText)
            }
        }
    }

    private func permissionRow(
        permission: AppPermissionKind,
        value: AppPermissionState,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: permission.symbolName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(value.tint)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(permission.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white)

                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(AurelinePalette.secondaryText)
                }

                Spacer()

                AurelineBadge(title: value.title, tint: value.tint)
            }

            if let actionTitle = actionTitle(for: value) {
                Button(actionTitle) {
                    handlePermissionAction(for: permission, state: value)
                }
                .buttonStyle(AurelineSecondaryButtonStyle())
                .disabled(activePermission == permission)
                .accessibilityIdentifier("settings.permission.\(permission.rawValue).action")
            }
        }
    }

    private func actionTitle(for state: AppPermissionState) -> String? {
        switch state {
        case .notDetermined:
            return "Allow"
        case .authorized:
            return "Refresh"
        case .denied, .restricted:
            return "Open Settings"
        case .unavailable:
            return nil
        }
    }

    private func handlePermissionAction(for permission: AppPermissionKind, state: AppPermissionState) {
        guard !state.needsSettingsRecovery else {
            openAppSettings()
            return
        }

        activePermission = permission

        Task {
            _ = await appEnvironment.permissions.requestAccess(for: permission)
            appEnvironment.permissions.refreshStatuses()
            activePermission = nil
        }
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }
}
