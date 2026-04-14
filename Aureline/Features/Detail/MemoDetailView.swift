import SwiftUI
import SwiftData

struct MemoDetailView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var errorMessage: String?
    @State private var showsDeleteConfirmation = false
    let memo: VoiceMemo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                TranscriptSectionView(memo: memo)

                actionSection

                extractionSection

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

            Button("Find Next Steps") {
                VoiceMemoRepository(modelContext: modelContext).addPlaceholderExtraction(to: memo)
            }
            .buttonStyle(AurelineSecondaryButtonStyle())
            .disabled(memo.transcriptionStatus != .completed)
            .accessibilityIdentifier("detail.addReview")
        }
        .aurelineCard()
    }

    private var extractionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Next Steps")
                .font(.headline)
                .foregroundStyle(Color.white)

            if memo.actionItems.isEmpty {
                Text("No next steps yet.")
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

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
