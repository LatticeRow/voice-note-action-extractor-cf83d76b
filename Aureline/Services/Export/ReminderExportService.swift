import EventKit
import Foundation

struct ReminderList: Identifiable, Equatable {
    let id: String
    let title: String
}

struct ReminderDraft: Equatable {
    let title: String
    let dueDate: Date?
    let notes: String
}

struct ReminderExportResult: Equatable {
    let exportedCount: Int
    let failedCount: Int

    var statusMessage: String {
        let totalCount = exportedCount + failedCount
        if failedCount == 0 {
            return "Saved \(exportedCount) \(exportedCount == 1 ? "reminder" : "reminders")."
        }
        return "Saved \(exportedCount) of \(totalCount) reminders."
    }
}

@MainActor
protocol ReminderExporting {
    func fetchLists() async throws -> [ReminderList]
    func exportSelectedActionItems(in memo: VoiceMemo, to listID: String) async throws -> ReminderExportResult
}

enum ReminderExportError: LocalizedError {
    case permissionDenied
    case noWritableLists
    case destinationMissing
    case noSelectedTasks
    case exportFailed
    case unavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Reminders access is required to save tasks."
        case .noWritableLists:
            return "No editable reminders lists are available."
        case .destinationMissing:
            return "That reminders list is no longer available."
        case .noSelectedTasks:
            return "Select at least one task first."
        case .exportFailed:
            return "Aureline couldn’t save those reminders."
        case .unavailable:
            return "Reminders isn’t available right now."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Allow access in Settings, then try again."
        case .noWritableLists:
            return "Create or enable a list in Reminders, then try again."
        case .destinationMissing, .noSelectedTasks, .exportFailed, .unavailable:
            return "Try again."
        }
    }
}

@MainActor
final class ReminderExportService: ReminderExporting {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    func fetchLists() async throws -> [ReminderList] {
        try await ensureFullAccess()

        let calendars = writableCalendars()
        guard !calendars.isEmpty else {
            throw ReminderExportError.noWritableLists
        }

        return calendars.map {
            ReminderList(id: $0.calendarIdentifier, title: $0.title)
        }
    }

    func exportSelectedActionItems(in memo: VoiceMemo, to listID: String) async throws -> ReminderExportResult {
        try await ensureFullAccess()

        let selectedItems = memo.sortedActionItems.filter(\.isSelectedForExport)
        guard !selectedItems.isEmpty else {
            throw ReminderExportError.noSelectedTasks
        }

        guard let calendar = writableCalendars().first(where: { $0.calendarIdentifier == listID }) else {
            throw ReminderExportError.destinationMissing
        }

        let drafts = Self.makeDrafts(for: memo, actionItems: selectedItems)
        var exportedCount = 0
        var failedCount = 0

        for (item, draft) in zip(selectedItems, drafts) {
            let reminder = EKReminder(eventStore: eventStore)
            reminder.calendar = calendar
            reminder.title = draft.title
            reminder.notes = draft.notes

            if let dueDate = draft.dueDate {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    in: TimeZone.current,
                    from: dueDate
                )
            }

            do {
                try eventStore.save(reminder, commit: true)
                item.exportStatus = .exported
                exportedCount += 1
            } catch {
                item.exportStatus = .failed
                failedCount += 1
            }
        }

        guard exportedCount > 0 else {
            throw ReminderExportError.exportFailed
        }

        return ReminderExportResult(exportedCount: exportedCount, failedCount: failedCount)
    }

    static func makeDrafts(for memo: VoiceMemo, actionItems: [ExtractedActionItem]) -> [ReminderDraft] {
        actionItems.map { item in
            ReminderDraft(
                title: item.normalizedText,
                dueDate: item.dueDate,
                notes: makeReminderNotes(for: memo, actionItem: item)
            )
        }
    }

    static func makeReminderNotes(for memo: VoiceMemo, actionItem: ExtractedActionItem) -> String {
        var lines = [
            "From \(memo.title)",
            "Captured \(detailDateFormatter.string(from: memo.createdAt))",
        ]

        if let dueDate = actionItem.dueDate {
            lines.append("Due \(detailDateFormatter.string(from: dueDate))")
        }

        if let contactName = actionItem.contactName,
           !contactName.isEmpty {
            if let contactMethod = actionItem.contactMethod,
               !contactMethod.isEmpty {
                lines.append("Contact \(contactName) via \(contactMethod)")
            } else {
                lines.append("Contact \(contactName)")
            }
        }

        let context = actionItem.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !context.isEmpty {
            lines.append("")
            lines.append("Context")
            lines.append(context)
        } else {
            let transcript = memo.transcriptPreview.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !transcript.isEmpty else {
                return lines.joined(separator: "\n")
            }
            lines.append("")
            lines.append("Transcript")
            lines.append(transcript)
        }

        return lines.joined(separator: "\n")
    }

    private func ensureFullAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .reminder)

        switch status {
        case .fullAccess:
            return
        case .authorized, .writeOnly, .notDetermined:
            let granted = try await requestFullAccess()
            guard granted else {
                throw ReminderExportError.permissionDenied
            }
        case .denied, .restricted:
            throw ReminderExportError.permissionDenied
        @unknown default:
            throw ReminderExportError.unavailable
        }
    }

    private func requestFullAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            eventStore.requestFullAccessToReminders { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func writableCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .reminder)
            .filter(\.allowsContentModifications)
            .sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    private static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

@MainActor
final class MockReminderExportService: ReminderExporting {
    private let lists = [
        ReminderList(id: "aureline.inbox", title: "Aureline"),
        ReminderList(id: "aureline.followup", title: "Follow Up"),
    ]

    func fetchLists() async throws -> [ReminderList] {
        lists
    }

    func exportSelectedActionItems(in memo: VoiceMemo, to listID: String) async throws -> ReminderExportResult {
        guard lists.contains(where: { $0.id == listID }) else {
            throw ReminderExportError.destinationMissing
        }

        let selectedItems = memo.sortedActionItems.filter(\.isSelectedForExport)
        guard !selectedItems.isEmpty else {
            throw ReminderExportError.noSelectedTasks
        }

        for item in selectedItems {
            item.exportStatus = .exported
        }

        return ReminderExportResult(exportedCount: selectedItems.count, failedCount: 0)
    }
}
