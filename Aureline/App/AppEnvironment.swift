import Observation

@MainActor
@Observable
final class AppEnvironment {
    let router = AppRouter()
    let permissions = PermissionCoordinator()
}
