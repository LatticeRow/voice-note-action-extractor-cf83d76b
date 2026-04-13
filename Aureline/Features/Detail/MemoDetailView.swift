import SwiftUI
import SwiftData

struct MemoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let memo: VoiceMemo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                TranscriptSectionView(memo: memo)

                actionSection

                extractionSection
            }
            .padding(20)
        }
        .screenBackground()
        .navigationTitle(memo.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                AurelineBadge(title: memo.source.title, tint: AurelinePalette.accent)
                AurelineBadge(title: memo.transcriptionStatus.title, tint: memo.transcriptionStatus.tint)
                AurelineBadge(title: memo.extractionStatus.title, tint: memo.extractionStatus.tint)
            }

            Text("Audio")
                .font(.headline)
                .foregroundStyle(Color.white)

            Text("Duration \(memo.durationText)")
                .foregroundStyle(AurelinePalette.secondaryText)
        }
        .aurelineCard()
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Next steps")
                .font(.headline)
                .foregroundStyle(Color.white)

            Button("Generate Transcript") {
                VoiceMemoRepository(modelContext: modelContext).addPlaceholderTranscript(to: memo)
            }
            .buttonStyle(AurelinePrimaryButtonStyle())
            .accessibilityIdentifier("detail.addTranscript")

            Button("Prepare Review") {
                VoiceMemoRepository(modelContext: modelContext).addPlaceholderExtraction(to: memo)
            }
            .buttonStyle(AurelineSecondaryButtonStyle())
            .accessibilityIdentifier("detail.addReview")
        }
        .aurelineCard()
    }

    private var extractionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Review")
                .font(.headline)
                .foregroundStyle(Color.white)

            if memo.actionItems.isEmpty {
                Text("No action items yet.")
                    .foregroundStyle(AurelinePalette.secondaryText)
            } else {
                ForEach(memo.actionItems) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.normalizedText)
                            .foregroundStyle(Color.white)

                        HStack(spacing: 8) {
                            if let contactName = item.contactName {
                                AurelineBadge(title: contactName, tint: AurelinePalette.accent)
                            }

                            if let dueDate = item.dueDate {
                                AurelineBadge(title: Self.shortDateFormatter.string(from: dueDate), tint: AurelinePalette.positive)
                            }
                        }
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
        .aurelineCard()
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
