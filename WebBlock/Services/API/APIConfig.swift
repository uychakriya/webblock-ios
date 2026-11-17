import Foundation

/// Same backend as the Android app (`api.base.url` and `auth.realm.url` in its local.properties.example).
enum APIConfig {
    static let defaultBaseURL = URL(string: "https://wb-api.roa-dev.digital/")!
    static let authRealmURL = "https://wb-auth.roa-dev.digital/realms/webblock"
    static let requestTimeout: TimeInterval = 30

    /// `WEBBLOCK_API_BASE_URL` overrides the default (must end with a slash).
    static var baseURL: URL {
        if let text = ProcessInfo.processInfo.environment["WEBBLOCK_API_BASE_URL"], let url = URL(string: text) { return url }
        return defaultBaseURL
    }

    /// Project's largest page (Android `PROJECT_PAGE_SIZE`).
    static let projectPageSize = 200
    /// Monitor lists show the newest 20 (Android `MONITOR_LIST_SIZE`).
    static let monitorListSize = 20
    /// Notification bell size (Android `BELL_SIZE`).
    static let bellSize = 50

    /// Google sign-in (docs/API-MAPPING.md 2.1): Keycloak client, redirect and scope for iOS.
    static let googleClientID = "webblock-ios"
    static let googleRedirectScheme = "com.webblock.app"
    static let googleRedirectURI = "com.webblock.app:/oauth2redirect"
    /// The realm's `webblock-ios` client allows `openid offline_access` (checked against Keycloak, 17 Nov 2026:
    /// adding `email` or `profile` is refused with `invalid_scope`). `offline_access` keeps the long-lived session.
    static let googleScope = "openid offline_access"
}

/// A message for the owner, shown as is.
struct APIError: Error, LocalizedError, Sendable {
    let message: String
    var errorDescription: String? { message }
}
