import XCTest
@testable import TokenPulse

final class TokenPulseTests: XCTestCase {
    func testSnapshotURLRequiresHTTPSExceptLoopbackAndNormalizesPath() {
        XCTAssertEqual(URLSessionSnapshotClient.snapshotURL(serverURL: "https://example.com/base/")?.absoluteString, "https://example.com/base/api/snapshot")
        XCTAssertEqual(URLSessionSnapshotClient.snapshotURL(serverURL: "http://localhost:3000")?.absoluteString, "http://localhost:3000/api/snapshot")
        XCTAssertNil(URLSessionSnapshotClient.snapshotURL(serverURL: "http://example.com"))
        XCTAssertNil(URLSessionSnapshotClient.snapshotURL(serverURL: "file:///tmp/snapshot"))
        XCTAssertNil(URLSessionSnapshotClient.snapshotURL(serverURL: "not a url"))
    }

    func testSnapshotDecodesACompleteNormalizedPayload() throws {
        let data = Data(#"{"schema":1,"fetchedAt":1,"receivedAt":2,"total":10,"input":8,"output":2,"cacheRead":0,"cacheHitRate":0,"activeSessions":0,"sessions":1,"platforms":[],"hardware":null}"#.utf8)
        let snapshot = try JSONDecoder().decode(PulseSnapshot.self, from: data)
        XCTAssertEqual(snapshot.total, 10)
        XCTAssertEqual(snapshot.receivedAt, 2)
        XCTAssertTrue(snapshot.platforms.isEmpty)
    }

    func testSnapshotRejectsMalformedAndStructurallyIncompletePayloads() {
        let malformed = Data("{bad".utf8)
        let incomplete = Data(#"{"schema":1,"total":10}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(PulseSnapshot.self, from: malformed))
        XCTAssertThrowsError(try JSONDecoder().decode(PulseSnapshot.self, from: incomplete))
    }

    @MainActor
    func testNewerRefreshWinsWhenOlderRequestFinishesLast() async {
        let store = PulseStore(client: DelayedClient())
        store.serverURL = "https://example.com"
        store.accessKey = "old"
        let old = Task { await store.refresh() }
        try? await Task.sleep(for: .milliseconds(5))
        store.accessKey = "new"
        await store.refresh()
        await old.value
        XCTAssertEqual(store.snapshot?.total, 2)
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.errorMessage)
    }

    @MainActor
    func testLockInvalidatesInFlightRefresh() async {
        let store = PulseStore(client: DelayedClient())
        store.serverURL = "https://example.com"
        store.accessKey = "old"
        let request = Task { await store.refresh() }
        try? await Task.sleep(for: .milliseconds(5))
        store.lock()
        await request.value
        XCTAssertNil(store.snapshot)
        XCTAssertEqual(store.accessKey, "")
    }
}

private struct DelayedClient: SnapshotFetching {
    func fetch(serverURL: String, accessKey: String) async throws -> PulseSnapshot {
        try await Task.sleep(for: accessKey == "old" ? .milliseconds(50) : .milliseconds(1))
        return PulseSnapshot(schema: 1, fetchedAt: 1, receivedAt: 1, total: accessKey == "old" ? 1 : 2, input: 0, output: 0, cacheRead: 0, cacheHitRate: 0, activeSessions: 0, sessions: 0, alerts: nil, platforms: [], hardware: nil)
    }
}
