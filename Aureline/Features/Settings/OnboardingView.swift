import SwiftUI

struct OnboardingView: View {
    let permissionStates: [AppPermissionKind: AppPermissionState]
    let openCapture: () -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Start with a voice note.")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.white)

            VStack(alignment: .leading, spacing: 12) {
                onboardingFact(
                    title: "Private on this iPhone",
                    message: "Your audio and transcript stay with Aureline unless you choose to share them.",
                    symbolName: "lock.shield.fill"
                )

                onboardingFact(
                    title: "Import Voice Memos",
                    message: "Bring them in from Share or Files. Aureline can’t browse the Voice Memos app.",
                    symbolName: "square.and.arrow.down.on.square.fill"
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Access")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)

                HStack(spacing: 8) {
                    permissionPill(for: .microphone)
                    permissionPill(for: .speech)
                    permissionPill(for: .reminders)
                }
            }

            Button("Open Capture", action: openCapture)
                .buttonStyle(AurelinePrimaryButtonStyle())
                .accessibilityIdentifier("inbox.openCapture")

            Button("Check Access", action: openSettings)
                .buttonStyle(AurelineSecondaryButtonStyle())
                .accessibilityIdentifier("inbox.reviewAccess")
        }
        .aurelineCard()
    }

    private func onboardingFact(title: String, message: String, symbolName: String) -> some View {
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

    private func permissionPill(for permission: AppPermissionKind) -> some View {
        let state = permissionStates[permission] ?? .unavailable

        return AurelineBadge(
            title: "\(permission.title) \(state.title)",
            tint: state.tint
        )
    }
}
