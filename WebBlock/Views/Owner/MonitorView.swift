import SwiftUI

// MARK: - Monitor tab

struct MonitorView: View {
    @Bindable var model: MonitorViewModel
    @Environment(AppState.self) private var appState
    @Environment(HomeViewModel.self) private var home

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
        .background(.wbBackground)
        .navigationTitle("Monitor")
        .portalToolbar()
        .refreshable { await model.load(plan: appState.plan) }
        .task(id: appState.plan) { await model.load(plan: appState.plan) }
    }

    private func content(_ s: MonitorSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            statusCard(s)
            HStack(spacing: Space.s) {
                statTile(symbol: "waveform.path.ecg", title: "Uptime", value: s.uptime)
                statTile(symbol: "checkmark.circle", title: "Deploy success", value: s.deploySuccess)
            }
            usageCard(s)
            resultsCard(s)
            if appState.plan.showsActivityLog { activityCard(s) }
            deploysCard(s)
        }
    }

    // MARK: Status

    private func statusCard(_ s: MonitorSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                Image(systemName: "circle.fill").font(.caption)
                    .foregroundStyle(s.isOnline ? Color.wbGreen : Color.wbRed)
                    .frame(width: 36, height: 36)
                    .background(s.isOnline ? Color.wbGreenSoft : Color.wbRedSoft, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.isOnline ? "Your website is online" : "Your website is offline").font(.headline).foregroundStyle(.wbText)
                    Text(s.websiteURL).font(.caption).foregroundStyle(.wbMuted)
                }
                Spacer(minLength: 0)
                Pill(text: s.isOnline ? "Live" : "Offline", symbol: "globe",
                     tint: s.isOnline ? .wbGreen : .wbRed, background: s.isOnline ? .wbGreenSoft : .wbRedSoft)
            }
            Divider()
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Last deploy").font(.caption).foregroundStyle(.wbMuted)
                Text(s.lastDeployText).font(.title.bold()).foregroundStyle(.wbText)
                Text(s.lastDeployDetail).font(.caption).foregroundStyle(.wbMuted)
            }
            VStack(spacing: 6) {
                ZStack {
                    Rectangle().fill(Color.wbBorder).frame(height: 2)
                    HStack(spacing: 0) {
                        ForEach(Array(s.lastSevenResults.enumerated()), id: \.offset) { index, result in
                            Circle().fill(result == .succeeded ? Color.wbGreen : Color.wbRed).frame(width: 9, height: 9)
                                .accessibilityLabel(result.rawValue)
                            if index < s.lastSevenResults.count - 1 { Spacer(minLength: 0) }
                        }
                    }
                }
                HStack {
                    Text("Last 7 deploys"); Spacer(); Text("Latest")
                }
                .font(.caption2).foregroundStyle(.wbMuted)
            }
        }
        .wbCard()
    }

    private func statTile(symbol: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            IconTile(symbol: symbol)
            Text(title).font(.caption).foregroundStyle(.wbMuted)
            Text(value).font(.title.bold()).foregroundStyle(.wbText).minimumScaleFactor(0.7).lineLimit(1)
        }
        .wbCard()
        .accessibilityElement(children: .combine)
    }

    // MARK: Plan usage

    private func usageCard(_ s: MonitorSnapshot) -> some View {
        let plan = appState.plan
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plan usage").font(.headline).foregroundStyle(.wbText)
                    Text("\(plan.title) plan · resets on \(s.resetsOn)").font(.caption).foregroundStyle(.wbMuted)
                }
                Spacer()
                Pill(text: plan.title, tint: plan == .pro ? .wbAmber : .wbBrand,
                     background: plan == .pro ? .wbAmberSoft : .wbBrandSoft, uppercase: true)
            }
            HStack(alignment: .top, spacing: Space.xs) {
                UsageDonut(title: "Products", used: s.productsUsed, limit: plan.maxProducts)
                UsageDonut(title: "Redeploys this month", used: s.redeploysUsed, limit: max(plan.maxRedeploys, 1))
                UsageDonut(title: "Websites", used: s.websitesUsed, limit: plan.maxWebsites)
            }
        }
        .wbCard()
    }

    // MARK: Deploy results (bar chart)

    private func resultsCard(_ s: MonitorSnapshot) -> some View {
        let total = max(s.totalDeploys, 1)
        let maxCount = max(s.succeededCount, s.failedCount, 1)
        return VStack(alignment: .leading, spacing: Space.s) {
            Text("Deploy results").font(.headline).foregroundStyle(.wbText)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(s.totalDeploys)").font(.title.bold()).foregroundStyle(.wbText)
                Text("total deploys").font(.subheadline).foregroundStyle(.wbMuted)
            }
            HStack(alignment: .bottom, spacing: Space.xl) {
                bar(count: s.succeededCount, of: maxCount, tint: .wbGreen, label: "Succeeded",
                    share: "\(s.succeededCount * 100 / total)% of deploys")
                bar(count: s.failedCount, of: maxCount, tint: .wbRed, label: "Failed",
                    share: "\(s.failedCount * 100 / total)% of deploys")
            }
            .frame(maxWidth: .infinity)
        }
        .wbCard()
    }

    private func bar(count: Int, of maxCount: Int, tint: Color, label: String, share: String) -> some View {
        VStack(spacing: 4) {
            Text("\(count)").font(.subheadline.weight(.bold)).foregroundStyle(.wbText)
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint)
                .frame(width: 56, height: max(6, 90 * CGFloat(count) / CGFloat(maxCount)))
            HStack(spacing: 4) { Circle().fill(tint).frame(width: 6, height: 6); Text(label) }
                .font(.caption).foregroundStyle(.wbText)
            Text(share).font(.caption2).foregroundStyle(.wbMuted)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Recent deploys

    private func deploysCard(_ s: MonitorSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent deploys").font(.headline).foregroundStyle(.wbText).padding(.bottom, Space.s)
            ForEach(s.deploys) { deploy in
                HStack(alignment: .top, spacing: Space.s) {
                    Text("\(deploy.number)").font(.subheadline.weight(.bold)).foregroundStyle(.wbText)
                        .frame(width: 26, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(deploy.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline).foregroundStyle(.wbText)
                        HStack(spacing: 6) {
                            Text(initials(deploy.startedBy)).font(.system(size: 9, weight: .bold)).foregroundStyle(.wbBrand)
                                .frame(width: 20, height: 20).background(.wbBrandSoft, in: Circle())
                            Text(deploy.startedBy).font(.caption).foregroundStyle(.wbMuted)
                        }
                        if deploy.liveFor != "—" {
                            Text("Live for \(deploy.liveFor)").font(.caption).foregroundStyle(.wbMuted)
                        }
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        ResultPill(result: deploy.result)
                        Text(deploy.duration).font(.caption).foregroundStyle(.wbMuted)
                    }
                }
                .padding(.vertical, Space.s)
                .accessibilityElement(children: .combine)
                if deploy.id != s.deploys.last?.id { Divider() }
            }
        }
        .wbCard()
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    // MARK: Activity log (Pro / Ultra)

    private func activityCard(_ s: MonitorSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent activity log").font(.headline).foregroundStyle(.wbText).padding(.bottom, Space.s)
            ForEach(s.activity) { item in
                HStack(alignment: .top, spacing: Space.s) {
                    Image(systemName: icon(for: item))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(tint(for: item))
                        .frame(width: 32, height: 32)
                        .background(soft(for: item), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.subheadline.weight(.medium)).foregroundStyle(.wbText)
                        if let detail = item.detail { Text(detail).font(.caption).foregroundStyle(.wbRed) }
                        HStack(spacing: Space.xs) {
                            Pill(text: item.kind.rawValue, tint: kindTint(item.kind), background: kindSoft(item.kind))
                            Text(item.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.wbMuted)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Space.s)
                .accessibilityElement(children: .combine)
                if item.id != s.activity.last?.id { Divider() }
            }
        }
        .wbCard()
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
