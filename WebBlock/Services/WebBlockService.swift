import Foundation

enum ServiceError: LocalizedError {
    case invalidCredentials, notFound, offline

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "Email or password is incorrect. Check them and try again."
        case .notFound: "We couldn’t find that item. Pull to refresh and try again."
        case .offline: "You appear to be offline. Check your connection and try again."
        }
    }
}

/// Everything the app needs from the backend. `MockWebBlockService` implements it with
/// clearly-labelled sample data; replace it with an API-backed type when the endpoints exist.
protocol WebBlockService: Sendable {
    // Sign in (accounts are created on the WebBlock website, not in the app)
    func signIn(email: String, password: String) async throws -> UserProfile
    func signInWithGoogle() async throws -> UserProfile

    // The owner's websites and notifications
    func websites() async throws -> [Website]
    func notifications() async throws -> [AppNotification]
    func markAllNotificationsRead() async throws

    // Business portal
    func products(websiteID: UUID) async throws -> [Product]
    func saveProduct(_ product: Product, websiteID: UUID) async throws -> Product
    func deleteProduct(id: UUID, websiteID: UUID) async throws
    func businessInfo(websiteID: UUID) async throws -> BusinessInfo
    func saveBusinessInfo(_ info: BusinessInfo, websiteID: UUID) async throws -> BusinessInfo
    func monitor(websiteID: UUID, plan: PlanTier) async throws -> MonitorSnapshot
}

enum ServiceLocator {
    /// Swap for an API-backed implementation (Spring Boot + Keycloak) when it is ready.
    nonisolated(unsafe) static var current: WebBlockService = MockWebBlockService()
}
