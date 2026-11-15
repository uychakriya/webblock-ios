import SwiftUI
import Observation

enum LoadState: Equatable {
    case idle, loading, loaded
    case failed(String)
}

struct Toast: Identifiable, Equatable {
    enum Kind { case success, warning, error }
    let id = UUID()
    var kind: Kind = .success
    var title: String
    var message: String
}

/// Session state shared across the whole app.
@MainActor @Observable
final class AppState {
    var user: UserProfile?
    let notifications: NotificationsViewModel

    var isSignedIn: Bool { user != nil }
    /// The signed-in account's plan decides the limits shown on the Monitor page.
    var plan: PlanTier { user?.plan ?? .freeTrial }

    init(service: WebBlockService = ServiceLocator.current) {
        notifications = NotificationsViewModel(service: service)
    }

    func signedIn(_ profile: UserProfile) { user = profile }

    func signOut() {
        user = nil
        notifications.reset()
    }
}

@MainActor @Observable
final class NotificationsViewModel {
    var items: [AppNotification] = []
    var state: LoadState = .idle
    var showUnreadOnly = false
    private let service: WebBlockService

    init(service: WebBlockService = ServiceLocator.current) { self.service = service }

    var unreadCount: Int { items.filter(\.isUnread).count }
    var visible: [AppNotification] { showUnreadOnly ? items.filter(\.isUnread) : items }

    func load() async {
        state = .loading
        do {
            items = try await service.notifications()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func markAllRead() async {
        try? await service.markAllNotificationsRead()
        for index in items.indices { items[index].isUnread = false }
    }

    func reset() {
        items = []; state = .idle; showUnreadOnly = false
    }
}
