import Foundation

enum MemoSource: String, CaseIterable, Codable {
    case recorded
    case imported

    var title: String {
        switch self {
        case .recorded:
            return "Recorded"
        case .imported:
            return "Imported"
        }
    }

    var symbolName: String {
        switch self {
        case .recorded:
            return "mic.fill"
        case .imported:
            return "square.and.arrow.down.fill"
        }
    }
}
