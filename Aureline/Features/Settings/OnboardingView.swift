import SwiftUI

struct OnboardingView: View {
    let openCapture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Start with a voice note.")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.white)

            Text("Use Capture to add your first note.")
                .foregroundStyle(AurelinePalette.secondaryText)

            Button("Open Capture", action: openCapture)
                .buttonStyle(AurelinePrimaryButtonStyle())
                .accessibilityIdentifier("inbox.openCapture")
        }
        .aurelineCard()
    }
}
