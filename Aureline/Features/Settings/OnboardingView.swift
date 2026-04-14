import SwiftUI

struct OnboardingView: View {
    let openCapture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add your first note.")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.white)

            Text("Record or import audio.")
                .foregroundStyle(AurelinePalette.secondaryText)

            Button("Open Capture", action: openCapture)
                .buttonStyle(AurelinePrimaryButtonStyle())
                .accessibilityIdentifier("inbox.openCapture")
        }
        .aurelineCard()
    }
}
