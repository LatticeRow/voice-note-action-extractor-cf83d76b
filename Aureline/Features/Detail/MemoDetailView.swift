import SwiftUI
import SwiftData

struct MemoDetailView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var errorMessage: String?
    @State private var showsDeleteConfirmation = false
    @State private var reviewStatusMessage: String?
    let memo: VoiceMemo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                TranscriptSectionView(memo: memo)

                actionSection

                ExtractionReviewView(memo: memo) {
                    reviewStatusMessage = "Saved."
                }

                deleteSection
            }
            .padding(20)
        }
        .screenBackground()
        .navigationTitle(memo.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this note?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Note", role: .destructive, action: deleteMemo)
        } message: {
            Text("This removes the note and its audio.")
        }
        .alert("Couldn’t update note", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Try again.")
        }
        .safeAreaInset(edge: .bottom) {
            if let reviewStatusMessage {
                Text(reviewStatusMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(AurelinePalette.accent)
                    )
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(1.6))
                        if self.reviewStatusMessage == reviewStatusMessage {
                            self.reviewStatusMessage = nil
                        }
                    }
            }
        }
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

            Text(audioSummary)
                .foregroundStyle(AurelinePalette.secondaryText)
        }
        .aurelineCard()
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Actions")
                .font(.headline)
                .foregroundStyle(Color.white)

            Button(transcriptionActionTitle) {
                Task {
                    await appEnvironment.processingQueue.transcribeMemo(id: memo.id)
                    appEnvironment.permissions.refreshStatuses()
                }
            }
            .buttonStyle(AurelinePrimaryButtonStyle())
            .disabled(memo.transcriptionStatus == .processing)
            .accessibilityIdentifier("detail.addTranscript")

            Button(extractionActionTitle) {
                Task {
                    await appEnvironment.processingQueue.extractMemo(id: memo.id)
                }
            }
            .buttonStyle(AurelineSecondaryButtonStyle())
            .disabled(memo.transcriptionStatus != .completed)
            .accessibilityIdentifier("detail.extractActions")
        }
        .aurelineCard()
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manage")
                .font(.headline)
                .foregroundStyle(Color.white)

            Button("Delete Note", role: .destructive) {
                showsDeleteConfirmation = true
            }
            .buttonStyle(AurelineSecondaryButtonStyle())
            .accessibilityIdentifier("detail.deleteMemo")
        }
        .aurelineCard()
    }

    private var audioSummary: String {
        let filename = memo.originalFilename ?? URL(fileURLWithPath: memo.audioRelativePath).lastPathComponent
        return "Duration \(memo.durationText) • \(filename)"
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func deleteMemo() {
        do {
            try VoiceMemoRepository(modelContext: modelContext).deleteMemo(memo)
            dismiss()
        } catch {
            errorMessage = "Aureline couldn’t update this note. Try again."
        }
    }

    private var transcriptionActionTitle: String {
        switch memo.transcriptionStatus {
        case .notStarted:
            return "Transcribe"
        case .processing:
            return "Transcribing"
        case .completed:
            return "Transcribe Again"
        case .failed:
            return "Try Again"
        }
    }

    private var extractionActionTitle: String {
        switch memo.extractionStatus {
        case .notStarted:
            return "Review Next Steps"
        case .processing:
            return "Reviewing"
        case .completed:
            return "Refresh Review"
        case .failed:
            return "Try Review Again"
        }
    }
}
