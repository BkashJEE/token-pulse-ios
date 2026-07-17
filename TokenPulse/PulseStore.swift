import Foundation
import Observation

protocol SnapshotFetching: Sendable {
    func fetch(serverURL: String, accessKey: String) async throws -> PulseSnapshot
}

struct URLSessionSnapshotClient: SnapshotFetching {
    static func snapshotURL(serverURL: String) -> URL? {
        guard var components = URLComponents(string: serverURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = components.host, !host.isEmpty,
              scheme == "https" || ["localhost", "127.0.0.1", "::1"].contains(host.lowercased()) else { return nil }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, "api", "snapshot"].filter { !$0.isEmpty }.joined(separator: "/")
        components.query = nil
        components.fragment = nil
        return components.url
    }

    func fetch(serverURL: String, accessKey: String) async throws -> PulseSnapshot {
        guard let url = Self.snapshotURL(serverURL: serverURL) else { throw PulseError.invalidServerURL }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("Bearer \(accessKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PulseError.invalidResponse }
        guard http.statusCode == 200 else { throw http.statusCode == 401 ? PulseError.unauthorized : PulseError.server(http.statusCode) }
        return try JSONDecoder().decode(PulseSnapshot.self, from: data)
    }
}

@MainActor
@Observable
final class PulseStore {
    var snapshot: PulseSnapshot?
    var isLoading = false
    var errorMessage: String?
    var serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "https://token-pulse-mobile.vercel.app"
    var accessKey = KeychainStore.read(account: "dashboard") ?? ""
    private let client: any SnapshotFetching
    private var refreshGeneration = 0

    init(client: any SnapshotFetching = URLSessionSnapshotClient()) {
        self.client = client
    }

    var isConfigured: Bool { URLSessionSnapshotClient.snapshotURL(serverURL: serverURL) != nil && !accessKey.isEmpty }

    func connect(serverURL: String, accessKey: String) async {
        self.serverURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.accessKey = accessKey.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(self.serverURL, forKey: "serverURL")
        try? KeychainStore.save(self.accessKey, account: "dashboard")
        await refresh()
    }

    func refresh() async {
        guard isConfigured else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        isLoading = true
        defer { if generation == refreshGeneration { isLoading = false } }
        do {
            let nextSnapshot = try await client.fetch(serverURL: serverURL, accessKey: accessKey)
            guard generation == refreshGeneration else { return }
            snapshot = nextSnapshot
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error is PulseError ? "Check the server URL and access key." : "Token Pulse could not reach your dashboard."
        }
    }

    func lock() {
        refreshGeneration += 1
        KeychainStore.delete(account: "dashboard")
        accessKey = ""
        snapshot = nil
    }
}

enum PulseError: Error { case invalidServerURL, invalidResponse, unauthorized, server(Int) }
