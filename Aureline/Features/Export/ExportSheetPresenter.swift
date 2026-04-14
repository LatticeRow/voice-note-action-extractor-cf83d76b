import SwiftUI
import UIKit

struct ReminderDestinationSheet: View {
    let selectedCount: Int
    let lists: [ReminderList]
    @Binding var selectedListID: String?
    let isExporting: Bool
    let onCancel: () -> Void
    let onExport: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("\(selectedCount) \(selectedCount == 1 ? "task" : "tasks") ready.")
                        .foregroundStyle(AurelinePalette.secondaryText)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose a list")
                            .font(.headline)
                            .foregroundStyle(Color.white)

                        ForEach(Array(lists.enumerated()), id: \.element.id) { index, list in
                            Button {
                                selectedListID = list.id
                            } label: {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(list.title)
                                            .foregroundStyle(Color.white)
                                        Text("Reminders")
                                            .font(.footnote)
                                            .foregroundStyle(AurelinePalette.secondaryText)
                                    }

                                    Spacer()

                                    Image(systemName: selectedListID == list.id ? "checkmark.circle.fill" : "circle")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(selectedListID == list.id ? AurelinePalette.accent : AurelinePalette.secondaryText)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(AurelinePalette.cardRaised)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .stroke(
                                                    selectedListID == list.id ? AurelinePalette.accent.opacity(0.5) : AurelinePalette.stroke,
                                                    lineWidth: 1
                                                )
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("export.reminders.list.\(index)")
                        }
                    }

                    Button(isExporting ? "Saving" : "Save to Reminders", action: onExport)
                        .buttonStyle(AurelinePrimaryButtonStyle())
                        .disabled(selectedListID == nil || isExporting)
                        .accessibilityIdentifier("export.reminders.confirm")

                    Button("Cancel", action: onCancel)
                        .buttonStyle(AurelineSecondaryButtonStyle())
                        .accessibilityIdentifier("export.reminders.cancel")
                }
                .padding(20)
            }
            .screenBackground()
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct NotesShareSheet: UIViewControllerRepresentable {
    let document: NotesShareDocument
    let onComplete: @MainActor () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [NotesShareItemSource(document: document)],
            applicationActivities: nil
        )
        controller.view.accessibilityIdentifier = "notes.shareSheet"
        controller.completionWithItemsHandler = { _, _, _, _ in
            Task { @MainActor in
                onComplete()
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private final class NotesShareItemSource: NSObject, UIActivityItemSource {
    let document: NotesShareDocument

    init(document: NotesShareDocument) {
        self.document = document
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        document.body
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        document.body
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        document.subject
    }
}
