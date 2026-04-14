import SwiftUI

struct MemoRowView: View {
    let memo: VoiceMemo

    var body: some View {
        NavigationLink(value: AppDestination.detail(memo.id)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(memo.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.white)

                        Text(Self.dateFormatter.string(from: memo.createdAt))
                            .font(.subheadline)
                            .foregroundStyle(AurelinePalette.secondaryText)
                    }

                    Spacer()

                    Image(systemName: memo.source.symbolName)
                        .font(.headline)
                        .foregroundStyle(AurelinePalette.accent)
                }

                HStack(spacing: 10) {
                    AurelineBadge(title: memo.source.title, tint: AurelinePalette.accent)
                    AurelineBadge(title: memo.transcriptionStatus.title, tint: memo.transcriptionStatus.tint)
                    AurelineBadge(title: memo.extractionStatus.title, tint: memo.extractionStatus.tint)
                    AurelineBadge(title: memo.durationText, tint: .white.opacity(0.7))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(memo.transcriptPreview)
                        .font(.subheadline)
                        .foregroundStyle(AurelinePalette.secondaryText)
                        .lineLimit(3)

                    HStack(spacing: 8) {
                        AurelineBadge(title: memo.reviewSummary, tint: AurelinePalette.cardRaised.opacity(0.9))

                        if memo.selectedActionCount > 0 {
                            AurelineBadge(
                                title: "\(memo.selectedActionCount) selected",
                                tint: AurelinePalette.positive
                            )
                        }
                    }

                    if let lastProcessingError = memo.lastProcessingError,
                       !lastProcessingError.isEmpty {
                        Label(lastProcessingError, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(AurelinePalette.negative)
                            .lineLimit(2)
                    }
                }
            }
            .aurelineCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("memoRow.\(memo.title)")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
