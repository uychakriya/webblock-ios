import Foundation

// Wire types of the WebBlock v2 API, mirrored from the Android app's `remote/dto` package.
// Optional or defaulted fields decode leniently, like the Android `@Serializable` classes with defaults.

/// Every v2 list: `{items, page (zero-based), size, totalItems}`.
struct PageDto<T: Decodable>: Decodable {
    let items: [T]
    let page: Int
    let size: Int
    let totalItems: Int

    private enum Keys: String, CodingKey { case items, page, size, totalItems }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        items = try c.decodeIfPresent([T].self, forKey: .items) ?? []
        page = try c.decodeIfPresent(Int.self, forKey: .page) ?? 0
        size = try c.decodeIfPresent(Int.self, forKey: .size) ?? 0
        totalItems = try c.decodeIfPresent(Int.self, forKey: .totalItems) ?? 0
    }
}

// MARK: User v2

struct SignInRequest: Encodable {
    let email: String
    let password: String
    /// Asks for an offline session: about 30 days idle, no maximum.
    var stayLoggedIn = true
}

struct AppSignInRequest: Encodable {
    let code: String
    let codeVerifier: String
    let redirectUri: String
}

struct RefreshTokenRequest: Encodable { let refreshToken: String }

struct ProfileDto: Decodable {
    let id: String
    let fullName: String
    let email: String
    /// `FREE_TRIAL`, `PLUS`, `PRO`, `ULTRA`; `nil` while Payment is down.
    let plan: String?
    let avatarUrl: String?
}

struct EmailRequest: Encodable { let email: String }

struct CodeSentDto: Decodable {
    let expiresInSeconds: Int
    let resendAfterSeconds: Int
}

struct VerifyCodeRequest: Encodable {
    let email: String
    let code: String
}

struct VerificationDto: Decodable {
    let verificationToken: String
    let expiresInSeconds: Int
}

struct NewPasswordRequest: Encodable {
    let verificationToken: String
    let password: String
    let confirmPassword: String
}

// MARK: Project v2

struct WebsiteDto: Decodable {
    let id: String
    let name: String
    let businessType: String?
    /// `LIVE`, `DRAFT`, `SUSPENDED`.
    let status: String
    let domain: String?
    let thumbnailUrl: String?
    let logoUrl: String?
}

struct OpeningHourDto: Codable {
    /// `MONDAY` ... `SUNDAY`.
    let day: String
    let open: Bool
    /// "HH:mm".
    let opensAt: String
    let closesAt: String
}

struct BusinessInfoDto: Decodable {
    let websiteId: String?
    let description: String
    let logoUrl: String?
    let phone: String
    let email: String
    let address: String
    let mapsUrl: String?
    let hours: [OpeningHourDto]
    let updatedAt: String?

    private enum Keys: String, CodingKey {
        case websiteId, description, logoUrl, phone, email, address, mapsUrl, hours, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        websiteId = try c.decodeIfPresent(String.self, forKey: .websiteId)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        logoUrl = try c.decodeIfPresent(String.self, forKey: .logoUrl)
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        mapsUrl = try c.decodeIfPresent(String.self, forKey: .mapsUrl)
        hours = try c.decodeIfPresent([OpeningHourDto].self, forKey: .hours) ?? []
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

/// `PUT /business-info`. `logoUrl` is left out, so the logo is kept.
struct BusinessInfoBody: Encodable {
    let description: String
    let phone: String
    let email: String
    let address: String
    /// Sent as `null` when empty.
    let mapsUrl: String?
    let hours: [OpeningHourDto]

    private enum Keys: String, CodingKey { case description, phone, email, address, mapsUrl, hours }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(description, forKey: .description)
        try c.encode(phone, forKey: .phone)
        try c.encode(email, forKey: .email)
        try c.encode(address, forKey: .address)
        try c.encode(mapsUrl, forKey: .mapsUrl) // explicit null
        try c.encode(hours, forKey: .hours)
    }
}

struct ProductDto: Decodable {
    let id: String
    let name: String
    let description: String
    let category: String
    /// Decimal string ("6.00"); `nil` is a hidden price.
    let price: String?
    let imageUrl: String?
    let version: Int64?

    private enum Keys: String, CodingKey { case id, name, description, category, price, imageUrl, version }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        price = try c.decodeIfPresent(String.self, forKey: .price)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        version = try c.decodeIfPresent(Int64.self, forKey: .version)
    }
}

struct CategoryRequest: Encodable { let name: String }

struct MediaAssetDto: Decodable {
    let id: String
    let url: String
    let name: String?
}

struct ActivityEventDto: Decodable {
    let id: String
    /// `DEPLOY`, `PRODUCT`, `BUSINESS_INFO`.
    let type: String
    /// `SUCCEEDED`, `FAILED`, `CHANGED`.
    let outcome: String?
    let title: String
    let detail: String?
    let occurredAt: String
}

// MARK: Provisioning v2 and Payment v2

struct SiteStatusDto: Decodable {
    let websiteId: String?
    let online: Bool
    /// Last 30 days, a decimal string ("99.98"); `nil` without a check.
    let uptimePercent: String?
    let checkedAt: String?

    private enum Keys: String, CodingKey { case websiteId, online, uptimePercent, checkedAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        websiteId = try c.decodeIfPresent(String.self, forKey: .websiteId)
        online = try c.decodeIfPresent(Bool.self, forKey: .online) ?? false
        uptimePercent = try c.decodeIfPresent(String.self, forKey: .uptimePercent)
        checkedAt = try c.decodeIfPresent(String.self, forKey: .checkedAt)
    }
}

struct DeployStatsDto: Decodable {
    let total: Int
    let succeeded: Int
    let failed: Int

    private enum Keys: String, CodingKey { case total, succeeded, failed }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
        succeeded = try c.decodeIfPresent(Int.self, forKey: .succeeded) ?? 0
        failed = try c.decodeIfPresent(Int.self, forKey: .failed) ?? 0
    }
}

struct PersonDto: Decodable { let fullName: String }

struct ReleaseDto: Decodable {
    let id: String
    let number: Int
    let startedBy: PersonDto?
    let startedAt: String
    let finishedAt: String?
    let durationSeconds: Int?
    /// `SUCCEEDED`, `FAILED`; `nil` while running.
    let status: String?
    /// `LIVE`, `REPLACED`, `FAILED`, ...
    let state: String?
    let promotedAt: String?
}

struct UsageMetricDto: Decodable {
    /// `websites`, `deploys`, `redeploys`, `generations`, `products`, `photos`.
    let key: String
    let label: String?
    let cardLabel: String?
    let used: Int?
    /// `nil` = unlimited.
    let limit: Int?
}

struct PlanUsageDto: Decodable {
    let plan: String?
    let resetsAt: String?
    let metrics: [UsageMetricDto]

    private enum Keys: String, CodingKey { case plan, resetsAt, metrics }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        plan = try c.decodeIfPresent(String.self, forKey: .plan)
        resetsAt = try c.decodeIfPresent(String.self, forKey: .resetsAt)
        metrics = try c.decodeIfPresent([UsageMetricDto].self, forKey: .metrics) ?? []
    }
}

// MARK: Notification v2

struct NotificationTargetDto: Decodable {
    let websiteId: String?
    /// `MONITOR`, `PRODUCTS`, `BUSINESS_INFO`, or `nil` (no button).
    let tab: String?
    let workflow: String?
}

struct NotificationDto: Decodable {
    /// A Knock id, not a UUID.
    let id: String
    let title: String
    let message: String
    /// `SUCCESS`, `WARNING`, `INFO`.
    let kind: String?
    let websiteId: String?
    let createdAt: String
    let read: Bool
    let detail: String?
    let target: NotificationTargetDto?

    private enum Keys: String, CodingKey { case id, title, message, kind, websiteId, createdAt, read, detail, target }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        message = try c.decode(String.self, forKey: .message)
        kind = try c.decodeIfPresent(String.self, forKey: .kind)
        websiteId = try c.decodeIfPresent(String.self, forKey: .websiteId)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        read = try c.decodeIfPresent(Bool.self, forKey: .read) ?? false
        detail = try c.decodeIfPresent(String.self, forKey: .detail)
        target = try c.decodeIfPresent(NotificationTargetDto.self, forKey: .target)
    }
}

/// `PATCH /me/notifications` and `/me/notifications/{id}`: only `{"read": true}`.
struct ReadUpdate: Encodable { var read = true }
