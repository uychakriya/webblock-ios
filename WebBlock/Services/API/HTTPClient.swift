import Foundation

struct MultipartFile: Sendable {
    let field: String
    let fileName: String
    let mimeType: String
    let data: Data
}

/// URLSession client for the WebBlock v2 API. Adds `Authorization: Bearer <token>` to every route but the
/// public User ones, and renews the session once after a 401 (Android `AuthInterceptor` + `TokenAuthenticator`).
struct HTTPClient: Sendable {
    let baseURL: URL
    let urlSession: URLSession
    /// `nil` for the plain client the refresh call uses.
    let session: SessionManager?

    /// User v2 routes that take no token: sign-in, refresh, sign-out and password reset.
    private static let publicPrefixes = ["/api/user/v2/sessions", "/api/user/v2/password-resets"]

    init(baseURL: URL = APIConfig.baseURL, urlSession: URLSession = .shared, session: SessionManager?) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.session = session
    }

    static func isPublic(_ path: String) -> Bool {
        publicPrefixes.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    // MARK: Typed helpers

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try decode(try await send("GET", path, query: query))
    }

    func send<T: Decodable>(_ method: String, _ path: String, json: Data?) async throws -> T {
        try decode(try await send(method, path, json: json))
    }

    func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError(message: ApiMessages.unexpectedAnswer)
        }
    }

    static func encode<T: Encodable>(_ body: T) throws -> Data {
        try JSONEncoder().encode(body)
    }

    // MARK: Transport

    @discardableResult
    func send(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        json: Data? = nil,
        file: MultipartFile? = nil
    ) async throws -> Data {
        let isPublic = Self.isPublic("/" + path)
        var token: String?
        if !isPublic, let session { token = try await accessToken(from: session) }
        let (data, response) = try await perform(method, path, query, json, file, token)
        if response.statusCode == 401, let session, let sent = token {
            // Renew once and repeat. A second 401 or a refused refresh reaches the caller.
            if let fresh = try await session.refreshAfterUnauthorized(stale: sent) {
                let (retryData, retryResponse) = try await perform(method, path, query, json, file, fresh)
                return try check(retryData, retryResponse)
            }
        }
        return try check(data, response)
    }

    private func accessToken(from session: SessionManager) async throws -> String? {
        do {
            return try await session.accessToken()
        } catch let error as URLError {
            throw Self.map(error)
        }
    }

    private func check(_ data: Data, _ response: HTTPURLResponse) throws -> Data {
        guard !(200..<300).contains(response.statusCode) else { return data }
        throw ApiException.parse(
            status: response.statusCode,
            body: data,
            retryAfter: response.value(forHTTPHeaderField: "Retry-After"),
            requestIdHeader: response.value(forHTTPHeaderField: "X-Request-Id")
        )
    }

    private func perform(
        _ method: String,
        _ path: String,
        _ query: [URLQueryItem],
        _ json: Data?,
        _ file: MultipartFile?,
        _ token: String?
    ) async throws -> (Data, HTTPURLResponse) {
        guard let base = URL(string: path, relativeTo: baseURL),
              var components = URLComponents(url: base, resolvingAgainstBaseURL: true) else {
            throw APIError(message: ApiMessages.generic)
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError(message: ApiMessages.generic) }

        var request = URLRequest(url: url, timeoutInterval: APIConfig.requestTimeout)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if let file {
            let boundary = "Boundary-" + UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            var body = Data()
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(file.field)\"; filename=\"\(file.fileName)\"\r\n")
            body.append("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            body.append("\r\n--\(boundary)--\r\n")
            request.httpBody = body
        } else if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = json
        }

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError(message: ApiMessages.generic) }
            return (data, http)
        } catch let error as URLError {
            throw Self.map(error)
        }
    }

    private static func map(_ error: URLError) -> Error {
        error.code == .cancelled ? CancellationError() : APIError(message: ApiMessages.noConnection)
    }
}

private extension Data {
    mutating func append(_ string: String) { append(Data(string.utf8)) }
}

/// Reads every page of a list until it has `totalItems` (or a page comes back empty).
func allPages<T>(_ fetch: (_ page: Int) async throws -> PageDto<T>) async throws -> [T] {
    var items: [T] = []
    var page = 0
    while true {
        let result = try await fetch(page)
        items += result.items
        if result.items.isEmpty || items.count >= result.totalItems { return items }
        page += 1
    }
}
