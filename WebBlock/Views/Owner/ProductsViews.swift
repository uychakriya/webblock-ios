import SwiftUI
import PhotosUI

// MARK: - Products tab

struct ProductsView: View {
    @Bindable var model: ProductsViewModel
    @Environment(HomeViewModel.self) private var home
    @Environment(KeyboardWatcher.self) private var keyboard
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: Space.s, alignment: .top)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("Shown as Product Cards on \(home.selected?.url ?? "your website").")
                    .font(.subheadline).foregroundStyle(.wbMuted)
                SiteHeaderCard().appearAnimated()

                ChipRow {
                    FilterChip(title: "All", count: model.products.count, isSelected: model.category == nil) { model.category = nil }
                    ForEach(model.categories, id: \.self) { name in
                        FilterChip(title: name, isSelected: model.category == name) { model.category = name }
                    }
                }

                HStack {
                    Text(model.summary).font(.footnote).foregroundStyle(.wbMuted)
                    Spacer()
                    WBIconSegmented(options: [("square.grid.2x2", "Grid", ProductLayout.grid),
                                              ("list.bullet", "List", ProductLayout.list)],
                                    selection: $model.layout)
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
                        Button("Show more") { model.visibleCount += model.pageSize }.buttonStyle(.wbSecondary)
                    }
                }
            }
            .padding(.horizontal, Space.screen).padding(.top, Space.xs).padding(.bottom, Space.l)
        }
        .liquidBackdrop()
        .navigationTitle("Products")
        .portalToolbar()
        .searchable(text: $model.query, prompt: "Search products")
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
                    .liquidGlass(in: Capsule(), tint: Color(hex: 0x3F72D0), interactive: true)
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
        .confirmationDialog("Delete “\(model.pendingDelete?.name ?? "")”?", isPresented: .init(
            get: { model.pendingDelete != nil }, set: { if !$0 { model.pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Delete product", role: .destructive) { Task { await model.confirmDelete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will be removed from your website the next time you deploy. This can’t be undone.")
        }
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
            Image(systemName: "ellipsis").foregroundStyle(.wbMuted).frame(width: 32, height: 32).contentShape(Rectangle())
        }
        .accessibilityLabel("More actions for \(product.name)")
    }

    static let redTrash = UIImage(systemName: "trash")!.withTintColor(.systemRed, renderingMode: .alwaysOriginal)
}

struct ProductRow: View {
    let product: Product
    let model: ProductsViewModel
    var body: some View {
        HStack(spacing: Space.s) {
            NavigationLink(value: product) {
                HStack(spacing: Space.s) {
                    ProductPhoto(product: product, size: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name).font(.subheadline.weight(.semibold)).foregroundStyle(.wbText).lineLimit(1)
                        Text("\(product.category) · \(product.description)").font(.footnote).foregroundStyle(.wbMuted).lineLimit(1)
                        Text(product.price.currencyText).font(.subheadline.weight(.bold)).foregroundStyle(.wbText)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.wbCardPress)
            ProductMenu(product: product, model: model)
        }
        .wbCard(padding: Space.s)
    }
}

struct ProductTile: View {
    let product: Product
    let model: ProductsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            NavigationLink(value: product) { ProductPhoto(product: product, size: nil) }
                .buttonStyle(.wbSpotifyCard)
            HStack(alignment: .top, spacing: 0) {
                NavigationLink(value: product) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name).font(.subheadline.weight(.semibold)).foregroundStyle(.wbText).lineLimit(1)
                        Text("\(product.category) · \(product.description)").font(.caption).foregroundStyle(.wbMuted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.wbCardPress)
                ProductMenu(product: product, model: model)
            }
            Text(product.price.currencyText).font(.subheadline.weight(.bold)).foregroundStyle(.wbText)
        }
        .wbCard(padding: Space.s)
    }
}

/// Placeholder until the API supplies product photo URLs (Figma shows real photos).
struct ProductPhoto: View {
    let product: Product
    let size: CGFloat?

    var body: some View {
        Group {
            if let size {
                content.frame(width: size, height: size)
            } else {
                // Card photo: full card width at the Figma 4:3 ratio. The image sits in an
                // overlay so `scaledToFill` can never push the card wider than its column.
                Color.clear
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay { content }
            }
        }
        .background(.wbBrandSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog("Delete “\(product.name)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete product", role: .destructive) {
                    Task { await model.delete(product); dismiss() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("It will be removed from your website the next time you deploy. This can’t be undone.")
            }
        } else {
            ContentUnavailableView("Product removed", systemImage: "trash")
        }
    }

    // MARK: Photo header — full-bleed photo, glass buttons, name over the image

    private func hero(_ product: Product) -> some View {
        Color.clear
            .frame(height: 440)
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
                    Color.clear.frame(width: 46, height: 46)
                }
                .padding(.horizontal, Space.screen)
                .padding(.top, 58)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(product.name).font(.system(size: 32, weight: .bold))
                            .lineLimit(2).minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Space.screen)
                .padding(.bottom, Space.l)
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
            HStack(alignment: .center) {
                Text(product.price.currencyText).font(.system(size: 26, weight: .bold)).foregroundStyle(.wbText)
                Spacer(minLength: Space.s)
                Pill(text: product.category)
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Description").font(.headline).foregroundStyle(.wbText)
                Text(product.description)
                    .font(.subheadline).foregroundStyle(.wbMuted)
                    .lineLimit(expanded ? nil : 4)
                    .lineSpacing(3)
                if product.description.count > 160 {
                    Button(expanded ? "Show less" : "Read more…") { withAnimation(.snappy) { expanded.toggle() } }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Bottom buttons

    private func actionBar(_ product: Product) -> some View {
        HStack(spacing: Space.s) {
            Button { confirmDelete = true } label: {
                Label("Delete", systemImage: "trash").lineLimit(1).minimumScaleFactor(0.8)
            }
            .buttonStyle(.wbDestructive)
            Button { model.editing = ProductDraft(product) } label: {
                Label("Edit product", systemImage: "square.and.pencil").lineLimit(1).minimumScaleFactor(0.8)
            }
            .buttonStyle(.wbPrimary)
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
        .background(Color(.systemGroupedBackground))
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
