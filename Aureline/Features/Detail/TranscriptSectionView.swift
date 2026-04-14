import SwiftUI

struct TranscriptSectionView: View {
    let memo: VoiceMemo

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Transcript")
                    .font(.headline)
                    .foregroundStyle(Color.white)

                Spacer()

                AurelineBadge(
                    title: memo.transcriptionStatus.title,
                    tint: memo.transcriptionStatus.tint
                )
            }

            switch memo.transcriptionStatus {
            case .processing:
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(AurelinePalette.accent)
                    Text("Aureline is adding text now.")
                        .foregroundStyle(AurelinePalette.secondaryText)
                }
            case .failed:
                AurelineStateView(
                    title: "Transcript unavailable",
                    message: memo.lastProcessingError ?? "Try again.",
                    systemImage: "waveform.badge.exclamationmark",
                    tint: AurelinePalette.negative
                )
            case .notStarted:
                AurelineStateView(
                    title: "No transcript yet",
                    message: "Add text to review what was said.",
                    systemImage: "text.badge.plus",
                    tint: AurelinePalette.caution
                )
            case .completed:
                completedBody
            }
        }
        .aurelineCard()
    }

    @ViewBuilder
    private var completedBody: some View {
        if let transcriptText = memo.transcriptText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !transcriptText.isEmpty {
            if !memo.sortedTranscriptSegments.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(memo.sortedTranscriptSegments.count) passages")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AurelinePalette.secondaryText)

                    ForEach(memo.sortedTranscriptSegments) { segment in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Self.timestampFormatter.string(from: segment.startSeconds) ?? "0:00")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AurelinePalette.accent)

                            Text(segment.text)
                                .foregroundStyle(Color.white.opacity(0.92))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(AurelinePalette.cardRaised)
                        )
                    }
                }
            }

            Text(transcriptText)
                .foregroundStyle(Color.white.opacity(0.92))
                .textSelection(.enabled)
        } else {
            AurelineStateView(
                title: "No transcript text",
                message: "Try adding text again.",
                systemImage: "text.page.slash",
                tint: AurelinePalette.caution
            )
        }
    }

    private static let timestampFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
}
