import SwiftUI

// MARK: - Card

struct CardModifier: ViewModifier {
    var padding: CGFloat = Space.m
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.wbCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(.wbBorder, lineWidth: 1))
    }
}

extension View {
    func wbCard(padding: CGFloat = Space.m) -> some View { modifier(CardModifier(padding: padding)) }
}

// MARK: - Buttons (pill-shaped, like the Figma "Sign in" and "Add product" buttons)

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: 0x4F86DD), Color(hex: 0x3A6CCB)], startPoint: .top, endPoint: .bottom))
                    .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.45)
            }
            .shadow(color: Color(hex: 0x4379D6).opacity(isEnabled ? 0.3 : 0), radius: 10, y: 5)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var destructive = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(destructive ? Color.wbRed : Color.wbText)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(configuration.isPressed ? Color.wbSoft : Color.wbCard, in: Capsule())
            .overlay(Capsule().stroke(destructive ? Color.wbRed.opacity(0.4) : Color.wbBorder, lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.5)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var wbPrimary: PrimaryButtonStyle { .init() }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    static var wbSecondary: SecondaryButtonStyle { .init() }
    static var wbDestructive: SecondaryButtonStyle { .init(destructive: true) }
}

/// Primary button that swaps its label for a spinner while work is running.
struct LoadingButton: View {
    let title: String
    var isLoading = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            if isLoading { ProgressView().tint(.white) } else { Text(title) }
        }
        .buttonStyle(.wbPrimary)
        .disabled(isLoading)
    }
}

// MARK: - Pills

struct Pill: View {
    let text: String
    var symbol: String?
    var tint: Color = .wbBrand
    var background: Color = .wbBrandSoft
    var uppercase = false
    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).imageScale(.small) }
            Text(uppercase ? text.uppercased() : text)
        }
        .font(uppercase ? .caption2.weight(.bold) : .caption.weight(.medium))
        .foregroundStyle(tint)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(background, in: Capsule())
    }
}

/// SUCCEEDED / FAILED pill used in the deploy lists.
struct ResultPill: View {
    let result: DeployResult
    var body: some View {
        Pill(text: result.rawValue,
             tint: result == .succeeded ? .wbGreen : .wbRed,
             background: result == .succeeded ? .wbGreenSoft : .wbRedSoft,
             uppercase: true)
    }
}

// MARK: - Fields

struct LabeledField: View {
    let title: String
    @Binding var text: String
    var prompt = ""
    var error: String?
    var isOptional = false
    var isSecure = false
    var revealable = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?
    var capitalization: TextInputAutocapitalization = .sentences
    var axis: Axis = .horizontal
    var readOnly = false
    var hint: String?

    @State private var revealed = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs + 2) {
            HStack(spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
                if isOptional { Text("optional").font(.caption).foregroundStyle(.wbMuted) }
            }
            HStack {
                field
                if isSecure && revealable {
                    Button { revealed.toggle() } label: {
                        Image(systemName: revealed ? "eye.slash" : "eye").foregroundStyle(.wbMuted)
                    }
                    .accessibilityLabel(revealed ? "Hide password" : "Show password")
                }
            }
            .padding(.horizontal, Space.s)
            .frame(minHeight: 48, alignment: .top)
            .padding(.vertical, axis == .vertical ? Space.xs : 0)
            .background(readOnly ? Color.wbSoft : Color.wbCard,
                        in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .stroke(error != nil ? Color.wbRed : (focused ? Color.wbBrand : Color.wbBorder), lineWidth: focused ? 1.5 : 1))
            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote).foregroundStyle(.wbRed)
            } else if let hint {
                Text(hint).font(.footnote).foregroundStyle(.wbMuted)
            }
        }
    }

    @ViewBuilder private var field: some View {
        Group {
            if isSecure && !revealed {
                SecureField(prompt, text: $text)
            } else {
                TextField(prompt, text: $text, axis: axis)
                    .lineLimit(axis == .vertical ? 3...8 : 1...1)
            }
        }
        .focused($focused)
        .keyboardType(keyboard)
        .textContentType(contentType)
        .textInputAutocapitalization(capitalization)
        .autocorrectionDisabled(keyboard == .emailAddress || isSecure)
        .disabled(readOnly)
        .foregroundStyle(readOnly ? Color.wbMuted : Color.wbText)
        .frame(minHeight: 48)
    }
}

// MARK: - Chips (Figma shows them inside a soft pill track, the selected one in white)

struct FilterChip: View {
    let title: String
    var count: Int?
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if let count { Text("\(count)").foregroundStyle(isSelected ? Color.wbBrand : Color.wbMuted) }
            }
            .font(.subheadline.weight(isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? Color.wbBrand : Color.wbMuted)
            .padding(.horizontal, 14).frame(minHeight: 36)
            .background(isSelected ? Color.wbCard : Color.clear, in: Capsule())
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ChipRow<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) { content }.padding(3)
        }
        .background(Color.wbBrandSoft.opacity(0.7), in: Capsule())
    }
}

// MARK: - Text rows

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.footnote.weight(.semibold)).textCase(.uppercase)
            .foregroundStyle(.wbMuted).tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.wbMuted)
            Spacer(minLength: Space.m)
            Text(value).foregroundStyle(.wbText).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

/// Small caption over a value, as in the Figma "Business details" card.
struct DetailField: View {
    let label: String
    let value: String
    var isLink = false
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.wbMuted)
            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(isLink ? Color.wbBrand : Color.wbText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Page header (blue title + muted subtitle, like the Figma page headers)

struct PageHeader: View {
    let title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.largeTitle.bold()).foregroundStyle(.wbBrand)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.wbMuted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - State views

struct LoadingView: View {
    var text = "Loading…"
    var body: some View {
        VStack(spacing: Space.s) { ProgressView(); Text(text).font(.subheadline).foregroundStyle(.wbMuted) }
            .frame(maxWidth: .infinity, minHeight: 240)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: retry).buttonStyle(.borderedProminent).tint(.wbBrand)
        }
    }
}

/// Switches between loading / error / content for any `LoadState`.
struct StateContainer<Content: View>: View {
    let state: LoadState
    let retry: () -> Void
    @ViewBuilder var content: Content
    var body: some View {
        switch state {
        case .idle, .loading: LoadingView()
        case .failed(let message): ErrorStateView(message: message, retry: retry)
        case .loaded: content
        }
    }
}

// MARK: - Toast

struct ToastView: View {
    let toast: Toast
    private var symbol: String {
        switch toast.kind { case .success: "checkmark.circle.fill"; case .warning: "exclamationmark.triangle.fill"; case .error: "xmark.octagon.fill" }
    }
    private var tint: Color {
        switch toast.kind { case .success: .wbGreen; case .warning: .wbAmber; case .error: .wbRed }
    }
    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            Image(systemName: symbol).foregroundStyle(tint).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title).font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
                Text(toast.message).font(.footnote).foregroundStyle(.wbMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.m)
        .background(.wbCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(tint.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, Space.screen)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func toast(_ toast: Binding<Toast?>) -> some View {
        overlay(alignment: .top) {
            if let value = toast.wrappedValue {
                ToastView(toast: value)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: value.id) {
                        UIAccessibility.post(notification: .announcement, argument: "\(value.title). \(value.message)")
                        try? await Task.sleep(for: .seconds(3.5))
                        withAnimation { toast.wrappedValue = nil }
                    }
                    .onTapGesture { withAnimation { toast.wrappedValue = nil } }
                    .padding(.top, Space.xs)
            }
        }
        .animation(.snappy, value: toast.wrappedValue)
    }
}

// MARK: - Avatar, icon tile, usage donut

struct AvatarView: View {
    let initials: String
    var size: CGFloat = 64
    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundStyle(.wbBrand)
            .frame(width: size, height: size)
            .background(.wbBrandSoft, in: Circle())
            .accessibilityHidden(true)
    }
}

struct IconTile: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.title3.weight(.medium))
            .foregroundStyle(.wbBrand)
            .frame(width: 44, height: 44)
            .background(.wbBrandSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Plan-usage donut from the Monitor page: blue normally, amber near the limit, red at the limit.
struct UsageDonut: View {
    let title: String
    let used: Int
    let limit: Int

    private var progress: Double { limit == 0 ? 0 : min(1, Double(used) / Double(limit)) }
    private var left: Int { max(0, limit - used) }
    private var atLimit: Bool { used >= limit }
    private var nearLimit: Bool { !atLimit && progress >= 0.8 }
    private var tint: Color { atLimit ? .wbRed : (nearLimit ? .wbAmber : .wbBrand) }
    private var caption: String {
        atLimit ? "Limit reached" : (nearLimit ? "\(left) left · near limit" : "\(left) left")
    }

    var body: some View {
        VStack(spacing: Space.xs) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.wbText).multilineTextAlignment(.center)
            ZStack {
                Circle().stroke(Color.wbSoft, lineWidth: 11)
                Circle().trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(used)").font(.title3.bold()).foregroundStyle(tint)
                    Text("of \(limit)").font(.caption2).foregroundStyle(.wbMuted)
                }
            }
            .frame(width: 88, height: 88)
            Text(caption).font(.caption2).foregroundStyle(atLimit || nearLimit ? tint : Color.wbMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(used) of \(limit) used, \(caption)")
    }
}

// MARK: - Opening hours

struct OpeningHoursEditor: View {
    @Binding var days: [OpeningDay]
    var body: some View {
        VStack(spacing: 0) {
            ForEach($days) { $day in
                VStack(alignment: .leading, spacing: Space.xs) {
                    Toggle(isOn: $day.isOpen) {
                        Text(day.weekday).font(.subheadline.weight(.semibold))
                    }
                    .tint(.wbBrand)
                    if day.isOpen {
                        HStack {
                            DatePicker("Opens", selection: $day.opens, displayedComponents: .hourAndMinute)
                            DatePicker("Closes", selection: $day.closes, displayedComponents: .hourAndMinute)
                        }
                        .labelsHidden()
                        .font(.subheadline)
                    } else {
                        Text("Closed all day").font(.footnote).foregroundStyle(.wbMuted)
                    }
                }
                .padding(.vertical, Space.s)
                if day.id != days.last?.id { Divider() }
            }
        }
        .wbCard(padding: Space.m)
    }
}

struct OpeningHoursList: View {
    let days: [OpeningDay]
    var body: some View {
        VStack(spacing: 0) {
            ForEach(days) { day in
                HStack {
                    Text(day.weekday).foregroundStyle(.wbText)
                    Spacer()
                    Text(day.isOpen
                         ? "\(day.opens.formatted(date: .omitted, time: .shortened)) – \(day.closes.formatted(date: .omitted, time: .shortened))"
                         : "Closed")
                        .foregroundStyle(day.isOpen ? Color.wbText : Color.wbMuted)
                }
                .font(.subheadline)
                .padding(.vertical, Space.s)
                .accessibilityElement(children: .combine)
                if day.id != days.last?.id { Divider() }
            }
        }
    }
}
