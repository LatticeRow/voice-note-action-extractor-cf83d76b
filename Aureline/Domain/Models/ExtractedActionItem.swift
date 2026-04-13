import Foundation
import SwiftData

@Model
final class ExtractedActionItem {
    @Attribute(.unique) var id: UUID
    var rawText: String
    var normalizedText: String
    var dueDate: Date?
    var contactName: String?
    var contactMethod: String?
    var confidence: Double
    var isSelectedForExport: Bool
    var exportStatusRaw: String
    var memo: VoiceMemo?

    init(
        id: UUID = UUID(),
        rawText: String,
        normalizedText: String,
        dueDate: Date? = nil,
        contactName: String? = nil,
        contactMethod: String? = nil,
        confidence: Double = 0.5,
        isSelectedForExport: Bool = true,
        exportStatus: ExportStatus = .pending,
        memo: VoiceMemo? = nil
    ) {
        self.id = id
        self.rawText = rawText
        self.normalizedText = normalizedText
        self.dueDate = dueDate
        self.contactName = contactName
        self.contactMethod = contactMethod
        self.confidence = confidence
        self.isSelectedForExport = isSelectedForExport
        self.exportStatusRaw = exportStatus.rawValue
        self.memo = memo
    }
}

extension ExtractedActionItem {
    var exportStatus: ExportStatus {
        get { ExportStatus(rawValue: exportStatusRaw) ?? .pending }
        set { exportStatusRaw = newValue.rawValue }
    }
}
