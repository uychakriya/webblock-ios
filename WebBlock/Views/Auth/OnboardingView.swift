import SwiftUI

// MARK: - Glass + motion helpers

private extension View {
    /// Frosted-glass surface for the illustration mockups. Drawn with material (not `glassEffect`) because
    /// these cards are rotated and floating, and system glass renders larger than their layout frame there.
    func obGlass(cornerRadius: CGFloat = 22) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(.regularMaterial, in: shape)
            .background(Color.wbCard.opacity(0.88), in: shape)          // bright, mostly solid so content reads clearly
            .overlay(shape.stroke(Color.wbBrand.opacity(0.10), lineWidth: 1))
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [.white, .white.opacity(0.35), .white.opacity(0.9)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.5)
            )
            .shadow(color: Color(hex: 0x4379D6).opacity(0.07), radius: 8, y: 3)
    }

    /// Gentle endless bob so the mockups feel alive.
    func obFloat(_ distance: CGFloat = 8, duration: Double = 3, delay: Double = 0) -> some View {
        modifier(FloatModifier(distance: distance, duration: duration, delay: delay))
    }
}

private struct FloatModifier: ViewModifier {
    let distance: CGFloat, duration: Double, delay: Double
    @State private var up = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -distance : distance)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) { up = true }
            }
    }
}

/// Springs a view in (scale + slide + fade) once its page becomes active.
private struct Entrance: ViewModifier {
    let active: Bool
    let delay: Double
    var x: CGFloat = 0
    var y: CGFloat = 40

    func body(content: Content) -> some View {
        content
            .opacity(active ? 1 : 0)
            .offset(x: active ? 0 : x, y: active ? 0 : y)
            .animation(.spring(response: 0.7, dampingFraction: 0.78).delay(active ? delay : 0), value: active)
    }
}

private extension View {
    func entrance(_ active: Bool, delay: Double = 0, x: CGFloat = 0, y: CGFloat = 40) -> some View {
        modifier(Entrance(active: active, delay: delay, x: x, y: y))
    }
}

// MARK: - Animated backdrop (the website's airy white-blue canvas with a dot grid)

private struct OnboardingBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark ? Color(hex: 0x0B1220) : Color.white)
            // dotted grid, fading out toward the bottom like the landing hero
            Canvas { ctx, size in
                let step: CGFloat = 22
                let dot = Color.wbBrand.opacity(scheme == .dark ? 0.22 : 0.16)
                var y: CGFloat = 8
                while y < size.height {
                    var x: CGFloat = 8
                    while x < size.width {
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(dot))
                        x += step
                    }
                    y += step
                }
            }
            .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.7)))
            FloatingDecor(showCircle: false)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Illustrations (drawn in SwiftUI, in the WebBlock palette)

/// A phone (steel rim, black bezel, dynamic island, status bar) showing the shop's mobile page,
/// styled after the petalandstem.webblock.com mobile site.
private struct PhoneMockup: View {
    private let ink = Color(hex: 0x1F2D5A)          // headline navy on the mobile site
    private let muted = Color(hex: 0x6B7796)

    var body: some View {
        ZStack {
            // steel rim + black bezel
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xA3ABBA), Color(hex: 0x4A5368), Color(hex: 0x9AA2B2)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 22.5, style: .continuous).fill(Color(hex: 0x0E1421)).padding(1.5)

            screen
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .padding(4.5)
        }
        .frame(width: 118, height: 240)
        .overlay(alignment: .top) {                                   // dynamic island
            Capsule().fill(Color.black).frame(width: 34, height: 10).padding(.top, 9)
        }
        .overlay(alignment: .trailing) {                              // side button
            Capsule().fill(Color(hex: 0x6A7388)).frame(width: 2.5, height: 30).offset(x: 2, y: -28)
        }
        .overlay(alignment: .leading) {                               // volume buttons
            VStack(spacing: 5) {
                Capsule().fill(Color(hex: 0x6A7388)).frame(width: 2.5, height: 9)
                Capsule().fill(Color(hex: 0x6A7388)).frame(width: 2.5, height: 15)
                Capsule().fill(Color(hex: 0x6A7388)).frame(width: 2.5, height: 15)
            }
            .offset(x: -2, y: -36)
        }
        .shadow(color: Color(hex: 0x0E1421).opacity(0.25), radius: 12, y: 6)
    }

    private var screen: some View {
        VStack(spacing: 0) {
            // status bar
            HStack {
                Text("9:41").font(.system(size: 6.5, weight: .semibold))
                Spacer()
                HStack(spacing: 2) {
                    Image(systemName: "cellularbars").font(.system(size: 5.5))
                    Image(systemName: "wifi").font(.system(size: 5.5))
                    Image(systemName: "battery.100").font(.system(size: 7))
                }
            }
            .foregroundStyle(Color(hex: 0x0E1421))
            .padding(.horizontal, 11).frame(height: 24, alignment: .bottom)

            // site header: logo, Contact, menu
            HStack(spacing: 4) {
                Text("✿ Petal & Stem").font(.system(size: 5, weight: .bold)).foregroundStyle(muted.opacity(0.7))
                Spacer()
                Capsule().fill(Color.wbBrand).frame(width: 24, height: 9)
                    .overlay(Text("Contact").font(.system(size: 4.5, weight: .semibold)).foregroundStyle(.white))
                VStack(spacing: 1.5) { ForEach(0..<3, id: \.self) { _ in Capsule().fill(muted.opacity(0.6)).frame(width: 7, height: 0.8) } }
            }
            .padding(.horizontal, 8).padding(.top, 5).padding(.bottom, 5)

            // hero card
            VStack(alignment: .leading, spacing: 3.5) {
                Text("Fresh flowers for every moment.").font(.system(size: 8.6, weight: .heavy)).foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Hand-tied bouquets, single stems and event flowers, arranged in our studio and delivered across town.")
                    .font(.system(size: 4.2)).foregroundStyle(muted).lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
                Capsule().fill(Color(hex: 0x3A5FBE)).frame(height: 13)
                    .overlay(Text("Shop flowers").font(.system(size: 5.5, weight: .semibold)).foregroundStyle(.white))
                    .padding(.top, 2)
                Capsule().fill(Color.white).frame(height: 13)
                    .overlay(Capsule().stroke(Color(hex: 0xDDE3EE), lineWidth: 0.8))
                    .overlay(Text("Visit the studio").font(.system(size: 5.5, weight: .semibold)).foregroundStyle(ink))
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(hex: 0xF4F6FB), Color(hex: 0xE3E7F0)], startPoint: .top, endPoint: .bottom),
                        in: UnevenRoundedRectangle(topLeadingRadius: 9, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 9))
            .padding(.horizontal, 6)

            // photo
            Color.clear.frame(height: 62).frame(maxWidth: .infinity)
                .overlay(Image("blue-lily-stem").resizable().scaledToFill())
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 9, bottomTrailingRadius: 9, topTrailingRadius: 0))
                .padding(.horizontal, 6)

            // next section, cut off by the bottom of the screen
            Text("POPULAR THIS WEEK").font(.system(size: 3.5, weight: .medium)).foregroundStyle(muted)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .overlay(Capsule().stroke(Color(hex: 0xDDE3EE), lineWidth: 0.6))
                .padding(.top, 10)
            Text("Fresh picks, hand-tied today").font(.system(size: 7, weight: .heavy)).foregroundStyle(ink)
                .lineLimit(1).minimumScaleFactor(0.8).padding(.horizontal, 6)
                .padding(.top, 5)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .overlay(alignment: .bottom) {                                // home indicator
            Capsule().fill(Color(hex: 0x0E1421)).frame(width: 36, height: 2.5).padding(.bottom, 4)
        }
    }
}

/// Page 1: the petalandstem.webblock.com site from the website, in a glass browser with a phone preview.
private struct WebsiteIllustration: View {
    let active: Bool
    @State private var pulse = false

    private let products: [(String, String, String)] = [
        ("blue-lily-stem", "Blue lily stem", "$6.00"),
        ("gift-bouquet", "Gift bouquet", "$38.00"),
        ("stone-vase", "Stone vase", "$24.00"),
    ]

    var body: some View {
        ZStack {
            // Browser window
            VStack(spacing: 8) {
                HStack(spacing: 5) {
                    ForEach([Color.wbRed, .wbAmber, .wbGreen], id: \.self) { Circle().fill($0.opacity(0.85)).frame(width: 7, height: 7) }
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill").font(.system(size: 7))
                        Text("petalandstem.webblock.com").font(.system(size: 9, weight: .medium)).lineLimit(1)
                    }
                    .foregroundStyle(.wbMuted)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.6), in: Capsule())
                }
                // hero: copy left, photo right
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fresh flowers\nfor every moment.").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: 0x1A273D))
                        Capsule().fill(Color(hex: 0x1A273D)).frame(width: 44, height: 12)
                            .overlay(Text("Shop flowers").font(.system(size: 6, weight: .semibold)).foregroundStyle(.white))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image("table-arrangement").resizable().scaledToFill()
                        .frame(width: 96, height: 70).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(8)
                .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                // products
                HStack(spacing: 6) {
                    ForEach(products.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 2) {
                            Image(products[i].0).resizable().scaledToFill()
                                .frame(height: 50).frame(maxWidth: .infinity).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            Text(products[i].1).font(.system(size: 6, weight: .medium)).foregroundStyle(Color(hex: 0x1A273D)).lineLimit(1)
                            Text(products[i].2).font(.system(size: 6, weight: .bold)).foregroundStyle(.wbBrand)
                        }
                        .entrance(active, delay: 0.35 + Double(i) * 0.1, y: 14)
                    }
                }
            }
            .padding(12)
            .frame(width: 268)
            .obGlass(cornerRadius: 22)
            .rotationEffect(.degrees(-3))
            .offset(x: -14, y: -8)
            .obFloat(6, duration: 3.2)
            .entrance(active, delay: 0.05)

            // Phone preview: a real phone shape showing the shop's mobile page, overlapping the browser
            PhoneMockup()
                .rotationEffect(.degrees(4))
                .offset(x: 104, y: 50)
                .obFloat(8, duration: 3.4, delay: 0.3)
                .entrance(active, delay: 0.5, x: 40, y: 30)

            // Live badge
            HStack(spacing: 6) {
                Circle().fill(Color.wbGreen).frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.wbGreen.opacity(0.5), lineWidth: 2).scaleEffect(pulse ? 2.2 : 1).opacity(pulse ? 0 : 1))
                Text("Live").font(.caption.weight(.bold)).foregroundStyle(.wbText)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .obGlass(cornerRadius: 16)
            .offset(x: 96, y: -118)
            .obFloat(6, duration: 2.6, delay: 0.3)
            .entrance(active, delay: 0.3, x: 30, y: -20)

            // Globe badge
            Image(systemName: "globe")
                .font(.system(size: 24, weight: .semibold)).foregroundStyle(.wbBrand)
                .frame(width: 54, height: 54)
                .obGlass(cornerRadius: 27)
                .offset(x: -120, y: 122)
                .obFloat(9, duration: 3.6, delay: 0.5)
                .entrance(active, delay: 0.45, x: -30, y: 20)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

/// Page 2: "Three steps to a live site" — a scrolling strip of template looks above an animated step list.
private struct StepsIllustration: View {
    let active: Bool
    @State private var step = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let steps: [(String, String)] = [
        ("Pick a template", "Ready-made designs"),
        ("Add your details", "Name, hours, contact"),
        ("Publish", "Live on webblock.com"),
    ]

    var body: some View {
        VStack(spacing: 30) {
            TemplateMarquee(running: active && !reduceMotion)
                .frame(height: 74)
                .entrance(active, delay: 0.05, y: -16)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(steps.indices, id: \.self) { i in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Text("\(i + 1)").font(.system(size: 12, weight: .bold))
                                .foregroundStyle(step >= i ? .white : Color.wbBrand)
                                .frame(width: 28, height: 28)
                                .background(step >= i ? Color.wbBrand : Color.wbBrandSoft, in: Circle())
                                .scaleEffect(step == i ? 1.12 : 1)
                            if i < steps.count - 1 {
                                Capsule().fill(Color.wbBrand.opacity(0.18)).frame(width: 2, height: 26)
                                    .overlay(alignment: .top) {
                                        Capsule().fill(Color.wbBrand).frame(width: 2, height: step > i ? 26 : 0)
                                    }
                            }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(steps[i].0).font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
                            Text(steps[i].1).font(.caption).foregroundStyle(.wbMuted)
                            if i == 2 && step == 2 {
                                Label("yourshop.webblock.com", systemImage: "checkmark.circle.fill")
                                    .font(.caption2.weight(.semibold)).foregroundStyle(.wbGreen)
                                    .padding(.top, 3).transition(.scale(scale: 0.8).combined(with: .opacity))
                            }
                        }
                        .padding(.top, 3)
                        Spacer(minLength: 0)
                    }
                    .entrance(active, delay: 0.2 + Double(i) * 0.12, x: -20, y: 10)
                }
            }
            .padding(16)
            .frame(width: 274)
            .obGlass(cornerRadius: 24)
            .rotationEffect(.degrees(-2))
            .obFloat(5, duration: 3.4)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: step)
        .task(id: active) {
            step = 0
            guard active, !reduceMotion else { step = 2; return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.3))
                step = step == 2 ? 0 : step + 1
            }
        }
    }
}

/// Endlessly scrolling row of template "looks", like the website's template carousel.
private struct TemplateMarquee: View {
    let running: Bool
    private struct Look { let title: String; let bg: Color; let fg: Color; let photo: String? }
    private let looks: [Look] = [
        Look(title: "Baked fresh,\nevery morning.", bg: Color(hex: 0xFBDCE6), fg: Color(hex: 0x8A2F4D), photo: nil),
        Look(title: "Fresh flowers\nfor every moment.", bg: Color(hex: 0xF4EEE6), fg: Color(hex: 0x1A273D), photo: "table-arrangement"),
        Look(title: "Roasted this week,\nbrewed for you.", bg: Color(hex: 0x2B1D16), fg: Color(hex: 0xF3E3CF), photo: nil),
        Look(title: "Sound you\ncan feel.", bg: Color(hex: 0xECEEF2), fg: Color(hex: 0x1A273D), photo: "stone-vase"),
    ]
    private let cardW: CGFloat = 112, gap: CGFloat = 10

    var body: some View {
        TimelineView(.animation(paused: !running)) { ctx in
            let loop = (cardW + gap) * CGFloat(looks.count)
            let x = running ? -CGFloat((ctx.date.timeIntervalSinceReferenceDate * 22).truncatingRemainder(dividingBy: Double(loop))) : 0
            HStack(spacing: gap) {
                ForEach(0..<(looks.count * 2), id: \.self) { i in card(looks[i % looks.count]) }
            }
            .fixedSize()
            .offset(x: x)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 330)
        .clipped()
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.1),
                                      .init(color: .black, location: 0.9), .init(color: .clear, location: 1)],
                             startPoint: .leading, endPoint: .trailing))
    }

    private func card(_ look: Look) -> some View {
        HStack(spacing: 6) {
            Text(look.title).font(.system(size: 8, weight: .bold)).foregroundStyle(look.fg)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let photo = look.photo {
                Image(photo).resizable().scaledToFill().frame(width: 38, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(8)
        .frame(width: cardW, height: 66)
        .background(look.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
    }
}

/// Page 2: a product card and business-hours card, tilted and stacked like the reference.
private struct ProductsIllustration: View {
    let active: Bool

    var body: some View {
        ZStack {
            // Business info card (back)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill").font(.system(size: 13)).foregroundStyle(Color.wbGreen)
                        .frame(width: 30, height: 30)
                        .background(Color.wbGreenSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text("Open today").font(.caption.weight(.bold)).foregroundStyle(.wbText)
                }
                Text("9:00 AM – 6:00 PM").font(.footnote).foregroundStyle(.wbMuted)
                HStack(spacing: 4) {
                    ForEach(["M", "T", "W", "T", "F"], id: \.self) { d in
                        Text(d).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 22, height: 22).background(Color.wbBrand, in: Circle())
                    }
                }
            }
            .padding(14)
            .frame(width: 190, alignment: .leading)
            .obGlass(cornerRadius: 22)
            .rotationEffect(.degrees(7))
            .offset(x: 62, y: 66)
            .obFloat(8, duration: 3.4, delay: 0.4)
            .entrance(active, delay: 0.25, x: 40, y: 30)

            // Product card (front)
            VStack(alignment: .leading, spacing: 10) {
                Color.clear.frame(height: 104).frame(maxWidth: .infinity)
                    .overlay(Image("gift-bouquet").resizable().scaledToFill())
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gift bouquet").font(.footnote.weight(.bold)).foregroundStyle(.wbText)
                        Text("In stock").font(.caption2).foregroundStyle(.wbGreen)
                    }
                    Spacer()
                    Text("$38.00").font(.subheadline.weight(.bold)).foregroundStyle(.wbBrand)
                }
            }
            .padding(14)
            .frame(width: 196)
            .obGlass(cornerRadius: 22)
            .rotationEffect(.degrees(-6))
            .offset(x: -44, y: -34)
            .obFloat(7, duration: 3, delay: 0)
            .entrance(active, delay: 0.05, x: -40, y: 30)

            // Add badge
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(LinearGradient(colors: [Color(hex: 0x6C9BEA), Color(hex: 0x3F72D0)], startPoint: .top, endPoint: .bottom), in: Circle())
                .shadow(color: Color.wbBrand.opacity(0.45), radius: 14, y: 8)
                .offset(x: 112, y: -98)
                .obFloat(9, duration: 2.8, delay: 0.6)
                .entrance(active, delay: 0.45, x: 20, y: -30)
        }
    }
}

/// Page 3: a monitor card with a ring, bar chart and a notification bubble.
private struct MonitorIllustration: View {
    let active: Bool
    @State private var progress: CGFloat = 0
    private let bars: [CGFloat] = [0.45, 0.7, 0.55, 0.9, 0.65, 0.8, 1.0]

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Site health").font(.caption.weight(.bold)).foregroundStyle(.wbText)
                    Spacer()
                    Text("SUCCEEDED").font(.system(size: 9, weight: .heavy)).foregroundStyle(.wbGreen)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(Color.wbGreenSoft, in: Capsule())
                }
                HStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(Color.wbBrand.opacity(0.18), lineWidth: 9)
                        Circle().trim(from: 0, to: progress * 0.98)
                            .stroke(LinearGradient(colors: [Color(hex: 0x6C9BEA), Color(hex: 0x3F72D0)], startPoint: .top, endPoint: .bottom),
                                    style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("99.9%").font(.system(size: 15, weight: .bold)).foregroundStyle(.wbText)
                            Text("uptime").font(.system(size: 9)).foregroundStyle(.wbMuted)
                        }
                    }
                    .frame(width: 84, height: 84)

                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(bars.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == bars.count - 1 ? Color.wbBrand : Color.wbBrand.opacity(0.35))
                                .frame(width: 10, height: 74 * bars[i] * (active ? 1 : 0.1))
                                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.25 + Double(i) * 0.06), value: active)
                        }
                    }
                    .frame(height: 74, alignment: .bottom)
                }
            }
            .padding(16)
            .frame(width: 270)
            .obGlass(cornerRadius: 24)
            .rotationEffect(.degrees(-3))
            .obFloat(7, duration: 3.3)
            .entrance(active, delay: 0.05)

            // Notification bubble
            HStack(spacing: 8) {
                Image(systemName: "bell.fill").font(.system(size: 13)).foregroundStyle(.white)
                    .frame(width: 30, height: 30).background(Color.wbAmber, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("New order received").font(.system(size: 11, weight: .bold)).foregroundStyle(.wbText)
                    Text("just now").font(.system(size: 9)).foregroundStyle(.wbMuted)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .obGlass(cornerRadius: 20)
            .rotationEffect(.degrees(4))
            .offset(x: 28, y: 112)
            .obFloat(8, duration: 2.9, delay: 0.4)
            .entrance(active, delay: 0.4, x: 30, y: 30)

            // Shield badge
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 24)).foregroundStyle(.wbGreen)
                .frame(width: 56, height: 56)
                .obGlass(cornerRadius: 28)
                .offset(x: -118, y: -96)
                .obFloat(9, duration: 3.5, delay: 0.7)
                .entrance(active, delay: 0.5, x: -30, y: -20)
        }
        .onChange(of: active, initial: true) { _, isActive in
            if isActive {
                withAnimation(.easeOut(duration: 1.2).delay(0.3)) { progress = 1 }
            } else {
                progress = 0
            }
        }
    }
}

// MARK: - Onboarding

/// First-launch intro shown before sign-in. Four pages styled after the WebBlock website, then "Get started".
struct OnboardingView: View {
    let finish: () -> Void
    @State private var page = 0

    private struct Page: Identifiable {
        let id: Int
        let eyebrow: String
        let title: String
        let accent: String
        let message: String
    }

    private let pages: [Page] = [
        Page(id: 0, eyebrow: "Your Website", title: "A professional website\nfor your business, ", accent: "without the agency.",
             message: "See every live website you own and open its business portal in one tap."),
        Page(id: 1, eyebrow: "How It Works", title: "Three steps\nto a ", accent: "live site.",
             message: "Pick a template, add your details and publish to your free webblock.com address."),
        Page(id: 2, eyebrow: "Manage", title: "Products and business info, ", accent: "anywhere.",
             message: "Add products with photos, update prices and edit your opening hours on the go."),
        Page(id: 3, eyebrow: "Monitor", title: "Stay on top\nof your ", accent: "site.",
             message: "Monitor your site’s health and get notified the moment something needs your attention."),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            OnboardingBackdrop()

            VStack(spacing: 0) {
                HStack {
                    Image("webblocks-logo").resizable().scaledToFit().frame(height: 48)
                        .accessibilityLabel("WebBlocks")
                    Spacer()
                    Button("Skip", action: finish)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.wbMuted)
                        .opacity(isLast ? 0 : 1)
                        .accessibilityHidden(isLast)
                }
                .frame(height: 48).padding(.horizontal, Space.screen)

                GeometryReader { geo in
                // The illustrations are drawn in a 340pt-tall design box; shrink them on short phones
                // (iPhone SE / mini) so the text, dots and button always fit, and never grow past 340.
                let artHeight = min(340, max(180, geo.size.height - 250))
                let artScale = artHeight / 340
                TabView(selection: $page) {
                    ForEach(pages) { item in
                        VStack(spacing: Space.l) {
                            Spacer(minLength: 0)
                            illustration(for: item.id)
                                .frame(height: 340)
                                .scaleEffect(artScale)
                                .frame(height: artHeight)
                                .accessibilityHidden(true)
                            VStack(spacing: Space.xs) {
                                Text(item.eyebrow).font(.subheadline.weight(.semibold)).foregroundStyle(.wbBrand)
                                (Text(item.title).foregroundStyle(Color.wbText) + Text(item.accent).foregroundStyle(Color.wbBrand))
                                    .font(.system(size: 28, weight: .bold))
                                    .minimumScaleFactor(0.85)
                                    .multilineTextAlignment(.center)
                                Text(item.message).font(.body).foregroundStyle(.wbMuted)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, Space.l)
                            .opacity(page == item.id ? 1 : 0)
                            .offset(y: page == item.id ? 0 : 14)
                            .animation(.easeOut(duration: 0.45), value: page)
                            Spacer(minLength: 0)
                        }
                        .tag(item.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                }

                HStack(spacing: 8) {
                    ForEach(pages) { item in
                        Capsule().fill(item.id == page ? Color.wbBrand : Color.wbBrand.opacity(0.22))
                            .frame(width: item.id == page ? 26 : 8, height: 8)
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: page)
                .padding(.bottom, Space.l)
                .accessibilityHidden(true)

                Button(isLast ? "Get started" : "Next") {
                    if isLast { finish() } else { withAnimation(.easeInOut(duration: 0.4)) { page += 1 } }
                }
                .buttonStyle(.wbPrimary)
                .disabled(false)                      // never inherit a disabled state from a parent
                .contentShape(Capsule())
                .padding(.horizontal, Space.screen).padding(.bottom, Space.m)
                .zIndex(1)                            // keep the button above the paging view
            }
        }
    }

    @ViewBuilder
    private func illustration(for id: Int) -> some View {
        let active = page == id
        switch id {
        case 0: WebsiteIllustration(active: active)
        case 1: StepsIllustration(active: active)
        case 2: ProductsIllustration(active: active)
        default: MonitorIllustration(active: active)
        }
    }
}
