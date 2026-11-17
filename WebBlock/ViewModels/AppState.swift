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

    private let service: WebBlockService
    private var expiryObserver: NSObjectProtocol?

    init(service: WebBlockService = ServiceLocator.current) {
        self.service = service
        notifications = NotificationsViewModel(service: service)
        // Back to sign-in when the refresh token stops working.
        expiryObserver = NotificationCenter.default.addObserver(forName: .webBlockSessionExpired, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.endSession() }
        }
        // Sign back in from the stored session on launch.
        Task { @MainActor in
            if let profile = await service.restoreSession() { self.user = profile }
        }
    }

    func signedIn(_ profile: UserProfile) { user = profile }

    func signOut() {
        let service = service
        Task { await service.signOut() }
        endSession()
    }

    private func endSession() {
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

    func markRead(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let wasUnread = items[index].isUnread
        items[index].isUnread = false
        if wasUnread {
            let service = service
            Task { await service.markNotificationRead(id: id) }
        }
    }

    func reset() {
        items = []; state = .idle; showUnreadOnly = false
    }
}
