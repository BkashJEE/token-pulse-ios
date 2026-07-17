import Foundation

struct PulseSnapshot: Codable {
    let schema: Int
    let fetchedAt: Double
    let receivedAt: Double?
    let total: Double
    let input: Double
    let output: Double
    let cacheRead: Double
    let activeSessions: Int
    let sessions: Int
    let platforms: [PlatformSnapshot]
    let hardware: HardwareSnapshot?
}

struct PlatformSnapshot: Codable, Identifiable {
    let id: String
    let label: String
    let connected: Bool
    let total: Double
    let sessions: Int
    let active: Int
    let quota: QuotaSnapshot?
    let activeSessionList: [SessionSnapshot]
}

struct QuotaSnapshot: Codable {
    let available: Bool
    let remainingPercent: Double?
    let resetsAt: Double?
}

struct SessionSnapshot: Codable, Identifiable {
    let id: String?
    let title: String?
    let model: String?
    let updatedAt: Double
    let total: Double

    var stableID: String { id ?? "\(title ?? "session")-\(updatedAt)" }
}

struct HardwareSnapshot: Codable {
    let pressure: String
    let cpu: CPUSnapshot
    let memory: MemorySnapshot
    let gpu: GPUSnapshot
    let recommendation: RecommendationSnapshot
}

struct CPUSnapshot: Codable { let utilization: Double }
struct MemorySnapshot: Codable { let utilization: Double }
struct GPUSnapshot: Codable { let vramGb: Double }
struct RecommendationSnapshot: Codable { let mode: String; let model: String; let route: String }

struct ActiveSession: Identifiable {
    let id: String
    let platform: PlatformSnapshot
    let session: SessionSnapshot
}
