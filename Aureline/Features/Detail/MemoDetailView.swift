import SwiftUI
import SwiftData

private struct DetailAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct MemoDetailView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showsDeleteConfirmation = false
    @State private var statusMessage: String?
    @State private var activeAlert: DetailAlert?
    @State private var isPreparingReminderExport = false
    @State private var showsReminderSheet = false
    @State private var reminderLists: [ReminderList] = []
    @State private var selectedReminderListID: String?
    @State private var isExportingReminders = false
    @State private var shareDocument: NotesShareDocument?

    let memo: VoiceMemo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                TranscriptSectionView(memo: memo)

                actionSection

                ExtractionReviewView(memo: memo) {
                    statusMessage = "Saved."
                }

                exportSection

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
        .alert(item: $activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .cancel(Text("OK"))
            )
        }
        .sheet(isPresented: $showsReminderSheet) {
            ReminderDestinationSheet(
                selectedCount: memo.selectedActionCount,
                lists: reminderLists,
                selectedListID: $selectedReminderListID,
                isExporting: isExportingReminders,
                onCancel: { showsReminderSheet = false },
                onExport: exportSelectedTasks
            )
        }
        .sheet(item: $shareDocument) { document in
            NotesShareSheet(document: document) {
                shareDocument = nil
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(AurelinePalette.accent)
                    )
                    .padding(.bottom, 12)
                    .accessibilityIdentifier("detail.statusMessage")
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(1.6))
                        if self.statusMessage == statusMessage {
                            self.statusMessage = nil
                        }
                    }
            }
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Export")
                    .font(.headline)
                    .foregroundStyle(Color.white)

                Spacer()

                if memo.selectedActionCount > 0 {
                    AurelineBadge(title: "\(memo.selectedActionCount) selected", tint: AurelinePalette.accent)
                }
            }

            Button(isPreparingReminderExport ? "Loading Lists" : "Export to Reminders", action: prepareReminderExport)
                .buttonStyle(AurelinePrimaryButtonStyle())
                .disabled(!canExportToReminders || isPreparingReminderExport)
                .accessibilityIdentifier("detail.exportReminders")

            Button("Share Summary") {
                shareDocument = appEnvironment.notesShareComposer.makeDocument(for: memo)
            }
            .buttonStyle(AurelineSecondaryButtonStyle())
            .disabled(!canShareSummary)
            .accessibilityIdentifier("detail.shareSummary")

            Text(exportHint)
                .font(.footnote)
                .foregroundStyle(AurelinePalette.secondaryText)
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
        return filename
    }

    private var metaSummary: String {
        "\(memo.durationText) • \(Self.dateFormatter.string(from: memo.createdAt))"
    }

    private var canRunExtraction: Bool {
        memo.transcriptionStatus == .completed
        && !(memo.transcriptText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private var canExportToReminders: Bool {
        memo.extractionStatus == .completed && memo.selectedActionCount > 0
    }

    private var canShareSummary: Bool {
        appEnvironment.notesShareComposer.canCompose(for: memo)
    }

    private var actionHint: String {
        if memo.transcriptionStatus == .processing {
            return "Wait for the transcript to finish."
        }

        if memo.transcriptionStatus != .completed {
            return "Add text before review."
        }

        return "Review the tasks before you export."
    }

    private var exportHint: String {
        if !canShareSummary {
            return "Add a transcript or review before sharing."
        }

        if !canExportToReminders {
            return "Select at least one task to save it to Reminders."
        }

        return "Save selected tasks or share the full summary."
    }

    private func deleteMemo() {
        do {
            try VoiceMemoRepository(modelContext: modelContext).deleteMemo(memo)
            dismiss()
        } catch {
            presentAlert(title: "Couldn’t delete note", error: error)
        }
    }

    private func prepareReminderExport() {
        guard canExportToReminders else { return }

        isPreparingReminderExport = true

        Task {
            do {
                let lists = try await appEnvironment.reminderExporter.fetchLists()
                reminderLists = lists
                selectedReminderListID = selectedReminderListID ?? lists.first?.id
                showsReminderSheet = true
                appEnvironment.permissions.refreshStatuses()
            } catch {
                presentAlert(title: "Couldn’t open Reminders", error: error)
                appEnvironment.permissions.refreshStatuses()
            }

            isPreparingReminderExport = false
        }
    }

    private func exportSelectedTasks() {
        guard let selectedReminderListID else { return }

        isExportingReminders = true

        Task {
            do {
                let result = try await appEnvironment.reminderExporter.exportSelectedActionItems(
                    in: memo,
                    to: selectedReminderListID
                )
                memo.touch()
                try modelContext.save()
                showsReminderSheet = false
                statusMessage = result.statusMessage
                appEnvironment.permissions.refreshStatuses()
            } catch {
                do {
                    try modelContext.save()
                } catch {
                    presentAlert(title: "Couldn’t update note", error: error)
                }

                presentAlert(title: "Couldn’t save reminders", error: error)
                appEnvironment.permissions.refreshStatuses()
            }

            isExportingReminders = false
        }
    }

    private func presentAlert(title: String, error: Error) {
        let description = (error as? LocalizedError)?.errorDescription ?? "Try again."
        let recovery = (error as? LocalizedError)?.recoverySuggestion
        activeAlert = DetailAlert(
            title: title,
            message: [description, recovery].compactMap { $0 }.joined(separator: " ")
        )
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
            return "Run Review"
        case .processing:
            return "Reviewing"
        case .completed:
            return "Run Again"
        case .failed:
            return "Try Review Again"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                AurelineBadge(title: memo.source.title, tint: AurelinePalette.accent)
                AurelineBadge(title: memo.transcriptionStatus.title, tint: memo.transcriptionStatus.tint)
                AurelineBadge(title: memo.extractionStatus.title, tint: memo.extractionStatus.tint)
            }

            Text(audioSummary)
                .font(.headline)
                .foregroundStyle(Color.white)

            Text(metaSummary)
                .foregroundStyle(AurelinePalette.secondaryText)

            if let lastProcessingError = memo.lastProcessingError,
               !lastProcessingError.isEmpty,
               memo.transcriptionStatus == .failed || memo.extractionStatus == .failed {
                Label(lastProcessingError, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AurelinePalette.negative)
            }
        }
        .aurelineCard()
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Next")
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
            .disabled(!canRunExtraction)
            .accessibilityIdentifier("detail.extractActions")

            Text(actionHint)
                .font(.footnote)
                .foregroundStyle(AurelinePalette.secondaryText)
        }
        .aurelineCard()
    }
}
