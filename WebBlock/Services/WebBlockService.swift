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

/// Everything the app needs from the backend. `APIWebBlockService` talks to the real WebBlock v2 API
/// (the same endpoints as the Android app); `MockWebBlockService` keeps the clearly-labelled sample data
/// for previews and tests.
protocol WebBlockService: Sendable {
    // Sign in (accounts are created on the WebBlock website, not in the app)
    func signIn(email: String, password: String) async throws -> UserProfile
    func signInWithGoogle() async throws -> UserProfile
    /// Emails a password-reset link to the account. Replace the mock with the real endpoint.
    func requestPasswordReset(email: String) async throws
    func verifyResetCode(email: String, code: String) async throws
    func resetPassword(email: String, code: String, newPassword: String) async throws

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

    // Session (real API only; the mock has nothing to restore or revoke)
    /// Signs back in from the stored refresh token on launch. `nil` when there is no usable session.
    func restoreSession() async -> UserProfile?
    func signOut() async
    /// Marks one notification read on the server when it is opened (failures are ignored).
    func markNotificationRead(id: UUID) async
}

extension WebBlockService {
    func restoreSession() async -> UserProfile? { nil }
    func signOut() async {}
    func markNotificationRead(id: UUID) async {}
}

enum ServiceLocator {
    /// Set to `true` to run every screen on the in-memory sample data, with no network
    /// (Android's `use.mock.data`). The default is the real API.
    static let useMockData = false

    nonisolated(unsafe) static var current: WebBlockService = useMockData ? MockWebBlockService() : APIWebBlockService()
}
