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
    static let card: CGFloat = 16
}

// MARK: - Figma-style backdrops

/// The soft pink → blue wash behind the Figma sign-in page.
struct AuthBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(hex: 0x0B1220), Color(hex: 0x101B33)]
                : [Color(hex: 0xF4E3F2), Color(hex: 0xDEE8FA), Color(hex: 0xD3E0F6)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
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
