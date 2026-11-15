import SwiftUI
import UIKit

// MARK: - Colors
// Light values are sampled from the WebBlock Figma ("Final submit"): brand #4379D6, ink #1A273D, muted #657899.
// Dark values are iOS adaptations.

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }

    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

extension ShapeStyle where Self == Color {
    static var wbBrand: Color { Color(light: 0x4379D6, dark: 0x6E9BEA) }        // buttons, links, page titles
    static var wbBrandDeep: Color { Color(light: 0x2F63C0, dark: 0x4F86DD) }    // gradient end / pressed
    static var wbBackground: Color { Color(light: 0xF6F8FD, dark: 0x0B1220) }
    static var wbCard: Color { Color(light: 0xFFFFFF, dark: 0x131B2E) }
    static var wbText: Color { Color(light: 0x1A273D, dark: 0xEAF0FB) }
    static var wbMuted: Color { Color(light: 0x657899, dark: 0x98A6C4) }
    static var wbBorder: Color { Color(light: 0xE1E8F5, dark: 0x26314B) }
    static var wbBrandSoft: Color { Color(light: 0xE6EEFB, dark: 0x1D2C4D) }    // icon tiles, selected rows
    static var wbSoft: Color { Color(light: 0xF0F4FB, dark: 0x18223A) }         // table headers, tracks
    static var wbGreen: Color { Color(light: 0x1E9E64, dark: 0x4CC38A) }
    static var wbGreenSoft: Color { Color(light: 0xE3F5EC, dark: 0x12301F) }
    static var wbAmber: Color { Color(light: 0xE59A1A, dark: 0xF0B14A) }
    static var wbAmberSoft: Color { Color(light: 0xFDF0D8, dark: 0x3A2A0C) }
    static var wbRed: Color { Color(light: 0xDC3F45, dark: 0xF07A6E) }
    static var wbRedSoft: Color { Color(light: 0xFDE8E8, dark: 0x3A1616) }
    static var wbPurple: Color { Color(light: 0x7C4DCC, dark: 0xB195EE) }
    static var wbPurpleSoft: Color { Color(light: 0xEFE7FB, dark: 0x2A1F45) }
}

// MARK: - Spacing (8 pt system) and radii

enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let screen: CGFloat = 18      // horizontal screen padding (16–20 pt)
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
}

enum Radius {
    static let control: CGFloat = 14
    static let card: CGFloat = 24
}

// MARK: - Figma-style backdrops

/// Sign-in backdrop: plain white page.
struct AuthBackground: View {
    var body: some View { LiquidBackdrop() }
}

/// The WebBlock mark: a blue rounded square with four dots, as in the Figma header.
struct BrandMark: View {
    var size: CGFloat = 36
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0x6C9BEA), Color(hex: 0x3F72D0)], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay {
                let dot = size * 0.2
                VStack(spacing: size * 0.1) {
                    HStack(spacing: size * 0.1) { dotView(dot); dotView(dot) }
                    HStack(spacing: size * 0.1) { dotView(dot); dotView(dot) }
                }
            }
            .shadow(color: Color(hex: 0x4379D6).opacity(0.3), radius: 6, y: 3)
            .accessibilityHidden(true)
    }

    private func dotView(_ side: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: side * 0.3, style: .continuous).fill(.white.opacity(0.95)).frame(width: side, height: side)
    }
}

// MARK: - Surface style

extension View {
    /// The app's one surface style, drawn identically on every iOS version (no system Liquid Glass, no
    /// live blur), so the UI looks the same everywhere and scrolling stays cheap. `tint` fills the shape
    /// with a solid colour (buttons, pills); without it the shape is a plain card. `interactive` is kept
    /// for source compatibility; press feedback comes from the button styles.
    func glass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        self
            .background(tint ?? Color.wbCard, in: shape)
            .overlay(shape.stroke(Color.wbBrand.opacity(tint == nil ? 0.10 : 0.0), lineWidth: 1))
    }

    /// Real see-through glass for buttons and the dock. iOS 26 gets system Liquid Glass; earlier
    /// versions get a frosted material with the same bright rim, so they look alike everywhere.
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false, glow: Bool = true) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(Self.glassStyle(tint: tint, interactive: interactive), in: shape)
        } else {
            // Same look without system glass: a lit gradient, a soft top highlight and a bright rim.
            self
                .background(.ultraThinMaterial, in: shape)
                .background(
                    LinearGradient(colors: tint.map { [$0.opacity(0.80), $0] } ?? [Color.white.opacity(0.45), Color.white.opacity(0.25)],
                                   startPoint: .top, endPoint: .bottom), in: shape)
                .overlay(shape.stroke(
                    LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.15), .white.opacity(0.6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                .shadow(color: (tint ?? Color.wbBrand).opacity(glow ? 0.25 : 0), radius: 10, y: 4)
        }
    }

    /// The glass-button look drawn by hand (lit gradient, bright rim, soft glow) with no live system effect.
    /// Used for chips, segment pills and small buttons inside scrolling rows, where system glass can draw a
    /// grey box behind them or slow scrolling. Looks the same on every iOS version.
    func glassFace<S: Shape>(in shape: S, tint: Color? = nil, glow: Bool = true) -> some View {
        self
            .background(
                LinearGradient(colors: tint.map { [$0.opacity(0.82), $0] } ?? [Color.wbCard, Color.wbCard.opacity(0.88)],
                               startPoint: .top, endPoint: .bottom), in: shape)
            .overlay(shape.stroke(
                LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.15), .white.opacity(0.6)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: (tint ?? Color.wbBrand).opacity(glow ? 0.22 : 0), radius: 8, y: 3)
    }

    @available(iOS 26, *)
    fileprivate static func glassStyle(tint: Color?, interactive: Bool) -> Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint) }
        return interactive ? g.interactive() : g
    }

    /// Puts the plain white canvas (with the floating decorations) behind a screen.
    func liquidBackdrop(panelHeight: CGFloat? = nil) -> some View { background { LiquidBackdrop(panelHeight: panelHeight) } }
}

/// White page (navy in dark mode). Pass `panelHeight` (a fraction of the screen) to add a flat light-blue
/// panel with rounded bottom corners across the top, as on the websites list. No gradient and no live blur.
struct LiquidBackdrop: View {
    var panelHeight: CGFloat? = nil
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                (scheme == .dark ? Color(hex: 0x0B1220) : Color.white)
                if let panelHeight {
                    UnevenRoundedRectangle(bottomLeadingRadius: 36, bottomTrailingRadius: 36, style: .continuous)
                        .fill(scheme == .dark ? Color(hex: 0x1A2B52) : Color(hex: 0xDCE7FA))
                        .frame(height: geo.size.height * panelHeight)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Header for the websites page, in the logo's colours: its blue squares blending into its purple square
/// across the top, with a soft lilac glow (the mascot), easing into the page colour by mid-screen.
struct HeroBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let page = scheme == .dark ? Color(hex: 0x0B1220) : Color.white
        ZStack {
            page
            // logo blue → logo purple, left to right
            LinearGradient(colors: [Color(hex: 0x3B6FE6), Color(hex: 0x5A7BEF), Color(hex: 0x8B5CF6)],
                           startPoint: .topLeading, endPoint: .topTrailing)
                .mask(LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0.85), location: 0.25),
                    .init(color: .clear, location: 0.52),
                ], startPoint: .top, endPoint: .bottom))
            // lilac glow from the mascot, top right
            RadialGradient(colors: [Color(hex: 0xD9CCFB).opacity(scheme == .dark ? 0.15 : 0.45), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 320)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Floating decoration (used on the intro screen)

private struct Drift: ViewModifier {
    let dx: CGFloat, dy: CGFloat, duration: Double, delay: Double
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .offset(x: on ? dx : -dx, y: on ? dy : -dy)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) { on = true }
            }
    }
}

/// Soft decorative shapes that sit in the empty parts of a screen. Purely visual, never hit-tested.
struct FloatingDecor: View {
    /// The big pale circle on the right edge; the intro turns it off because it looked messy there.
    var showCircle = true
    @Environment(\.colorScheme) private var scheme
    private var ink: Color { Color.wbBrand.opacity(scheme == .dark ? 0.55 : 1) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                if showCircle {
                    Circle().fill(ink.opacity(0.07))
                        .overlay(Circle().stroke(ink.opacity(0.10), lineWidth: 1))
                        .frame(width: 240)
                        .position(x: w + 30, y: h * 0.62)
                        .modifier(Drift(dx: 0, dy: 8, duration: 7, delay: 0))
                }

                // concentric rings bleeding off the bottom-left
                ConcentricRings(ink: ink)
                    .position(x: -10, y: h - 40)
                    .modifier(Drift(dx: 3, dy: -6, duration: 8, delay: 0.8))

                // row of four small dots
                HStack(spacing: 14) {
                    ForEach(0..<4, id: \.self) { _ in Circle().fill(ink.opacity(0.38)).frame(width: 6, height: 6) }
                }
                .position(x: w * 0.62, y: h - 70)
                .modifier(Drift(dx: 8, dy: 2, duration: 5, delay: 0.6))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct DotMatrix: View {
    let rows: Int, columns: Int
    let ink: Color
    var spacing: CGFloat = 13
    var dot: CGFloat = 6
    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { column in
                        // fades out toward the right edge
                        Circle().fill(ink.opacity(0.55 * (1 - Double(column) / Double(max(columns, 1)))))
                            .frame(width: dot, height: dot)
                    }
                }
            }
        }
    }
}

struct ConcentricRings: View {
    let ink: Color
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle().stroke(ink.opacity(0.10 - Double(i) * 0.02), lineWidth: 1)
                    .frame(width: 130 + CGFloat(i) * 60, height: 130 + CGFloat(i) * 60)
            }
        }
    }
}
