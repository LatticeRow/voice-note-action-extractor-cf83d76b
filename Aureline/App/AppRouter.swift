import Observation
import SwiftUI

enum AppTab: Hashable {
    case inbox
    case capture
    case settings
}

enum AppDestination: Hashable {
    case detail(UUID)
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .inbox
    var inboxPath = NavigationPath()

    func openCapture() {
        selectedTab = .capture
    }

    func openSettings() {
        selectedTab = .settings
    }

    func openDetail(_ memoID: UUID) {
        selectedTab = .inbox
        inboxPath.append(AppDestination.detail(memoID))
    }
}
