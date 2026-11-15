import SwiftUI
import Observation

// MARK: - Products

struct ProductDraft: Identifiable, Hashable {
    var id = UUID()
    var isNew = true
    var name = ""
    var category = ""
    var description = ""
    var priceText = ""
    var photoData: Data?
    var imageName: String?

    init() {}
    init(_ product: Product) {
        id = product.id; isNew = false
        name = product.name; category = product.category; description = product.description
        priceText = "\(product.price)"; photoData = product.photoData; imageName = product.imageName
    }

    var price: Decimal? { Decimal(string: priceText.replacingOccurrences(of: ",", with: ".")) }
    var nameError: String? { name.trimmingCharacters(in: .whitespaces).isEmpty ? "Enter a product name." : nil }
    var categoryError: String? { category.isEmpty ? "Choose a category." : nil }
    var priceError: String? { (price ?? -1) < 0 ? "Enter a price, for example 6.00." : nil }
    var isValid: Bool { nameError == nil && categoryError == nil && priceError == nil }

    var product: Product {
        Product(id: id, name: name.trimmingCharacters(in: .whitespaces), category: category,
                description: description, price: price ?? 0, photoData: photoData, imageName: imageName)
    }
}

enum ProductLayout: String, CaseIterable { case list, grid }

@MainActor @Observable
final class ProductsViewModel {
    var products: [Product] = []
    var state: LoadState = .idle
    var query = ""
    var category: String?
    var layout: ProductLayout = .grid
    var pageSize = 6
    var visibleCount = 6

    var editing: ProductDraft?
    var pendingDelete: Product?
    var customCategories: [String] = []
    var toast: Toast?
    var isSaving = false

    let websiteID: UUID
    private let service: WebBlockService
    init(websiteID: UUID, service: WebBlockService = ServiceLocator.current) {
        self.websiteID = websiteID
        self.service = service
    }

    /// The categories this website actually uses, in the order its products introduce them,
    /// plus any the owner just created. A website with no products yet starts from a florist-style default.
    var categories: [String] {
        var ordered: [String] = []
        for category in products.map(\.category) + customCategories where !ordered.contains(category) { ordered.append(category) }
        return ordered.isEmpty ? ["Flowers", "Bouquets", "Gifts", "Events"] : ordered
    }

    var filtered: [Product] {
        products.filter {
            (category == nil || $0.category == category)
                && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
        }
    }
    var shown: [Product] { Array(filtered.prefix(visibleCount)) }
    var canLoadMore: Bool { visibleCount < filtered.count }
    var summary: String {
        category == nil && query.isEmpty
            ? "Showing \(shown.count) of \(filtered.count) products"
            : "Showing \(filtered.count) product\(filtered.count == 1 ? "" : "s")"
    }

    func load() async {
        if products.isEmpty { state = .loading }
        do {
            products = try await service.products(websiteID: websiteID)
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func save(_ draft: ProductDraft) async -> Bool {
        guard draft.isValid else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await service.saveProduct(draft.product, websiteID: websiteID)
            if let index = products.firstIndex(where: { $0.id == saved.id }) { products[index] = saved }
            else { products.insert(saved, at: 0) }
            toast = draft.isNew
                ? Toast(title: "Product added", message: "It appears on your website after your next deploy.")
                : Toast(title: "Changes saved", message: "Your website shows them after your next deploy.")
            return true
        } catch {
            toast = Toast(kind: .error, title: "Couldn’t save product", message: error.localizedDescription)
            return false
        }
    }

    func confirmDelete() async {
        guard let product = pendingDelete else { return }
        pendingDelete = nil
        await delete(product)
    }

    func delete(_ product: Product) async {
        do {
            try await service.deleteProduct(id: product.id, websiteID: websiteID)
            products.removeAll { $0.id == product.id }
            toast = Toast(kind: .error, title: "Product deleted", message: "“\(product.name)” is removed after your next deploy.")
        } catch {
            toast = Toast(kind: .error, title: "Couldn’t delete product", message: error.localizedDescription)
        }
    }

    func addCategory(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if !categories.contains(trimmed) { customCategories.append(trimmed) }
        return trimmed
    }
}

// MARK: - Business information

@MainActor @Observable
final class BusinessInfoViewModel {
    var info: BusinessInfo?
    var draft: BusinessInfo?
    var state: LoadState = .idle
    var isEditing = false
    var isSaving = false
    var toast: Toast?

    let websiteID: UUID
    private let service: WebBlockService
    init(websiteID: UUID, service: WebBlockService = ServiceLocator.current) {
        self.websiteID = websiteID
        self.service = service
    }

    var canSave: Bool {
        guard let draft else { return false }
        return !draft.description.isEmpty && !draft.phone.isEmpty && draft.email.contains("@") && !isSaving
    }

    func load() async {
        state = .loading
        do {
            info = try await service.businessInfo(websiteID: websiteID)
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func beginEditing() { draft = info; isEditing = true }
    func cancelEditing() { draft = nil; isEditing = false }

    func save() async {
        guard let draft else { return }
        if draft.description.trimmingCharacters(in: .whitespaces).isEmpty {
            toast = Toast(kind: .error, title: "Add a description", message: "Tell customers what your business does."); return
        }
        if draft.phone.trimmingCharacters(in: .whitespaces).isEmpty {
            toast = Toast(kind: .error, title: "Add a phone number", message: "Customers use it to reach you."); return
        }
        if !draft.email.contains("@") {
            toast = Toast(kind: .error, title: "Check your email", message: "Enter a valid email address."); return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            info = try await service.saveBusinessInfo(draft, websiteID: websiteID)
            isEditing = false
            self.draft = nil
            toast = Toast(title: "Business information saved", message: "Your website shows the new details after your next deploy.")
        } catch {
            toast = Toast(kind: .error, title: "Couldn’t save", message: error.localizedDescription)
        }
    }
}

// MARK: - Monitor

@MainActor @Observable
final class MonitorViewModel {
    var snapshot: MonitorSnapshot?
    var state: LoadState = .idle
    let websiteID: UUID
    private let service: WebBlockService
    init(websiteID: UUID, service: WebBlockService = ServiceLocator.current) {
        self.websiteID = websiteID
        self.service = service
    }

    func load(plan: PlanTier) async {
        state = .loading
        do {
            snapshot = try await service.monitor(websiteID: websiteID, plan: plan)
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
