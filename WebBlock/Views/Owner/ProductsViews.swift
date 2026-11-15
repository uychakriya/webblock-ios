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
                Text("Products").font(.system(size: 40, weight: .bold)).foregroundStyle(Color(hex: 0x2F6BC9))
                    .padding(.top, Space.xs)

                searchBar

                SiteHeaderCard().appearAnimated()

                if showFilters {
                    VStack(alignment: .leading, spacing: Space.m) {
                        CategoryChips(model: model)

                        HStack {
                            Text(model.summary).font(.subheadline).foregroundStyle(.wbMuted)
                            Spacer()
                            WBIconSegmented(options: [("square.grid.2x2", "Grid", ProductLayout.grid),
                                                      ("list.bullet", "List", ProductLayout.list)],
                                            selection: $model.layout)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                StateContainer(state: model.state, retry: { Task { await model.load() } }) {
                    if model.filtered.isEmpty {
                        ContentUnavailableView(model.query.isEmpty ? "No products yet" : "No results",
                                               systemImage: "shippingbox",
                                               description: Text(model.query.isEmpty ? "Add your first product to show it on your website." : "Try a different name."))
                    } else if model.layout == .list {
                        LazyVStack(spacing: Space.s) {
                            ForEach(Array(model.shown.enumerated()), id: \.element.id) { i, product in
                                ProductRow(product: product, model: model).appearAnimated(index: i)
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
            .padding(.horizontal, Space.screen).padding(.top, Space.xs).padding(.bottom, Space.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { TileBackdrop() }
        .navigationTitle("Products")
        .navigationBarTitleDisplayMode(.inline)
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
        .overlay {
            if let product = model.pendingDelete {
                WBConfirm(title: "Delete “\(product.name)”?",
                          message: "It will be removed from your website the next time you deploy. This can’t be undone.",
                          confirmTitle: "Delete product",
                          onConfirm: { Task { await model.confirmDelete() } },
                          onCancel: { model.pendingDelete = nil })
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.pendingDelete != nil)
    }
}

extension ProductsView {
    /// Rounded glass search field with a filter button, like the website's product search.
    fileprivate var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 19, weight: .medium)).foregroundStyle(Color(hex: 0x2F6BC9))
            TextField("Search products…", text: $model.query)
                .focused($searching)
                .font(.system(size: 18))
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !model.query.isEmpty {
                Button { model.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.wbMuted)
                }
                .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showFilters.toggle() }
            } label: {
                // Same size as the magnifier, no circle behind it. The extra frame keeps a comfortable tap area.
                FunnelShape()
                    .stroke(Color(hex: 0x3862B6), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .background(FunnelShape().fill(Color(hex: 0x3862B6).opacity(showFilters ? 0.18 : 0)))
                    .frame(width: 20, height: 20)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: showFilters)
            .accessibilityLabel(showFilters ? "Hide filters" : "Show filters")
        }
        .padding(.leading, 18).padding(.trailing, 8)
        .frame(height: 54)
        .whiteCard(cornerRadius: 27)
        .contentShape(Capsule())
        .onTapGesture { searching = true }
    }
}

/// Categories inside one soft glass track; the selected one is a white pill that slides along.
private struct CategoryChips: View {
    @Bindable var model: ProductsViewModel
    @Namespace private var pill

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                chip("All", count: model.products.count, on: model.category == nil) { model.category = nil }
                ForEach(model.categories, id: \.self) { name in
                    chip(name, count: nil, on: model.category == name) { model.category = name }
                }
            }
            .padding(4)
        }
        .scrollBounceBehavior(.always, axes: .horizontal)
        .background(Color(hex: 0xE6EFFC), in: Capsule())
        .clipShape(Capsule())
    }

    private func chip(_ title: String, count: Int?, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { action() }
        } label: {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 16, weight: .semibold))
                if let count {
                    Text("\(count)").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).frame(minWidth: 26, minHeight: 24)
                        .background(Color(hex: 0x2F6BC9), in: Capsule())
                }
            }
            .foregroundStyle(on ? Color(hex: 0x2F6BC9) : Color(hex: 0x5B6B8C))
            .padding(.horizontal, 18).frame(height: 42)
            .background {
                if on {
                    Capsule().fill(Color.white)
                        .shadow(color: Color(hex: 0x1F3C7A).opacity(0.12), radius: 6, y: 2)
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
            Button("Edit product", systemImage: "pencil") { model.editing = ProductDraft(product) }
            // The app tint would turn a plain menu icon blue; a pre-coloured image keeps the trash red.
            Button(role: .destructive) { model.pendingDelete = product } label: {
                Label { Text("Delete product") } icon: { Image(uiImage: Self.redTrash) }
            }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 15, weight: .bold)).rotationEffect(.degrees(90))
                .foregroundStyle(Color(hex: 0x3A4256)).frame(width: 32, height: 32).contentShape(Rectangle())
        }
        .accessibilityLabel("More actions for \(product.name)")
    }

    static let redTrash = UIImage(systemName: "trash")!.withTintColor(.systemRed, renderingMode: .alwaysOriginal)
}

/// White rounded tag showing the product's category, laid over its photo.
private struct CategoryTag: View {
    let text: String
    var body: some View {
        Text(text).font(.dm(13, 600)).foregroundStyle(Color(hex: 0x14203F)).lineLimit(1)
            .padding(.horizontal, 14).padding(.vertical, 7)
            // frosted glass: blurs the photo behind it, with a bright rim
            .background(.ultraThinMaterial, in: Capsule())
            .background(Color.white.opacity(0.28), in: Capsule())
            .overlay(Capsule().strokeBorder(
                LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.25), .white.opacity(0.7)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
    }
}

private let productBlue = Color(hex: 0x3862B6)
private let productInk = Color(hex: 0x1F2A4D)
private let productMuted = Color(hex: 0x5F6B85)

struct ProductRow: View {
    let product: Product
    let model: ProductsViewModel
    var body: some View {
        HStack(spacing: Space.s) {
            NavigationLink(value: product) {
                HStack(spacing: Space.s) {
                    ProductPhoto(product: product, size: 84, cornerRadius: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(product.name).font(.dm(16, 600)).foregroundStyle(productInk).lineLimit(1)
                        Text(product.description).font(.dm(13, 400)).foregroundStyle(productMuted).lineLimit(1)
                        Text(product.price.currencyText).font(.dm(17, 700)).foregroundStyle(productBlue)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.wbCardPress)
            ProductMenu(product: product, model: model)
        }
        .padding(8)
        .whiteCard(cornerRadius: 22)
    }
}

struct ProductTile: View {
    let product: Product
    let model: ProductsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: product) {
                ProductPhoto(product: product, size: nil, cornerRadius: 18)
                    .overlay(alignment: .topLeading) { CategoryTag(text: product.category).padding(8) }
            }
            .buttonStyle(.wbSpotifyCard)

            NavigationLink(value: product) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.name).font(.dm(16, 600)).foregroundStyle(productInk).lineLimit(1)
                    Text(product.description).font(.dm(13, 400)).foregroundStyle(productMuted)
                        .lineSpacing(3)
                        .lineLimit(2, reservesSpace: true).multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8).padding(.top, 14)
            }
            .buttonStyle(.wbCardPress)

            HStack {
                Text(product.price.currencyText).font(.dm(18, 700)).foregroundStyle(productBlue)
                Spacer()
                ProductMenu(product: product, model: model)
            }
            .padding(.leading, 8).padding(.trailing, 0).padding(.top, 10).padding(.bottom, 4)
        }
        .padding(8)
        .whiteCard(cornerRadius: 26)
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
    var body: some View {
        if let product = model.products.first(where: { $0.id == productID }) {
            ScrollView {
                VStack(spacing: 0) {
                    hero(product)
                    // Same style as the edit screen: details straight on the page under the photo, no card.
                    infoCard(product)
                        .padding(.horizontal, Space.screen)
                        .padding(.top, Space.l)
                    // Delete / Edit sit right under the details, inside the page,
                    // so the bottom tab dock never covers them.
                    actionBar(product)
                        .padding(.top, Space.l)
                }
                .padding(.bottom, Space.l)
            }
            .ignoresSafeArea(edges: .top)
            .background { TileBackdrop() }
            .toolbar(.hidden, for: .navigationBar)
            // No bottom tab dock on the detail page; it comes back when you go back.
            .onAppear { home.dockHidden = true }
            .onDisappear { home.dockHidden = false }
            .overlay {
                if confirmDelete {
                    WBConfirm(title: "Delete “\(product.name)”?",
                              message: "It will be removed from your website the next time you deploy. This can’t be undone.",
                              confirmTitle: "Delete product",
                              onConfirm: { confirmDelete = false; Task { await model.delete(product); dismiss() } },
                              onCancel: { confirmDelete = false })
                }
            }
            .animation(.easeInOut(duration: 0.2), value: confirmDelete)
        } else {
            ContentUnavailableView("Product removed", systemImage: "trash")
        }
    }

    // MARK: Photo header — full-bleed photo, glass buttons, name over the image

    private func hero(_ product: Product) -> some View {
        Color.clear
            .frame(height: 400)
            .overlay { photo(product) }
            .overlay {
                // keeps the white text readable on bright photos
                LinearGradient(colors: [.black.opacity(0.35), .clear, .clear, .black.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom)
            }
            .clipped()
            .overlay(alignment: .top) {
                HStack {
                    circleButton("chevron.left", label: "Back") { dismiss() }
                    Spacer()
                    Text("Product").font(.headline).foregroundStyle(.white)
                    Spacer()
                    Menu {
                        Button("Edit product", systemImage: "pencil") { model.editing = ProductDraft(product) }
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label { Text("Delete product") } icon: { Image(uiImage: ProductMenu.redTrash) }
                        }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .rotationEffect(.degrees(90))
                            .frame(width: 46, height: 46)
                            .liquidGlass(in: Circle(), tint: .white.opacity(0.15), interactive: true)
                    }
                    .accessibilityLabel("More actions")
                }
                .padding(.horizontal, Space.screen)
                .padding(.top, 58)
            }
    }

    @ViewBuilder private func photo(_ product: Product) -> some View {
        if let name = product.imageName, let image = UIImage(named: name) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let data = product.photoData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            ZStack {
                Color.wbBrandSoft
                Image(systemName: "leaf").font(.system(size: 44)).foregroundStyle(.wbBrand)
            }
        }
    }

    private func circleButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .liquidGlass(in: Circle(), tint: .white.opacity(0.15), interactive: true)
        }
        .buttonStyle(.wbCardPress)
        .accessibilityLabel(label)
    }

    // MARK: Info — price, description, details

    private func infoCard(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 6) {
                Text(product.name).font(.title2.weight(.bold)).foregroundStyle(.wbText)
                Text(product.price.currencyText).font(.system(size: 22, weight: .bold)).foregroundStyle(.wbBrand)
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(product.description)
                    .font(.body).foregroundStyle(.wbMuted)
                    .lineLimit(expanded ? nil : 4)
                    .lineSpacing(3)
                if product.description.count > 160 {
                    Button(expanded ? "Show less" : "Read more…") { withAnimation(.snappy) { expanded.toggle() } }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
                }
            }

            // Plain details list (not tappable cards), so it doesn't look like the Delete / Edit buttons below.
            VStack(spacing: 0) {
                detailRow(symbol: "tag", tint: Color(hex: 0x7C4DFF), label: "Category", value: product.category)
                Divider()
                detailRow(symbol: "globe", tint: .wbGreen, label: "Shown on", value: home.selected?.name ?? "Your website")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One line of the details list: small coloured icon and label on the left, the value on the right.
    private func detailRow(symbol: String, tint: Color, label: String, value: String) -> some View {
        HStack(spacing: Space.xs) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(tint).frame(width: 22)
            Text(label).font(.subheadline).foregroundStyle(.wbMuted)
            Spacer(minLength: Space.s)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
                .multilineTextAlignment(.trailing).lineLimit(2)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    // MARK: Bottom buttons

    private func actionBar(_ product: Product) -> some View {
        HStack(spacing: Space.s) {
            Button { confirmDelete = true } label: {
                Label("Delete product", systemImage: "trash").lineLimit(1).minimumScaleFactor(0.8)
            }
            .buttonStyle(.wbDestructiveField)
            Button { model.editing = ProductDraft(product) } label: {
                Label("Edit product", systemImage: "square.and.pencil").lineLimit(1).minimumScaleFactor(0.8)
            }
            .buttonStyle(.wbPrimaryField)
        }
        .padding(.horizontal, Space.screen)
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

                // The fields, straight on the page background under the photo.
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
                                 isOptional: true, axis: .vertical)
                        .appearAnimated(index: 3)

                    LabeledField(title: "Price (USD)", text: $draft.priceText, prompt: "0.00",
                                 error: showErrors ? draft.priceError : nil, keyboard: .decimalPad)
                        .appearAnimated(index: 4)
                }
                .padding(.top, Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.screen)

                // Delete / Save right under the fields.
                footer.padding(.top, Space.l)
            }
            .padding(.bottom, Space.l)
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
    }

    // MARK: Header — glass close button and title, drawn on the photo

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
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

    // MARK: Footer — Delete + Save buttons

    private var footer: some View {
        HStack(spacing: Space.s) {
            if !draft.isNew {
                Button {
                    model.pendingDelete = draft.product
                    dismiss()
                } label: {
                    Label("Delete product", systemImage: "trash").lineLimit(1).minimumScaleFactor(0.8)
                }
                .buttonStyle(.wbDestructive)
            }
            Button {
                showErrors = true
                Task { if await model.save(draft) { dismiss() } }
            } label: {
                ZStack {
                    if model.isSaving { ProgressView().tint(.white) }
                    else { Label(draft.isNew ? "Save product" : "Save changes", systemImage: "square.and.arrow.down").lineLimit(1).minimumScaleFactor(0.8) }
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
                                Image(systemName: "pencil").font(.system(size: 14, weight: .semibold))
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
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        // Dashed drop zone. In the full-width header it sits inset, below the close button and title.
                        let zone = RoundedRectangle(cornerRadius: 24, style: .continuous)
                        VStack(spacing: Space.xs) {
                            Image(systemName: "photo.badge.plus").font(.system(size: 26, weight: .medium)).foregroundStyle(Color.wbBrand)
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
                        .padding(.bottom, hero ? Space.xs : 0)
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
