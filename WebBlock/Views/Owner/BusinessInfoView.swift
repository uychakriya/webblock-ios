import SwiftUI

// MARK: - Business information tab

struct BusinessInfoView: View {
    @Bindable var model: BusinessInfoViewModel
    @Environment(HomeViewModel.self) private var home
    @State private var hoursExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("This is what customers see on \(home.selected?.url ?? "your website").")
                    .font(.subheadline).foregroundStyle(.wbMuted)
                SiteHeaderCard().appearAnimated()

                StateContainer(state: model.state, retry: { Task { await model.load() } }) {
                    if let info = model.info {
                        if model.isEditing, model.draft != nil { editor(info) } else { viewer(info) }
                    }
                }
            }
            .padding(.horizontal, Space.screen).padding(.vertical, Space.xs)
        }
        .scrollDismissesKeyboard(.interactively)
        .liquidBackdrop()
        .navigationTitle("Business information")
        .navigationBarTitleDisplayMode(.large)
        // While editing, "back" leaves the edit form and returns to the page you came from.
        .portalToolbar(onBack: model.isEditing ? { withAnimation { model.cancelEditing() } } : nil)
        .refreshable { await model.load() }
        .task { if model.info == nil { await model.load() } }
        .toast($model.toast)
    }

    // MARK: View mode — a summary card plus tappable rows; full data opens on tap

    private func viewer(_ info: BusinessInfo) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(spacing: Space.s) {
                    AvatarView(initials: home.selected?.initials ?? "", size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(info.name).font(.title3.bold()).foregroundStyle(.wbText)
                        Label(info.url, systemImage: "globe").font(.caption).foregroundStyle(.wbMuted).lineLimit(1)
                        Pill(text: info.type, symbol: "storefront")
                    }
                }
                Button("Edit details") { model.beginEditing() }.buttonStyle(.wbPrimary)
            }
            .wbCard()

            SectionTitle(text: "Details")
            // About, Contact and Location are shown together with their full data — no tapping needed.
            VStack(alignment: .leading, spacing: Space.m) {
                infoBlock("About") {
                    Text(info.description).font(.subheadline).foregroundStyle(.wbText)
                        .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                infoBlock("Contact") {
                    infoLine("phone", "Phone", info.phone,
                             url: URL(string: "tel:" + info.phone.filter { $0.isNumber || $0 == "+" }))
                    infoLine("envelope", "Email", info.email, url: URL(string: "mailto:" + info.email))
                }
                Divider()
                infoBlock("Location") {
                    infoLine("mappin.and.ellipse", "Address", info.address)
                    if !info.mapsLink.isEmpty {
                        infoLine("map", "Map", "Open in Google Maps", url: URL(string: info.mapsLink))
                    }
                }
            }
            .wbCard()
            .appearAnimated()

            // Opening hours is its own card and drops down in place — nothing to navigate to.
            OpeningHoursDropdown(info: info, isExpanded: hoursExpanded) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { hoursExpanded.toggle() }
            }
            .appearAnimated(index: 1)
        }
    }

    private func infoBlock<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title).font(.headline).foregroundStyle(.wbText)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One tidy row: small icon, muted label above the value. Tappable values turn blue.
    @ViewBuilder
    private func infoLine(_ symbol: String, _ label: String, _ value: String, url: URL? = nil) -> some View {
        let row = HStack(alignment: .top, spacing: Space.s) {
            Image(systemName: symbol).font(.system(size: 15, weight: .medium)).foregroundStyle(.wbBrand)
                .frame(width: 36, height: 36)
                .background(Color.wbBrandSoft, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption).foregroundStyle(.wbMuted)
                Text(value).font(.subheadline.weight(url == nil ? .regular : .medium))
                    .foregroundStyle(url == nil ? Color.wbText : Color.wbBrand)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        if let url { Link(destination: url) { row } } else { row }
    }

    // MARK: Edit mode

    private func editor(_ info: BusinessInfo) -> some View {
        let draft = Binding(get: { model.draft ?? info }, set: { model.draft = $0 })
        return VStack(alignment: .leading, spacing: Space.m) {
            // Name, type and web address are not editable in Figma.
            LabeledField(title: "Business name", text: .constant(info.name), readOnly: true)
            LabeledField(title: "Business type", text: .constant(info.type), readOnly: true)
            LabeledField(title: "Website address", text: .constant(info.url), readOnly: true)
            LabeledField(title: "Description", text: draft.description, axis: .vertical)
            LabeledField(title: "Phone", text: draft.phone, keyboard: .phonePad, contentType: .telephoneNumber)
            LabeledField(title: "Email", text: draft.email, keyboard: .emailAddress, contentType: .emailAddress, capitalization: .never)
            LabeledField(title: "Address", text: draft.address, axis: .vertical)
            LabeledField(title: "Google Maps link", text: draft.mapsLink, isOptional: true, keyboard: .URL,
                         capitalization: .never, hint: "Adds a “Get directions” link")
            SectionTitle(text: "Opening hours")
            OpeningHoursEditor(days: draft.hours)
            HStack(spacing: Space.xs) {
                Button("Cancel") { model.cancelEditing() }.buttonStyle(.wbSecondary)
                LoadingButton(title: "Save changes", isLoading: model.isSaving) { Task { await model.save() } }
            }
        }
    }
}

// MARK: - Sections

enum BusinessSection: CaseIterable, Hashable {
    case about, contact, location, hours

    var title: String {
        switch self { case .about: "About"; case .contact: "Contact"; case .location: "Location"; case .hours: "Opening hours" }
    }
    var symbol: String {
        switch self { case .about: "text.alignleft"; case .contact: "phone"; case .location: "mappin.and.ellipse"; case .hours: "clock" }
    }

    /// One short line shown on the list row.
    func preview(_ info: BusinessInfo) -> String {
        switch self {
        case .about: return info.description
        case .contact: return info.phone
        case .location: return info.address
        case .hours:
            guard info.hours.count == 7 else { return "\(info.hours.filter(\.isOpen).count) days open" }
            let today = info.hours[(Calendar.current.component(.weekday, from: .now) + 5) % 7]
            return today.isOpen
                ? "Today \(today.opens.formatted(date: .omitted, time: .shortened)) – \(today.closes.formatted(date: .omitted, time: .shortened))"
                : "Closed today"
        }
    }
}

struct BusinessSectionRow: View {
    let section: BusinessSection
    let preview: String
    var body: some View {
        HStack(spacing: Space.s) {
            IconTile(symbol: section.symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title).font(.headline).foregroundStyle(.wbText)
                Text(preview).font(.subheadline).foregroundStyle(.wbMuted).lineLimit(1)
            }
            Spacer(minLength: Space.xs)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.wbMuted)
        }
        .wbCard(padding: Space.s)
        .contentShape(Rectangle())
    }
}

/// Full data for one section, opened from the list.
struct BusinessSectionDetail: View {
    let section: BusinessSection
    let info: BusinessInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                switch section {
                case .about:
                    VStack(alignment: .leading, spacing: Space.s) {
                        DetailField(label: "Business description", value: info.description)
                    }.wbCard()
                case .contact:
                    VStack(alignment: .leading, spacing: Space.m) {
                        link(label: "Phone number", value: info.phone, symbol: "phone.fill",
                             url: URL(string: "tel:" + info.phone.filter { $0.isNumber || $0 == "+" }))
                        Divider()
                        link(label: "Email", value: info.email, symbol: "envelope.fill", url: URL(string: "mailto:" + info.email))
                    }.wbCard()
                case .location:
                    VStack(alignment: .leading, spacing: Space.m) {
                        DetailField(label: "Address", value: info.address)
                        if !info.mapsLink.isEmpty {
                            Divider()
                            link(label: "Google Maps link", value: info.mapsLink, symbol: "map.fill", url: URL(string: info.mapsLink))
                        }
                    }.wbCard()
                case .hours:
                    OpeningHoursList(days: info.hours).wbCard()
                }
            }
            .padding(.horizontal, Space.screen).padding(.vertical, Space.xs)
        }
        .background(Color(.systemBackground))
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func link(label: String, value: String, symbol: String, url: URL?) -> some View {
        if let url {
            Link(destination: url) {
                HStack {
                    DetailField(label: label, value: value, isLink: true)
                    Image(systemName: symbol).foregroundStyle(.wbBrand)
                }
            }
        } else {
            DetailField(label: label, value: value)
        }
    }
}


/// Collapsed: icon, title and today's hours. Tap to drop down the full week.
struct OpeningHoursDropdown: View {
    let info: BusinessInfo
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        VStack(spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: Space.s) {
                    IconTile(symbol: BusinessSection.hours.symbol)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Opening hours").font(.headline).foregroundStyle(.wbText)
                        Text(BusinessSection.hours.preview(info)).font(.subheadline).foregroundStyle(.wbMuted)
                    }
                    Spacer(minLength: Space.xs)
                    Image(systemName: "chevron.down").font(.footnote.weight(.bold)).foregroundStyle(.wbMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(Space.s)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                    OpeningHoursList(days: info.hours)
                }
                .padding(.horizontal, Space.s).padding(.bottom, Space.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isExpanded ? Color.wbBrandSoft.opacity(0.55) : Color.wbSoft.opacity(0.6), in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.wbBrand.opacity(isExpanded ? 0.55 : 0.28), lineWidth: 1.2))
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .accessibilityElement(children: .contain)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }
}
