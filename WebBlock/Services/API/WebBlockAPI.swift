import Foundation

/// What a product save does to the photo (`imageUrl` in the body): absent keeps it, `null` removes it,
/// a URL sets it. Mirrors Android `PhotoChange`.
enum PhotoChange {
    case keep
    case remove
    case set(String)
}

/// All WebBlock v2 endpoints the Android app calls, one method per endpoint, same paths, verbs,
/// query parameters and bodies as its Retrofit interfaces (UserApi, SessionApi, ProjectApi, ProductApi,
/// ProvisioningApi, PaymentApi, NotificationApi).
struct WebBlockAPI: Sendable {
    let client: HTTPClient
    let session: SessionManager

    /// Production wiring: the refresh call runs on a client without auth, so a refresh never triggers another.
    static func live(baseURL: URL = APIConfig.baseURL, urlSession: URLSession = .shared) -> WebBlockAPI {
        let plain = HTTPClient(baseURL: baseURL, urlSession: urlSession, session: nil)
        let session = SessionManager { refreshToken in
            let body = try HTTPClient.encode(RefreshTokenRequest(refreshToken: refreshToken))
            return try await plain.send("POST", "api/user/v2/sessions/refresh", json: body)
        }
        return WebBlockAPI(client: HTTPClient(baseURL: baseURL, urlSession: urlSession, session: session), session: session)
    }

    private static func escape(_ segment: String) -> String {
        segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? segment
    }

    private func projectPath(_ id: String, _ tail: String = "") -> String {
        "api/project/v2/projects/\(Self.escape(id))\(tail)"
    }

    private func provisioningPath(_ id: String, _ tail: String) -> String {
        "api/provisioning/v2/projects/\(Self.escape(id))\(tail)"
    }

    private func pageQuery(page: Int, size: Int = APIConfig.projectPageSize, sort: String? = nil) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "size", value: String(size))]
        if let sort { items.append(URLQueryItem(name: "sort", value: sort)) }
        return items
    }

    // MARK: User v2 (7) + refresh (1)

    /// POST api/user/v2/sessions. Stores the session.
    @discardableResult
    func signIn(email: String, password: String) async throws -> TokenSetDto {
        let body = try HTTPClient.encode(SignInRequest(email: email, password: password))
        let set: TokenSetDto = try await client.send("POST", "api/user/v2/sessions", json: body)
        await session.start(set)
        return set
    }

    /// POST api/user/v2/sessions/google. Stores the session.
    @discardableResult
    func signInWithGoogle(code: String, codeVerifier: String, redirectUri: String) async throws -> TokenSetDto {
        let body = try HTTPClient.encode(AppSignInRequest(code: code, codeVerifier: codeVerifier, redirectUri: redirectUri))
        let set: TokenSetDto = try await client.send("POST", "api/user/v2/sessions/google", json: body)
        await session.start(set)
        return set
    }

    /// POST api/user/v2/sessions/refresh (plain client; `SessionManager` calls it on its own).
    func refresh(refreshToken: String) async throws -> TokenSetDto {
        let body = try HTTPClient.encode(RefreshTokenRequest(refreshToken: refreshToken))
        let plain = HTTPClient(baseURL: client.baseURL, urlSession: client.urlSession, session: nil)
        return try await plain.send("POST", "api/user/v2/sessions/refresh", json: body)
    }

    /// POST api/user/v2/sessions/revocations. The local session is cleared whatever the answer.
    func signOut() async throws {
        let refreshToken = await session.refreshToken()
        await session.clear()
        guard let refreshToken else { return }
        let body = try HTTPClient.encode(RefreshTokenRequest(refreshToken: refreshToken))
        try await client.send("POST", "api/user/v2/sessions/revocations", json: body)
    }

    /// GET api/user/v2/me
    func me() async throws -> ProfileDto {
        try await client.get("api/user/v2/me")
    }

    /// POST api/user/v2/password-resets
    @discardableResult
    func requestPasswordReset(email: String) async throws -> CodeSentDto {
        try await client.send("POST", "api/user/v2/password-resets", json: HTTPClient.encode(EmailRequest(email: email)))
    }

    /// POST api/user/v2/password-resets/verifications
    func verifyResetCode(email: String, code: String) async throws -> VerificationDto {
        try await client.send("POST", "api/user/v2/password-resets/verifications",
                              json: HTTPClient.encode(VerifyCodeRequest(email: email, code: code)))
    }

    /// POST api/user/v2/password-resets/confirmations
    func confirmPasswordReset(verificationToken: String, password: String, confirmPassword: String) async throws {
        let body = NewPasswordRequest(verificationToken: verificationToken, password: password, confirmPassword: confirmPassword)
        try await client.send("POST", "api/user/v2/password-resets/confirmations", json: HTTPClient.encode(body))
    }

    // MARK: Project v2: websites, business info, activity (5)

    /// GET api/project/v2/projects?page&size
    func websites(page: Int) async throws -> PageDto<WebsiteDto> {
        try await client.get("api/project/v2/projects", query: pageQuery(page: page))
    }

    /// GET api/project/v2/projects/{projectId}
    func website(projectId: String) async throws -> WebsiteDto {
        try await client.get(projectPath(projectId))
    }

    /// GET api/project/v2/projects/{projectId}/business-info
    func businessInfo(projectId: String) async throws -> BusinessInfoDto {
        try await client.get(projectPath(projectId, "/business-info"))
    }

    /// PUT api/project/v2/projects/{projectId}/business-info
    func saveBusinessInfo(projectId: String, body: BusinessInfoBody) async throws -> BusinessInfoDto {
        try await client.send("PUT", projectPath(projectId, "/business-info"), json: HTTPClient.encode(body))
    }

    /// GET api/project/v2/projects/{projectId}/activity?size  (Pro and Ultra only: 403 elsewhere)
    func activity(projectId: String, size: Int = APIConfig.monitorListSize) async throws -> PageDto<ActivityEventDto> {
        try await client.get(projectPath(projectId, "/activity"), query: [URLQueryItem(name: "size", value: String(size))])
    }

    // MARK: Project v2: products, categories, media (9)

    /// GET api/project/v2/projects/{projectId}/products?page&size&sort=createdAt,desc
    func products(projectId: String, page: Int) async throws -> PageDto<ProductDto> {
        try await client.get(projectPath(projectId, "/products"), query: pageQuery(page: page, sort: "createdAt,desc"))
    }

    /// GET api/project/v2/projects/{projectId}/product-categories: a bare `string[]` in the owner's order.
    func categories(projectId: String) async throws -> [String] {
        try await client.get(projectPath(projectId, "/product-categories"))
    }

    /// POST api/project/v2/projects/{projectId}/product-categories. 409 `CATEGORY_NAME_TAKEN` means it exists.
    func addCategory(projectId: String, name: String) async throws {
        try await client.send("POST", projectPath(projectId, "/product-categories"),
                              json: HTTPClient.encode(CategoryRequest(name: name)))
    }

    /// POST api/project/v2/projects/{projectId}/products
    func createProduct(projectId: String, body: Data) async throws -> ProductDto {
        try await client.send("POST", projectPath(projectId, "/products"), json: body)
    }

    /// PUT api/project/v2/projects/{projectId}/products/{productId}. 409: changed elsewhere since loaded.
    func updateProduct(projectId: String, productId: String, body: Data) async throws -> ProductDto {
        try await client.send("PUT", projectPath(projectId, "/products/\(Self.escape(productId))"), json: body)
    }

    /// DELETE api/project/v2/projects/{projectId}/products/{productId}: answers the deleted product.
    func deleteProduct(projectId: String, productId: String) async throws -> ProductDto {
        let data = try await client.send("DELETE", projectPath(projectId, "/products/\(Self.escape(productId))"))
        return try client.decode(data)
    }

    /// GET api/project/v2/projects/{projectId}/media?page&size
    func media(projectId: String, page: Int) async throws -> PageDto<MediaAssetDto> {
        try await client.get(projectPath(projectId, "/media"), query: pageQuery(page: page))
    }

    /// DELETE api/project/v2/projects/{projectId}/media/{mediaId}: 204; 409 `MEDIA_IN_USE` while used.
    func deleteMedia(projectId: String, mediaId: String) async throws {
        try await client.send("DELETE", projectPath(projectId, "/media/\(Self.escape(mediaId))"))
    }

    /// POST api/project/v2/projects/{projectId}/media (multipart, part "file"). JPEG or PNG, 2 MiB at most.
    func uploadMedia(projectId: String, file: MultipartFile) async throws -> MediaAssetDto {
        let data = try await client.send("POST", projectPath(projectId, "/media"), file: file)
        return try client.decode(data)
    }

    // MARK: Provisioning v2 (3) and Payment v2 (1)

    /// GET api/provisioning/v2/projects/{projectId}/status. 404 `deployment-not-found`: never deployed.
    func siteStatus(projectId: String) async throws -> SiteStatusDto {
        try await client.get(provisioningPath(projectId, "/status"))
    }

    /// GET api/provisioning/v2/projects/{projectId}/releases/stats
    func releaseStats(projectId: String) async throws -> DeployStatsDto {
        try await client.get(provisioningPath(projectId, "/releases/stats"))
    }

    /// GET api/provisioning/v2/projects/{projectId}/releases?size: finished releases, newest first.
    func releases(projectId: String, size: Int = APIConfig.monitorListSize) async throws -> PageDto<ReleaseDto> {
        try await client.get(provisioningPath(projectId, "/releases"), query: [URLQueryItem(name: "size", value: String(size))])
    }

    /// GET api/payment/v2/projects/{projectId}/usage
    func usage(projectId: String) async throws -> PlanUsageDto {
        try await client.get("api/payment/v2/projects/\(Self.escape(projectId))/usage")
    }

    // MARK: Notification v2 (3)

    /// GET api/notification/v2/me/notifications?page&size
    func notifications(page: Int = 0, size: Int = APIConfig.bellSize) async throws -> PageDto<NotificationDto> {
        try await client.get("api/notification/v2/me/notifications", query: pageQuery(page: page, size: size))
    }

    /// PATCH api/notification/v2/me/notifications  body {"read": true}: marks all read, 204.
    func markAllNotificationsRead() async throws {
        try await client.send("PATCH", "api/notification/v2/me/notifications", json: HTTPClient.encode(ReadUpdate()))
    }

    /// PATCH api/notification/v2/me/notifications/{notificationId}  body {"read": true}. 404 = not in the feed.
    @discardableResult
    func markNotificationRead(id: String) async throws -> NotificationDto {
        try await client.send("PATCH", "api/notification/v2/me/notifications/\(Self.escape(id))",
                              json: HTTPClient.encode(ReadUpdate()))
    }

    // MARK: Product body

    /// The body of `POST /products` and `PUT /products/{id}`, built like Android `productBody()`.
    /// `price` nil keeps (or makes) the price hidden. A blank description is left out (Project refuses "").
    static func productBody(
        name: String,
        description: String,
        category: String,
        price: String?,
        photo: PhotoChange,
        version: Int64?
    ) throws -> Data {
        var body: [String: Any] = ["name": name, "category": category, "price": price ?? NSNull()]
        if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { body["description"] = description }
        switch photo {
        case .keep: break
        case .remove: body["imageUrl"] = NSNull()
        case .set(let url): body["imageUrl"] = url
        }
        if let version { body["version"] = version }
        return try JSONSerialization.data(withJSONObject: body)
    }
}
