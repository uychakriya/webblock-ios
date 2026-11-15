import Foundation

// MARK: - Account

enum PlanTier: String, CaseIterable, Identifiable, Hashable, Sendable {
    case freeTrial, plus, pro, ultra
    var id: String { rawValue }

    var title: String {
        switch self {
        case .freeTrial: "Free trial"
        case .plus: "Plus"
        case .pro: "Pro"
        case .ultra: "Ultra"
        }
    }
    var planName: String { self == .freeTrial ? "Free trial" : "\(title) plan" }
    var maxWebsites: Int {
        switch self { case .freeTrial, .plus: 1; case .pro: 3; case .ultra: 10 }
    }
    var maxRedeploys: Int {
        switch self { case .freeTrial: 0; case .plus: 5; case .pro: 30; case .ultra: 100 }
    }
    var maxProducts: Int {
        switch self { case .freeTrial, .plus: 30; case .pro: 200; case .ultra: 1000 }
    }
    /// Pro and Ultra show the activity log on the Monitor page.
    var showsActivityLog: Bool { self == .pro || self == .ultra }
}

struct UserProfile: Hashable, Sendable {
    var fullName: String
    var email: String
    var plan: PlanTier

    var initials: String {
        fullName.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

// MARK: - Websites

enum WebsiteStatus: String, Hashable, Sendable {
    case live, draft, suspended, failed
}

struct Website: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var businessType: String
    var status: WebsiteStatus
    var url: String?

    /// Only live websites have the Business Portal, so only they appear in the app.
    var isLive: Bool { status == .live }

    var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

struct AppNotification: Identifiable, Hashable, Sendable {
    let id = UUID()
    var source: String
    var message: String
    var timeText: String
    var isUnread: Bool
}

// MARK: - Business portal

struct Product: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var category: String
    var description: String
    var price: Decimal
    var photoData: Data? = nil
}

struct OpeningDay: Identifiable, Hashable, Sendable {
    let id = UUID()
    var weekday: String
    var isOpen: Bool
    var opens: Date
    var closes: Date

    static func time(_ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: hour, minute: minute)) ?? .now
    }

    static var defaultWeek: [OpeningDay] {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].enumerated().map { index, day in
            OpeningDay(weekday: day, isOpen: index < 5, opens: time(9), closes: time(18))
        }
    }
}

struct BusinessInfo: Hashable, Sendable {
    var name: String
    var type: String
    var url: String
    var description: String
    var phone: String
    var email: String
    var address: String
    var mapsLink: String
    var hours: [OpeningDay]
}

enum DeployResult: String, Sendable { case succeeded = "Succeeded", failed = "Failed" }

struct Deploy: Identifiable, Hashable, Sendable {
    var id: Int { number }
    var number: Int
    var date: Date
    var result: DeployResult
    var duration: String
    var startedBy: String
    var liveFor: String
}

enum ActivityKind: String, Sendable { case deploy = "Deploy", product = "Product", businessInfo = "Business info" }

struct ActivityItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    var title: String
    var detail: String?
    var kind: ActivityKind
    var date: Date
    var isFailure: Bool
}

struct MonitorSnapshot: Sendable {
    var websiteURL: String
    var isOnline: Bool
    var uptime: String
    var deploySuccess: String
    var lastDeployText: String
    var lastDeployDetail: String
    var lastSevenResults: [DeployResult]     // oldest to latest
    var resetsOn: String                     // "1 Nov"
    var productsUsed: Int
    var redeploysUsed: Int
    var websitesUsed: Int
    var succeededCount: Int
    var failedCount: Int
    var deploys: [Deploy]
    var activity: [ActivityItem]

    var totalDeploys: Int { succeededCount + failedCount }
}

// MARK: - Helpers

extension Date {
    static func on(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .now
    }
}

extension Decimal {
    var currencyText: String { formatted(.currency(code: "USD")) }
}
