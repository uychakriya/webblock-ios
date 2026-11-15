import SwiftUI

// MARK: - Business information tab

struct BusinessInfoView: View {
    @Bindable var model: BusinessInfoViewModel
    @Environment(HomeViewModel.self) private var home

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("This is what customers see on \(home.selected?.url ?? "your website").")
                    .font(.subheadline).foregroundStyle(.wbMuted)
                SiteHeaderCard()

                StateContainer(state: model.state, retry: { Task { await model.load() } }) {
                    if let info = model.info {
                        if model.isEditing, model.draft != nil { editor(info) } else { viewer(info) }
                    }
                }
            }
            .padding(.horizontal, Space.screen).padding(.vertical, Space.xs)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(.wbBackground)
        .navigationTitle("Business information")
        .navigationBarTitleDisplayMode(.large)
        .portalToolbar()
        .refreshable { await model.load() }
        .task { if model.info == nil { await model.load() } }
        .toast($model.toast)
    }

    // MARK: View mode

    private func viewer(_ info: BusinessInfo) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: Space.s) {
                    AvatarView(initials: home.selected?.initials ?? "", size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.name).font(.title3.bold()).foregroundStyle(.wbText)
                        Label(info.url, systemImage: "globe").font(.caption).foregroundStyle(.wbMuted)
                        Label("Business type: \(info.type)", systemImage: "storefront").font(.caption).foregroundStyle(.wbMuted)
                    }
                }
                Button("Edit details") { model.beginEditing() }.buttonStyle(.wbPrimary)
            }
            .wbCard()

            VStack(alignment: .leading, spacing: Space.m) {
                Text("Business details").font(.headline).foregroundStyle(.wbText)
                SectionTitle(text: "About")
                DetailField(label: "Business description", value: info.description)
                Divider()
                SectionTitle(text: "Contact")
                DetailField(label: "Phone number", value: info.phone)
                Divider()
                DetailField(label: "Email", value: info.email)
                Divider()
                SectionTitle(text: "Location")
                DetailField(label: "Address", value: info.address)
                if !info.mapsLink.isEmpty {
                    Divider()
                    DetailField(label: "Google Maps link", value: info.mapsLink, isLink: true)
                }
            }
            .wbCard()

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Opening hours").font(.headline).foregroundStyle(.wbText)
                OpeningHoursList(days: info.hours)
            }
            .wbCard()
        }
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
                    .disabled(!model.canSave)
            }
        }
    }
}
