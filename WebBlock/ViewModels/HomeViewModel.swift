import SwiftUI
import Observation

/// Loads the owner's websites and keeps only the live ones, which are the only ones with a portal.
@MainActor @Observable
final class HomeViewModel {
    var state: LoadState = .idle
    var liveSites: [Website] = []
    var selected: Website?
    /// Which tab of the portal is showing. Kept here so a notification can jump straight to one.
    var selectedTab: PortalTab = .products
    /// True while a full-screen detail (e.g. a product) is open, so the bottom tab dock steps out of the way.
    var dockHidden = false
    /// Websites the owner switched away from, most recent last. Back steps through these before the list.
    private(set) var history: [Website] = []
    /// True when Back goes to an earlier website rather than the list of all websites.
    var canGoBackToPreviousSite: Bool { !history.isEmpty }

    private let service: WebBlockService
    init(service: WebBlockService = ServiceLocator.current) { self.service = service }

    func load() async {
        state = .loading
        do {
            liveSites = try await service.websites().filter(\.isLive)
            // Land on the website list after sign-in. Only keep a selection if the owner
            // was already inside a site that is still live (e.g. after a refresh).
            if let current = selected, let kept = liveSites.first(where: { $0.id == current.id }) {
                selected = kept
            } else {
                selected = nil
            }
            // Forget websites that are no longer live (and the whole trail if we're back on the list).
            history = selected == nil ? [] : history.compactMap { old in liveSites.first { $0.id == old.id } }
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Opens a website from the list of all websites: a fresh start, so Back returns to the list.
    func select(_ site: Website) { history = []; selectedTab = .products; selected = site }

    /// Opens a live website's portal on a specific tab. Returns false if that website isn't live.
    @discardableResult
    func open(websiteID: UUID, tab: PortalTab) -> Bool {
        guard let site = liveSites.first(where: { $0.id == websiteID }) else { return false }
        if let current = selected, current.id != site.id {
            history.removeAll { $0.id == site.id }      // no loops: each website appears once in the trail
            history.append(current)
        }
        selected = site
        selectedTab = tab
        return true
    }
    /// Back: returns to the website you were on before switching, keeping the same tab.
    /// With no earlier website, returns to the list of all live websites.
    func backToList() {
        if let previous = history.popLast() {
            selected = previous
        } else {
            selected = nil
        }
    }
}
