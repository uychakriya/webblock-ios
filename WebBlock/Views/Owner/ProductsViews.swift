import SwiftUI
import PhotosUI

// MARK: - Products tab

struct ProductsView: View {
    @Bindable var model: ProductsViewModel
    @Environment(HomeViewModel.self) private var home
    @Environment(KeyboardWatcher.self) private var keyboard
    private let columns = [GridItem(.flexible(), spacing: Space.s, alignment: .top),
                           GridItem(.flexible(), spacing: Space.s, alignment: .top)]
    @FocusState private var searching: Bool
    @State private var showFilters = true          // the filter button shows / hides the chips and the summary row

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                // Which website you're editing, then search and filters, then the catalog.
                SiteHeaderCard().appearAnimated()

                searchBar

                if showFilters {
                    VStack(alignment: .leading, spacing: Space.s) {
                        CategoryChips(model: model)

                        HStack(alignment: .center) {
                            Text(model.summary)
                                .font(.footnote.weight(.medium)).foregroundStyle(.wbMuted)
                            Spacer(minLength: Space.s)
                            Picker("Layout", selection: $model.layout) {
                                Image(systemName: "square.grid.2x2").accessibilityLabel("Grid").tag(ProductLayout.grid)
                                Image(systemName: "list.bullet").accessibilityLabel("List").tag(ProductLayout.list)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 96)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                StateContainer(state: model.state, retry: { Task { await model.load() } }) {
                    if model.filtered.isEmpty {
                        WBEmptyState(symbol: "shippingbox.fill",
                                     title: model.query.isEmpty ? "No products yet" : "No results",
                                     message: model.query.isEmpty ? "Add your first product to show it on your website." : "Try a different name.",
                                     floats: false)
                            .padding(.vertical, Space.xl)
                    } else if model.layout == .list {
                        // One separate rounded card per product.
                        LazyVStack(spacing: Space.s) {
                            ForEach(Array(model.shown.enumerated()), id: \.element.id) { i, product in
                                ProductRow(product: product, model: model)
                                    .whiteCard(cornerRadius: 24)
                                    .appearAnimated(index: i)
                            }
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: Space.s) {
                            ForEach(Array(model.shown.enumerated()), id: \.element.id) { i, product in
                                ProductTile(product: product, model: model).appearAnimated(index: i)
                            }
                        }
                    }
                    if model.canLoadMore {
                        Button("Show more") { model.visibleCount += model.pageSize }.buttonStyle(.wbSecondaryField)
                    }
                }
            }
            .padding(.horizontal, Space.screen).padding(.top, Space.xs)
            // Room for the floating "Add product" button, so the last row can scroll clear of it.
            .padding(.bottom, Space.l + 50 + Space.m)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { TileBackdrop() }
        .navigationTitle("Products")
        .navigationBarTitleDisplayMode(.large)
        .portalToolbar()
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.category)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.layout)
        .refreshable { await model.load() }
        .task { if model.products.isEmpty { await model.load() } }
        .overlay(alignment: .bottomTrailing) {
            if !keyboard.isVisible {
            Button { model.editing = ProductDraft() } label: {
                Label("Add product", systemImage: "plus").font(.body.weight(.semibold))
                    .padding(.horizontal, Space.m).frame(height: 50)
                    .foregroundStyle(.white)
                    .brandFace(in: Capsule())
            }
            .buttonStyle(.wbCardPress)
            .padding(.horizontal, Space.screen)
            .padding(.bottom, 80)           // sits above the glass dock
            .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: keyboard.isVisible)
        .toast($model.toast)
        .navigationDestination(for: Product.self) { product in ProductDetailView(productID: product.id, model: model) }
        .fullScreenCover(item: $model.editing) { draft in ProductFormSheet(model: model, draft: draft) }
        // Same native alert as "Log out of WebBlock?".
        .alert("Delete “\(model.pendingDelete?.name ?? "product")”?",
               isPresented: Binding(get: { model.pendingDelete != nil },
                                    set: { if !$0 { model.pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) { model.pendingDelete = nil }
            Button("Delete", role: .destructive) { Task { await model.confirmDelete() } }
        } message: {
            Text("It will be removed from your website the next time you deploy. This can’t be undone.")
        }
    }
}

extension ProductsView {
    /// Rounded glass search field with a filter button, like the website's product search.
    fileprivate var searchBar: some View {
        HStack(spacing: Space.xs) {
            HStack(spacing: Space.xs) {
                Image(systemName: "magnifyingglass").font(.body.weight(.medium)).foregroundStyle(.wbMuted)
                TextField("Search products", text: $model.query)
                    .focused($searching)
                    .font(.body)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                if !model.query.isEmpty {
                    Button { model.query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.wbMuted.opacity(0.7))
                            .frame(width: 32, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, Space.s)
            .frame(minHeight: 44)
            .fieldSurface(focused: searching)
            .contentShape(Rectangle())
            .onTapGesture { searching = true }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showFilters.toggle() }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(showFilters ? Color.white : Color.wbBrand)
                    .frame(width: 44, height: 44)
                    .background {
                        if showFilters {
                            Circle().fill(Color.wbBrand)
                        }
                    }
                    .fieldSurface(focused: false, filled: !showFilters)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.wbCardPress)
            .sensoryFeedback(.selection, trigger: showFilters)
            .accessibilityLabel(showFilters ? "Hide filters" : "Show filters")
        }
        .animation(.easeInOut(duration: 0.15), value: searching)
    }
}

private extension View {
    /// The surface of the search field and the filter button: a capsule (a circle on the square filter button) with a hairline,
    /// whose border turns brand blue while the field is focused.
    func fieldSurface(focused: Bool, filled: Bool = true) -> some View {
        let shape = Capsule()
        return self
            .background { if filled { shape.fill(Color.wbCard) } }
            .overlay(shape.strokeBorder(focused ? Color.wbBrand : Color.wbBrand.opacity(0.12), lineWidth: focused ? 1.5 : 1))
            .shadow(color: Color(hex: 0x1F3C7A).opacity(0.05), radius: 6, y: 2)
    }
}

/// Category filter, styled like the Overview / Activity switch: a tinted track with a white pill
/// that slides to the category you pick. Scrolls sideways when there are many categories.
private struct CategoryChips: View {
    @Bindable var model: ProductsViewModel
    @Namespace private var pill

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                chip("All", count: model.products.count, on: model.category == nil) { model.category = nil }
                ForEach(model.categories, id: \.self) { name in
                    chip(name, count: nil, on: model.category == name) { model.category = name }
                }
            }
            .padding(4)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .background(Color(hex: 0xE6EFFC), in: Capsule())
    }

    private func chip(_ title: String, count: Int?, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { action() }
        } label: {
            HStack(spacing: 6) {
                Text(title).font(.dm(16, 600)).lineLimit(1)
                if let count {
                    Text("\(count)").font(.caption2.weight(.bold)).monospacedDigit()
                        .foregroundStyle(on ? Color.white : Color(hex: 0x3862B6))
                        .padding(.horizontal, 6).frame(minWidth: 20, minHeight: 20)
                        .background(on ? Color(hex: 0x3862B6) : Color.white, in: Capsule())
                }
            }
            .foregroundStyle(on ? Color(hex: 0x3862B6) : Color(hex: 0x5F6B85))
            .padding(.horizontal, 18).frame(minHeight: 42)
            .background {
                if on {
                    Capsule().fill(Color.white)
                        .shadow(color: Color(hex: 0x1F3C7A).opacity(0.10), radius: 8, y: 3)
                        .matchedGeometryEffect(id: "chip", in: pill)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: on)
    }
}

/// The “…” menu on every product card.
private struct ProductMenu: View {
    let product: Product
    let model: ProductsViewModel
    var body: some View {
        Menu {
            // System menus only draw plain icons, so each one is pre-rendered with a soft tinted circle behind it.
            Button { model.editing = ProductDraft(product) } label: {
                Label { Text("Edit product") } icon: { Image(uiImage: Self.editIcon) }
            }
            Button(role: .destructive) { model.pendingDelete = product } label: {
                Label { Text("Delete product") } icon: { Image(uiImage: Self.trashIcon) }
            }
        } label: {
            Image(systemName: "ellipsis").wbFont(15, .bold).rotationEffect(.degrees(90))
                .foregroundStyle(Color(hex: 0x3A4256)).frame(width: 32, height: 32)
                .frame(width: 44, height: 44).contentShape(Rectangle())   // 44pt touch target
                .padding(-6)                                              // keeps the 32pt layout
        }
        .accessibilityLabel("More actions for \(product.name)")
    }

    static let editIcon = badge("pencil", .systemBlue)
    static let trashIcon = badge("trash", .systemRed)

    /// Icon in its own colour on a light circle of the same colour (not a strong fill).
    private static func badge(_ symbol: String, _ color: UIColor) -> UIImage {
        let side: CGFloat = 30
        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let glyph = UIImage(systemName: symbol, withConfiguration: cfg)!.withTintColor(color, renderingMode: .alwaysOriginal)
        let img = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            color.withAlphaComponent(0.12).setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: side, height: side)).fill()
            let g = glyph.size
            glyph.draw(at: CGPoint(x: (side - g.width) / 2, y: (side - g.height) / 2))
        }
        return img.withRenderingMode(.alwaysOriginal)
    }
}

/// One type scale for every product card, so the grid and the list read the same.
/// System text styles: they follow the owner's text size setting.
private enum ProductType {
    static let name = Font.subheadline.weight(.semibold)     // 15 pt
    static let detail = Font.footnote                         // 13 pt
    static let price = Font.subheadline.weight(.bold)
    static let tag = Font.caption2.weight(.semibold)          // 11 pt
}

/// Card metrics shared by the grid tile and the list row.
private enum ProductCardMetrics {
    static let radius: CGFloat = 20
    static let inset: CGFloat = Space.xs                      // 8 pt around the content
    static let photoRadius: CGFloat = 14                      // nests inside the card's corner
}

/// Small frosted tag showing the product's category, laid over its photo.
private struct CategoryTag: View {
    let text: String
    var body: some View {
        Text(text).font(ProductType.tag).foregroundStyle(Color(hex: 0x14203F)).lineLimit(1)
            .padding(.horizontal, Space.xs).padding(.vertical, Space.xxs)
            .background(.ultraThinMaterial, in: Capsule())
            .background(Color.white.opacity(0.55), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.8), lineWidth: 0.5))
    }
}

/// The description always takes the same number of lines (even when empty), so cards line up.
private func descriptionText(_ text: String, lines: Int) -> some View {
    Text(text.isEmpty ? " " : text)
        .font(ProductType.detail).foregroundStyle(.wbMuted)
        .lineLimit(lines, reservesSpace: true)
        .multilineTextAlignment(.leading)
}

private func priceText(_ product: Product) -> some View {
    Text(product.price.currencyText).font(ProductType.price).foregroundStyle(.wbBrand).monospacedDigit()
}

struct ProductRow: View {
    let product: Product
    let model: ProductsViewModel

    private static let photoSize: CGFloat = 80

    private var subtitle: String {
        [product.category, product.description].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: Space.xs) {
            NavigationLink(value: product) {
                HStack(spacing: Space.s) {
                    ProductPhoto(product: product, size: Self.photoSize, cornerRadius: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name).font(ProductType.name).foregroundStyle(.wbText).lineLimit(1)
                        Text(subtitle.isEmpty ? " " : subtitle)
                            .font(ProductType.detail).foregroundStyle(.wbMuted).lineLimit(1)
                        priceText(product).padding(.top, 2)
                    }
                    Spacer(minLength: Space.xs)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.wbCardPress)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(product.name), \(product.price.currencyText)")
            .accessibilityHint(subtitle)
            ProductMenu(product: product, model: model)
        }
        .padding(.leading, Space.xs).padding(.trailing, Space.xxs)
        .padding(.vertical, Space.xs)
    }
}

struct ProductTile: View {
    let product: Product
    let model: ProductsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: product) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    ProductPhoto(product: product, size: nil, cornerRadius: ProductCardMetrics.photoRadius)
                        .overlay(alignment: .topLeading) { CategoryTag(text: product.category).padding(Space.xs) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name).font(ProductType.name).foregroundStyle(.wbText).lineLimit(1)
                        descriptionText(product.description, lines: 2)
                    }
                    .padding(.horizontal, Space.xxs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.wbCardPress)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(product.name), \(product.price.currencyText)")
            .accessibilityHint(product.description)

            HStack {
                priceText(product)
                Spacer(minLength: 0)
                ProductMenu(product: product, model: model)
            }
            .padding(.leading, Space.xxs)
            .padding(.top, Space.xxs)
        }
        .padding(ProductCardMetrics.inset)
        .whiteCard(cornerRadius: ProductCardMetrics.radius)
    }
}

/// Product photo: full card width at 4:3, or a fixed square.
struct ProductPhoto: View {
    let product: Product
    let size: CGFloat?
    var cornerRadius: CGFloat = 12

    var body: some View {
        Group {
            if let size {
                content.frame(width: size, height: size)
            } else {
                // The image sits in an overlay so `scaledToFill` can never push the card wider than its column.
                Color.clear
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay { content }
            }
        }
        .background(.wbBrandSoft)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    @ViewBuilder private var content: some View {
        if let name = product.imageName, let image = UIImage(named: name) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let data = product.photoData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Image(systemName: "leaf").font(.title2).foregroundStyle(.wbBrand)
        }
    }
}

// MARK: - Detail

struct ProductDetailView: View {
    let productID: UUID
    @Bindable var model: ProductsViewModel
    @State private var confirmDelete = false
    @State private var expanded = false
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeViewModel.self) private var home

    private let heroHeight: CGFloat = 380

    var body: some View {
        if let product = model.products.first(where: { $0.id == productID }) {
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        hero(product)
                        // The details sit on a sheet that overlaps the bottom of the photo.
                        infoSheet(product)
                            .photoSheet()
                    }
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
                // Back floats at the top-left of the photo, just under the status bar on every iPhone
                // (the overlay already starts below the safe area, so no extra inset is added).
                .overlay(alignment: .topLeading) {
                    topBar(product).padding(.top, Space.xxs)
                }
                // Edit and Delete stay pinned at the bottom, always reachable.
                .safeAreaInset(edge: .bottom, spacing: 0) { actionBar(product) }
            }
            .background(Color.wbBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            // No bottom tab dock on the detail page; it comes back when you go back.
            .onAppear { home.dockHidden = true }
            .onDisappear { home.dockHidden = false }
            .alert("Delete “\(product.name)”?", isPresented: $confirmDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { Task { await model.delete(product); dismiss() } }
            } message: {
                Text("It will be removed from your website the next time you deploy. This can’t be undone.")
            }
        } else {
            ContentUnavailableView("Product removed", systemImage: "trash")
        }
    }

    // MARK: Photo + floating controls

    private func hero(_ product: Product) -> some View {
        Color.clear
            .frame(height: heroHeight)
            .overlay { photo(product) }
            .overlay(alignment: .top) {
                // A soft shade under the status bar and the floating buttons.
                LinearGradient(colors: [.black.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 140)
            }
            .clipped()
            .accessibilityHidden(true)
    }

    @ViewBuilder private func photo(_ product: Product) -> some View {
        if let name = product.imageName, let image = UIImage(named: name) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let data = product.photoData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            ZStack {
                Color.wbBrandSoft
                Image(systemName: "photo").font(.largeTitle).foregroundStyle(.wbBrand.opacity(0.6))
            }
        }
    }

    private func topBar(_ product: Product) -> some View {
        HStack {
            Button { dismiss() } label: { FloatingIcon(symbol: "chevron.left") }
                .buttonStyle(.wbCardPress)
                .accessibilityLabel("Back")
            Spacer()
        }
        .padding(.horizontal, Space.m)
    }

    // MARK: Info sheet — category, name, price, description, details

    private func infoSheet(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Text(product.name).font(.title2.weight(.bold)).foregroundStyle(.wbText)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                Spacer(minLength: Space.xs)
                Text(product.price.currencyText).font(.title3.weight(.bold)).foregroundStyle(.wbBrand)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)

            if !product.description.isEmpty {
                VStack(alignment: .leading, spacing: Space.xs) {
                    sectionTitle("Description")
                    Text(product.description)
                        .font(.body).foregroundStyle(.wbMuted)
                        .lineLimit(expanded ? nil : 4)
                        .lineSpacing(3)
                    if product.description.count > 160 {
                        Button(expanded ? "Show less" : "Read more") { withAnimation(.snappy) { expanded.toggle() } }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.wbBrand)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                sectionTitle("Details")
                VStack(spacing: 0) {
                    detailRow(symbol: "tag.fill", tint: Color(hex: 0x7C4DFF), label: "Category",
                              value: product.category.isEmpty ? "—" : product.category)
                    Divider().padding(.leading, 52)
                    detailRow(symbol: "globe", tint: .wbGreen, label: "Shown on", value: home.selected?.name ?? "Your website")
                }
                .whiteCard(cornerRadius: 20)
            }
        }
        .padding(.horizontal, Space.screen)
        .padding(.top, Space.l)
        .padding(.bottom, Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)

    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
            .accessibilityAddTraits(.isHeader)
    }

    /// One line of the details card: an icon tile, the label, and the value on the right.
    private func detailRow(symbol: String, tint: Color, label: String, value: String) -> some View {
        HStack(spacing: Space.s) {
            Image(systemName: symbol).font(.footnote.weight(.semibold)).foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(label).font(.subheadline).foregroundStyle(.wbMuted)
            Spacer(minLength: Space.s)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
                .multilineTextAlignment(.trailing).lineLimit(2)
        }
        .padding(.horizontal, Space.s).padding(.vertical, Space.s)
        .accessibilityElement(children: .combine)
    }

    // MARK: Pinned action bar

    private func actionBar(_ product: Product) -> some View {
        // Two equal buttons: Delete on the left, Edit (the main action) on the right, under the thumb.
        HStack(spacing: Space.s) {
            Button { confirmDelete = true } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.wbDestructive)
            .accessibilityHint("Asks before deleting")

            Button { model.editing = ProductDraft(product) } label: {
                Label("Edit product", systemImage: "square.and.pencil")
            }
            .buttonStyle(.wbPrimary)
        }
        .padding(.horizontal, Space.screen)
        .padding(.top, Space.s)
        .padding(.bottom, Space.xs)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

/// How far the rounded content sheet overlaps the photo above it (product detail and edit form).
let photoSheetRadius: CGFloat = 28

extension View {
    /// Puts content on a rounded sheet that overlaps the bottom of the photo above it. The sheet's surface runs on
    /// past the content, so a short page never shows a seam (the scroll view clips it at its own edge).
    func photoSheet() -> some View {
        self
            .background(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: photoSheetRadius, topTrailingRadius: photoSheetRadius,
                                       style: .continuous)
                    .fill(Color.wbBackground)
                    .frame(height: 3000)
                    .shadow(color: .black.opacity(0.08), radius: 12, y: -4)
            }
            .padding(.top, -photoSheetRadius)
    }
}

/// A 40 pt frosted round button that floats over a photo (44 pt tap area).
private struct FloatingIcon: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color(hex: 0x1A273D))
            .frame(width: 40, height: 40)
            .background(.regularMaterial, in: Circle())
            .background(Color.white.opacity(0.55), in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }
}

// MARK: - Add / edit form

struct ProductFormSheet: View {
    let model: ProductsViewModel
    @State var draft: ProductDraft
    @State private var showErrors = false
    @State private var newCategory = ""
    @State private var addingCategory = false
    @Environment(\.dismiss) private var dismiss

    init(model: ProductsViewModel, draft: ProductDraft) {
        self.model = model
        _draft = State(initialValue: draft)
    }

    private var hasPhoto: Bool { draft.photoData != nil || draft.imageName != nil }

    var body: some View {
        GeometryReader { geo in
        let topInset = geo.safeAreaInsets.top
        ScrollView {
            VStack(spacing: 0) {
                // Big photo on top, like the product page, with the close button and title on it.
                // Full screen: the photo runs up under the status bar.
                ProductPhotoField(draft: $draft, hero: true, topInset: topInset)
                    .overlay(alignment: .top) { header.padding(.top, topInset) }

                // The fields and buttons sit on a rounded sheet over the photo, like the product page.
                VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: Space.m) {
                    LabeledField(title: "Product name", text: $draft.name, prompt: "e.g. Sunflower bunch",
                                 error: showErrors ? draft.nameError : nil, capitalization: .words)
                        .appearAnimated(index: 1)

                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text("Category").font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
                        FlowLayout(spacing: Space.xs) {
                            Button { addingCategory = true } label: {
                                Label("New", systemImage: "plus").font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.wbBrand)
                                    .padding(.horizontal, 16).frame(minHeight: 40)
                                    .overlay(Capsule().strokeBorder(Color.wbBrand.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                            }
                            .buttonStyle(.wbCardPress)
                            ForEach(model.categories, id: \.self) { name in
                                FilterChip(title: name, isSelected: draft.category == name) { draft.category = name }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if showErrors, let error = draft.categoryError {
                            Label(error, systemImage: "exclamationmark.circle.fill").font(.footnote).foregroundStyle(.wbRed)
                        }
                    }
                    .appearAnimated(index: 2)

                    LabeledField(title: "Description", text: $draft.description,
                                 prompt: "Tell customers what it is, what’s included and how to care for it.",
                                 error: showErrors ? draft.descriptionError : nil,
                                 isOptional: true, axis: .vertical,
                                 hint: "10–300 characters, or leave it empty.")
                        .appearAnimated(index: 3)

                    LabeledField(title: "Price (USD)", text: $draft.priceText, prompt: "0.00",
                                 error: showErrors ? draft.priceError : nil, keyboard: .decimalPad)
                        .appearAnimated(index: 4)
                }
                .padding(.top, Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.screen)

                // Cancel / Save right under the fields.
                footer.padding(.top, Space.l)
                }
                .padding(.bottom, Space.l)
                .photoSheet()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .contentMargins(.bottom, 0, for: .scrollContent)    // no dock here, so drop the space the tabs reserve for it
        .ignoresSafeArea(edges: .top)
        }
        .background { TileBackdrop() }
        .overlay {
            if addingCategory {
                WBPrompt(title: "New category", placeholder: "Category name", text: $newCategory,
                         confirmTitle: "Add", onConfirm: {
                    if let name = model.addCategory(newCategory) { draft.category = name }
                    newCategory = ""
                    withAnimation { addingCategory = false }
                }, onCancel: {
                    newCategory = ""
                    withAnimation { addingCategory = false }
                })
            }
        }
        .animation(.easeInOut(duration: 0.2), value: addingCategory)
        // A failed save must be visible here: the products list (and its own toast) sits under this full-screen form.
        .toast(Bindable(model).toast)
    }

    // MARK: Header — glass close button and title, drawn on the photo

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").wbFont(15, .semibold)
                    .foregroundStyle(hasPhoto ? Color.white : Color.wbBrand)
                    .frame(width: 44, height: 44)
                    .liquidGlass(in: Circle(), tint: hasPhoto ? .white.opacity(0.15) : .white, interactive: true)
            }
            .buttonStyle(.wbCardPress)
            .accessibilityLabel("Close")
            Spacer()
            Text(draft.isNew ? "Add product" : "Edit product").font(.headline)
                .foregroundStyle(hasPhoto ? Color.white : Color.wbText)
            Spacer()
            Color.clear.frame(width: 44, height: 44)      // the photo's pencil badge sits here
        }
        .padding(.horizontal, Space.screen).padding(.top, Space.m)
    }

    // MARK: Footer — two equal buttons: Cancel on the left, Save on the right

    private var footer: some View {
        HStack(spacing: Space.s) {
            Button { dismiss() } label: {
                Text("Cancel")
            }
            .buttonStyle(.wbSecondary)
            .accessibilityHint("Closes without saving")
            Button {
                showErrors = true
                Task { if await model.save(draft) { dismiss() } }
            } label: {
                ZStack {
                    if model.isSaving { ProgressView().tint(.white) }
                    else { Label(draft.isNew ? "Save product" : "Save", systemImage: "checkmark") }
                }
            }
            .buttonStyle(.wbPrimary)
            .allowsHitTesting(!model.isSaving)
        }
        .padding(.horizontal, Space.screen)
    }
}

/// Sizes the photo area: a fixed-height edge-to-edge header in hero mode, a rounded 16:9 box otherwise.
private struct PhotoFrame: ViewModifier {
    let hero: Bool
    let empty: Bool
    var extra: CGFloat = 0
    func body(content: Content) -> some View {
        if hero {
            content.frame(maxWidth: .infinity).frame(height: (empty ? 300 : 360) + extra).clipped()
        } else {
            content
                .aspectRatio(empty ? 2.1 : 16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

/// Photo area: dashed “Add a photo” drop zone when empty, full-width photo with a pencil badge
/// and a “Change photo” pill when there is one. JPG/PNG up to 2 MB.
private struct ProductPhotoField: View {
    @Binding var draft: ProductDraft
    /// Full-width header photo (edge to edge, fixed height) as on the product page.
    var hero = false
    /// Status-bar height when the photo runs under it (full screen), so the badge sits below it.
    var topInset: CGFloat = 0
    @State private var item: PhotosPickerItem?
    @State private var error: String?
    private let maxBytes = 2_000_000

    private var image: UIImage? {
        if let data = draft.photoData, let ui = UIImage(data: data) { return ui }
        if let name = draft.imageName { return UIImage(named: name) }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            PhotosPicker(selection: $item, matching: .images) {
                ZStack {
                    if let image {
                        Color.clear
                            .overlay { Image(uiImage: image).resizable().scaledToFill() }
                            .overlay {
                                if hero {   // keeps the white title readable on bright photos
                                    LinearGradient(colors: [.black.opacity(0.35), .clear, .clear], startPoint: .top, endPoint: .bottom)
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                // White glass badge, matching the "Change photo" pill.
                                Image(systemName: "pencil").wbFont(14, .semibold)
                                    .foregroundStyle(Color(hex: 0x1F2D5A))
                                    .frame(width: 36, height: 36)
                                    .liquidGlass(in: Circle(), tint: .white.opacity(0.6))
                                    .padding(hero ? Space.screen : Space.xs)
                                    .padding(.top, hero ? Space.m - Space.screen + 4 + topInset : 0)
                            }
                            .overlay(alignment: .bottomLeading) {
                                Label("Change photo", systemImage: "camera.fill").font(.caption.weight(.semibold))
                                    // White glass pill with dark text so it reads on any photo.
                                    .foregroundStyle(Color(hex: 0x1F2D5A)).padding(.horizontal, 14).frame(height: 34)
                                    .liquidGlass(in: Capsule(), tint: .white.opacity(0.6))
                                    .padding(hero ? Space.screen : Space.xs)
                                    .padding(.bottom, hero ? photoSheetRadius : 0)   // clear of the sheet's curve
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        // Dashed drop zone. In the full-width header it sits inset, below the close button and title.
                        let zone = RoundedRectangle(cornerRadius: 24, style: .continuous)
                        VStack(spacing: Space.xs) {
                            Image(systemName: "photo.badge.plus").wbFont(26, .medium).foregroundStyle(Color.wbBrand)
                                .frame(width: 60, height: 60)
                                .background(Color.wbCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: Color.wbBrand.opacity(0.12), radius: 8, y: 3)
                            Text("Tap to add a photo").font(.subheadline.weight(.semibold)).foregroundStyle(Color.wbBrand)
                            Text("PNG or JPG, up to 2 MB · Landscape 4:3").font(.caption).foregroundStyle(.wbMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.wbBrandSoft.opacity(0.7), in: zone)
                        .overlay(zone.strokeBorder(Color.wbBrand.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])))
                        .padding(.horizontal, hero ? Space.screen : 0)
                        .padding(.top, hero ? topInset + 44 + Space.m * 2 : 0)
                        .padding(.bottom, hero ? Space.xs + photoSheetRadius : 0)   // clear of the sheet's curve
                    }
                }
                .modifier(PhotoFrame(hero: hero, empty: image == nil, extra: topInset))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: image == nil)
            }
            .buttonStyle(.wbCardPress)
            .contextMenu {
                if image != nil {
                    Button("Remove photo", systemImage: "trash", role: .destructive) {
                        withAnimation { draft.photoData = nil; draft.imageName = nil }; item = nil
                    }
                }
            }
            if let error { Label(error, systemImage: "exclamationmark.circle.fill").font(.footnote).foregroundStyle(.wbRed) }
        }
        .onChange(of: item) { _, newItem in
            Task {
                guard let newItem, let loaded = try? await newItem.loadTransferable(type: Data.self) else { return }
                if loaded.count > maxBytes { error = "That file is larger than 2 MB."; item = nil }
                else { error = nil; withAnimation { draft.photoData = loaded; draft.imageName = nil } }
            }
        }
    }
}


/// Classic filter funnel, drawn by hand so it looks the same on every iOS version
/// (the SF Symbol "funnel" doesn't exist before iOS 18 and would show blank).
struct FunnelShape: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y) }
        var p = Path()
        p.move(to: pt(0.04, 0.08))
        p.addLine(to: pt(0.96, 0.08))
        p.addLine(to: pt(0.62, 0.50))
        p.addLine(to: pt(0.62, 0.94))
        p.addLine(to: pt(0.38, 0.80))
        p.addLine(to: pt(0.38, 0.50))
        p.closeSubpath()
        return p
    }
}
