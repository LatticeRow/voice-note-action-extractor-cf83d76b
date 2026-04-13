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
            return "Not started"
        case .processing:
            return "In progress"
        case .completed:
            return "Ready"
        case .failed:
            return "Error"
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
