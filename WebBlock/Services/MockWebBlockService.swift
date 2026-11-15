import Foundation

/// SAMPLE DATA ONLY.
/// Every string below is copied from the "Final submit" page of the WebBlock Figma file
/// (Petal & Stem, product names, prices, deploy history, plan limits, ...).
/// Anything not in Figma is marked `// SAMPLE`.
actor MockWebBlockService: WebBlockService {

    // MARK: State

    private var user = UserProfile(fullName: "Sovannarith Soeun", email: "sovannarith@gmail.com", plan: .plus)

    private static let petalID = UUID(), bakeryID = UUID(), coffeeID = UUID(), yogaID = UUID()

    private var siteList: [Website] = [
        Website(id: petalID, name: "Petal & Stem", businessType: "Florist", status: .live, url: "petalandstem.webblock.com", logoAsset: "petal-stem-logo"),
        // SAMPLE: three more live websites so the list has several to choose from.
        Website(id: bakeryID, name: "Golden Crumb Bakery", businessType: "Bakery", status: .live, url: "goldencrumb.webblock.com", logoAsset: "golden-crumb-logo"),
        Website(id: coffeeID, name: "Bean & Brew Café", businessType: "Café", status: .live, url: "beanandbrew.webblock.com", logoAsset: "bean-brew-logo"),
        Website(id: yogaID, name: "Studio Lotus Yoga", businessType: "Yoga studio", status: .live, url: "studiolotus.webblock.com", logoAsset: "studio-lotus-logo"),
        // Not live, so the app hides them. Kept to show the "live only" rule working.
        Website(id: UUID(), name: "Maple & Rye Bakery", businessType: "Bakery", status: .draft, url: nil),
        Website(id: UUID(), name: "Lantern Café", businessType: "Café", status: .draft, url: "lanterncafe.webblock.com"),
        Website(id: UUID(), name: "Northpoint Audio", businessType: "Audio store", status: .suspended, url: "northpointaudio.webblock.com"),
    ]

    private var notificationList: [AppNotification] = [  // timestamps are SAMPLE: Figma lists the times unordered
        AppNotification(source: "Petal & Stem", message: "Your latest changes are live.", timeText: "2 mins ago", isUnread: true, logoAsset: "petal-stem-logo",
                        detail: "Deploy 10 finished successfully and your latest changes are now live on petalandstem.webblock.com. Visitors see the updated products and opening hours.",
                        websiteID: petalID, tab: .monitor, actionTitle: "Open Monitor"),
        AppNotification(source: "Northpoint Audio", message: "Website suspended · reactivate it any time.", timeText: "1 hour ago", isUnread: true,
                        detail: "This website is suspended, so it is hidden from visitors and can’t be managed in the app. You can reactivate it any time from the WebBlock website."),
        AppNotification(source: "WebBlock Billing", message: "Your free trial ends in 9 days. Pick a plan.", timeText: "3 hours ago", isUnread: true,
                        detail: "Your free trial ends in 9 days. Choose Plus, Pro or Ultra to keep your websites online and your products published.",
                        websiteID: petalID, tab: .monitor, actionTitle: "See plan usage"),
        AppNotification(source: "WebBlock Support", message: "We replied to your message about your domain.", timeText: "5 hours ago", isUnread: true,
                        detail: "Our team replied to your message about connecting your domain. Check your email for the full answer and the next steps."),
        AppNotification(source: "Lantern Café", message: "Draft saved · publish when you’re ready.", timeText: "Yesterday", isUnread: false,
                        detail: "Your draft is saved. It isn’t live yet, so visitors can’t see it. Publish it from the WebBlock website when you’re ready."),
        AppNotification(source: "Maple & Rye", message: "Website created from the Sweet pastel template.", timeText: "2 days ago", isUnread: false,
                        detail: "Your website was created from the Sweet pastel template. Add your products and details, then publish it."),
        AppNotification(source: "Petal & Stem", message: "Connected to petalandstem.webblock.com.", timeText: "2 days ago", isUnread: false, logoAsset: "petal-stem-logo",
                        detail: "Your website is now connected to petalandstem.webblock.com. Review how your details appear to customers in Business information.",
                        websiteID: petalID, tab: .info, actionTitle: "Open Business information"),
        AppNotification(source: "WebBlock", message: "Welcome to WebBlock, Sovannarith!", timeText: "3 days ago", isUnread: false,
                        detail: "Thanks for joining WebBlock. Pick a template, add your details and publish your first website in minutes."),
    ]

    // Each tuple's last value is the bundled image name in Assets.xcassets (from the Figma "Final submit" page).
    private static let petalProducts: [Product] = [
        ("Blue lily stem", "Flowers", "A single long-stemmed blue lily, cut fresh each morning. Looks lovely on its own in a slim vase.", 6, "blue-lily-stem"),
        ("Gift bouquet", "Bouquets", "A hand-tied bouquet of seasonal flowers, wrapped in kraft paper with a ribbon and a small card.", 38, "gift-bouquet"),
        ("Lily bunch", "Flowers", "Three lily stems tied by hand. The buds open over a few days and fill the room with a soft scent.", 16, "lily-bunch"),
        ("Stone vase", "Gifts", "A handmade ceramic vase with a matte stone finish. Holds a small bouquet or stands well on its own.", 24, "stone-vase"),
        ("Table arrangement", "Events", "A low arrangement of seasonal flowers and greenery for dining tables and events. Order two days ahead.", 45, "table-arrangement"),
        ("Spring tulip bunch", "Flowers", "This week’s special: ten fresh tulips in soft spring colours, tied with natural twine.", 14, "spring-tulip-bunch"),
        ("Peony bouquet", "Bouquets", "Soft pink peonies in season, tied with eucalyptus. The full blooms open slowly over several days.", 32, "peony-bouquet"),
        ("Petal candle", "Gifts", "A hand-poured soy wax candle topped with dried petals. Burns for about 40 hours.", 26, "petal-candle"),
        ("Dried grass bunch", "Flowers", "Natural dried grasses that keep their shape and colour for months. No water needed.", 18, "dried-grass-bunch"),
        ("Bud vase", "Gifts", "A small hand-glazed bud vase. Pairs well with a single stem or a few dried flowers.", 18, "bud-vase"),
        ("Ceramic bud vase", "Gifts", "A small hand-thrown vase with a matte glaze, sized for one or two stems.", 22, "ceramic-bud-vase"),
        ("Pampas stem", "Flowers", "One tall, fluffy pampas stem, dried to last for years. Adds a calm, natural touch to any room.", 12, "pampas-stem"),
    ].map { Product(id: UUID(), name: $0.0, category: $0.1, description: $0.2, price: Decimal($0.3), imageName: $0.4) }

    private static let petalInfo = BusinessInfo(
        name: "Petal & Stem", type: "Florist", url: "petalandstem.webblock.com",
        description: "Hand-tied bouquets, single stems and event flowers, arranged in our studio and delivered across town.",
        phone: "012 345 678", email: "hello@petalandstem.com", address: "18 Garden Lane, Phnom Penh",
        mapsLink: "https://maps.app.goo.gl/PetalStem18", hours: OpeningDay.defaultWeek
    )

    /// SAMPLE: a week with the given hours; `closedDays` are weekday indexes (0 = Monday).
    private static func week(_ open: Int, _ close: Int, closed: Set<Int> = []) -> [OpeningDay] {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].enumerated().map { i, day in
            OpeningDay(weekday: day, isOpen: !closed.contains(i), opens: OpeningDay.time(open), closes: OpeningDay.time(close))
        }
    }

    /// Each tuple ends with the bundled illustration (Assets.xcassets "sample-…") for that product.
    private static func sampleProducts(_ items: [(String, String, String, Int, String)]) -> [Product] {
        items.map { Product(id: UUID(), name: $0.0, category: $0.1, description: $0.2, price: Decimal($0.3), imageName: $0.4) }
    }

    private var productsBySite: [UUID: [Product]] = [
        petalID: petalProducts,
        bakeryID: sampleProducts([
            ("Butter croissant", "Pastries", "Flaky, golden and baked fresh every morning with French butter.", 3, "sample-croissant"),
            ("Sourdough loaf", "Bread", "A 24-hour fermented loaf with a crisp crust and a soft, tangy crumb.", 7, "sample-sourdough"),
            ("Pain au chocolat", "Pastries", "Laminated dough wrapped around two bars of dark chocolate.", 4, "sample-pain-au-chocolat"),
            ("Cinnamon roll", "Pastries", "Soft rolls swirled with cinnamon sugar and topped with cream cheese icing.", 5, "sample-cinnamon-roll"),
        ]),
        coffeeID: sampleProducts([
            ("Flat white", "Coffee", "A double shot of house espresso with silky steamed milk.", 4, "sample-flat-white"),
            ("Iced latte", "Coffee", "Espresso over ice with cold milk. Add vanilla or caramel on request.", 5, "sample-iced-latte"),
            ("Matcha latte", "Tea", "Ceremonial-grade matcha whisked with steamed milk.", 5, "sample-matcha-latte"),
            ("Banana bread", "Bakes", "Baked daily. Moist, lightly spiced and served warm.", 3, "sample-banana-bread"),
        ]),
        yogaID: sampleProducts([
            ("Drop-in class", "Classes", "One 60-minute class. Mats and props are provided.", 8, "sample-yoga-dropin"),
            ("10-class pass", "Passes", "Ten classes, valid for three months. Share with a friend.", 70, "sample-yoga-pass"),
            ("Monthly unlimited", "Memberships", "Unlimited classes for 30 days, including weekend workshops.", 90, "sample-yoga-monthly"),
            ("Private session", "Classes", "A one-to-one session tailored to your goals and experience.", 35, "sample-yoga-private"),
        ]),
    ]

    private var infoBySite: [UUID: BusinessInfo] = [
        petalID: petalInfo,
        bakeryID: BusinessInfo(
            name: "Golden Crumb Bakery", type: "Bakery", url: "goldencrumb.webblock.com",
            description: "Neighbourhood bakery making croissants, sourdough and cakes from scratch every morning.",
            phone: "023 456 789", email: "hello@goldencrumb.com", address: "42 Riverside Road, Phnom Penh",
            mapsLink: "https://maps.app.goo.gl/GoldenCrumb42", hours: week(6, 16)),
        coffeeID: BusinessInfo(
            name: "Bean & Brew Café", type: "Café", url: "beanandbrew.webblock.com",
            description: "Specialty coffee, fresh bakes and a quiet corner to work from, roasted locally.",
            phone: "077 123 456", email: "hello@beanandbrew.com", address: "9 Street 240, Phnom Penh",
            mapsLink: "", hours: week(7, 20, closed: [])),
        yogaID: BusinessInfo(
            name: "Studio Lotus Yoga", type: "Yoga studio", url: "studiolotus.webblock.com",
            description: "Small-group vinyasa, yin and beginner classes in a calm, light-filled studio.",
            phone: "096 987 654", email: "namaste@studiolotus.com", address: "27 Sothearos Blvd, Phnom Penh",
            mapsLink: "https://maps.app.goo.gl/StudioLotus27", hours: week(7, 19, closed: [6])),
    ]

    private func delay() async { try? await Task.sleep(for: .milliseconds(120)) }

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

    func requestPasswordReset(email: String) async throws {
        await delay()   // SAMPLE: pretends the reset email was sent
    }

    func verifyResetCode(email: String, code: String) async throws {
        await delay()   // SAMPLE: accepts any 6-digit code
        guard code.count == 6 else { throw NSError(domain: "WebBlock", code: 1, userInfo: [NSLocalizedDescriptionKey: "That code isn’t right. Try again."]) }
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws {
        await delay()   // SAMPLE: pretends the password was updated
    }

    // MARK: Websites

    func websites() async throws -> [Website] { await delay(); return siteList }

    func notifications() async throws -> [AppNotification] { await delay(); return notificationList }
    func markAllNotificationsRead() async throws {
        for index in notificationList.indices { notificationList[index].isUnread = false }
    }

    // MARK: Business portal

    func products(websiteID: UUID) async throws -> [Product] { await delay(); return productsBySite[websiteID] ?? [] }

    func saveProduct(_ product: Product, websiteID: UUID) async throws -> Product {
        await delay()
        var list = productsBySite[websiteID] ?? []
        if let index = list.firstIndex(where: { $0.id == product.id }) {
            list[index] = product
        } else {
            list.insert(product, at: 0)
        }
        productsBySite[websiteID] = list
        return product
    }

    func deleteProduct(id: UUID, websiteID: UUID) async throws {
        await delay()
        productsBySite[websiteID]?.removeAll { $0.id == id }
    }

    func businessInfo(websiteID: UUID) async throws -> BusinessInfo { await delay(); return infoBySite[websiteID] ?? Self.petalInfo }
    func saveBusinessInfo(_ updated: BusinessInfo, websiteID: UUID) async throws -> BusinessInfo {
        await delay()
        // Name, business type and web address cannot be changed.
        var info = infoBySite[websiteID] ?? Self.petalInfo
        info.description = updated.description; info.phone = updated.phone; info.email = updated.email
        info.address = updated.address; info.mapsLink = updated.mapsLink; info.hours = updated.hours
        infoBySite[websiteID] = info
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
            websiteURL: siteList.first { $0.id == websiteID }?.url ?? "petalandstem.webblock.com", isOnline: true, uptime: "99.98%", deploySuccess: "71%",
            lastDeployText: "2 days ago", lastDeployDetail: "Deploy 10 · 18 Oct, 2:15 PM",
            lastSevenResults: deploys.reversed().map(\.result), resetsOn: "1 Nov",
            productsUsed: 26, photosUsed: 41, redeploysUsed: 5, websitesUsed: 1,
            succeededCount: 8, failedCount: 2, deploys: deploys, activity: activity
        )
    }
}
