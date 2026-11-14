import XCTest
@testable import Requota

final class CodexLiveTests: XCTestCase {
    func testFreshNativeTokenVerifiesIdentityAndReadsLiveUsage() async throws {
        guard let path = ProcessInfo.processInfo.environment["CODEX_LIVE_TOKEN_FILE"] else {
            throw XCTSkip("Requires an independently authorized private Codex sign-in.")
        }
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as? [String: Any])
        let token = try XCTUnwrap(raw["id_token"] as? String)
        let keys = try await ProviderHTTP.json(URLRequest(url: URL(string: OpenAIAuth.issuer + "/.well-known/jwks.json")!))
        let claims = try IdentityVerifier.verify(token, jwks: keys, issuer: OpenAIAuth.issuer, audience: OpenAIAuth.codexClientID, nonce: nil)
        let accountID = (claims["https://api.openai.com/auth"] as? [String: Any])?["chatgpt_account_id"] as? String
        let credential = try OpenAIAuth.credential(raw, previous: nil, clientID: OpenAIAuth.codexClientID, subject: claims["sub"] as! String, accountID: accountID, hostID: "live-test", email: nil)
        let snapshot = try await UsageClient.fetch(account: AgentAccount(provider: .codex), credential: credential)
        XCTAssertTrue(snapshot.identity == credential.registrationIdentity, "Usage must belong to the verified provider, client, subject and workspace.")
        XCTAssertNotNil(snapshot.plan)
        XCTAssertTrue(snapshot.windows.contains { $0.safePercent != nil })
        print("CODEX LIVE: signature, issuer, audience and identity verified; current quota parsed. CLI credentials were not refreshed or replaced.")
    }
}
