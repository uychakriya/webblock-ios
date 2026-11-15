import SwiftUI

// MARK: - Monitor tab

enum MonitorPage: String, CaseIterable, Identifiable {
    case overview = "Overview", activity = "Activity"
    var id: String { rawValue }
}

struct MonitorView: View {
    @Bindable var model: MonitorViewModel
    @Environment(AppState.self) private var appState
    @Environment(HomeViewModel.self) private var home
    @State private var expandedDeploy: Int?
    @State private var showAllDeploys = false
    @State private var expandedActivity: UUID?
    @State private var page: MonitorPage = .overview

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("Here’s how \(home.selected?.url ?? "your website") is doing today.")
                    .font(.subheadline).foregroundStyle(.wbMuted)
                SiteHeaderCard()

                StateContainer(state: model.state, retry: { Task { await model.load(plan: appState.plan) } }) {
                    if let snapshot = model.snapshot { content(snapshot) }
                }
            }
            .padding(.horizontal, Space.screen).padding(.vertical, Space.xs)
        }
        .liquidBackdrop()
        .navigationTitle("Monitor")
        .portalToolbar()
        .refreshable { await model.load(plan: appState.plan) }
        .task(id: appState.plan) { await model.load(plan: appState.plan) }
    }

    private func content(_ s: MonitorSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            WBSegmented(options: MonitorPage.allCases.map { ($0.rawValue, $0) }, selection: $page)

            switch page {
            case .overview:
                StatusCard(snapshot: s).appearAnimated(index: 0)
                SectionTitle(text: "Summary")
                summaryCard(s).appearAnimated(index: 1)
                SectionTitle(text: "Plan usage")
                planUsageCard(s).appearAnimated(index: 2)
                SectionTitle(text: "Health metrics")
                healthTiles(s).appearAnimated(index: 3)
                SectionTitle(text: "Deploy activity")
                DeployActivityCard(snapshot: s).appearAnimated(index: 4)
            case .activity:
                activityLog(s).appearAnimated(index: 0)
                deploysCard(s).appearAnimated(index: 1)
            }
        }
    }

    // MARK: Summary — success ring + usage bars

    private func summaryCard(_ s: MonitorSnapshot) -> some View {
        let plan = appState.plan
        let uptime = (Double(s.uptime.trimmingCharacters(in: CharacterSet(charactersIn: "%"))) ?? 0) / 100
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                SuccessRing(succeeded: s.succeededCount, failed: s.failedCount)
                VStack(spacing: Space.xs) {
                    MetricBar(symbol: "globe", tint: .wbGreen, title: "Uptime", value: s.uptime, fraction: uptime)
                    MetricBar(symbol: "archivebox", tint: .wbBrand, title: "Products",
                              value: "\(s.productsUsed) / \(plan.maxProducts)", fraction: Double(s.productsUsed) / Double(max(plan.maxProducts, 1)))
                    MetricBar(symbol: "photo", tint: .wbAmber, title: "Photos",
                              value: "\(s.photosUsed) / \(plan.maxPhotos)", fraction: Double(s.photosUsed) / Double(max(plan.maxPhotos, 1)))
                }
            }
        }
        .wbCard()
    }

    // MARK: Plan usage — redeploys and websites, kept apart from the summary

    private func planUsageCard(_ s: MonitorSnapshot) -> some View {
        let plan = appState.plan
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                UsageRing(symbol: "arrow.triangle.2.circlepath", tint: .wbPurple, title: "Redeploys",
                          used: s.redeploysUsed, limit: plan.maxRedeploys)
                UsageRing(symbol: "square.stack.3d.up", tint: .wbBrand, title: "Websites",
                          used: s.websitesUsed, limit: plan.maxWebsites)
            }
            Divider()
            Text("\(plan.title) plan · resets on \(s.resetsOn)").font(.caption).foregroundStyle(.wbMuted)
        }
        .wbCard()
    }

    // MARK: Health metrics — three tinted tiles

    private func healthTiles(_ s: MonitorSnapshot) -> some View {
        let total = max(s.totalDeploys, 1)
        return HStack(spacing: Space.s) {
            HealthTile(symbol: "paperplane.fill", tint: .wbBrand, soft: .wbBrandSoft,
                       title: "Deploys", value: "\(s.totalDeploys)", caption: "in total")
            HealthTile(symbol: "exclamationmark.triangle.fill", tint: .wbRed, soft: .wbRedSoft,
                       title: "Failed", value: "\(s.failedCount)", barFraction: Double(s.failedCount) / Double(total))
            HealthTile(symbol: "timer", tint: .wbAmber, soft: .wbAmberSoft,
                       title: "Avg. time", value: Self.averageTime(s.deploys), caption: "per deploy")
        }
    }

    /// Average of the "1m 41s" style durations.
    private static func averageTime(_ deploys: [Deploy]) -> String {
        func seconds(_ text: String) -> Int? {
            var total = 0, found = false
            for part in text.split(separator: " ") {
                if part.hasSuffix("m"), let m = Int(part.dropLast()) { total += m * 60; found = true }
                else if part.hasSuffix("s"), let sec = Int(part.dropLast()) { total += sec; found = true }
            }
            return found ? total : nil
        }
        let values = deploys.compactMap { seconds($0.duration) }
        guard !values.isEmpty else { return "—" }
        let avg = values.reduce(0, +) / values.count
        return "\(avg / 60)m \(avg % 60)s"
    }

    // MARK: Recent deploys

    private func deploysCard(_ s: MonitorSnapshot) -> some View {
        let limit = 4
        let rows = showAllDeploys ? s.deploys : Array(s.deploys.prefix(limit))
        return VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text("Recent deploys").font(.headline).foregroundStyle(.wbText)
                Spacer()
                Text("Tap for details").font(.caption).foregroundStyle(.wbMuted)
            }
            ForEach(rows) { deploy in
                DeployRow(deploy: deploy, isExpanded: expandedDeploy == deploy.id) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        expandedDeploy = expandedDeploy == deploy.id ? nil : deploy.id
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if s.deploys.count > limit {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showAllDeploys.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAllDeploys ? "Show less" : "Show all \(s.deploys.count) deploys")
                        Image(systemName: "chevron.down").rotationEffect(.degrees(showAllDeploys ? 180 : 0))
                    }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.wbBrand)
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.wbCardPress)
            }
        }
        .wbCard()
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    // MARK: Activity log (Pro / Ultra)

    private func activityLog(_ s: MonitorSnapshot) -> some View {
        let items = s.activity
        return VStack(alignment: .leading, spacing: Space.s) {
            SectionTitle(text: "Recent activity log")
            VStack(spacing: 0) {
                if items.isEmpty {
                    Text("No activity of this type yet.").font(.subheadline).foregroundStyle(.wbMuted)
                        .frame(maxWidth: .infinity).padding(.vertical, Space.l)
                }
                ForEach(items) { item in
                    activityRow(item)
                    if item.id != items.last?.id { Divider().padding(.leading, 58) }
                }
            }
            .wbCard(padding: 0)
        }
    }

    /// Compact row: icon, title, short date. Tap to drop down the type, status and any error.
    private func activityRow(_ item: ActivityItem) -> some View {
        let open = expandedActivity == item.id
        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { expandedActivity = open ? nil : item.id }
            } label: {
                HStack(spacing: Space.s) {
                    Image(systemName: icon(for: item)).font(.footnote.weight(.semibold))
                        .foregroundStyle(tint(for: item))
                        .frame(width: 34, height: 34).background(soft(for: item), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.subheadline.weight(.medium)).foregroundStyle(.wbText)
                            .multilineTextAlignment(.leading)
                        Text(item.date.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                            .font(.caption).foregroundStyle(.wbMuted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(.wbMuted)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(.horizontal, Space.s).padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(spacing: Space.xs) {
                    detailLine("Type") { Pill(text: item.kind.rawValue, tint: kindTint(item.kind), background: kindSoft(item.kind)) }
                    detailLine("Status") {
                        Text(item.isFailure ? "Failed" : "Completed").font(.subheadline.weight(.medium))
                            .foregroundStyle(item.isFailure ? Color.wbRed : Color.wbGreen)
                    }
                    detailLine("When") {
                        Text(item.date.formatted(date: .long, time: .shortened)).font(.subheadline).foregroundStyle(.wbText)
                    }
                    if let detail = item.detail {
                        Text(detail).font(.footnote).foregroundStyle(.wbRed)
                            .padding(Space.xs).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.wbRedSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(.horizontal, Space.s).padding(.bottom, Space.s).padding(.leading, 42)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(open ? Color.wbBrandSoft.opacity(0.35) : Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityValue(open ? "Expanded" : "Collapsed")
    }

    private func detailLine<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.wbMuted)
            Spacer()
            value()
        }
    }

    private func icon(for item: ActivityItem) -> String {
        if item.isFailure { return "xmark" }
        switch item.kind { case .deploy: return "checkmark"; case .product: return "shippingbox"; case .businessInfo: return "pencil" }
    }
    private func tint(for item: ActivityItem) -> Color {
        if item.isFailure { return .wbRed }
        switch item.kind { case .deploy: return .wbGreen; case .product: return .wbBrand; case .businessInfo: return .wbPurple }
    }
    private func soft(for item: ActivityItem) -> Color {
        if item.isFailure { return .wbRedSoft }
        switch item.kind { case .deploy: return .wbGreenSoft; case .product: return .wbBrandSoft; case .businessInfo: return .wbPurpleSoft }
    }
    private func kindTint(_ kind: ActivityKind) -> Color {
        switch kind { case .deploy: .wbBrand; case .product: .wbGreen; case .businessInfo: .wbPurple }
    }
    private func kindSoft(_ kind: ActivityKind) -> Color {
        switch kind { case .deploy: .wbBrandSoft; case .product: .wbGreenSoft; case .businessInfo: .wbPurpleSoft }
    }
}


/// One deploy: a compact summary row that expands in place to show who ran it, how long it took, etc.
private struct DeployRow: View {
    let deploy: Deploy
    let isExpanded: Bool
    let toggle: () -> Void

    private var ok: Bool { deploy.result == .succeeded }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: Space.s) {
                    Image(systemName: ok ? "checkmark" : "xmark")
                        .font(.footnote.weight(.bold)).foregroundStyle(ok ? Color.wbGreen : Color.wbRed)
                        .frame(width: 34, height: 34)
                        .background(ok ? Color.wbGreenSoft : Color.wbRedSoft, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Deploy #\(deploy.number)").font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
                        Text(deploy.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.wbMuted)
                    }
                    Spacer(minLength: 0)
                    ResultPill(result: deploy.result)
                    Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(.wbMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(Space.s)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: Space.xs) {
                    Divider()
                    detail("person.fill", "Started by", deploy.startedBy)
                    detail("clock", "Duration", deploy.duration)
                    if deploy.liveFor != "—" { detail("globe", "Live for", deploy.liveFor) }
                }
                .padding(.horizontal, Space.s).padding(.bottom, Space.s)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isExpanded ? Color.wbBrandSoft.opacity(0.55) : Color.wbSoft.opacity(0.6),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder((ok ? Color.wbBrand : Color.wbRed).opacity(isExpanded ? 0.55 : 0.28), lineWidth: 1.2)
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .accessibilityElement(children: .contain)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }

    private func detail(_ symbol: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: Space.xs) {
            Image(systemName: symbol).font(.caption).foregroundStyle(Color.wbBrand).frame(width: 20)
            Text(title).font(.subheadline).foregroundStyle(.wbMuted)
            Spacer()
            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(.wbText)
        }
    }
}


// MARK: - Summary pieces

/// Ring with the success percentage in the middle.
private struct SuccessRing: View {
    let succeeded: Int
    let failed: Int
    @State private var progress: CGFloat = 0
    private var total: Int { succeeded + failed }
    private var fraction: CGFloat { total == 0 ? 0 : CGFloat(succeeded) / CGFloat(total) }
    private var percent: Int { Int((fraction * 100).rounded()) }

    var body: some View {
        ZStack {
            Circle().stroke(Color.wbBrand.opacity(0.12), lineWidth: 16)
            Circle().trim(from: 0, to: max(0.001, fraction * progress))
                .stroke(LinearGradient(colors: [Color(hex: 0x6C9BEA), Color.wbBrand], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(CGFloat(percent) * progress))%").font(.title2.bold()).foregroundStyle(.wbText)
                    .contentTransition(.numericText())
                Text("Success").font(.caption).foregroundStyle(.wbMuted)
            }
        }
        .frame(width: 112, height: 112)
        .onAppear { withAnimation(.easeOut(duration: 1.0).delay(0.25)) { progress = 1 } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(percent) percent of deploys succeeded")
    }
}

/// Icon tile + title + value on top, a thin coloured progress bar underneath.
private struct MetricBar: View {
    let symbol: String
    let tint: Color
    let title: String
    let value: String
    let fraction: Double
    @State private var shown = false

    var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: symbol).font(.footnote.weight(.semibold)).foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Color.wbCard.opacity(0.85), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(spacing: 5) {
                HStack {
                    Text(title).font(.footnote.weight(.medium)).foregroundStyle(.wbText)
                    Spacer(minLength: 4)
                    Text(value).font(.caption).foregroundStyle(.wbMuted)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(tint.opacity(0.14))
                        Capsule().fill(tint).frame(width: max(6, geo.size.width * min(1, max(0, fraction)) * (shown ? 1 : 0)))
                    }
                }
                .frame(height: 6)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.9).delay(0.3)) { shown = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

/// Tinted tile: white icon chip, label, big value, then a caption or a thin bar.
private struct HealthTile: View {
    let symbol: String
    let tint: Color
    let soft: Color
    let title: String
    let value: String
    var caption: String?
    var barFraction: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol).font(.footnote.weight(.semibold)).foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.bottom, 4)
            Text(title).font(.caption).foregroundStyle(.wbMuted)
            Text(value).font(.title2.bold()).foregroundStyle(.wbText).minimumScaleFactor(0.7).lineLimit(1)
            Spacer(minLength: 6)
            if let barFraction {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.8))
                        Capsule().fill(tint).frame(width: max(8, geo.size.width * barFraction))
                    }
                }
                .frame(height: 6)
            } else if let caption {
                Text(caption).font(.caption).foregroundStyle(.wbMuted)
            }
        }
        .padding(Space.s)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .background(soft.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(tint.opacity(0.18), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Deploy activity (build time per deploy, smooth area line)

/// How long each deploy took, oldest to latest, as a smooth filled line. Failed deploys get a red dot.
private struct DeployActivityCard: View {
    let snapshot: MonitorSnapshot
    @State private var drawn: CGFloat = 0

    private struct Entry: Identifiable {
        let id: Int
        let seconds: Double
        let failed: Bool
        let date: Date
    }

    private static func seconds(_ text: String) -> Double? {
        var total = 0, found = false
        for part in text.split(separator: " ") {
            if part.hasSuffix("m"), let m = Int(part.dropLast()) { total += m * 60; found = true }
            else if part.hasSuffix("s"), let sec = Int(part.dropLast()) { total += sec; found = true }
        }
        return found ? Double(total) : nil
    }

    /// The latest ten deploys with a known duration, oldest first.
    private var entries: [Entry] {
        snapshot.deploys.sorted { $0.number < $1.number }.suffix(10).compactMap { d in
            Self.seconds(d.duration).map { Entry(id: d.number, seconds: $0, failed: d.result == .failed, date: d.date) }
        }
    }

    private static func label(_ seconds: Double) -> String { "\(Int(seconds) / 60)m \(Int(seconds) % 60)s" }

    var body: some View {
        let entries = entries
        let lo = entries.map(\.seconds).min() ?? 0, hi = entries.map(\.seconds).max() ?? 1
        let span = max(hi - lo, 1)
        // y in 0.12…0.88 so the line and dots never touch the card edge
        let pts = entries.enumerated().map { i, e in
            CGPoint(x: entries.count > 1 ? CGFloat(i) / CGFloat(entries.count - 1) : 0.5,
                    y: 0.12 + 0.76 * CGFloat((e.seconds - lo) / span))
        }
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Build time").font(.title3.bold()).foregroundStyle(.wbText)
                    Text("Last \(entries.count) deploys").font(.caption).foregroundStyle(.wbMuted)
                }
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(Color.wbRed).frame(width: 9, height: 9)
                    Text("Failed").font(.caption).foregroundStyle(.wbMuted)
                }
            }
            if entries.count < 2 {
                Text("Deploy a few times to see how your build time changes.").font(.subheadline).foregroundStyle(.wbMuted)
            } else {
                HStack(alignment: .top, spacing: Space.xs) {
                    VStack(alignment: .trailing) {
                        Text(Self.label(hi)); Spacer(); Text(Self.label(lo))
                    }
                    .font(.caption2).foregroundStyle(.wbMuted)
                    .frame(width: 44, height: 130)

                    ZStack {
                        VStack { Divider(); Spacer(); Divider(); Spacer(); Divider() }.opacity(0.5)
                        SmoothLine(points: pts, closed: true)
                            .fill(LinearGradient(colors: [Color.wbBrand.opacity(0.25), Color.wbBrand.opacity(0)], startPoint: .top, endPoint: .bottom))
                            .opacity(drawn)
                        SmoothLine(points: pts)
                            .trim(from: 0, to: drawn)
                            .stroke(Color.wbBrand, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        GeometryReader { geo in
                            ForEach(entries.indices, id: \.self) { i in
                                if entries[i].failed {
                                    Circle().fill(Color.wbRed)
                                        .frame(width: 12, height: 12)
                                        .overlay(Circle().stroke(Color.wbCard, lineWidth: 2))
                                        .position(x: pts[i].x * geo.size.width, y: geo.size.height - pts[i].y * geo.size.height)
                                        .opacity(drawn >= 1 ? 1 : 0)
                                }
                            }
                        }
                    }
                    .frame(height: 130)
                }
                HStack {
                    Text(entries.first?.date.formatted(.dateTime.day().month(.abbreviated)) ?? "")
                    Spacer()
                    Text(entries.last?.date.formatted(.dateTime.day().month(.abbreviated)) ?? "")
                }
                .font(.caption).foregroundStyle(.wbMuted)
                .padding(.leading, 44 + Space.xs)
            }
        }
        .wbCard()
        .onAppear { withAnimation(.easeInOut(duration: 1.0)) { drawn = 1 } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Build time of the last \(entries.count) deploys, from \(Self.label(lo)) to \(Self.label(hi)). \(entries.filter(\.failed).count) failed.")
    }
}

// MARK: - Status card (online banner + smooth line of the last deploys)

private struct SmoothLine: Shape {
    var points: [CGPoint]          // x, y in 0…1 (y up)
    var closed = false

    func path(in rect: CGRect) -> Path {
        let pts = points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.maxY - $0.y * rect.height) }
        var path = Path()
        guard pts.count > 1 else { return path }
        path.move(to: pts[0])
        for i in 0..<(pts.count - 1) {
            let p0 = i > 0 ? pts[i - 1] : pts[i], p1 = pts[i], p2 = pts[i + 1]
            let p3 = i + 2 < pts.count ? pts[i + 2] : p2
            path.addCurve(to: p2,
                          control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                          control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
        }
        if closed {
            path.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: rect.maxY))
            path.addLine(to: CGPoint(x: pts[0].x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

private struct StatusCard: View {
    let snapshot: MonitorSnapshot
    @State private var pulse = false
    @State private var drawn: CGFloat = 0
    @Environment(\.openURL) private var openURL

    private var online: Bool { snapshot.isOnline }
    private var tint: Color { online ? .wbGreen : .wbRed }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.card, style: .continuous) }
    private let rise: [CGFloat] = [0.12, 0.28, 0.36, 0.5, 0.58, 0.76, 0.9]

    private var points: [CGPoint] {
        let n = snapshot.lastSevenResults.count
        return (0..<n).map { i in CGPoint(x: n == 1 ? 0.5 : CGFloat(i) / CGFloat(n - 1), y: rise[min(i, rise.count - 1)]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            header
            Divider()
            chart
            HStack {
                Text("Last 7 deploys"); Spacer(); Text("Latest")
            }
            .font(.caption).foregroundStyle(.wbMuted)
            HStack(alignment: .firstTextBaseline) {
                Text(online ? "Your latest changes are live." : "Your website is currently offline.")
                    .font(.subheadline).foregroundStyle(.wbText)
                Spacer(minLength: Space.xs)
                Button {
                    if let url = URL(string: "https://\(snapshot.websiteURL)") { openURL(url) }
                } label: {
                    HStack(spacing: 3) { Text("Visit site"); Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold)) }
                        .font(.footnote.weight(.semibold)).foregroundStyle(Color.wbBrand)
                }
                .buttonStyle(.wbCardPress)
                .accessibilityLabel("Visit \(snapshot.websiteURL)")
            }
        }
        .padding(Space.m)
        .background(alignment: .topLeading) {
            DotMatrix(rows: 4, columns: 5, ink: .wbBrand, spacing: 10, dot: 3).opacity(0.7).offset(x: 14, y: 10)
        }
        .background(alignment: .bottomTrailing) {
            Circle().fill(Color.wbBrand.opacity(0.08)).frame(width: 120).offset(x: 40, y: 50)
        }
        .glass(in: shape)
        .clipShape(shape)
        .overlay(shape.stroke(Color.wbBrand.opacity(0.15), lineWidth: 1))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) { pulse = true }
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) { drawn = 1 }
        }
    }

    private var header: some View {
        HStack(spacing: Space.s) {
            ZStack {
                Circle().stroke(tint.opacity(0.35), lineWidth: 2).frame(width: 64, height: 64)
                    .scaleEffect(pulse ? 1.35 : 1).opacity(pulse ? 0 : 0.9)
                Circle().fill(Color.wbBrandSoft).frame(width: 64, height: 64)
                Image(systemName: online ? "globe" : "wifi.slash").font(.title2).foregroundStyle(online ? Color.wbBrand : Color.wbRed)
            }
            .frame(width: 70, height: 70)
            VStack(alignment: .leading, spacing: 2) {
                Text(online ? "Your website is online" : "Your website is offline")
                    .font(.headline).foregroundStyle(.wbText)
                Text("Last deploy \(snapshot.lastDeployText)").font(.subheadline).foregroundStyle(.wbMuted)
                Text(snapshot.lastDeployDetail).font(.caption).foregroundStyle(.wbMuted)
            }
            Spacer(minLength: 0)
            Text(online ? "LIVE" : "OFFLINE").font(.caption2.weight(.bold)).foregroundStyle(tint)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.wbCard.opacity(0.7), in: Capsule())
                .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1))
        }
    }

    private var chart: some View {
        let pts = points
        return ZStack {
            SmoothLine(points: pts, closed: true)
                .fill(LinearGradient(colors: [Color.wbBrand.opacity(0.18), Color.wbBrand.opacity(0)], startPoint: .top, endPoint: .bottom))
                .opacity(drawn)
            SmoothLine(points: pts)
                .trim(from: 0, to: drawn)
                .stroke(Color.wbBrand, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            GeometryReader { geo in
                ForEach(pts.indices, id: \.self) { i in
                    let ok = snapshot.lastSevenResults[i] == .succeeded
                    Circle().fill(ok ? Color.wbBrand : Color.wbRed)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .position(x: pts[i].x * geo.size.width, y: geo.size.height - pts[i].y * geo.size.height)
                        .scaleEffect(drawn > CGFloat(i) / CGFloat(max(pts.count, 1)) ? 1 : 0.01)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: drawn)
                        .accessibilityLabel("Deploy result: \(snapshot.lastSevenResults[i].rawValue)")
                }
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 96)
    }
}


/// Plan allowance tile: big count, "left" status and a row of block segments (not a ring or a bar).
private struct UsageRing: View {
    let symbol: String
    let tint: Color
    let title: String
    let used: Int
    let limit: Int

    private var left: Int { max(limit - used, 0) }
    private var full: Bool { used >= limit }
    private var segments: Int { min(max(limit, 1), 10) }
    private var filled: Int { Int((min(Double(used) / Double(max(limit, 1)), 1) * Double(segments)).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.footnote.weight(.semibold)).foregroundStyle(tint)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.wbText)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(used)").font(.title.bold()).foregroundStyle(.wbText)
                Text("/ \(limit)").font(.subheadline).foregroundStyle(.wbMuted)
            }
            HStack(spacing: 3) {
                ForEach(0..<segments, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(i < filled ? tint : tint.opacity(0.16)).frame(height: 8)
                }
            }
            Text(full ? "Limit reached" : "\(left) left").font(.caption.weight(.medium))
                .foregroundStyle(full ? Color.wbAmber : Color.wbMuted)
        }
        .padding(Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(used) of \(limit) used, \(full ? "limit reached" : "\(left) left")")
    }
}
