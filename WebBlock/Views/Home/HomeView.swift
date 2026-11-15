import SwiftUI

/// After sign-in the app shows the owner's live website and its three portal pages.
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var model = HomeViewModel()

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading:
                LoadingView(text: "Loading your website…")
                    .frame(maxHeight: .infinity)
                    .background(.wbBackground)
            case .failed(let message):
                NavigationStack {
                    ErrorStateView(message: message) { Task { await model.load() } }
                        .background(.wbBackground)
                        .navigationTitle("WebBlock")
                        .portalToolbar()
                }
            case .loaded:
                if let site = model.selected {
                    PortalTabs(website: site).id(site.id)
                } else {
                    NoLiveWebsiteView { Task { await model.load() } }
                }
            }
        }
        .environment(model)
        .task {
            await model.load()
            await appState.notifications.load()
        }
    }
}

// MARK: - Tabs: Products · Business information · Monitor

struct PortalTabs: View {
    @State private var products: ProductsViewModel
    @State private var info: BusinessInfoViewModel
    @State private var monitor: MonitorViewModel

    init(website: Website) {
        _products = State(initialValue: ProductsViewModel(websiteID: website.id))
        _info = State(initialValue: BusinessInfoViewModel(websiteID: website.id))
        _monitor = State(initialValue: MonitorViewModel(websiteID: website.id))
    }

    var body: some View {
        TabView {
            NavigationStack { ProductsView(model: products) }
                .tabItem { Label("Products", systemImage: "shippingbox") }
            NavigationStack { BusinessInfoView(model: info) }
                .tabItem { Label("Business information", systemImage: "storefront") }
            NavigationStack { MonitorView(model: monitor) }
                .tabItem { Label("Monitor", systemImage: "waveform.path.ecg") }
        }
    }
}

struct NoLiveWebsiteView: View {
    let retry: () -> Void
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("No live website yet", systemImage: "globe")
            } description: {
                Text("Your products, business information and monitor appear here once a website is live. Publish one from the WebBlock website, then pull to refresh.")
            } actions: {
                Button("Refresh", action: retry).buttonStyle(.borderedProminent).tint(.wbBrand)
            }
            .background(.wbBackground)
            .navigationTitle("WebBlock")
            .portalToolbar()
        }
    }
}

// MARK: - Site card (Figma: "PS · Petal & Stem · petalandstem.webblock.com")

struct SiteHeaderCard: View {
    @Environment(HomeViewModel.self) private var home

    var body: some View {
        if let site = home.selected {
            let content = HStack(spacing: Space.s) {
                Text(site.initials)
                    .font(.footnote.weight(.bold)).foregroundStyle(.wbBrand)
                    .frame(width: 38, height: 38)
                    .background(.wbBrandSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(site.name).font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
                    Text(site.url ?? "").font(.caption).foregroundStyle(.wbMuted)
                }
                Spacer()
                Pill(text: "Live", symbol: "globe", tint: .wbGreen, background: .wbGreenSoft)
                if home.liveSites.count > 1 {
                    Image(systemName: "chevron.up.chevron.down").font(.footnote).foregroundStyle(.wbMuted)
                }
            }
            .padding(Space.s)
            .background(Color.wbBrandSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(.wbBorder, lineWidth: 1))

            if home.liveSites.count > 1 {
                Menu {
                    ForEach(home.liveSites) { option in
                        Button { home.select(option) } label: {
                            if option.id == site.id { Label(option.name, systemImage: "checkmark") } else { Text(option.name) }
                        }
                    }
                } label: { content }
                .buttonStyle(.plain)
                .accessibilityLabel("Website: \(site.name). Switch website")
            } else {
                content.accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Bell + profile (top right of every page)

struct PortalToolbar: ViewModifier {
    @Environment(AppState.self) private var appState
    @State private var showNotifications = false
    @State private var confirmLogout = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showNotifications = true } label: {
                        Image(systemName: "bell")
                            .overlay(alignment: .topTrailing) {
                                if appState.notifications.unreadCount > 0 {
                                    Circle().fill(Color.wbRed).frame(width: 9, height: 9).offset(x: 3, y: -2)
                                }
                            }
                    }
                    .accessibilityLabel("Notifications, \(appState.notifications.unreadCount) unread")

                    Button { confirmLogout = true } label: {
                        AvatarView(initials: appState.user?.initials ?? "?", size: 30)
                    }
                    .accessibilityLabel("Account: \(appState.user?.fullName ?? "")")
                    .accessibilityHint("Opens the log out confirmation")
                }
            }
            .sheet(isPresented: $showNotifications) { NotificationsSheet(model: appState.notifications) }
            .alert("Log out of WebBlock?", isPresented: $confirmLogout) {
                Button("Log out", role: .destructive) { appState.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Signed in as \(appState.user?.email ?? "your account").\nYou’ll need to sign in again to manage and publish your websites.")
            }
    }
}

extension View {
    func portalToolbar() -> some View { modifier(PortalToolbar()) }
}

// MARK: - Notifications

struct NotificationsSheet: View {
    @Bindable var model: NotificationsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Show", selection: $model.showUnreadOnly) {
                    Text("All").tag(false)
                    Text("Unread \(model.unreadCount)").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(Space.screen)

                if model.visible.isEmpty {
                    ContentUnavailableView("You’re all caught up", systemImage: "bell.slash",
                                           description: Text("New notifications will appear here."))
                } else {
                    List(model.visible) { item in
                        HStack(alignment: .top, spacing: Space.s) {
                            Circle().fill(item.isUnread ? Color.wbBrand : .clear).frame(width: 8, height: 8).padding(.top, 6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.source).font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
                                Text(item.message).font(.subheadline).foregroundStyle(.wbMuted)
                                Text(item.timeText).font(.caption).foregroundStyle(.wbMuted)   // SAMPLE timestamps
                            }
                        }
                        .listRowBackground(Color.wbCard)
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(item.isUnread ? "Unread" : "")
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(.wbBackground)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mark all as read") { Task { await model.markAllRead() } }
                        .disabled(model.unreadCount == 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
