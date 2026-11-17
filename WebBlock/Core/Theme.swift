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

    /// Solid website-blue button surface. Drawn by hand, so it looks identical on every iOS version
    /// (no translucent system glass that washes the blue out into a soft tint).
    func brandFace<S: Shape>(in shape: S, glow: Bool = true) -> some View {
        self
            // A deeper blue in Dark Mode keeps white labels readable (about 5:1 instead of 2.6:1).
            .background(Color(light: 0x4379D6, dark: 0x3466C4), in: shape)
            .overlay(shape.stroke(
                LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.08), .white.opacity(0.3)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: Color.wbBrand.opacity(glow ? 0.3 : 0), radius: 8, y: 3)
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

/// The app-wide page background (now the pale tiled blue, see `TileBackdrop`). Formerly: white page. Pass `panelHeight` (a fraction of the screen) to add a flat light-blue
/// panel with rounded bottom corners across the top, as on the websites list. No gradient and no live blur.
struct LiquidBackdrop: View {
    var panelHeight: CGFloat? = nil          // kept for existing call sites; every screen now uses the tiled page
    var body: some View { TileBackdrop() }
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
    var enabled = true
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .offset(x: enabled ? (on ? dx : -dx) : 0, y: enabled ? (on ? dy : -dy) : 0)
            .onAppear {
                guard enabled, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) { on = true }
            }
    }
}

/// Soft decorative shapes that sit in the empty parts of a screen. Purely visual, never hit-tested.
struct FloatingDecor: View {
    /// The big pale circle on the right edge; the intro turns it off because it looked messy there.
    var showCircle = true
    /// Turn the slow drift off for a completely still version.
    var animated = true
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
                        .modifier(Drift(dx: 0, dy: 8, duration: 7, delay: 0, enabled: animated))
                }

                // concentric rings bleeding off the bottom-left
                ConcentricRings(ink: ink)
                    .position(x: -10, y: h - 40)
                    .modifier(Drift(dx: 3, dy: -6, duration: 8, delay: 0.8, enabled: animated))

                // row of four small dots
                HStack(spacing: 14) {
                    ForEach(0..<4, id: \.self) { _ in Circle().fill(ink.opacity(0.38)).frame(width: 6, height: 6) }
                }
                .position(x: w * 0.62, y: h - 70)
                .modifier(Drift(dx: 8, dy: 2, duration: 5, delay: 0.6, enabled: animated))
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


// MARK: - Tiled page background + soft glass cards (Products style)

/// Pale blue page made of soft square tiles that fades to white by mid-screen.
struct TileBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    private let tile: CGFloat = 42

    var body: some View {
        let page = scheme == .dark ? Color(hex: 0x0B1220) : Color.white
        ZStack(alignment: .top) {
            page
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    LinearGradient(colors: scheme == .dark ? [Color(hex: 0x1A2B52), Color(hex: 0x0B1220)]
                                                          : [Color(hex: 0xE7EFFC), Color(hex: 0xEEF4FD), Color(hex: 0xF8FBFF)],
                                   startPoint: .top, endPoint: .bottom)
                    Canvas { ctx, size in
                        let cols = Int(size.width / tile) + 2, rows = Int(size.height / tile) + 2
                        for r in 0..<rows {
                            for c in 0..<cols {
                                // mostly flat pale blue; a handful of squares a shade deeper or lighter, scattered
                                var h = UInt32(truncatingIfNeeded: r &* 73856093 ^ c &* 19349663)
                                h = (h ^ (h >> 13)) &* 1274126177
                                let v = Int((h ^ (h >> 16)) % 100)
                                let fill: (Color, Double)
                                switch v {
                                case 0..<9:   fill = (Color(hex: 0xC9DAF6), 0.22)      // deeper
                                case 9..<20:  fill = (Color(hex: 0xD3E2F8), 0.18)      // slightly deeper
                                case 20..<30: fill = (.white, 0.35)                    // lighter
                                default: continue
                                }
                                ctx.fill(Path(CGRect(x: CGFloat(c) * tile, y: CGFloat(r) * tile, width: tile, height: tile)),
                                         with: .color(fill.0.opacity(scheme == .dark ? fill.1 * 0.22 : fill.1)))
                            }
                        }
                        var grid = Path()
                        for c in 0...cols { grid.move(to: CGPoint(x: CGFloat(c) * tile, y: 0)); grid.addLine(to: CGPoint(x: CGFloat(c) * tile, y: size.height)) }
                        for r in 0...rows { grid.move(to: CGPoint(x: 0, y: CGFloat(r) * tile)); grid.addLine(to: CGPoint(x: size.width, y: CGFloat(r) * tile)) }
                        ctx.stroke(grid, with: .color(Color(hex: 0xC6D8F5).opacity(scheme == .dark ? 0.08 : 0.20)), lineWidth: 1)
                    }
                }
                .frame(height: geo.size.height * 0.62)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.35),
                                              .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct SoftGlass: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(.ultraThinMaterial, in: shape)
            .background(scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.66), in: shape)
            .overlay(shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.35), .white.opacity(0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2))
            .overlay(shape.stroke(Color(hex: 0x3F72D0).opacity(0.10), lineWidth: 1))
            .shadow(color: Color(hex: 0x1F3C7A).opacity(0.08), radius: 12, y: 5)
    }
}

extension View {
    /// Frosted white glass card: blurred material, bright rim, soft blue shadow. Drawn by hand so it stays
    /// smooth inside scrolling lists.
    func softGlass(cornerRadius: CGFloat = 24) -> some View { modifier(SoftGlass(cornerRadius: cornerRadius)) }
}


// MARK: - DM Sans (the website's body font)

enum DMSans {
    /// Registers the bundled variable font once at launch. Falls back to the system font if it can't load.
    static func register() {
        guard let url = Bundle.main.url(forResource: "DMSans", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
    static var isAvailable: Bool { UIFont.familyNames.contains("DM Sans") }
}

extension Font {
    /// DM Sans at an exact size and weight (100–1000, 400 regular, 500 medium, 600 semibold, 700 bold).
    static func dm(_ size: CGFloat, _ weight: CGFloat = 400) -> Font {
        guard DMSans.isAvailable else {
            let w: Font.Weight = weight >= 700 ? .bold : weight >= 600 ? .semibold : weight >= 500 ? .medium : .regular
            return .system(size: size, weight: w)
        }
        let wght = NSNumber(value: 0x77676874)                    // the 'wght' variation axis
        let desc = UIFontDescriptor(fontAttributes: [
            .family: "DM Sans",
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wght: NSNumber(value: Double(weight))],
        ])
        return Font(UIFont(descriptor: desc, size: size))
    }
}


private struct WhiteCard: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(scheme == .dark ? Color(hex: 0x142038) : Color.white, in: shape)
            .overlay(shape.stroke(Color(hex: 0x3F72D0).opacity(0.10), lineWidth: 1))
            .shadow(color: Color(hex: 0x1F3C7A).opacity(0.07), radius: 10, y: 4)
    }
}

extension View {
    /// Solid white card with a hairline border and a soft shadow.
    func whiteCard(cornerRadius: CGFloat = 24) -> some View { modifier(WhiteCard(cornerRadius: cornerRadius)) }
}

// MARK: - Dynamic Type for fixed design sizes

/// Keeps a design size (e.g. 14pt semibold) but scales it with the owner's text size setting,
/// relative to the closest system text style.
private struct ScaledSystemFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: Self.style(for: size))
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }

    private static func style(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<12: .caption2
        case ..<13: .caption
        case ..<14: .footnote
        case ..<16: .subheadline
        case ..<18: .body
        case ..<21: .title3
        case ..<23: .title2
        case ..<29: .title
        default: .largeTitle
        }
    }
}

extension View {
    /// `.font(.system(size:weight:))` that follows Dynamic Type.
    func wbFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> some View {
        modifier(ScaledSystemFont(size: size, weight: weight))
    }
}
