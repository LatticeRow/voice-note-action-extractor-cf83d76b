import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("Review access.")
                    .foregroundStyle(AurelinePalette.secondaryText)

                permissionCard

                VStack(alignment: .leading, spacing: 12) {
                    Text("Privacy")
                        .font(.headline)
                        .foregroundStyle(Color.white)

                    Text("Data stays on this iPhone.")
                        .foregroundStyle(AurelinePalette.secondaryText)
                }
                .aurelineCard()
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

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("System access")
                .font(.headline)
                .foregroundStyle(Color.white)

            permissionRow(title: "Microphone", value: appEnvironment.permissions.microphoneStatus)
            permissionRow(title: "Speech", value: appEnvironment.permissions.speechStatus)
            permissionRow(title: "Reminders", value: appEnvironment.permissions.remindersStatus)

            Button("Refresh Access") {
                appEnvironment.permissions.refreshStatuses()
            }
            .buttonStyle(AurelineSecondaryButtonStyle())
            .accessibilityIdentifier("settings.refresh")
        }
        .aurelineCard()
    }

    private func permissionRow(title: String, value: AppPermissionState) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.white)
            Spacer()
            Text(value.title)
                .foregroundStyle(AurelinePalette.secondaryText)
        }
        .font(.subheadline.weight(.medium))
    }
}
