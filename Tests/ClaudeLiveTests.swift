import XCTest
@testable import Requota

final class ClaudeLiveTests: XCTestCase {
    func testLiveOAuthReadsResetInventoryAndMatchesIdentity() async throws {
        guard let path = ProcessInfo.processInfo.environment["CLAUDE_LIVE_SESSION_FILE"] else {
            throw XCTSkip("Requires an authorized private Claude session.")
        }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let credential = try decoder.decode(AccountCredential.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let snapshot = try await UsageClient.fetch(account: AgentAccount(provider: .claude), credential: credential)
        XCTAssertEqual(snapshot.identity, credential.registrationIdentity)
        XCTAssertNotNil(snapshot.plan)
        XCTAssertTrue(snapshot.windows.contains { $0.safePercent != nil })
        if let inventory = snapshot.resetInventory {
            XCTAssertNotNil(snapshot.bankedResets)
            XCTAssertTrue(inventory.grants.allSatisfy { $0.id.hasPrefix("claude-reset-") })
        }
        print("CLAUDE LIVE: identity matched; current usage and plan parsed; reset inventory recognized when eligible.")
    }
}
