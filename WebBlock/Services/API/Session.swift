import Foundation
import Security

/// User v2 `TokenSet`: the answer of `POST /sessions`, `/sessions/google` and `/sessions/refresh`.
struct TokenSetDto: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    /// Seconds.
    let expiresIn: Int64
    /// Seconds; 0 or less means unknown (an offline session without a maximum).
    let refreshExpiresIn: Int64
    let tokenType: String?
    let userId: String
    let email: String
    let roles: [String]

    private enum Keys: String, CodingKey {
        case accessToken, refreshToken, expiresIn, refreshExpiresIn, tokenType, userId, email, roles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        accessToken = try c.decode(String.self, forKey: .accessToken)
        refreshToken = try c.decode(String.self, forKey: .refreshToken)
        expiresIn = try c.decode(Int64.self, forKey: .expiresIn)
        refreshExpiresIn = try c.decodeIfPresent(Int64.self, forKey: .refreshExpiresIn) ?? 0
        tokenType = try c.decodeIfPresent(String.self, forKey: .tokenType)
        userId = try c.decode(String.self, forKey: .userId)
        email = try c.decode(String.self, forKey: .email)
        roles = try c.decodeIfPresent([String].self, forKey: .roles) ?? []
    }
}

/// The signed-in session's tokens. Never logged; only written to the Keychain.
struct StoredTokens: Codable, Sendable, Equatable {
    var accessToken: String
    var refreshToken: String
    var issuedAtMillis: Int64
    var accessExpiresAtMillis: Int64
    /// `nil` when unknown (`refreshExpiresIn` <= 0): the session lasts until a refresh is refused.
    var refreshExpiresAtMillis: Int64?

    private static let accessMarginMillis: Int64 = 30_000
    private static let refreshShare = 0.8

    func canRefresh(_ now: Int64) -> Bool { refreshExpiresAtMillis.map { $0 > now } ?? true }
    func isAccessValid(_ now: Int64) -> Bool { accessExpiresAtMillis > now }

    /// Renew 30 s before the access token runs out, or at 80 % of the refresh token's life when known.
    func needsRefresh(_ now: Int64) -> Bool {
        if accessExpiresAtMillis - now < Self.accessMarginMillis { return true }
        guard let refreshExpiresAt = refreshExpiresAtMillis else { return false }
        let renewAt = issuedAtMillis + Int64(Double(refreshExpiresAt - issuedAtMillis) * Self.refreshShare)
        return now >= renewAt
    }

    init(set: TokenSetDto, now: Int64) {
        accessToken = set.accessToken
        refreshToken = set.refreshToken
        issuedAtMillis = now
        accessExpiresAtMillis = now + set.expiresIn * 1000
        refreshExpiresAtMillis = set.refreshExpiresIn > 0 ? now + set.refreshExpiresIn * 1000 : nil
    }
}

protocol TokenStore: Sendable {
    func load() -> StoredTokens?
    func save(_ tokens: StoredTokens)
    func clear()
}

struct KeychainTokenStore: TokenStore {
    private let service = "com.webblock.app.session"
    private let account = "tokens"

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func load() -> StoredTokens? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return try? JSONDecoder().decode(StoredTokens.self, from: data)
    }

    func save(_ tokens: StoredTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        SecItemDelete(query as CFDictionary)
        var q = query
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }

    func clear() { SecItemDelete(query as CFDictionary) }
}

extension Notification.Name {
    /// Posted when the refresh token stops working, so the app goes back to sign-in.
    static let webBlockSessionExpired = Notification.Name("webBlockSessionExpired")
}

/// Owns the session's tokens, hands out a valid access token and renews it with
/// `POST /api/user/v2/sessions/refresh` (early, and once after a 401). Concurrent callers share one
/// refresh: Keycloak rotates the refresh token, so a second refresh with the old one would end the session.
actor SessionManager {
    typealias Refresher = @Sendable (_ refreshToken: String) async throws -> TokenSetDto

    private let store: TokenStore
    private let refresher: Refresher
    private let clock: @Sendable () -> Int64
    private var loaded = false
    private var tokens: StoredTokens?
    private var refreshTask: Task<String?, Error>?

    init(
        store: TokenStore = KeychainTokenStore(),
        clock: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) },
        refresher: @escaping Refresher
    ) {
        self.store = store
        self.clock = clock
        self.refresher = refresher
    }

    func hasSession() -> Bool { current()?.canRefresh(clock()) == true }
    func refreshToken() -> String? { current()?.refreshToken }

    func start(_ set: TokenSetDto) {
        let fresh = StoredTokens(set: set, now: clock())
        tokens = fresh
        loaded = true
        store.save(fresh)
    }

    func clear() {
        tokens = nil
        loaded = true
        store.clear()
    }

    /// A token to send, renewed first when due. `nil` without a session or when the session ended.
    func accessToken() async throws -> String? {
        guard let current = current() else { return nil }
        if !current.needsRefresh(clock()) { return current.accessToken }
        do {
            return try await refreshShared(stale: nil)
        } catch let error as URLError {
            // No answer (offline): keep using the current token while it is still valid.
            if current.isAccessValid(clock()) { return current.accessToken }
            throw error
        }
    }

    /// After a 401 for `stale`: the renewed token, or `nil` when the session ended.
    func refreshAfterUnauthorized(stale: String) async throws -> String? {
        try await refreshShared(stale: stale)
    }

    /// Renews now, whatever the expiry (restoring the session on launch). `nil` when the session ended.
    func refreshNow() async throws -> String? {
        guard let current = current() else { return nil }
        return try await sharedRefresh(current.refreshToken)
    }

    private func refreshShared(stale: String?) async throws -> String? {
        guard let current = current() else { return nil }
        let renewedMeanwhile = stale.map { current.accessToken != $0 } ?? !current.needsRefresh(clock())
        if renewedMeanwhile { return current.accessToken }
        return try await sharedRefresh(current.refreshToken)
    }

    private func sharedRefresh(_ refreshToken: String) async throws -> String? {
        if let refreshTask { return try await refreshTask.value }
        let task = Task { try await self.performRefresh(refreshToken) }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performRefresh(_ refreshToken: String) async throws -> String? {
        do {
            let set = try await refresher(refreshToken)
            start(set)
            return set.accessToken
        } catch let error as ApiException where [400, 401, 403].contains(error.status) {
            clear()
            NotificationCenter.default.post(name: .webBlockSessionExpired, object: nil)
            return nil
        }
    }

    private func current() -> StoredTokens? {
        if !loaded {
            tokens = store.load()
            loaded = true
        }
        return tokens
    }
}
