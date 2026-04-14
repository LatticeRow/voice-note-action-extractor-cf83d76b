import SwiftUI

struct ExtractionReviewView: View {
    @Environment(\.modelContext) private var modelContext

    let memo: VoiceMemo
    let onSave: () -> Void

    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Review")
                    .font(.headline)
                    .foregroundStyle(Color.white)

                Spacer()

                AurelineBadge(
                    title: memo.extractionStatus.title,
                    tint: memo.extractionStatus.tint
                )
            }

            switch memo.extractionStatus {
            case .processing:
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(AurelinePalette.accent)
                    Text("Reviewing this note.")
                        .foregroundStyle(AurelinePalette.secondaryText)
                }
            case .failed:
                AurelineStateView(
                    title: "Review unavailable",
                    message: memo.lastProcessingError ?? "Try again.",
                    systemImage: "list.bullet.clipboard",
                    tint: AurelinePalette.negative
                )
            case .notStarted:
                AurelineStateView(
                    title: "No review yet",
                    message: "Run review to find tasks and key details.",
                    systemImage: "sparkles.rectangle.stack",
                    tint: AurelinePalette.caution
                )
            case .completed:
                completedReview
            }
        }
        .aurelineCard()
        .alert("Couldn’t save review", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Try again.")
        }
    }

    @ViewBuilder
    private var completedReview: some View {
        if memo.actionItems.isEmpty, memo.mentions.isEmpty {
            AurelineStateView(
                title: "Nothing to review",
                message: "No clear tasks or details were found in this note.",
                systemImage: "checklist.unchecked",
                tint: AurelinePalette.secondaryText
            )
        } else {
            if !memo.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(memo.selectedActionCount) of \(memo.actionItems.count) tasks selected")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AurelinePalette.secondaryText)

                    ForEach(Array(memo.sortedActionItems.enumerated()), id: \.element.id) { index, item in
                        ActionItemEditorView(item: item, index: index) {
                            deleteActionItem(item)
                        }
                    }
                }
            }

            if !memo.mentions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mentions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white)

                    ForEach(Array(memo.sortedMentions.enumerated()), id: \.element.id) { index, mention in
                        MentionEditorCard(mention: mention, index: index) {
                            deleteMention(mention)
                        }
                    }
                }
            }

            Button("Save Changes", action: saveChanges)
                .buttonStyle(AurelinePrimaryButtonStyle())
                .accessibilityIdentifier("detail.saveReview")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { newValue in
                if !newValue {
                    errorMessage = nil
                }
            }
        )
    }

    private func saveChanges() {
        do {
            memo.touch()
            try modelContext.save()
            onSave()
        } catch {
            errorMessage = "Aureline couldn’t save your edits."
        }
    }

    private func deleteActionItem(_ item: ExtractedActionItem) {
        do {
            memo.actionItems.removeAll { $0.id == item.id }
            modelContext.delete(item)
            memo.touch()
            try modelContext.save()
            onSave()
        } catch {
            errorMessage = "Aureline couldn’t remove that task."
        }
    }

    private func deleteMention(_ mention: ExtractedMention) {
        do {
            memo.mentions.removeAll { $0.id == mention.id }
            modelContext.delete(mention)
            memo.touch()
            try modelContext.save()
            onSave()
        } catch {
            errorMessage = "Aureline couldn’t remove that mention."
        }
    }
}

private struct MentionEditorCard: View {
    @Bindable var mention: ExtractedMention
    let index: Int
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                AurelineBadge(
                    title: mention.kind.rawValue.capitalized,
                    tint: mention.kind == .date ? AurelinePalette.positive : AurelinePalette.accent
                )

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.headline)
                }
                .accessibilityLabel("Delete mention")
                .accessibilityIdentifier("extraction.mention.\(index).delete")
            }

            TextField("Mention", text: $mention.displayText)
                .foregroundStyle(Color.white)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AurelinePalette.cardRaised)
                )
                .accessibilityIdentifier("extraction.mention.\(index).text")

            if let normalizedValue = mention.normalizedValue,
               !normalizedValue.isEmpty {
                Text(normalizedValue)
                    .font(.footnote)
                    .foregroundStyle(AurelinePalette.secondaryText)
            }

            AurelineBadge(
                title: "Confidence \(Int(mention.confidence * 100))%",
                tint: mention.confidence >= 0.75 ? AurelinePalette.positive : AurelinePalette.caution
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AurelinePalette.cardRaised)
        )
    }
}
