import SwiftUI

private let pulseGreen = Color(red: 0.79, green: 1.0, blue: 0.38)
private let surface = Color(red: 0.065, green: 0.082, blue: 0.09)

struct ContentView: View {
    @Bindable var store: PulseStore

    var body: some View {
        Group {
            if let snapshot = store.snapshot { DashboardView(snapshot: snapshot, store: store) }
            else { ConnectView(store: store) }
        }
        .background(Color(red: 0.03, green: 0.043, blue: 0.05).ignoresSafeArea())
    }
}

private struct ConnectView: View {
    @Bindable var store: PulseStore
    @State private var serverURL = "https://token-pulse-mobile.vercel.app"
    @State private var accessKey = ""

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "waveform.path.ecg").font(.system(size: 28, weight: .semibold)).foregroundStyle(pulseGreen).frame(width: 58, height: 58).background(surface).clipShape(.rect(cornerRadius: 18))
            VStack(spacing: 6) { Text("Token Pulse").font(.title2.bold()); Text("Your private agent telemetry, wherever you are.").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center) }
            VStack(spacing: 10) {
                TextField("Server URL", text: $serverURL).textInputAutocapitalization(.never).keyboardType(.URL).padding().background(surface).clipShape(.rect(cornerRadius: 12))
                SecureField("Mobile access key", text: $accessKey).textInputAutocapitalization(.never).padding().background(surface).clipShape(.rect(cornerRadius: 12))
                Button { Task { await store.connect(serverURL: serverURL, accessKey: accessKey) } } label: { HStack { if store.isLoading { ProgressView().tint(.black) }; Text("Open dashboard").fontWeight(.bold) }.frame(maxWidth: .infinity).padding() }.buttonStyle(.plain).foregroundStyle(.black).background(pulseGreen).clipShape(.rect(cornerRadius: 12))
            }
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.orange) }
        }
        .padding(28)
    }
}

private struct DashboardView: View {
    let snapshot: PulseSnapshot
    @Bindable var store: PulseStore
    @Environment(\.scenePhase) private var scenePhase

    private var activeSessions: [ActiveSession] {
        snapshot.platforms.flatMap { platform in platform.activeSessionList.map { ActiveSession(id: "\(platform.id)-\($0.stableID)", platform: platform, session: $0) } }.sorted { $0.session.updatedAt > $1.session.updatedAt }.prefix(12).map { $0 }
    }

    var body: some View {
        TabView {
            overviewTab.tabItem { Label("Overview", systemImage: "square.grid.2x2.fill") }
            sessionsTab.tabItem { Label("Sessions", systemImage: "list.bullet") }.badge(snapshot.activeSessions)
            systemTab.tabItem { Label("System", systemImage: "waveform.path.ecg") }
        }
        .tint(pulseGreen)
        .task { await store.refresh() }
        .task(id: scenePhase) { if scenePhase == .active { await store.refresh() } }
    }

    private var overviewTab: some View {
        ScrollView { LazyVStack(spacing: 10) {
            header
            VStack(alignment: .leading, spacing: 7) { Text("TOKENS TODAY").metricLabel(); Text(snapshot.total.compact).font(.system(size: 56, weight: .bold, design: .rounded)); Text("\(snapshot.sessions) sessions across \(snapshot.platforms.filter(\.connected).count) runtimes").font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 18)
            HStack(spacing: 8) { MetricTile(label: "FRESH INPUT", value: snapshot.input.compact); MetricTile(label: "CACHE READ", value: snapshot.cacheRead.compact); MetricTile(label: "OUTPUT", value: snapshot.output.compact) }
            ForEach(snapshot.platforms) { PlatformRow(platform: $0) }
            HStack(spacing: 8) { MetricTile(label: "CACHE HIT", value: "\(Int(snapshot.cacheHitRate * 100))%"); MetricTile(label: "AVG / SESSION", value: (snapshot.sessions > 0 ? snapshot.total / Double(snapshot.sessions) : 0).compact) }
        }.padding(18) }.refreshable { await store.refresh() }
    }

    private var sessionsTab: some View {
        ScrollView { LazyVStack(spacing: 0) {
            header
            HStack { VStack(alignment: .leading, spacing: 4) { Text("LIVE WORK").metricLabel(); Text("Active sessions").font(.title2.bold()) }; Spacer(); Text("Last 20 minutes").font(.caption2).foregroundStyle(.secondary) }.padding(.vertical, 18)
            ForEach(activeSessions) { ActiveSessionRow(item: $0) }
        }.padding(18) }.refreshable { await store.refresh() }
    }

    private var systemTab: some View {
        ScrollView { LazyVStack(spacing: 10) {
            header
            if let hardware = snapshot.hardware {
                VStack(alignment: .leading, spacing: 7) { Text("AGENT READINESS").metricLabel(); Text(hardware.recommendation.mode).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(pulseGreen); Text(hardware.recommendation.route).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 18)
                HStack(spacing: 8) { MetricTile(label: "CPU LOAD", value: "\(Int(hardware.cpu.utilization))%"); MetricTile(label: "MEMORY", value: "\(Int(hardware.memory.utilization))%"); MetricTile(label: "GPU VRAM", value: "\(hardware.gpu.vramGb, specifier: "%.0f") GB") }
                ReadinessRow(hardware: hardware)
            }
            HStack { Text("Provider quotas").font(.headline); Spacer(); Text("Account allowance").font(.caption2).foregroundStyle(.secondary) }.padding(.top, 14)
            ForEach(snapshot.platforms) { platform in HStack { Circle().fill(platform.color).frame(width: 7, height: 7); Text(platform.label).font(.caption.bold()); Spacer(); Text(platform.quota?.available == true ? "\(Int(platform.quota?.remainingPercent ?? 0))% left" : "Not exposed").font(.caption.bold()).foregroundStyle(pulseGreen) }.padding(.vertical, 10).overlay(alignment: .bottom) { Divider().opacity(0.25) } }
            HStack { Button("Refresh now") { Task { await store.refresh() } }.buttonStyle(.borderedProminent).tint(pulseGreen).foregroundStyle(.black); Button("Lock", role: .destructive) { store.lock() }.buttonStyle(.bordered) }.padding(.top, 14)
        }.padding(18) }.refreshable { await store.refresh() }
    }

    private var header: some View { HStack { Circle().fill(pulseGreen).frame(width: 8, height: 8).shadow(color: pulseGreen, radius: 7); Text("Token Pulse").fontWeight(.bold); Spacer(); Text("LIVE").font(.caption2.bold()).foregroundStyle(pulseGreen).padding(.horizontal, 7).padding(.vertical, 4).background(pulseGreen.opacity(0.08)).clipShape(.rect(cornerRadius: 6)) }.padding(.vertical, 9) }
}

private struct MetricTile: View { let label: String; let value: String; var body: some View { VStack(alignment: .leading, spacing: 6) { Text(label).metricLabel(); Text(value).font(.headline) }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(surface).clipShape(.rect(cornerRadius: 13)) } }
private struct PlatformRow: View { let platform: PlatformSnapshot; var body: some View { HStack { Circle().fill(platform.color).frame(width: 7, height: 7); VStack(alignment: .leading) { Text(platform.label).font(.subheadline.bold()); Text("\(platform.active) active").font(.caption2).foregroundStyle(.secondary) }; Spacer(); VStack(alignment: .trailing) { Text(platform.total.compact).font(.title3.bold()); Text(platform.quota?.available == true ? "\(Int(platform.quota?.remainingPercent ?? 0))% quota left" : "\(platform.sessions) sessions").font(.caption2).foregroundStyle(.secondary) } }.padding(14).background(surface).clipShape(.rect(cornerRadius: 14)) } }
private struct ReadinessRow: View { let hardware: HardwareSnapshot; var body: some View { HStack { VStack(alignment: .leading, spacing: 6) { Text("AGENT READINESS").metricLabel(); Text(hardware.recommendation.mode).font(.caption.bold()).foregroundStyle(pulseGreen) }; Spacer(); VStack(alignment: .trailing, spacing: 4) { Text(hardware.recommendation.model).font(.caption.bold()); Text("\(Int(hardware.cpu.utilization))% CPU · \(Int(hardware.memory.utilization))% RAM · \(hardware.gpu.vramGb, specifier: "%.0f") GB VRAM").font(.caption2).foregroundStyle(.secondary) } }.padding(14).background(pulseGreen.opacity(0.04)).overlay(RoundedRectangle(cornerRadius: 14).stroke(pulseGreen.opacity(0.15))).clipShape(.rect(cornerRadius: 14)) } }
private struct ActiveSessionRow: View { let item: ActiveSession; var body: some View { HStack { Circle().fill(item.platform.color).frame(width: 7, height: 7); VStack(alignment: .leading) { Text(item.session.title ?? "Untitled session").font(.caption.bold()).lineLimit(1); Text("\(item.platform.label) · \(item.session.updatedAt.relative)").font(.caption2).foregroundStyle(.secondary) }; Spacer(); Text(item.session.total.compact).font(.caption.bold()).foregroundStyle(pulseGreen) }.padding(.vertical, 8).overlay(alignment: .bottom) { Divider().opacity(0.25) } } }

private extension Text { func metricLabel() -> some View { font(.system(size: 9, weight: .bold)).tracking(1.1).foregroundStyle(.secondary) } }
private extension Double { var compact: String { let formatter = NumberFormatter(); formatter.numberStyle = .decimal; if self >= 1_000_000 { return String(format: "%.1fM", self / 1_000_000) }; if self >= 1_000 { return String(format: "%.1fK", self / 1_000) }; return formatter.string(from: NSNumber(value: self)) ?? "0" }; var relative: String { let seconds = max(0, Date().timeIntervalSince1970 - self / 1000); return seconds < 60 ? "just now" : seconds < 3600 ? "\(Int(seconds / 60))m ago" : "\(Int(seconds / 3600))h ago" } }
private extension PlatformSnapshot { var color: Color { id == "codex" ? pulseGreen : id == "openclaw" ? .orange : .purple } }

#Preview("Connected") { ContentView(store: PulseStore()) }
