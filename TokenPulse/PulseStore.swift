import Foundation
import Observation

@MainActor
@Observable
final class PulseStore {
    var snapshot: PulseSnapshot?
    var isLoading = false
    var errorMessage: String?
    var serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "https://token-pulse-mobile.vercel.app"
    var accessKey = KeychainStore.read(account: "dashboard") ?? ""

    var isConfigured: Bool { URL(string: serverURL) != nil && !accessKey.isEmpty }

    func connect(serverURL: String, accessKey: String) async {
        self.serverURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.accessKey = accessKey.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(self.serverURL, forKey: "serverURL")
        try? KeychainStore.save(self.accessKey, account: "dashboard")
        await refresh()
    }

    func refresh() async {
        guard isConfigured, let url = URL(string: "\(serverURL)/api/snapshot") else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.setValue("Bearer \(accessKey)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw PulseError.unauthorized }
            snapshot = try JSONDecoder().decode(PulseSnapshot.self, from: data)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error is PulseError ? "Check the server URL and access key." : "Token Pulse could not reach your dashboard."
        }
    }

    func lock() {
        KeychainStore.delete(account: "dashboard")
        accessKey = ""
        snapshot = nil
    }
}

enum PulseError: Error { case unauthorized }
