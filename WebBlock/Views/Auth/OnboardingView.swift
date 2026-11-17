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
            .animation(.spring(response: 0.38, dampingFraction: 0.82).delay(active ? delay * 0.35 : 0), value: active)
    }
}

/// Text reveal for the active page: fades in, rises and sharpens from a light blur, staggered by `delay`.
/// With Reduce Motion it only fades.
private struct Reveal: ViewModifier {
    let shown: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content        // no motion: text is simply there
    }
}

/// A single light sweep across the call-to-action when it changes to "Get started". Never hit-tested.
private struct Sheen: View {
    let trigger: Bool
    @State private var position: CGFloat = -0.5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, .white.opacity(0.38), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: geo.size.width * 0.35)
                .rotationEffect(.degrees(12))
                .offset(x: position * geo.size.width)
        }
        .mask(Capsule())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, now in
            guard now, !reduceMotion else { return }
            position = -0.5
            withAnimation(.easeInOut(duration: 0.9).delay(0.2)) { position = 1.1 }
        }
    }
}

/// The 3D stage for a page's illustration, timed like a camera move in a product film: it arrives from depth
/// (tilted back, small, out of focus), lands in a gentle three-quarter view over a soft ground shadow, then drifts
/// very slowly while its page is on screen. When the intro ends it pushes toward the viewer and fades.
/// The drift pauses when the page is not showing or the app is in the background. Reduce Motion: fades only.
private struct HeroStage: ViewModifier {
    let active: Bool
    let exiting: Bool
    @State private var arrived = false
    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content        // no arrival, drift or exit motion
    }
}

private extension View {
    func heroStage(active: Bool, exiting: Bool) -> some View {
        modifier(HeroStage(active: active, exiting: exiting))
    }

    /// Layered parallax while pages are swiped: the layer lags (or leads) the page by `shift` of its width
    /// and turns in perspective by up to `turn` degrees. Driven by geometry, so it follows the finger exactly.
    func swipeParallax(pageWidth: CGFloat, shift: CGFloat, turn: Double = 0, enabled: Bool) -> some View {
        visualEffect { content, proxy in
            let progress = enabled && pageWidth > 0 ? (proxy.frame(in: .global).midX - pageWidth / 2) / pageWidth : 0
            return content
                .offset(x: -progress * pageWidth * shift)
                .rotation3DEffect(.degrees(Double(progress) * -turn), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        }
    }

    func reveal(_ shown: Bool, delay: Double = 0) -> some View {
        modifier(Reveal(shown: shown, delay: delay))
    }

    func entrance(_ active: Bool, delay: Double = 0, x: CGFloat = 0, y: CGFloat = 40) -> some View {
        modifier(Entrance(active: active, delay: delay, x: x, y: y))
    }
}

// MARK: - Animated backdrop (the website's airy white-blue canvas with a dot grid)

private struct OnboardingBackdrop: View {
    var page = 0
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

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
            FloatingDecor(showCircle: false, animated: false)
            ambientGlow
        }
        .ignoresSafeArea()
    }

    /// Two soft glows: they glide across as the pages change and breathe very slowly.
    private var ambientGlow: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let step = CGFloat(page)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.wbBrand.opacity(scheme == .dark ? 0.22 : 0.13), .clear],
                                         center: .center, startRadius: 0, endRadius: w * 0.55))
                    .frame(width: w * 1.1, height: w * 1.1)
                    .scaleEffect(breathe ? 1.06 : 0.95)
                    .position(x: w * (0.12 + 0.25 * step), y: h * 0.30)
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0x8B5CF6).opacity(scheme == .dark ? 0.14 : 0.08), .clear],
                                         center: .center, startRadius: 0, endRadius: w * 0.45))
                    .frame(width: w * 0.9, height: w * 0.9)
                    .scaleEffect(breathe ? 0.96 : 1.05)
                    .position(x: w * (0.92 - 0.22 * step), y: h * 0.66)
            }
        }
        .allowsHitTesting(false)
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
        .frame(width: 132, height: 268)
        .overlay(alignment: .top) {                                   // dynamic island
            Capsule().fill(Color.black).frame(width: 38, height: 11).padding(.top, 10)
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
                Text("9:41").font(.system(size: 8, weight: .semibold))
                Spacer()
                Image(systemName: "battery.100").font(.system(size: 9))
            }
            .foregroundStyle(Color(hex: 0x0E1421))
            .padding(.horizontal, 13).frame(height: 28, alignment: .bottom)

            // site header
            HStack(spacing: 4) {
                Text("✿ Petal & Stem").font(.system(size: 8, weight: .bold)).foregroundStyle(muted)
                Spacer()
                VStack(spacing: 2) { ForEach(0..<3, id: \.self) { _ in Capsule().fill(muted.opacity(0.7)).frame(width: 10, height: 1.2) } }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)

            // hero card: one clear headline + one button
            VStack(alignment: .leading, spacing: 7) {
                Text("Fresh flowers for every moment.").font(.system(size: 13, weight: .heavy)).foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
                Capsule().fill(Color(hex: 0x3A5FBE)).frame(height: 20)
                    .overlay(Text("Shop flowers").font(.system(size: 8.5, weight: .semibold)).foregroundStyle(.white))
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(hex: 0xF4F6FB), Color(hex: 0xE3E7F0)], startPoint: .top, endPoint: .bottom),
                        in: UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 10))
            .padding(.horizontal, 7)

            // photo fills the rest of the screen
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(Image("blue-lily-stem").resizable().scaledToFill())
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 10, bottomTrailingRadius: 10, topTrailingRadius: 0))
                .padding(.horizontal, 7).padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .overlay(alignment: .bottom) {                                // home indicator
            Capsule().fill(Color(hex: 0x0E1421)).frame(width: 40, height: 3).padding(.bottom, 3)
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
                        Image(systemName: "lock.fill").font(.system(size: 8))
                        Text("petalandstem.webblock.com").font(.system(size: 10.5, weight: .medium)).lineLimit(1)
                    }
                    .foregroundStyle(.wbMuted)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.6), in: Capsule())
                }
                // hero: copy left, photo right
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fresh flowers\nfor every moment.").font(.system(size: 14, weight: .bold)).foregroundStyle(Color(hex: 0x1A273D))
                        Capsule().fill(Color(hex: 0x1A273D)).frame(width: 62, height: 18)
                            .overlay(Text("Shop flowers").font(.system(size: 8.5, weight: .semibold)).foregroundStyle(.white))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image("table-arrangement").resizable().scaledToFill()
                        .frame(width: 100, height: 80).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(8)
                .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                // products
                HStack(spacing: 6) {
                    ForEach(products.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 2) {
                            Image(products[i].0).resizable().scaledToFill()
                                .frame(height: 56).frame(maxWidth: .infinity).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            Text(products[i].1).font(.system(size: 8.5, weight: .medium)).foregroundStyle(Color(hex: 0x1A273D)).lineLimit(1)
                            Text(products[i].2).font(.system(size: 8.5, weight: .bold)).foregroundStyle(.wbBrand)
                        }
                        .entrance(active, delay: 0.35 + Double(i) * 0.1, y: 14)
                    }
                }
            }
            .padding(12)
            .frame(width: 292)
            .obGlass(cornerRadius: 22)
            .rotationEffect(.degrees(-2))
            .offset(x: -20, y: -26)
            .obFloat(6, duration: 3.2)
            .entrance(active, delay: 0.05)

            // Phone preview: a real phone shape showing the shop's mobile page, overlapping the browser
            PhoneMockup()
                .rotationEffect(.degrees(3))
                .offset(x: 92, y: 62)
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
            .offset(x: 104, y: -134)
            .obFloat(6, duration: 2.6, delay: 0.3)
            .entrance(active, delay: 0.3, x: 30, y: -20)

            // Globe badge
            Image(systemName: "globe")
                .font(.system(size: 24, weight: .semibold)).foregroundStyle(.wbBrand)
                .frame(width: 54, height: 54)
                .obGlass(cornerRadius: 27)
                .offset(x: -124, y: 128)
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
        VStack(spacing: 22) {
            TemplateMarquee(running: active && !reduceMotion)
                .frame(height: 107)
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

/// Endlessly scrolling row of the website's real template thumbnails (same order as the landing carousel).
private struct TemplateMarquee: View {
    let running: Bool
    private let names = ["petal-stem", "sugar-crumb", "kiln-coffee", "northpoint-audio",
                         "stitch-and-shell", "keycap-lab", "cold-brew-co", "plates"]
    private let cardW: CGFloat = 148, gap: CGFloat = 12
    private var cardH: CGFloat { cardW * 1584 / 2560 }     // thumbnails are 2560×1584

    var body: some View {
        TimelineView(.animation(paused: !running)) { ctx in
            let loop = (cardW + gap) * CGFloat(names.count)
            let x = running ? -CGFloat((ctx.date.timeIntervalSinceReferenceDate * 24).truncatingRemainder(dividingBy: Double(loop))) : 0
            HStack(spacing: gap) {
                ForEach(0..<(names.count * 2), id: \.self) { i in
                    Image("tpl-" + names[i % names.count]).resizable().scaledToFill()
                        .frame(width: cardW, height: cardH)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black.opacity(0.08), lineWidth: 1))
                        .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
                }
            }
            .fixedSize()
            .offset(x: x)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 340, height: cardH + 14)
        .clipped()
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.1),
                                      .init(color: .black, location: 0.9), .init(color: .clear, location: 1)],
                             startPoint: .leading, endPoint: .trailing))
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
    private let showSplash = false
    @State private var exiting = false         // the camera push when the intro ends
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            OnboardingBackdrop(page: page)

            VStack(spacing: 0) {
                HStack {
                    if showSplash {
                        Color.clear.frame(width: 48, height: 48)
                    } else {
                        BrandLogo(height: 38)
                            .accessibilityLabel("WebBlocks")
                    }
                    Spacer()
                    Button("Skip", action: leave)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.wbMuted)
                        .opacity(isLast ? 0 : 1)
                        .accessibilityHidden(isLast)
                }
                .frame(height: 48).padding(.horizontal, Space.screen)
                .opacity(showSplash ? 0 : 1)

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
                                .heroStage(active: page == item.id && !showSplash, exiting: exiting)
                                                                .frame(height: 340)
                                .scaleEffect(artScale)
                                .frame(height: artHeight)
                                .accessibilityHidden(true)
                            let shown = page == item.id && !showSplash
                            VStack(spacing: Space.xs) {
                                Text(item.eyebrow.uppercased())
                                    .font(.footnote.weight(.semibold)).tracking(1.2)
                                    .foregroundStyle(.wbBrand)
                                    .reveal(shown, delay: 0.2)
                                (Text(item.title).foregroundStyle(Color.wbText) + Text(item.accent).foregroundStyle(Color.wbBrand))
                                    .wbFont(28, .bold)
                                    .minimumScaleFactor(0.85)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .reveal(shown, delay: 0.3)
                                Text(item.message).font(.body).foregroundStyle(.wbMuted)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, Space.xxs)
                                    .reveal(shown, delay: 0.4)
                            }
                            .padding(.horizontal, Space.l)
                                                        .accessibilityElement(children: .combine)
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
                .padding(.bottom, Space.l)
                .accessibilityHidden(true)

                Button {
                    if isLast { leave() } else { page += 1 }
                } label: {
                    HStack(spacing: Space.xs) {
                        Text(isLast ? "Get started" : "Next")
                        if isLast {
                            Image(systemName: "arrow.right").font(.body.weight(.bold))
                        }
                    }
                }
                .buttonStyle(.wbPrimaryField)         // 50 pt: a comfortable touch target for the main action
                .disabled(false)                      // never inherit a disabled state from a parent
                .contentShape(Capsule())
                .opacity(showSplash ? 0 : 1)
                .padding(.horizontal, Space.screen).padding(.bottom, Space.m)
                .zIndex(1)                            // keep the button above the paging view
            }
            .opacity(showSplash || exiting ? 0 : 1)
            .allowsHitTesting(!showSplash && !exiting)
        }
        .sensoryFeedback(.selection, trigger: page)
        .sensoryFeedback(.impact(weight: .medium), trigger: exiting)
    }

    /// Ends the intro and hands over to the existing first-launch flow.
    private func leave() { finish() }

    @ViewBuilder
    private func illustration(for id: Int) -> some View {
        let active = page == id && !showSplash
        switch id {
        case 0: WebsiteIllustration(active: active)
        case 1: StepsIllustration(active: active)
        case 2: ProductsIllustration(active: active)
        default: MonitorIllustration(active: active)
        }
    }
}
