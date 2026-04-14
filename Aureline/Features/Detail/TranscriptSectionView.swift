import SwiftUI

struct TranscriptSectionView: View {
    let memo: VoiceMemo

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Transcript")
                .font(.headline)
                .foregroundStyle(Color.white)

            if let transcriptText = memo.transcriptText, !transcriptText.isEmpty {
                Text(transcriptText)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .textSelection(.enabled)
            } else {
                Text("No transcript yet.")
                    .foregroundStyle(AurelinePalette.secondaryText)
            }
        }
        .aurelineCard()
    }
}
