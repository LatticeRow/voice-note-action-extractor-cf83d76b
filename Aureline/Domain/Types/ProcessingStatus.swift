import Foundation
import SwiftUI

enum ProcessingStatus: String, CaseIterable, Codable {
    case notStarted
    case processing
    case completed
    case failed

    var title: String {
        switch self {
        case .notStarted:
            return "Pending"
        case .processing:
            return "Working"
        case .completed:
            return "Done"
        case .failed:
            return "Failed"
        }
    }

    var tint: Color {
        switch self {
        case .notStarted:
            return AurelinePalette.caution
        case .processing:
            return AurelinePalette.accent
        case .completed:
            return AurelinePalette.positive
        case .failed:
            return AurelinePalette.negative
        }
    }
}
