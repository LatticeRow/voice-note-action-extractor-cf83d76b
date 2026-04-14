import SwiftUI

struct TranscriptSectionView: View {
    let memo: VoiceMemo

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Transcript")
                .font(.headline)
                .foregroundStyle(Color.white)

            switch memo.transcriptionStatus {
            case .processing:
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(AurelinePalette.accent)
                    Text("Transcribing…")
                        .foregroundStyle(AurelinePalette.secondaryText)
                }
            case .failed:
                if let errorMessage = memo.lastProcessingError, !errorMessage.isEmpty {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(AurelinePalette.negative)
                } else {
                    Text("Transcription failed.")
                        .foregroundStyle(AurelinePalette.negative)
                }
            case .notStarted:
                Text("Tap Transcribe to add text.")
                    .foregroundStyle(AurelinePalette.secondaryText)
            case .completed:
                EmptyView()
            }

            if let transcriptText = memo.transcriptText, !transcriptText.isEmpty {
                Text(transcriptText)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .textSelection(.enabled)
            }
        }
        .aurelineCard()
    }
}
