import SwiftUI
import Observation

/// Loads the owner's websites and keeps only the live ones, which are the only ones with a portal.
@MainActor @Observable
final class HomeViewModel {
    var state: LoadState = .idle
    var liveSites: [Website] = []
    var selected: Website?

    private let service: WebBlockService
    init(service: WebBlockService = ServiceLocator.current) { self.service = service }

    func load() async {
        state = .loading
        do {
            liveSites = try await service.websites().filter(\.isLive)
            if let current = selected, let kept = liveSites.first(where: { $0.id == current.id }) {
                selected = kept
            } else {
                selected = liveSites.first
            }
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func select(_ site: Website) { selected = site }
}
