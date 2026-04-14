import SwiftUI

struct ExtractionReviewView: View {
    @Environment(\.modelContext) private var modelContext

    let memo: VoiceMemo
    let onSave: () -> Void

    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Review")
                .font(.headline)
                .foregroundStyle(Color.white)

            if memo.extractionStatus == .processing {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(AurelinePalette.accent)
                    Text("Finding next steps…")
                        .foregroundStyle(AurelinePalette.secondaryText)
                }
            } else if memo.actionItems.isEmpty {
                Text(emptyStateText)
                    .foregroundStyle(AurelinePalette.secondaryText)
            } else {
                ForEach(Array(memo.actionItems.enumerated()), id: \.element.id) { index, item in
                    ActionItemEditorView(item: item, index: index)
                }

                Button("Save Review", action: saveChanges)
                    .buttonStyle(AurelinePrimaryButtonStyle())
                    .accessibilityIdentifier("detail.saveReview")
            }

            if !memo.mentions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Found")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white)

                    ForEach(memo.mentions) { mention in
                        HStack {
                            AurelineBadge(title: mention.kind.rawValue.capitalized, tint: mention.kind == .date ? AurelinePalette.positive : AurelinePalette.accent)
                            Text(mention.displayText)
                                .foregroundStyle(Color.white.opacity(0.92))
                            Spacer()
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .aurelineCard()
        .alert("Couldn’t save review", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Try again.")
        }
    }

    private var emptyStateText: String {
        switch memo.extractionStatus {
        case .failed:
            return memo.lastProcessingError ?? "Try again."
        case .completed:
            return "No clear next steps found."
        case .processing:
            return ""
        case .notStarted:
            return "Run review to pull out tasks, dates, and contacts."
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
}
