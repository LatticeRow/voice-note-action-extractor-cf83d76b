import Foundation

struct NotesShareDocument: Identifiable {
    let id = UUID()
    let subject: String
    let body: String
}

struct NotesShareComposer {
    func canCompose(for memo: VoiceMemo) -> Bool {
        let transcript = memo.transcriptText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !transcript.isEmpty || !memo.actionItems.isEmpty || !memo.mentions.isEmpty
    }

    func makeDocument(for memo: VoiceMemo) -> NotesShareDocument {
        let selectedTasks = memo.sortedActionItems.filter(\.isSelectedForExport)
        let tasks = selectedTasks.isEmpty ? memo.sortedActionItems : selectedTasks
        let mentions = memo.sortedMentions
        let transcript = memo.transcriptText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var lines = [
            "# \(memo.title)",
            "Captured \(Self.dateFormatter.string(from: memo.createdAt))",
        ]

        if !tasks.isEmpty {
            lines.append("")
            lines.append("## Tasks")

            for item in tasks {
                lines.append("- [ ] \(item.normalizedText)")

                var detailParts: [String] = []
                if let dueDate = item.dueDate {
                    detailParts.append("Due \(Self.dateFormatter.string(from: dueDate))")
                }
                if let contactName = item.contactName,
                   !contactName.isEmpty {
                    if let contactMethod = item.contactMethod,
                       !contactMethod.isEmpty {
                        detailParts.append("Contact \(contactName) via \(contactMethod)")
                    } else {
                        detailParts.append("Contact \(contactName)")
                    }
                }
                if !detailParts.isEmpty {
                    lines.append("  \(detailParts.joined(separator: " • "))")
                }
            }
        }

        if !mentions.isEmpty {
            lines.append("")
            lines.append("## Mentions")
            for mention in mentions {
                lines.append("- \(mention.displayText)")
            }
        }

        if !transcript.isEmpty {
            lines.append("")
            lines.append("## Transcript")
            lines.append(transcript)
        }

        return NotesShareDocument(
            subject: memo.title,
            body: lines.joined(separator: "\n")
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
