import SwiftUI

/// After sign-in the app lists all the owner's live websites. Selecting one opens its
/// portal (Products · Business information · Monitor); the toolbar returns to the list.
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var model = HomeViewModel()

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading:
                LoadingView(text: "Loading your website…")
                    .frame(maxHeight: .infinity)
                    .liquidBackdrop()
            case .failed(let message):
                NavigationStack {
                    ErrorStateView(message: message) { Task { await model.load() } }
                        .liquidBackdrop()
                        .navigationTitle("WebBlock")
                        .portalToolbar()
                }
            case .loaded:
                if let site = model.selected {
                    PortalTabs(website: site).id(site.id)
                } else if model.liveSites.isEmpty {
                    NoLiveWebsiteView { Task { await model.load() } }
                } else {
                    WebsiteListView()
                }
            }
        }
        .environment(model)
        .task {
            // Load the websites and the notifications at the same time instead of one after the other.
            async let notificationsLoaded: Void = appState.notifications.load()
            await model.load()
            await notificationsLoaded
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

    @Environment(HomeViewModel.self) private var home
    @State private var keyboard = KeyboardWatcher()

    var body: some View {
        @Bindable var home = home
        TabView(selection: $home.selectedTab) {
            NavigationStack { ProductsView(model: products) }
                .toolbar(.hidden, for: .tabBar)
                .tag(PortalTab.products)
            NavigationStack { BusinessInfoView(model: info) }
                .toolbar(.hidden, for: .tabBar)
                .tag(PortalTab.info)
            NavigationStack { MonitorView(model: monitor) }
                .toolbar(.hidden, for: .tabBar)
                .tag(PortalTab.monitor)
        }
        .animation(.easeOut(duration: 0.12), value: home.selectedTab)   // pages cross-fade as the pill moves
        .contentMargins(.bottom, 84, for: .scrollContent)      // lets the last items scroll clear of the dock
        .noBottomScrollEdgeEffect()                            // no white fade behind the dock
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // While the keyboard is up (searching, typing) the dock steps out of the way.
            if !keyboard.isVisible && !home.dockHidden {
                GlassDock(selection: $home.selectedTab)
                    .transition(.opacity)
            }
        }
        .environment(keyboard)
        .animation(.easeInOut(duration: 0.2), value: keyboard.isVisible)
        .animation(.easeInOut(duration: 0.2), value: home.dockHidden)
    }
}

// MARK: - Live websites list (landing screen after sign-in)

/// Shown right after sign-in: every live website the owner can manage.
/// Tapping one opens its portal (Products · Business information · Monitor).
struct WebsiteListView: View {
    @Environment(HomeViewModel.self) private var home
    @Environment(AppState.self) private var appState

    private var firstName: String {
        appState.user?.fullName.split(separator: " ").first.map(String.init) ?? ""
    }

    private var workspaceChip: some View {
        Label("Your Workspace", systemImage: "sparkles")
            .wbFont(12, .semibold).foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.white.opacity(0.18), in: Capsule())
    }

    /// "Welcome back" card on the blue header: workspace chip and live-website count on top, then the greeting.
    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            // Chip and live count share a row when they fit; with large text they stack.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center) {
                    workspaceChip.fixedSize()
                    Spacer(minLength: Space.xs)
                    liveCount
                }
                VStack(alignment: .leading, spacing: Space.xs) {
                    workspaceChip
                    liveCount
                }
            }
            Text("Welcome back, \(firstName)!").wbFont(24, .bold).foregroundStyle(.white)
                .minimumScaleFactor(0.8).lineLimit(2)
            Text("Choose a website to manage its products, business information and monitor.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: 0x4F86DD), Color(hex: 0x3A6CCB)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color(hex: 0x1F3C7A).opacity(0.22), radius: 16, y: 8)
        .accessibilityElement(children: .contain)
    }

    /// Small "4 Live websites" badge at the top right of the welcome card.
    private var liveCount: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe").wbFont(12, .semibold).foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(LinearGradient(colors: [Color(hex: 0x6C9BEA), Color(hex: 0x3F72D0)], startPoint: .top, endPoint: .bottom), in: Circle())
            Text("\(home.liveSites.count)").wbFont(16, .bold).foregroundStyle(.wbText)
            Text("Live").wbFont(12).foregroundStyle(.wbMuted)
        }
        .padding(.leading, 5).padding(.trailing, 12).padding(.vertical, 5)
        .background(Color.wbCard, in: Capsule())
        .overlay(Capsule().stroke(Color.wbBrand.opacity(0.12), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(home.liveSites.count) live websites")
    }

    var body: some View {
        NavigationStack {
            // The header and the welcome card stay put; only the list of websites scrolls underneath.
            VStack(alignment: .leading, spacing: Space.l) {
                VStack(alignment: .leading, spacing: Space.l) {
                    // Header: your full logo on the left, bell + profile on the right.
                    HStack(alignment: .center) {
                        BrandLogo(height: 44)
                        Spacer()
                        AccountButtons()
                    }
                    .padding(.top, Space.xs)
                    welcomeCard
                }
                .padding(.horizontal, Space.screen).padding(.top, Space.xs)

                ScrollView {
                    VStack(alignment: .leading, spacing: Space.s) {
                        LazyVStack(spacing: Space.m) {
                            ForEach(Array(home.liveSites.enumerated()), id: \.element.id) { index, site in
                                WebsiteCard(site: site, open: { tab in home.select(site); home.selectedTab = tab })
                                    .appearAnimated(index: index)
                            }
                        }
                    }
                    .padding(.horizontal, Space.screen).padding(.top, Space.xs).padding(.bottom, Space.l)
                }
                .scrollIndicators(.hidden)
                .refreshable { await home.load() }
            }
            .background { TileBackdrop() }
            .navigationTitle("Your websites")
            .portalToolbar(hero: true)
        }
    }
}

/// The website's logo, or a gradient initials tile when it has none.
struct WebsiteLogo: View {
    let site: Website
    var size: CGFloat = 56

    var body: some View {
        let shape = Circle()
        Group {
            if let logo = site.logoAsset {
                Image(logo).resizable().scaledToFill()
            } else {
                Text(site.initials)
                    .font(.headline.weight(.bold)).foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(LinearGradient(colors: [Color(hex: 0x4F86DD), Color(hex: 0x3A6CCB)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.stroke(.wbBorder, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// One live website: logo, name and type, its address, and shortcuts into each portal tab.
struct WebsiteCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let site: Website
    let open: (PortalTab) -> Void
    @State private var opening = false

    /// Shows the blue arrow reacting to the tap for a moment, then opens the portal.
    private func openWithArrow() {
        guard !opening else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { opening = true }
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            open(.products)
            opening = false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            // Tapping the top of the card shows the arrow, then opens the portal on Products.
            Button { openWithArrow() } label: {
                VStack(alignment: .leading, spacing: Space.s) {
                    HStack(spacing: Space.s) {
                        WebsiteLogo(site: site, size: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(site.name).font(.headline).foregroundStyle(.wbText).lineLimit(2)
                            Text(site.businessType).font(.subheadline).foregroundStyle(.wbMuted).lineLimit(1)
                            if typeSize.isAccessibilitySize {
                                Pill(text: "Live", symbol: "circle.fill", tint: .wbGreen, background: .wbGreenSoft)
                            }
                        }
                        .layoutPriority(1)
                        Spacer(minLength: Space.xs)
                        if !typeSize.isAccessibilitySize {
                            Pill(text: "Live", symbol: "circle.fill", tint: .wbGreen, background: .wbGreenSoft)
                        }
                        Image(systemName: "arrow.right")
                            .wbFont(14, .bold)
                            .foregroundStyle(opening ? Color.white : Color.wbBrand)
                            .frame(width: 36, height: 36)
                            .background(opening ? Color.wbBrand : Color.wbCard, in: Circle())
                            .overlay(Circle().strokeBorder(Color.wbBrand.opacity(0.15), lineWidth: 1))
                            .shadow(color: Color.wbBrand.opacity(opening ? 0.35 : 0.08), radius: opening ? 8 : 4, y: 2)
                            .offset(x: opening ? 4 : 0)
                            .scaleEffect(opening ? 1.12 : 1)
                    }

                    if let url = site.url {
                        HStack(spacing: 6) {
                            Image(systemName: "link").font(.caption.weight(.semibold))
                            Text(url).font(.footnote).lineLimit(1).truncationMode(.middle)
                        }
                        .foregroundStyle(.wbBrand)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.wbBrandSoft.opacity(0.6), in: Capsule())
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.wbCardPress)
            .accessibilityHint("Opens the business portal for \(site.name)")

            Divider()

            // Shortcuts straight to each tab.
            HStack(spacing: Space.xs) {
                shortcut("shippingbox", "Products", .products)
                shortcut("storefront", "Business", .info)
                shortcut("waveform.path.ecg", "Monitor", .monitor)
            }
        }
        .wbCard(padding: Space.m)
        .shadow(color: Color(hex: 0x1F3C7A).opacity(0.06), radius: 12, y: 6)
    }

    private func shortcut(_ symbol: String, _ title: String, _ tab: PortalTab) -> some View {
        Button { open(tab) } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).wbFont(16, .semibold)
                Text(title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(.wbBrand)
            .frame(maxWidth: .infinity).frame(height: 54)
            .glassFace(in: RoundedRectangle(cornerRadius: 14, style: .continuous), tint: .wbBrandSoft)
        }
        .buttonStyle(.wbCardPress)
        .accessibilityLabel("Open \(title) for \(site.name)")
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
            .liquidBackdrop()
            .navigationTitle("WebBlock")
            .portalToolbar()
        }
    }
}

// MARK: - Site card (current website + switcher), shared by the three portal tabs

struct SiteHeaderCard: View {
    @Environment(HomeViewModel.self) private var home
    @State private var expanded = false
    @State private var switchingID: Website.ID?      // the row whose arrow is lit blue before navigating

    var body: some View {
        if let site = home.selected {
            let others = home.liveSites.filter { $0.id != site.id }
            let multiple = !others.isEmpty
            let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
            VStack(spacing: 0) {
                // Current website
                Button {
                    guard multiple else { return }
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { expanded.toggle() }
                } label: {
                    HStack(spacing: Space.s) {
                        WebsiteLogo(site: site, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.name).font(.headline).foregroundStyle(.wbText).lineLimit(2)
                            // Live status and address on one quiet line.
                            HStack(spacing: 6) {
                                Circle().fill(Color.wbGreen).frame(width: 7, height: 7)
                                Text("Live").font(.footnote.weight(.semibold)).foregroundStyle(Color.wbGreen)
                                    .fixedSize()
                                if let url = site.url, !url.isEmpty {
                                    Text("·").font(.footnote).foregroundStyle(.wbMuted)
                                    Text(url).font(.footnote).foregroundStyle(.wbMuted)
                                        .lineLimit(1).truncationMode(.middle)
                                }
                            }
                        }
                        .layoutPriority(1)
                        Spacer(minLength: Space.xs)
                        if multiple {
                            Image(systemName: expanded ? "chevron.up" : "chevron.up.chevron.down")
                                .font(.footnote.weight(.semibold)).foregroundStyle(.wbBrand)
                                .frame(width: 32, height: 32)
                                .background(Color.wbBrand.opacity(expanded ? 0.16 : 0.08), in: Circle())
                        }
                    }
                    .padding(Space.s)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(multiple ? "Website: \(site.name), live. Switch website" : "Website: \(site.name), live")
                .accessibilityValue(multiple ? (expanded ? "Expanded" : "Collapsed") : "")

                // All websites: the current one is highlighted and ticked, the others switch on tap
                if expanded && multiple {
                    Divider().padding(.horizontal, Space.s)
                    VStack(spacing: Space.xs) {
                        ForEach(home.liveSites) { option in
                            row(option, current: option.id == site.id)
                        }
                    }
                    .padding(Space.s)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .clipShape(shape)
            .whiteCard(cornerRadius: 20)          // same shape as the product cards
            .overlay(shape.strokeBorder(Color.wbBrand.opacity(0.35), lineWidth: 1.2))   // soft blue border
            .animation(.easeInOut(duration: 0.2), value: expanded)
        }
    }

    /// One website in the open list. Switching keeps you on the same tab; the current one just closes the list.
    private func row(_ option: Website, current: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button {
            guard switchingID == nil else { return }
            if current { withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { expanded = false }; return }
            switchingID = option.id
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { expanded = false }
            home.open(websiteID: option.id, tab: home.selectedTab)
            switchingID = nil
        } label: {
            HStack(spacing: Space.s) {
                WebsiteLogo(site: option, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name).font(.subheadline.weight(.semibold)).foregroundStyle(.wbText).lineLimit(1)
                    Text(option.url ?? "").font(.footnote).foregroundStyle(.wbMuted).lineLimit(1)
                }
                Spacer(minLength: 0)
                if current {
                    Image(systemName: "checkmark").wbFont(15, .semibold).foregroundStyle(Color.wbBrand)
                }
            }
            .padding(.horizontal, Space.s).padding(.vertical, 10)
            .background(current ? Color.wbBrand.opacity(0.10) : Color.wbCard, in: shape)
            .overlay(shape.strokeBorder(Color.wbBrand.opacity(current ? 0 : 0.08), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(current ? "\(option.name), current website" : "Switch to \(option.name)")
        .accessibilityAddTraits(current ? .isSelected : [])
    }
}

// MARK: - Bell + profile (top right of every page)

extension ToolbarContent {
    /// Drops the system glass capsule (iOS 26) so our own padded pill isn't clamped to the nav-bar height.
    @ToolbarContentBuilder
    func hidingSharedBackground() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

struct PortalToolbar: ViewModifier {
    /// The blue "Welcome" page draws its own header (full logo + these buttons), so it adds no bar items.
    var hero = false
    /// When set, the back button runs this (e.g. leave an edit form) instead of returning to the websites list.
    var onBack: (() -> Void)?
    @Environment(AppState.self) private var appState
    @Environment(HomeViewModel.self) private var home

    /// Name of the portal tab being shown, used in place of the greeting inside a website.
    private var tabTitle: String {
        switch home.selectedTab {
        case .products: "Products"
        case .info: "Business info"
        case .monitor: "Monitor"
        }
    }

    func body(content: Content) -> some View {
        if hero {
            content.toolbar(.hidden, for: .navigationBar)
        } else {
            content
                .toolbar {
                    // The collapsed (inline) title would collide with the greeting, so keep that slot empty;
                    // the large title still shows under the bar.
                    ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }

                    // Inside a website's portal, offer a way back to the list of all live websites.
                    if home.selected != nil {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { if let onBack { onBack() } else { home.backToList() } } label: {
                                Label("Websites", systemImage: "chevron.left")
                            }
                            .accessibilityLabel(onBack == nil && !home.canGoBackToPreviousSite ? "Back to your websites" : "Back")
                        }
                    }

                    // Left: inside a website, its name + the current tab; otherwise the greeting.
                    // Right: notification bell + profile avatar.
                    ToolbarItem(placement: .topBarLeading) {
                        if home.selected != nil {
                            // Inside a website the label next to the back arrow simply says "Websites".
                            Button { if let onBack { onBack() } else { home.backToList() } } label: {
                                Text("Websites").font(.dm(17, 600)).foregroundStyle(.wbText).fixedSize()
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Back to your websites")
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Hello 👋").font(.caption).foregroundStyle(.wbMuted).lineLimit(1)
                                Text(appState.user?.fullName ?? "").font(.subheadline.weight(.bold))
                                    .foregroundStyle(.wbText).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .hidingSharedBackground()

                    ToolbarItem(placement: .topBarTrailing) { AccountButtons() }
                        .hidingSharedBackground()
                }
        }
    }
}

/// Notification bell + profile avatar (with the account menu, intro replay and log-out confirmation).
/// Solid white circles with blue icons on every page, including the blue welcome page.
struct AccountButtons: View {
    /// `true` on the blue welcome page: both buttons sit together in one white capsule.
    var grouped = false
    @Environment(AppState.self) private var appState
    @State private var showNotifications = false
    @State private var confirmLogout = false
    @State private var showIntro = false
    @State private var showAccountMenu = false

    var body: some View {
        HStack(spacing: grouped ? 4 : 12) {
            Button { showNotifications = true } label: {
                // Just the bell, no circle behind it; a red count badge shows how many notifications are waiting.
                Image(systemName: "bell").font(.title3).foregroundStyle(Color(hex: 0x3F72D0))
                    .frame(width: 44, height: 44)
                    .overlay(alignment: .topTrailing) {
                        let count = appState.notifications.unreadCount
                        if count > 0 {
                            Text(count > 99 ? "99+" : "\(count)")
                                .wbFont(11, .bold).foregroundStyle(.white)
                                .padding(.horizontal, 5).frame(minWidth: 18, minHeight: 18)
                                .background(Color.wbRed, in: Capsule())
                                .overlay(Capsule().stroke(.white, lineWidth: 1.5))
                                .offset(x: -2, y: 2)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.wbCardPress)
            .accessibilityLabel("Notifications, \(appState.notifications.unreadCount) unread")

            Button { showAccountMenu = true } label: {
                Text(appState.user?.initials ?? "?").wbFont(14, .bold)
                    .foregroundStyle(Color(hex: 0x3F72D0))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: 0xE6EEFB), in: Circle())
                    .frame(width: 44, height: 44)
                    .modifier(WhiteCircle(plain: grouped))
            }
            .buttonStyle(.wbCardPress)
            .popover(isPresented: $showAccountMenu, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    // Who is signed in
                    HStack(spacing: Space.s) {
                        AvatarView(initials: appState.user?.initials ?? "?", size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.user?.fullName ?? "").wbFont(14, .semibold)
                                .foregroundStyle(.wbText).lineLimit(1)
                            Text(appState.user?.email ?? "").wbFont(11)
                                .foregroundStyle(.wbMuted).lineLimit(1)
                            if let plan = appState.user?.plan {
                                Text(plan.title).wbFont(10, .bold).foregroundStyle(.wbBrand)
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(Color.wbBrandSoft, in: Capsule())
                                    .padding(.top, 2)
                            }
                        }
                    }
                    .padding(.horizontal, Space.s).padding(.vertical, Space.s)

                    Divider()

                    VStack(spacing: 2) {
                        accountRow("Replay intro", symbol: "play.fill", tint: .wbText, iconTint: .wbBrand) {
                            showAccountMenu = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { showIntro = true }
                        }
                        accountRow("Log out", symbol: "rectangle.portrait.and.arrow.right", tint: .wbRed) {
                            showAccountMenu = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { confirmLogout = true }
                        }
                    }
                    .padding(Space.xs)
                }
                .frame(width: 240)
                .presentationCompactAdaptation(.popover)
            }
            .accessibilityLabel("Account: \(appState.user?.fullName ?? "")")
            .accessibilityHint("Opens the account menu")
        }
        .padding(grouped ? 6 : 0)
        .background { if grouped { Capsule().fill(Color.white) } }
        .overlay { if grouped { Capsule().stroke(Color(hex: 0x3F72D0).opacity(0.12), lineWidth: 1) } }
        .shadow(color: Color(hex: 0x1F3C7A).opacity(grouped ? 0.18 : 0), radius: 10, y: 4)
        .fullScreenCover(isPresented: $showIntro) { OnboardingView { showIntro = false } }
        .fullScreenCover(isPresented: $showNotifications) { NotificationsSheet(model: appState.notifications) }
        .alert("Log out of WebBlock?", isPresented: $confirmLogout) {
            Button("Log out", role: .destructive) { appState.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Signed in as \(appState.user?.email ?? "your account").\nYou’ll need to sign in again to manage and publish your websites.")
        }
    }

    /// A menu row: a soft tinted circle with the icon on the left, then the title.
    private func accountRow(_ title: String, symbol: String, tint: Color, iconTint: Color? = nil, action: @escaping () -> Void) -> some View {
        let iconTint = iconTint ?? tint
        return Button(action: action) {
            HStack(spacing: 12) {
                // Same-size soft circle for every row, so the icons line up in one column.
                Image(systemName: symbol).wbFont(11, .semibold).foregroundStyle(iconTint)
                    .frame(width: 30, height: 30)
                    .background(iconTint.opacity(0.12), in: Circle())
                Text(title).wbFont(16).foregroundStyle(tint)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.xs).frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// White glass circle with a soft blue rim; always light, so dark bars or dark mode never turn it black.
private struct WhiteCircle: ViewModifier {
    /// Inside the grouped capsule the circle needs no rim or shadow of its own.
    var plain = false
    func body(content: Content) -> some View {
        content
            // White glass. Forced to the light appearance so a dark bar or dark mode can't turn it black.
            .liquidGlass(in: Circle(), tint: .white.opacity(0.6), interactive: true)
            .environment(\.colorScheme, .light)
            .overlay(Circle().stroke(Color(hex: 0x3F72D0).opacity(plain ? 0 : 0.15), lineWidth: 1))
            .contentShape(Circle())
    }
}

extension View {
    func portalToolbar(hero: Bool = false, onBack: (() -> Void)? = nil) -> some View { modifier(PortalToolbar(hero: hero, onBack: onBack)) }
}

// MARK: - Notifications

/// Logo of the website a notification belongs to, with an unread dot on its corner.
struct NotificationAvatar: View {
    let item: AppNotification
    var showsDot = true
    private let size: CGFloat = 48

    var body: some View {
        let shape = Circle()
        Group {
            if let logo = item.logoAsset {
                Image(logo).resizable().scaledToFill()
            } else if item.isFromWebBlock {
                Image(systemName: "bell.fill").wbFont(18, .semibold).foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(LinearGradient(colors: [Color(hex: 0x4F86DD), Color(hex: 0x3A6CCB)], startPoint: .topLeading, endPoint: .bottomTrailing))
            } else {
                Text(item.initials).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(LinearGradient(colors: [Color(hex: 0x4F86DD), Color(hex: 0x3A6CCB)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.stroke(.wbBorder, lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            Circle().fill(Color.wbBrand).frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.wbCard, lineWidth: 2))
                .scaleEffect(item.isUnread && showsDot ? 1 : 0)
                .opacity(item.isUnread && showsDot ? 1 : 0)
                .offset(x: 4, y: -4)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: item.isUnread)
        }
        .accessibilityHidden(true)
    }
}

struct NotificationsSheet: View {
    @Bindable var model: NotificationsViewModel
    @Environment(HomeViewModel.self) private var home
    @Environment(\.dismiss) private var dismiss
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                // Pinned header: the title and the All / Unread switch stay put while the list scrolls.
                Text("Notifications")
                    .font(.system(size: 26, weight: .bold)).foregroundStyle(.wbBrand)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Space.screen).padding(.top, Space.xxs)
                    .accessibilityAddTraits(.isHeader)
                WBSegmented(options: [("All", false), ("Unread \(model.unreadCount)", true)],
                            selection: $model.showUnreadOnly)
                    .padding(Space.screen)

                if model.visible.isEmpty {
                    WBEmptyState(symbol: "bell.slash.fill",
                                 title: "You’re all caught up",
                                 message: model.showUnreadOnly ? "No unread notifications. Everything new will appear here."
                                                               : "New notifications will appear here.")
                } else {
                    ScrollView {
                        let fresh = model.visible.filter(\.isUnread)
                        let earlier = model.visible.filter { !$0.isUnread }
                        VStack(alignment: .leading, spacing: Space.l) {
                            if !fresh.isEmpty {
                                VStack(alignment: .leading, spacing: Space.s) {
                                    sectionHeader("New", count: fresh.count)
                                    ForEach(fresh) { item in
                                        Button { tap(item) } label: { row(item) }
                                            .buttonStyle(.wbCardPress)
                                            .background(Color.wbBrandSoft.opacity(0.7), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Color.wbBrand.opacity(0.12), lineWidth: 1))
                                    }
                                }
                            }
                            if !earlier.isEmpty {
                                VStack(alignment: .leading, spacing: Space.s) {
                                    sectionHeader("Earlier", count: nil)
                                    VStack(spacing: 0) {
                                        ForEach(Array(earlier.enumerated()), id: \.element.id) { index, item in
                                            Button { tap(item) } label: { row(item) }
                                                .buttonStyle(.wbCardPress)
                                            if index < earlier.count - 1 {
                                                Divider().padding(.leading, 48 + Space.s + Space.s)
                                            }
                                        }
                                    }
                                    .background(Color.wbCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Color.wbBrand.opacity(0.10), lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, Space.screen).padding(.bottom, Space.l)
                    }
                }
            }
            .liquidBackdrop()
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                if let item = model.items.first(where: { $0.id == id }) {
                    NotificationDetailView(item: item) { open(item) }
                        .onAppear { model.markRead(id) }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close notifications")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mark all as read") { Task { await model.markAllRead() } }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int?) -> some View {
        HStack(spacing: Space.xs) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.wbMuted)
            if let count {
                Text("\(count)").font(.caption.weight(.bold)).foregroundStyle(.wbBrand)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.wbBrandSoft, in: Capsule())
            }
        }
    }

    private func row(_ item: AppNotification) -> some View {
        HStack(alignment: .top, spacing: Space.s) {
            NotificationAvatar(item: item, showsDot: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.source).font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
                Text(item.message).font(.subheadline).foregroundStyle(.wbMuted).multilineTextAlignment(.leading)
            }
            Spacer(minLength: Space.xs)
            VStack(alignment: .trailing, spacing: 8) {
                Text(item.timeText).font(.caption).foregroundStyle(item.isUnread ? Color.wbBrand : Color.wbMuted)   // SAMPLE timestamps
                if item.isUnread { Circle().fill(Color.wbBrand).frame(width: 9, height: 9) }
            }
        }
        .padding(Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.isUnread ? "Unread" : "")
        .accessibilityHint("Opens the notification")
    }

    /// Tapping opens the notification's own page. Its button then jumps to the related data.
    private func tap(_ item: AppNotification) {
        model.markRead(item.id)
        path.append(item.id)
    }

    /// Closes the full-screen list and jumps to the website and tab the notification is about.
    private func open(_ item: AppNotification) {
        guard let id = item.websiteID, let tab = item.tab else { return }
        dismiss()
        home.open(websiteID: id, tab: tab)
    }
}

/// One notification's own page: what happened, the message, the activity, and a shortcut to the related data.
struct NotificationDetailView: View {
    let item: AppNotification
    let open: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                // Header card
                VStack(alignment: .leading, spacing: Space.m) {
                    HStack(spacing: Space.s) {
                        NotificationAvatar(item: item, showsDot: false)
                        Text(item.source).font(.subheadline.weight(.medium)).foregroundStyle(.wbMuted)
                    }
                    Text(item.message).font(.title2.bold()).foregroundStyle(.wbText)
                    HStack(spacing: Space.s) {
                        Pill(text: item.isUnread ? "New" : "Read", symbol: item.isUnread ? "circle.fill" : "checkmark.circle.fill",
                             tint: item.isUnread ? .wbBrand : .wbGreen,
                             background: item.isUnread ? .wbBrandSoft : Color.wbGreen.opacity(0.15))
                        Label(item.timeText, systemImage: "clock").font(.subheadline).foregroundStyle(.wbMuted)
                    }
                }
                .wbCard()

                // Message card
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Message").font(.subheadline.weight(.semibold)).foregroundStyle(.wbMuted)
                    Text(item.detail.isEmpty ? item.message : item.detail).font(.body).foregroundStyle(.wbText)
                }
                .wbCard()

                // Activity card
                VStack(alignment: .leading, spacing: 0) {
                    Text("Activity").font(.subheadline.weight(.semibold)).foregroundStyle(.wbMuted)
                        .padding(.bottom, Space.s)
                    activityRow("bell.fill", tint: .wbBrand, soft: Color.wbBrandSoft,
                                title: "Notification received", subtitle: item.timeText, line: !item.isUnread)
                    if !item.isUnread {
                        activityRow("checkmark", tint: .wbGreen, soft: Color.wbGreen.opacity(0.15),
                                    title: "Marked as read", subtitle: "When you opened it", line: false)
                    }
                }
                .wbCard()

                if let actionTitle = item.actionTitle {
                    Button(actionTitle, action: open).buttonStyle(.wbPrimary)
                }
            }
            .padding(.horizontal, Space.screen).padding(.vertical, Space.xs)
        }
        .background { TileBackdrop() }
        .navigationTitle("Notification")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func activityRow(_ symbol: String, tint: Color, soft: Color, title: String, subtitle: String, line: Bool) -> some View {
        HStack(alignment: .top, spacing: Space.s) {
            VStack(spacing: 0) {
                Image(systemName: symbol).wbFont(14, .semibold).foregroundStyle(tint)
                    .frame(width: 40, height: 40).background(soft, in: Circle())
                if line { Rectangle().fill(Color.wbBorder).frame(width: 2, height: 18) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
                Text(subtitle).font(.subheadline).foregroundStyle(.wbMuted)
            }
            .padding(.top, 2)
            Spacer(minLength: 0)
        }
    }
}

private extension View {
    /// iOS 26 draws a soft white fade at the bottom of scroll views, under floating bars. Hide it.
    @ViewBuilder func noBottomScrollEdgeEffect() -> some View {
        if #available(iOS 26, *) {
            self.scrollEdgeEffectHidden(true, for: .bottom)
        } else {
            self
        }
    }
}
