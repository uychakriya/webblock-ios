import SwiftUI

// MARK: - Card

struct CardModifier: ViewModifier {
    var padding: CGFloat = Space.m
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Color.wbBrand.opacity(0.12), lineWidth: 1))
    }
}

extension View {
    func wbCard(padding: CGFloat = Space.m) -> some View { modifier(CardModifier(padding: padding)) }
}

// MARK: - Motion

/// Press feedback for tappable cards: springs down on touch, bounces back on release.
/// With `spotify: true` it also behaves like a Spotify card: the background lightens and a round
/// action button fades in and slides up from the bottom-right corner on hover (iPad pointer) or press.
struct CardPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var spotify = false
    func makeBody(configuration: Configuration) -> some View {
        CardPressBody(configuration: configuration, scale: scale, spotify: spotify)
    }
}

private struct CardPressBody: View {
    let configuration: ButtonStyleConfiguration
    let scale: CGFloat
    let spotify: Bool
    @State private var hovering = false
    private var active: Bool { configuration.isPressed || hovering }

    var body: some View {
        configuration.label
            .overlay {
                if spotify {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(Color.wbBrand.opacity(active ? 0.07 : 0))
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if spotify {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.wbBrand, in: Circle())
                        .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
                        .scaleEffect(configuration.isPressed ? 1.08 : 1)
                        .opacity(active ? 1 : 0)
                        .offset(y: active ? 0 : 10)
                        .padding(Space.s)
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(configuration.isPressed ? scale : (hovering && spotify ? 1.015 : 1))
            .shadow(color: .black.opacity(spotify && active ? 0.14 : 0), radius: 14, y: 8)
            .animation(.spring(response: 0.32, dampingFraction: 0.68), value: active)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, new in new }
    }
}

extension ButtonStyle where Self == CardPressStyle {
    static var wbCardPress: CardPressStyle { .init() }
    static var wbSpotifyCard: CardPressStyle { .init(scale: 0.98, spotify: true) }
}

/// Fades + slides a view in when it first appears; `index` staggers siblings.
struct AppearModifier: ViewModifier {
    var index = 0
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .scaleEffect(shown ? 1 : 0.96)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(min(index, 8)) * 0.06)) {
                    shown = true
                }
            }
    }
}

extension View {
    func appearAnimated(index: Int = 0) -> some View { modifier(AppearModifier(index: index)) }
}

// MARK: - Buttons (pill-shaped, like the Figma "Sign in" and "Add product" buttons)

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .liquidGlass(in: Capsule(), tint: Color(hex: 0x3F72D0), interactive: true)
            .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.2), value: isEnabled)
            .hoverEffect(.highlight)
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
            // Destructive buttons share Cancel's look (same glass and thin outline); only the text is red.
            .liquidGlass(in: Capsule(), interactive: true)
            .overlay(Capsule().strokeBorder(Color.wbBrand.opacity(0.18), lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .hoverEffect(.highlight)
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
            ZStack {
                if isLoading { ProgressView().tint(.white).transition(.scale.combined(with: .opacity)) }
                else { Text(title).transition(.scale.combined(with: .opacity)) }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isLoading)
        }
        .buttonStyle(.wbPrimary)
        .allowsHitTesting(!isLoading)        // ignore taps while working, but stay solid blue
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
        .glass(in: Capsule(), tint: background.opacity(0.9))
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
            .padding(.horizontal, axis == .vertical ? Space.s : Space.m)
            .frame(minHeight: 50, alignment: .top)
            .padding(.vertical, axis == .vertical ? Space.xs : 0)
            .glass(in: fieldShape, tint: readOnly ? Color.wbSoft : nil)
            .overlay(fieldShape
                .stroke(error != nil ? Color.wbRed : (focused ? Color.wbBrand : Color.wbBrand.opacity(readOnly ? 0.15 : 0.3)),
                        lineWidth: focused || error != nil ? 1.5 : 1))
            .animation(.easeInOut(duration: 0.2), value: focused)
            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote).foregroundStyle(.wbRed)
            } else if let hint {
                Text(hint).font(.footnote).foregroundStyle(.wbMuted)
            }
        }
    }

    /// Single-line fields are pill-shaped like the buttons; multi-line ones keep soft rounded corners.
    private var fieldShape: AnyShape {
        axis == .vertical
            ? AnyShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            : AnyShape(Capsule())
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
    @Namespace private var fallback
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if let count { Text("\(count)").opacity(0.6) }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : Color.wbText)
            .padding(.horizontal, 18).frame(minHeight: 44)
            // Hand-drawn glass (not system glass): system glass inside a clipped, scrolling row draws a grey box.
            .glassFace(in: Capsule(), tint: isSelected ? Color(hex: 0x3F72D0) : nil, glow: false)   // flat: no shadow
            .overlay { if !isSelected { Capsule().stroke(Color.wbBrand.opacity(0.3), lineWidth: 1) } }
            .scaleEffect(isSelected ? 1.04 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isSelected)
        }
        .buttonStyle(.wbCardPress)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

/// Horizontally scrolling row of separate pill chips (outlined, with the selected one filled).
/// It stays inside the same left and right edges as the cards; swipe sideways to reach the rest.
/// The chip cut off at the right edge is the hint that there is more.
struct ChipRow<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.xs) { content }
                .padding(.vertical, 4).padding(.horizontal, 2)
        }
        .scrollBounceBehavior(.always, axes: .horizontal)
    }
}

/// Wraps its children onto new lines so they stay inside the same width as the form fields.
struct FlowLayout: Layout {
    var spacing: CGFloat = Space.xs

    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (frames, CGSize(width: maxX, height: y + rowHeight))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal.width ?? .infinity, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(bounds.width, subviews)
        for (view, frame) in zip(subviews, result.frames) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }
}

// MARK: - Text rows

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.subheadline.weight(.semibold))
            .foregroundStyle(.wbMuted)
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
            Text(title).font(.title2.bold()).foregroundStyle(.wbBrand)
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
        // Fully opaque (white base + a light tint on top) so the page content can't show through the text.
        .background(Color.wbCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(tint.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
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
            .glass(in: Circle(), tint: Color.wbBrand.opacity(0.18))
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
            .glass(in: RoundedRectangle(cornerRadius: 14, style: .continuous), tint: Color.wbBrand.opacity(0.18))
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

    /// A single clean row: title + count on top, progress bar, status caption.
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.wbText)
                Spacer(minLength: Space.xs)
                Text("\(used)").font(.subheadline.weight(.bold)).foregroundStyle(.wbText)
                + Text(" / \(limit)").font(.subheadline).foregroundStyle(.wbMuted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.wbSoft)
                    Capsule().fill(tint).frame(width: max(8, geo.size.width * progress))
                }
            }
            .frame(height: 8)
            Text(caption).font(.caption).foregroundStyle(atLimit || nearLimit ? tint : Color.wbMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(used) of \(limit) used, \(caption)")
    }
}

// MARK: - Opening hours

/// Opening-hours editor: one compact row per day (name, summary, on/off switch).
/// Tap a row to expand it and edit that day's times; only one day is open at a time.
struct OpeningHoursEditor: View {
    @Binding var days: [OpeningDay]
    @State private var expanded: UUID?

    var body: some View {
        VStack(spacing: Space.xs) {
            ForEach($days) { $day in
                row($day)
            }
        }
    }

    private func summary(_ day: OpeningDay) -> String {
        day.isOpen
            ? "\(day.opens.formatted(date: .omitted, time: .shortened)) – \(day.closes.formatted(date: .omitted, time: .shortened))"
            : "Closed"
    }

    private func row(_ day: Binding<OpeningDay>) -> some View {
        let isExpanded = expanded == day.wrappedValue.id && day.wrappedValue.isOpen
        let openBinding = Binding(
            get: { day.wrappedValue.isOpen },
            set: { newValue in
                day.wrappedValue.isOpen = newValue
                withAnimation(.snappy) {
                    if newValue { expanded = day.wrappedValue.id }
                    else if expanded == day.wrappedValue.id { expanded = nil }
                }
            })
        return VStack(spacing: 0) {
            HStack(spacing: Space.s) {
                Button {
                    guard day.wrappedValue.isOpen else { return }
                    withAnimation(.snappy) { expanded = isExpanded ? nil : day.wrappedValue.id }
                } label: {
                    HStack(spacing: Space.s) {
                        Image(systemName: "calendar").font(.system(size: 18, weight: .medium))
                            .foregroundStyle(day.wrappedValue.isOpen ? Color.wbBrand : Color.wbMuted)
                            .frame(width: 44, height: 44)
                            .background(Color.wbBrandSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.wrappedValue.weekday).font(.headline).foregroundStyle(.wbText)
                            Text(summary(day.wrappedValue)).font(.subheadline)
                                .foregroundStyle(day.wrappedValue.isOpen ? Color.wbBrand : Color.wbMuted)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Toggle("\(day.wrappedValue.weekday) open", isOn: openBinding).labelsHidden().tint(.wbBrand)
            }
            .padding(Space.s)

            if isExpanded {
                VStack(spacing: Space.s) {
                    Divider().overlay(Color.wbBrand.opacity(0.15))
                    HStack(spacing: Space.s) {
                        timeField("Opens", selection: day.opens)
                        timeField("Closes", selection: day.closes)
                    }
                }
                .padding(.horizontal, Space.s).padding(.bottom, Space.s)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isExpanded ? Color.wbBrandSoft.opacity(0.55) : Color.wbCard,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(Color.wbBrand.opacity(isExpanded ? 0.45 : 0.15), lineWidth: 1.2))
        .shadow(color: Color.wbBrand.opacity(isExpanded ? 0.10 : 0), radius: 10, y: 4)
        .accessibilityElement(children: .contain)
    }

    private func timeField(_ title: String, selection: Binding<Date>) -> some View {
        TimeField(title: title, selection: selection)
    }
}

/// "Opens" / "Closes" field: clock label, then a white pill with the time and a chevron.
/// Tapping it pops up a wheel to pick the time.
private struct TimeField: View {
    let title: String
    @Binding var selection: Date
    @State private var picking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "clock").font(.subheadline).foregroundStyle(.wbMuted)
            Button { picking = true } label: {
                HStack {
                    Text(selection.formatted(date: .omitted, time: .shortened))
                        .font(.body).foregroundStyle(.wbText)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down").font(.footnote.weight(.semibold)).foregroundStyle(.wbMuted)
                }
                .padding(.horizontal, Space.m).frame(height: 48)
                .background(Color.wbCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color(hex: 0x1F3C7A).opacity(0.08), radius: 6, y: 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.wbCardPress)
            .accessibilityLabel("\(title), \(selection.formatted(date: .omitted, time: .shortened))")
            .popover(isPresented: $picking) {
                DatePicker(title, selection: $selection, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden()
                    .frame(width: 260)
                    .padding(Space.s)
                    .presentationCompactAdaptation(.popover)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Glass dock (floating tab bar whose notch follows the selected tab)

/// A pill with a round cutout in its top edge at `notchCenter`, so a circular button sits snugly inside it.
struct DockShape: Shape {
    var notchCenter: CGFloat
    var notchRadius: CGFloat = 35      // the cutout is a circle centred on the bar's top edge
    var fillet: CGFloat = 12           // softens where the cutout meets the top edge

    var animatableData: CGFloat {
        get { notchCenter }
        set { notchCenter = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let h = rect.height, r = h / 2, R = notchRadius, f = fillet
        let cx = min(max(notchCenter, rect.minX + r + R + f), rect.maxX - r - R - f)
        let cy = rect.minY
        // where the fillet curves land on the circle (20° below horizontal on each side)
        let theta = 20.0 * .pi / 180
        let left = CGPoint(x: cx - R * cos(theta), y: cy + R * sin(theta))

        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: cx - R - f, y: rect.minY))
        p.addQuadCurve(to: left, control: CGPoint(x: cx - R, y: rect.minY))
        p.addArc(center: CGPoint(x: cx, y: cy), radius: R,
                 startAngle: .degrees(180 - 20), endAngle: .degrees(20), clockwise: true)
        p.addQuadCurve(to: CGPoint(x: cx + R + f, y: rect.minY), control: CGPoint(x: cx + R, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.midY), radius: r,
                 startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.midY), radius: r,
                 startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// Liquid Glass dock with the three portal tabs. The selected tab rises into a round button in the notch.
struct GlassDock: View {
    @Binding var selection: PortalTab

    private struct Item { let tab: PortalTab; let title: String; let symbol: String }
    private let items = [
        Item(tab: .products, title: "Products", symbol: "shippingbox"),
        Item(tab: .info, title: "Business", symbol: "storefront"),
        Item(tab: .monitor, title: "Monitor", symbol: "waveform.path.ecg"),
    ]
    private let barHeight: CGFloat = 64
    private let lift: CGFloat = 28          // how far the round button rises above the bar
    private let sideInset: CGFloat = 30     // keeps the notch clear of the rounded ends

    private var index: Int { items.firstIndex { $0.tab == selection } ?? 0 }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let tabWidth = (width - sideInset * 2) / CGFloat(items.count)
            let notchX = sideInset + tabWidth * (CGFloat(index) + 0.5)

            ZStack(alignment: .topLeading) {
                // bar
                HStack(spacing: 0) {
                    ForEach(items.indices, id: \.self) { i in tab(items[i], selected: i == index) }
                }
                .padding(.horizontal, sideInset)
                .frame(width: width, height: barHeight)
                .liquidGlass(in: DockShape(notchCenter: notchX))
                .overlay(
                    DockShape(notchCenter: notchX).stroke(
                        LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.25), .white.opacity(0.8)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2))
                .overlay(DockShape(notchCenter: notchX).stroke(Color.wbBrand.opacity(0.12), lineWidth: 1))
                .shadow(color: Color.wbBrand.opacity(0.10), radius: 10, y: 4)
                .offset(y: lift)

                // floating round button showing the selected tab
                Image(systemName: items[index].symbol)
                    .font(.system(size: 21, weight: .semibold)).foregroundStyle(.white)
                    .id(items[index].symbol)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .frame(width: 54, height: 54)
                    .liquidGlass(in: Circle(), tint: Color(hex: 0x3F72D0), interactive: true)
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    .shadow(color: Color.wbBrand.opacity(0.28), radius: 6, y: 3)
                    .position(x: notchX, y: lift)
                    .allowsHitTesting(false)
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: selection)
        }
        .frame(height: barHeight + lift)
        .padding(.horizontal, Space.m)
        .padding(.bottom, -20)             // drops the dock into the home-indicator gap, closer to the screen edge
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func tab(_ item: Item, selected: Bool) -> some View {
        Button { selection = item.tab } label: {
            VStack(spacing: 3) {
                Image(systemName: item.symbol).font(.system(size: 20, weight: .medium))
                    .frame(height: 24)
                    .opacity(selected ? 0 : 1)             // the selected icon lives in the round button
                Text(item.title).font(.system(size: 10, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(selected ? Color.wbBrand : Color.wbText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}


// MARK: - Segmented control (app style, identical on every iOS version)

struct WBSegmented<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    @Binding var selection: Value
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { i in
                let on = options[i].value == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = options[i].value }
                } label: {
                    Text(options[i].label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(on ? Color.white : Color.wbText)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background {
                            if on { Capsule().fill(.clear).glassFace(in: Capsule(), tint: Color(hex: 0x3F72D0)).matchedGeometryEffect(id: "pill", in: pill) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.wbBrandSoft, in: Capsule())
    }
}

// MARK: - Text prompt (replaces the system alert with a text field)

struct WBPrompt: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let confirmTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture(perform: onCancel)
            VStack(spacing: Space.m) {
                Text(title).font(.headline).foregroundStyle(.wbText)
                TextField(placeholder, text: $text)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(onConfirm)
                    .padding(.horizontal, Space.m).frame(height: 48)
                    .background(Color.wbBrandSoft.opacity(0.6), in: Capsule())
                HStack(spacing: Space.s) {
                    Button("Cancel", action: onCancel).buttonStyle(.wbSecondary)
                    Button(confirmTitle, action: onConfirm).buttonStyle(.wbPrimary)
                }
            }
            .padding(Space.l)
            .frame(maxWidth: 340)
            .background(Color.wbCard, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            .padding(.horizontal, Space.screen)
        }
        .transition(.opacity)
        .onAppear { focused = true }
        .accessibilityAddTraits(.isModal)
    }
}


// MARK: - Keyboard visibility

/// Tracks whether the on-screen keyboard is up, so floating bars and buttons can get out of its way.
@MainActor @Observable
final class KeyboardWatcher {
    var isVisible = false
    init() {
        let nc = NotificationCenter.default
        _ = nc.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isVisible = true }
        }
        _ = nc.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isVisible = false }
        }
    }
}


/// The same switch as `WBSegmented`, with an icon in each segment (grid / list).
struct WBIconSegmented<Value: Hashable>: View {
    let options: [(symbol: String, label: String, value: Value)]
    @Binding var selection: Value
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { i in
                let on = options[i].value == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = options[i].value }
                } label: {
                    Image(systemName: options[i].symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(on ? Color.white : Color.wbText)
                        .frame(width: 44, height: 30)
                        .background {
                            if on { Capsule().fill(.clear).glassFace(in: Capsule(), tint: Color(hex: 0x3F72D0)).matchedGeometryEffect(id: "pill", in: pill) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(options[i].label)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.wbBrandSoft, in: Capsule())
    }
}


// MARK: - Empty state (app style)

/// Friendly empty state: the icon in soft layered blue circles, a bold title, a short line and an optional button.
struct WBEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @State private var float = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Space.m) {
            ZStack {
                Circle().fill(Color.wbBrandSoft.opacity(0.45)).frame(width: 150, height: 150)
                Circle().fill(Color.wbBrandSoft).frame(width: 112, height: 112)
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0x6C9BEA), Color(hex: 0x3F72D0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 76, height: 76)
                    .shadow(color: Color(hex: 0x3F72D0).opacity(0.35), radius: 12, y: 6)
                Image(systemName: symbol).font(.system(size: 30, weight: .semibold)).foregroundStyle(.white)
                // little sparkles around the circles
                Image(systemName: "sparkle").font(.system(size: 14, weight: .bold)).foregroundStyle(Color(hex: 0x8B5CF6))
                    .offset(x: 62, y: -50)
                Circle().fill(Color.wbBrand.opacity(0.35)).frame(width: 8, height: 8).offset(x: -66, y: 38)
                Circle().fill(Color(hex: 0x8B5CF6).opacity(0.35)).frame(width: 6, height: 6).offset(x: -48, y: -60)
            }
            .offset(y: float ? -4 : 4)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { float = true }
            }
            .accessibilityHidden(true)

            VStack(spacing: Space.xs) {
                Text(title).font(.title3.bold()).foregroundStyle(.wbText)
                Text(message).font(.subheadline).foregroundStyle(.wbMuted).multilineTextAlignment(.center)
            }
            .padding(.horizontal, Space.l)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.wbSecondary)
                    .frame(maxWidth: 220)
                    .padding(.top, Space.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
