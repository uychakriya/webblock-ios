import Foundation

/// The real `WebBlockService`: the same WebBlock v2 calls the Android app makes (docs/API-MAPPING.md),
/// mapped onto the models the screens already use, so no view changes.
actor APIWebBlockService: WebBlockService {
    private let api: WebBlockAPI

    /// Last catalog read per product, for versions (409 detection) and the photo a save replaces.
    private var productCache: [UUID: ProductDto] = [:]
    private var categoryCache: [UUID: [String]] = [:]
    private var photoCache: [String: Data] = [:]
    private var siteNames: [String: String] = [:]
    /// Knock ids of the notifications last loaded, keyed by the app's own ids.
    private var knockIDs: [UUID: String] = [:]
    /// Password reset: the `verificationToken` is kept in memory only, keyed by email.
    private var verificationTokens: [String: String] = [:]

    init(api: WebBlockAPI = .live()) { self.api = api }

    // MARK: Sign in (User v2)

    func signIn(email: String, password: String) async throws -> UserProfile {
        let set = try await api.signIn(email: email, password: password)
        if set.roles.contains("ADMIN") && !set.roles.contains("USER") {
            try? await api.signOut()
            throw APIError(message: "This app is for website owners. Sign in to the WebBlock admin on the web.")
        }
        return try await profile()
    }

    func signInWithGoogle() async throws -> UserProfile {
        let result = try await GoogleSignIn.authorize()
        try await api.signInWithGoogle(code: result.code, codeVerifier: result.codeVerifier, redirectUri: APIConfig.googleRedirectURI)
        return try await profile()
    }

    func requestPasswordReset(email: String) async throws {
        try await api.requestPasswordReset(email: email)
    }

    func verifyResetCode(email: String, code: String) async throws {
        let result = try await api.verifyResetCode(email: email, code: code)
        verificationTokens[email.lowercased()] = result.verificationToken
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws {
        let key = email.lowercased()
        var token = verificationTokens[key]
        if token == nil { token = try await api.verifyResetCode(email: email, code: code).verificationToken }
        guard let token else { throw APIError(message: "The reset has expired. Start again.") }
        do {
            try await api.confirmPasswordReset(verificationToken: token, password: newPassword, confirmPassword: newPassword)
        } catch let error as ApiException where error.code == "verification-token-invalid" {
            verificationTokens[key] = nil
            throw error
        }
        verificationTokens[key] = nil
    }

    func restoreSession() async -> UserProfile? {
        guard await api.session.hasSession() else { return nil }
        guard (try? await api.session.refreshNow()) != nil else { return nil }
        return try? await profile()
    }

    func signOut() async {
        try? await api.signOut()
        productCache = [:]; categoryCache = [:]; siteNames = [:]; knockIDs = [:]
    }

    private func profile() async throws -> UserProfile {
        let me = try await api.me()
        return UserProfile(fullName: me.fullName, email: me.email, plan: Self.plan(me.plan))
    }

    // MARK: Websites and notifications

    func websites() async throws -> [Website] {
        let api = self.api
        let sites = try await allPages { page in try await api.websites(page: page) }
        siteNames = Dictionary(sites.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return sites.compactMap(Self.website)
    }

    func notifications() async throws -> [AppNotification] {
        let page = try await api.notifications(page: 0, size: APIConfig.bellSize)
        if siteNames.isEmpty {
            let api = self.api
            if let sites = try? await allPages({ p in try await api.websites(page: p) }) {
                siteNames = Dictionary(sites.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
            }
        }
        knockIDs = [:]
        return page.items.map { dto in
            let siteID = dto.target?.websiteId ?? dto.websiteId
            let tab: PortalTab? = {
                guard siteID != nil else { return nil }
                guard let target = dto.target else { return .monitor }
                switch target.tab {
                case "MONITOR": return .monitor
                case "PRODUCTS": return .products
                case "BUSINESS_INFO": return .info
                default: return nil
                }
            }()
            let item = AppNotification(
                source: dto.title,
                message: dto.message,
                timeText: Self.relative(Self.parseDate(dto.createdAt)),
                isUnread: !dto.read,
                logoAsset: nil,
                detail: dto.detail ?? "",
                websiteID: siteID.flatMap(UUID.init(uuidString:)),
                tab: tab,
                actionTitle: tab.map(Self.actionTitle)
            )
            knockIDs[item.id] = dto.id
            return item
        }
    }

    func markAllNotificationsRead() async throws {
        try await api.markAllNotificationsRead()
    }

    func markNotificationRead(id: UUID) async {
        guard let knockID = knockIDs[id] else { return }
        _ = try? await api.markNotificationRead(id: knockID)   // a failure is ignored (Android)
    }

    // MARK: Products

    func products(websiteID: UUID) async throws -> [Product] {
        let project = Self.wire(websiteID)
        let api = self.api
        async let list = allPages { page in try await api.products(projectId: project, page: page) }
        async let categories = api.categories(projectId: project)
        let (dtos, cats) = try await (list, categories)
        categoryCache[websiteID] = cats
        productCache = [:]
        for dto in dtos { if let id = UUID(uuidString: dto.id) { productCache[id] = dto } }

        // Photos are shown from `photoData`, so the images are downloaded once and kept by URL.
        let missing = Set(dtos.compactMap(\.imageUrl).filter { !$0.isEmpty && photoCache[$0] == nil })
        if !missing.isEmpty {
            await withTaskGroup(of: (String, Data?).self) { group in
                for url in missing { group.addTask { (url, await Self.download(url)) } }
                for await (url, data) in group { if let data { photoCache[url] = data } }
            }
        }
        return dtos.compactMap { dto in
            guard let id = UUID(uuidString: dto.id) else { return nil }
            return Self.product(dto, id: id, photo: dto.imageUrl.flatMap { photoCache[$0] })
        }
    }

    func saveProduct(_ product: Product, websiteID: UUID) async throws -> Product {
        let project = Self.wire(websiteID)
        let previous = productCache[product.id]
        try await ensureCategory(product.category, websiteID: websiteID, project: project)

        // Photo: unchanged keeps it, a new one is uploaded first, none removes it.
        var photo = PhotoChange.keep
        var uploaded: (url: String, data: Data)?
        let oldURL = previous?.imageUrl ?? ""
        if let data = product.photoData {
            if !oldURL.isEmpty, photoCache[oldURL] == data {
                photo = .keep
            } else {
                let encoded = try PhotoEncoder.encode(data)
                let file = MultipartFile(field: "file", fileName: encoded.fileName, mimeType: encoded.mimeType, data: encoded.data)
                let url = try await api.uploadMedia(projectId: project, file: file).url
                photo = .set(url)
                uploaded = (url, data)
            }
        } else if !oldURL.isEmpty {
            photo = .remove
        }

        // An empty price on a hidden-price product keeps it hidden.
        let hidden = previous != nil && previous?.price == nil && product.price == 0
        let body = try WebBlockAPI.productBody(
            name: product.name, description: product.description, category: product.category,
            price: hidden ? nil : Self.priceText(product.price), photo: photo, version: previous?.version
        )

        let saved: ProductDto
        do {
            if let previous {
                saved = try await api.updateProduct(projectId: project, productId: previous.id, body: body)
            } else {
                saved = try await api.createProduct(projectId: project, body: body)
            }
        } catch let error as ApiException where error.status == 409 {
            throw APIError(message: ApiMessages.changedElsewhere)
        }
        let savedID = UUID(uuidString: saved.id) ?? product.id
        productCache[savedID] = saved
        if let uploaded { photoCache[uploaded.url] = uploaded.data }
        if !oldURL.isEmpty, oldURL != saved.imageUrl { await deleteUnusedPhoto(project: project, url: oldURL) }
        return Self.product(saved, id: savedID, photo: saved.imageUrl.flatMap { photoCache[$0] })
    }

    func deleteProduct(id: UUID, websiteID: UUID) async throws {
        let project = Self.wire(websiteID)
        let deleted = try await api.deleteProduct(projectId: project, productId: productCache[id]?.id ?? Self.wire(id))
        productCache[id] = nil
        if let url = deleted.imageUrl, !url.isEmpty { await deleteUnusedPhoto(project: project, url: url) }
    }

    // MARK: Business information

    func businessInfo(websiteID: UUID) async throws -> BusinessInfo {
        let project = Self.wire(websiteID)
        let api = self.api
        async let site = api.website(projectId: project)
        async let info = api.businessInfo(projectId: project)
        return Self.business(try await info, site: try await site)
    }

    func saveBusinessInfo(_ info: BusinessInfo, websiteID: UUID) async throws -> BusinessInfo {
        let project = Self.wire(websiteID)
        let maps = info.mapsLink.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = BusinessInfoBody(
            description: info.description, phone: info.phone, email: info.email, address: info.address,
            mapsUrl: maps.isEmpty ? nil : maps,
            hours: Self.weekdays.map { day in
                let hour = info.hours.first { $0.weekday == day.capitalized }
                return OpeningHourDto(
                    day: day,
                    open: hour?.isOpen ?? false,
                    opensAt: Self.hhmm(hour?.opens ?? OpeningDay.time(9)),
                    closesAt: Self.hhmm(hour?.closes ?? OpeningDay.time(18))
                )
            }
        )
        let saved = try await api.saveBusinessInfo(projectId: project, body: body)
        let site = try await api.website(projectId: project)
        return Self.business(saved, site: site)
    }

    // MARK: Monitor

    func monitor(websiteID: UUID, plan: PlanTier) async throws -> MonitorSnapshot {
        let project = Self.wire(websiteID)
        let api = self.api
        let size = APIConfig.monitorListSize
        // Any part but the website itself may fail on its own; that part then shows "—" or nothing.
        async let site = api.website(projectId: project)
        async let status = Self.optional { try await api.siteStatus(projectId: project) }
        async let stats = Self.optional { try await api.releaseStats(projectId: project) }
        async let releases = Self.optional { try await api.releases(projectId: project, size: size).items }
        async let usage = Self.optional { try await api.usage(projectId: project) }
        async let activity = Self.optional { try await api.activity(projectId: project, size: size).items }   // 403 = empty log
        let website = try await site
        let (status0, stats0, usage0) = (await status, await stats, await usage)
        let list = await releases ?? []
        let events = await activity ?? []
        return Self.snapshot(site: website, status: status0, stats: stats0, releases: list, usage: usage0, activity: events)
    }

    // MARK: Helpers

    private func ensureCategory(_ name: String, websiteID: UUID, project: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let known = categoryCache[websiteID] ?? []
        guard !trimmed.isEmpty, !known.contains(where: { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        do {
            try await api.addCategory(projectId: project, name: trimmed)
        } catch let error as ApiException where error.status == 409 {
            // CATEGORY_NAME_TAKEN: it exists already, which is what the owner wanted.
        }
        categoryCache[websiteID] = known + [trimmed]
    }

    /// Finds the image by its URL in the library and deletes it; any refusal is fine
    /// (Project answers 409 `MEDIA_IN_USE` while anything still uses it).
    private func deleteUnusedPhoto(project: String, url: String) async {
        let api = self.api
        do {
            let assets = try await allPages { page in try await api.media(projectId: project, page: page) }
            if let asset = assets.first(where: { $0.url == url }) {
                try await api.deleteMedia(projectId: project, mediaId: asset.id)
            }
        } catch {}
    }

    private static func optional<T>(_ work: () async throws -> T) async -> T? { try? await work() }

    private static func download(_ url: String) async -> Data? {
        guard let url = URL(string: url) else { return nil }
        return try? await URLSession.shared.data(from: url).0
    }

    private static func wire(_ id: UUID) -> String { id.uuidString.lowercased() }

    private static func plan(_ code: String?) -> PlanTier {
        switch code {
        case "PLUS": .plus
        case "PRO": .pro
        case "ULTRA": .ultra
        default: .freeTrial
        }
    }

    private static func website(_ dto: WebsiteDto) -> Website? {
        guard let id = UUID(uuidString: dto.id) else { return nil }
        let status: WebsiteStatus = switch dto.status {
        case "LIVE": .live
        case "SUSPENDED": .suspended
        default: .draft
        }
        let type = dto.businessType.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } ?? "—"
        return Website(id: id, name: dto.name, businessType: type, status: status, url: dto.domain)
    }

    private static func product(_ dto: ProductDto, id: UUID, photo: Data?) -> Product {
        Product(
            id: id, name: dto.name, category: dto.category, description: dto.description,
            price: dto.price.flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) } ?? 0,
            photoData: photo, imageName: nil
        )
    }

    /// "6.00": a dot and two decimals, never grouped, whatever the device's region.
    private static func priceText(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: price as NSDecimalNumber) ?? "\(price)"
    }

    private static func actionTitle(_ tab: PortalTab) -> String {
        switch tab {
        case .monitor: "Open Monitor"
        case .products: "Open Products"
        case .info: "Open Business information"
        }
    }

    // MARK: Business mapping

    private static let weekdays = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]

    private static func business(_ dto: BusinessInfoDto, site: WebsiteDto) -> BusinessInfo {
        let hours = weekdays.map { day -> OpeningDay in
            let hour = dto.hours.first { $0.day == day }
            return OpeningDay(
                weekday: day.capitalized,
                isOpen: hour?.open ?? false,
                opens: hour.flatMap { time($0.opensAt) } ?? OpeningDay.time(9),
                closes: hour.flatMap { time($0.closesAt) } ?? OpeningDay.time(18)
            )
        }
        return BusinessInfo(
            name: site.name,
            type: site.businessType.flatMap { $0.isEmpty ? nil : $0 } ?? "—",
            url: site.domain ?? "",
            description: dto.description, phone: dto.phone, email: dto.email, address: dto.address,
            mapsLink: dto.mapsUrl ?? "", hours: hours
        )
    }

    /// "09:30" → a date at that time (only the time is used).
    private static func time(_ text: String) -> Date? {
        let parts = text.split(separator: ":")
        guard let hour = parts.first.flatMap({ Int($0) }) else { return nil }
        return OpeningDay.time(hour, parts.count > 1 ? Int(parts[1]) ?? 0 : 0)
    }

    private static func hhmm(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    // MARK: Monitor mapping

    private static func snapshot(
        site: WebsiteDto, status: SiteStatusDto?, stats: DeployStatsDto?, releases: [ReleaseDto],
        usage: PlanUsageDto?, activity: [ActivityEventDto]
    ) -> MonitorSnapshot {
        let metrics = Dictionary(uniqueKeysWithValues: (usage?.metrics ?? []).map { ($0.key, $0) })
        let latest = releases.first
        let latestAt = latest.flatMap { parseDate($0.finishedAt) ?? parseDate($0.startedAt) }
        let total = stats?.total ?? 0
        let succeeded = stats?.succeeded ?? 0
        let now = Date()
        return MonitorSnapshot(
            websiteURL: site.domain ?? "",
            isOnline: status?.online ?? false,
            uptime: status?.uptimePercent.map { "\($0)%" } ?? "—",
            deploySuccess: total > 0 ? "\(Int((Double(succeeded) * 100 / Double(total)).rounded()))%" : "—",
            lastDeployText: latestAt.map { relative($0) } ?? "—",
            lastDeployDetail: latest.flatMap { release in latestAt.map { "Deploy \(release.number) · \(deployDate($0))" } } ?? "",
            lastSevenResults: releases.prefix(7).reversed().map { $0.status == "SUCCEEDED" ? .succeeded : .failed },
            resetsOn: parseDate(usage?.resetsAt).map(dayMonth) ?? "—",
            productsUsed: metrics["products"]?.used ?? 0,
            photosUsed: metrics["photos"]?.used ?? 0,
            redeploysUsed: (metrics["redeploys"] ?? metrics["deploys"])?.used ?? 0,
            websitesUsed: metrics["websites"]?.used ?? 0,
            succeededCount: succeeded,
            failedCount: stats?.failed ?? 0,
            deploys: releases.enumerated().map { index, release in
                Deploy(
                    number: release.number,
                    date: parseDate(release.startedAt) ?? now,
                    result: release.status == "SUCCEEDED" ? .succeeded : .failed,
                    duration: durationText(release.durationSeconds),
                    startedBy: release.startedBy?.fullName ?? "—",
                    liveFor: liveFor(releases, index, now) ?? "—"
                )
            },
            activity: activity.map { event in
                ActivityItem(
                    title: event.title, detail: event.detail,
                    kind: event.type == "DEPLOY" ? .deploy : (event.type == "PRODUCT" ? .product : .businessInfo),
                    date: parseDate(event.occurredAt) ?? now,
                    isFailure: event.outcome == "FAILED"
                )
            }
        )
    }

    /// Time live: from promotion to the next newer successful release ("(current)" for the live one); `nil` for a failed one.
    private static func liveFor(_ releases: [ReleaseDto], _ index: Int, _ now: Date) -> String? {
        let release = releases[index]
        guard release.status == "SUCCEEDED" else { return nil }
        func liveSince(_ r: ReleaseDto) -> Date? { parseDate(r.promotedAt) ?? parseDate(r.finishedAt) }
        let isLive = release.state == "LIVE"
        let start = liveSince(release)
        let end = isLive ? now : releases[..<index].last { $0.status == "SUCCEEDED" }.flatMap(liveSince)
        guard let start, let end else { return "—" }
        return isLive ? "\(span(start, end)) (current)" : span(start, end)
    }

    private static func span(_ start: Date, _ end: Date) -> String {
        let hours = max(0, Int(end.timeIntervalSince(start))) / 3600
        let days = hours / 24
        if days == 1 { return "1 day" }
        if days > 1 { return "\(days) days" }
        if hours == 1 { return "1 hour" }
        if hours > 1 { return "\(hours) hours" }
        return "Under an hour"
    }

    private static func durationText(_ seconds: Int?) -> String {
        guard let seconds else { return "—" }
        return seconds >= 60 ? String(format: "%dm %02ds", seconds / 60, seconds % 60) : "\(seconds)s"
    }

    // MARK: Dates

    static func parseDate(_ text: String?) -> Date? {
        guard let text else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    private static func relative(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private static func dayMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }

    private static func deployDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("d MMM, h:mm a")
        return formatter.string(from: date)
    }
}
