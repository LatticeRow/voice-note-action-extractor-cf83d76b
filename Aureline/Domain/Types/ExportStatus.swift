import Foundation

enum ExportStatus: String, CaseIterable, Codable {
    case pending
    case exported
    case failed
}
