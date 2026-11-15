import SwiftUI

// MARK: - Products tab

struct ProductsView: View {
    @Bindable var model: ProductsViewModel
    @Environment(HomeViewModel.self) private var home
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: Space.s)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("Shown as Product Cards on \(home.selected?.url ?? "your website").")
                    .font(.subheadline).foregroundStyle(.wbMuted)
                SiteHeaderCard()

                ChipRow {
                    FilterChip(title: "All", count: model.products.count, isSelected: model.category == nil) { model.category = nil }
                    ForEach(model.categories, id: \.self) { name in
                        FilterChip(title: name, isSelected: model.category == name) { model.category = name }
                    }
                }

                HStack {
                    Text(model.summary).font(.footnote).foregroundStyle(.wbMuted)
                    Spacer()
                    Picker("Layout", selection: $model.layout) {
                        Image(systemName: "square.grid.2x2").tag(ProductLayout.grid)
                        Image(systemName: "list.bullet").tag(ProductLayout.list)
                    }
                    .pickerStyle(.segmented).frame(width: 110)
                }

                StateContainer(state: model.state, retry: { Task { await model.load() } }) {
                    if model.filtered.isEmpty {
                        ContentUnavailableView(model.query.isEmpty ? "No products yet" : "No results",
                                               systemImage: "shippingbox",
                                               description: Text(model.query.isEmpty ? "Add your first product to show it on your website." : "Try a different name."))
                    } else if model.layout == .list {
                        LazyVStack(spacing: Space.s) {
                            ForEach(model.shown) { product in ProductRow(product: product, model: model) }
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: Space.s) {
                            ForEach(model.shown) { product in ProductTile(product: product, model: model) }
                        }
                    }
                    if model.canLoadMore {
                        Button("Show more") { model.visibleCount += model.pageSize }.buttonStyle(.wbSecondary)
                    }
                }
            }
            .padding(.horizontal, Space.screen).padding(.top, Space.xs).padding(.bottom, 88)
        }
        .background(.wbBackground)
        .navigationTitle("Products")
        .portalToolbar()
        .searchable(text: $model.query, prompt: "Search products")
        .refreshable { await model.load() }
        .task { if model.products.isEmpty { await model.load() } }
        .overlay(alignment: .bottomTrailing) {
            Button { model.editing = ProductDraft() } label: {
                Label("Add product", systemImage: "plus").font(.body.weight(.semibold))
                    .padding(.horizontal, Space.m).frame(height: 50)
                    .foregroundStyle(.white)
                    .background(LinearGradient(colors: [Color(hex: 0x4F86DD), Color(hex: 0x3A6CCB)], startPoint: .top, endPoint: .bottom), in: Capsule())
                    .shadow(color: Color(hex: 0x4379D6).opacity(0.35), radius: 10, y: 5)
            }
            .padding(Space.screen)
        }
        .toast($model.toast)
        .navigationDestination(for: Product.self) { product in ProductDetailView(productID: product.id, model: model) }
        .sheet(item: $model.editing) { draft in ProductFormSheet(model: model, draft: draft) }
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
            Button("Delete product", systemImage: "trash", role: .destructive) { model.pendingDelete = product }
        } label: {
            Image(systemName: "ellipsis").foregroundStyle(.wbMuted).frame(width: 32, height: 32).contentShape(Rectangle())
        }
        .accessibilityLabel("More actions for \(product.name)")
    }
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
            .buttonStyle(.plain)
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
            NavigationLink(value: product) { ProductPhoto(product: product, size: nil).frame(height: 110) }
                .buttonStyle(.plain)
            HStack(alignment: .top, spacing: 0) {
                NavigationLink(value: product) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name).font(.subheadline.weight(.semibold)).foregroundStyle(.wbText).lineLimit(1)
                        Text("\(product.category) · \(product.description)").font(.caption).foregroundStyle(.wbMuted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
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
            if let data = product.photoData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "leaf").font(.title2).foregroundStyle(.wbBrand)
            }
        }
        .frame(width: size, height: size)
        .frame(maxWidth: size == nil ? .infinity : nil)
        .background(.wbBrandSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Detail

struct ProductDetailView: View {
    let productID: UUID
    @Bindable var model: ProductsViewModel
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let product = model.products.first(where: { $0.id == productID }) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.m) {
                    ProductPhoto(product: product, size: nil).frame(height: 220)
                    Text(product.name).font(.title2.bold()).foregroundStyle(.wbText)
                    HStack {
                        Pill(text: product.category)
                        Spacer()
                        Text(product.price.currencyText).font(.title3.bold()).foregroundStyle(.wbText)
                    }
                    Text(product.description).font(.body).foregroundStyle(.wbMuted)
                    Button("Edit product") { model.editing = ProductDraft(product) }.buttonStyle(.wbPrimary)
                    Button("Delete product") { confirmDelete = true }.buttonStyle(.wbDestructive)
                }
                .padding(Space.screen)
            }
            .background(.wbBackground)
            .navigationTitle("Product")
            .navigationBarTitleDisplayMode(.inline)
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.m) {
                    LogoPicker(data: $draft.photoData)
                    LabeledField(title: "Product name", text: $draft.name, prompt: "Garden rose bouquet",
                                 error: showErrors ? draft.nameError : nil, capitalization: .words)

                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Category").font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
                        ChipRow {
                            ForEach(model.categories, id: \.self) { name in
                                FilterChip(title: name, isSelected: draft.category == name) { draft.category = name }
                            }
                            Button { addingCategory = true } label: {
                                Label("New", systemImage: "plus").font(.subheadline.weight(.medium)).padding(.horizontal, 12).frame(minHeight: 36)
                            }
                        }
                        if showErrors, let error = draft.categoryError {
                            Label(error, systemImage: "exclamationmark.circle.fill").font(.footnote).foregroundStyle(.wbRed)
                        }
                    }

                    LabeledField(title: "Description", text: $draft.description, prompt: "What makes it special?", isOptional: true, axis: .vertical)
                    LabeledField(title: "Price (USD)", text: $draft.priceText, prompt: "0.00",
                                 error: showErrors ? draft.priceError : nil, keyboard: .decimalPad)
                }
                .padding(Space.screen)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.wbBackground)
            .navigationTitle(draft.isNew ? "Add product" : "Edit product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(draft.isNew ? "Add" : "Save") {
                        showErrors = true
                        Task { if await model.save(draft) { dismiss() } }
                    }
                    .disabled(model.isSaving)
                }
            }
            .alert("New category", isPresented: $addingCategory) {
                TextField("Category name", text: $newCategory)
                Button("Add") {
                    if let name = model.addCategory(newCategory) { draft.category = name }
                    newCategory = ""
                }
                Button("Cancel", role: .cancel) { newCategory = "" }
            }
        }
        .presentationDetents([.large])
    }
}
