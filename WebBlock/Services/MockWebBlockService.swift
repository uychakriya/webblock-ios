import Foundation

/// SAMPLE DATA ONLY.
/// Every string below is copied from the "Final submit" page of the WebBlock Figma file
/// (Petal & Stem, product names, prices, deploy history, plan limits, ...).
/// Anything not in Figma is marked `// SAMPLE`.
actor MockWebBlockService: WebBlockService {

    // MARK: State

    private var user = UserProfile(fullName: "Sovannarith Soeun", email: "sovannarith@gmail.com", plan: .plus)

    private var siteList: [Website] = [
        Website(id: UUID(), name: "Petal & Stem", businessType: "Florist", status: .live, url: "petalandstem.webblock.com"),
        // Not live, so the app hides them. Kept to show the "live only" rule working.
        Website(id: UUID(), name: "Maple & Rye Bakery", businessType: "Bakery", status: .draft, url: nil),
        Website(id: UUID(), name: "Lantern Café", businessType: "Café", status: .draft, url: "lanterncafe.webblock.com"),
        Website(id: UUID(), name: "Northpoint Audio", businessType: "Audio store", status: .suspended, url: "northpointaudio.webblock.com"),
    ]

    private var notificationList: [AppNotification] = [  // timestamps are SAMPLE: Figma lists the times unordered
        AppNotification(source: "Petal & Stem", message: "Your latest changes are live.", timeText: "2 mins ago", isUnread: true),
        AppNotification(source: "Northpoint Audio", message: "Website suspended · reactivate it any time.", timeText: "1 hour ago", isUnread: true),
        AppNotification(source: "WebBlock Billing", message: "Your free trial ends in 9 days. Pick a plan.", timeText: "3 hours ago", isUnread: true),
        AppNotification(source: "WebBlock Support", message: "We replied to your message about your domain.", timeText: "5 hours ago", isUnread: true),
        AppNotification(source: "Lantern Café", message: "Draft saved · publish when you’re ready.", timeText: "Yesterday", isUnread: false),
        AppNotification(source: "Maple & Rye", message: "Website created from the Sweet pastel template.", timeText: "2 days ago", isUnread: false),
        AppNotification(source: "Petal & Stem", message: "Connected to petalandstem.webblock.com.", timeText: "2 days ago", isUnread: false),
        AppNotification(source: "WebBlock", message: "Welcome to WebBlock, Sovannarith!", timeText: "3 days ago", isUnread: false),
    ]

    private var productList: [Product] = [
        ("Blue lily stem", "Flowers", "A single long-stemmed blue lily, cut fresh each morning. Looks lovely on its own in a slim vase.", 6),
        ("Gift bouquet", "Bouquets", "A hand-tied bouquet of seasonal flowers, wrapped in kraft paper with a ribbon and a small card.", 38),
        ("Lily bunch", "Flowers", "Three lily stems tied by hand. The buds open over a few days and fill the room with a soft scent.", 16),
        ("Stone vase", "Gifts", "A handmade ceramic vase with a matte stone finish. Holds a small bouquet or stands well on its own.", 24),
        ("Table arrangement", "Events", "A low arrangement of seasonal flowers and greenery for dining tables and events. Order two days ahead.", 45),
        ("Spring tulip bunch", "Flowers", "This week’s special: ten fresh tulips in soft spring colours, tied with natural twine.", 14),
        ("Peony bouquet", "Bouquets", "Soft pink peonies in season, tied with eucalyptus. The full blooms open slowly over several days.", 32),
        ("Petal candle", "Gifts", "A hand-poured soy wax candle topped with dried petals. Burns for about 40 hours.", 26),
        ("Dried grass bunch", "Flowers", "Natural dried grasses that keep their shape and colour for months. No water needed.", 18),
        ("Bud vase", "Gifts", "A small hand-glazed bud vase. Pairs well with a single stem or a few dried flowers.", 18),
        ("Ceramic bud vase", "Gifts", "A small hand-thrown vase with a matte glaze, sized for one or two stems.", 22),
        ("Pampas stem", "Flowers", "One tall, fluffy pampas stem, dried to last for years. Adds a calm, natural touch to any room.", 12),
    ].map { Product(id: UUID(), name: $0.0, category: $0.1, description: $0.2, price: Decimal($0.3)) }

    private var info = BusinessInfo(
        name: "Petal & Stem", type: "Florist", url: "petalandstem.webblock.com",
        description: "Hand-tied bouquets, single stems and event flowers, arranged in our studio and delivered across town.",
        phone: "012 345 678", email: "hello@petalandstem.com", address: "18 Garden Lane, Phnom Penh",
        mapsLink: "https://maps.app.goo.gl/PetalStem18", hours: OpeningDay.defaultWeek
    )

    private func delay() async { try? await Task.sleep(for: .milliseconds(450)) }

    // MARK: Sign in

    /// SAMPLE rule: any email with "@" and a password of 8+ characters signs in.
    /// An email starting with "pro" or "ultra" signs in on that plan so you can compare the Monitor page.
    func signIn(email: String, password: String) async throws -> UserProfile {
        await delay()
        guard email.contains("@"), password.count >= 8 else { throw ServiceError.invalidCredentials }
        user.email = email
        let name = email.lowercased()
        user.plan = name.hasPrefix("ultra") ? .ultra : (name.hasPrefix("pro") ? .pro : .plus)
        return user
    }

    func signInWithGoogle() async throws -> UserProfile {
        await delay()
        return user
    }

    // MARK: Websites

    func websites() async throws -> [Website] { await delay(); return siteList }

    func notifications() async throws -> [AppNotification] { await delay(); return notificationList }
    func markAllNotificationsRead() async throws {
        for index in notificationList.indices { notificationList[index].isUnread = false }
    }

    // MARK: Business portal

    func products(websiteID: UUID) async throws -> [Product] { await delay(); return productList }

    func saveProduct(_ product: Product, websiteID: UUID) async throws -> Product {
        await delay()
        if let index = productList.firstIndex(where: { $0.id == product.id }) {
            productList[index] = product
        } else {
            productList.insert(product, at: 0)
        }
        return product
    }

    func deleteProduct(id: UUID, websiteID: UUID) async throws {
        await delay()
        productList.removeAll { $0.id == id }
    }

    func businessInfo(websiteID: UUID) async throws -> BusinessInfo { await delay(); return info }
    func saveBusinessInfo(_ updated: BusinessInfo, websiteID: UUID) async throws -> BusinessInfo {
        await delay()
        // Name, business type and web address cannot be changed.
        info.description = updated.description; info.phone = updated.phone; info.email = updated.email
        info.address = updated.address; info.mapsLink = updated.mapsLink; info.hours = updated.hours
        return info
    }

    func monitor(websiteID: UUID, plan: PlanTier) async throws -> MonitorSnapshot {
        await delay()
        let deploys = [
            Deploy(number: 10, date: .on(2026, 10, 18, 14, 15), result: .succeeded, duration: "1m 41s", startedBy: "Maya Sok", liveFor: "2 days (current)"),
            Deploy(number: 9, date: .on(2026, 10, 15, 10, 2), result: .succeeded, duration: "1m 38s", startedBy: "Maya Sok", liveFor: "3 days"),
            Deploy(number: 8, date: .on(2026, 10, 11, 16, 47), result: .failed, duration: "1m 09s", startedBy: "Maya Sok", liveFor: "—"),
            Deploy(number: 7, date: .on(2026, 10, 8, 9, 20), result: .succeeded, duration: "1m 44s", startedBy: "Maya Sok", liveFor: "7 days"),
            Deploy(number: 6, date: .on(2026, 10, 2, 10, 24), result: .succeeded, duration: "1m 52s", startedBy: "Maya Sok", liveFor: "6 days"),
            Deploy(number: 5, date: .on(2026, 9, 28, 16, 10), result: .failed, duration: "1m 47s", startedBy: "Maya Sok", liveFor: "—"),
            Deploy(number: 4, date: .on(2026, 9, 21, 9, 2), result: .succeeded, duration: "1m 12s", startedBy: "Maya Sok", liveFor: "11 days"),
        ]
        let activity = [
            ActivityItem(title: "Deploy 10 succeeded", detail: nil, kind: .deploy, date: .on(2026, 10, 18, 14, 15), isFailure: false),
            ActivityItem(title: "Product “Lily bunch” added", detail: nil, kind: .product, date: .on(2026, 10, 17, 11, 40), isFailure: false),
            ActivityItem(title: "Deploy 9 succeeded", detail: nil, kind: .deploy, date: .on(2026, 10, 15, 10, 2), isFailure: false),
            ActivityItem(title: "Opening hours updated", detail: nil, kind: .businessInfo, date: .on(2026, 10, 14, 9, 5), isFailure: false),
            ActivityItem(title: "Deploy 8 failed", detail: "Image “spring-tulips.jpg” is over 10 MB", kind: .deploy, date: .on(2026, 10, 11, 16, 48), isFailure: true),
            ActivityItem(title: "Product “Spring tulip bunch” added", detail: nil, kind: .product, date: .on(2026, 10, 11, 16, 30), isFailure: false),
            ActivityItem(title: "Deploy 7 succeeded", detail: nil, kind: .deploy, date: .on(2026, 10, 8, 9, 22), isFailure: false),
        ]
        return MonitorSnapshot(
            websiteURL: "petalandstem.webblock.com", isOnline: true, uptime: "99.98%", deploySuccess: "71%",
            lastDeployText: "2 days ago", lastDeployDetail: "Deploy 10 · 18 Oct, 2:15 PM",
            lastSevenResults: deploys.reversed().map(\.result), resetsOn: "1 Nov",
            productsUsed: 26, redeploysUsed: 5, websitesUsed: 1,
            succeededCount: 8, failedCount: 2, deploys: deploys, activity: activity
        )
    }
}
