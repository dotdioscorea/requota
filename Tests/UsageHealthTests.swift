import XCTest
@testable import Requota

final class UsageHealthTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func testStructuredClaudeInventoryReplacesObsoleteLegacyMetersAndValues() throws {
        let raw: [String: Any] = ["five_hour": ["utilization": 90], "seven_day": ["utilization": 80], "limits": [
            ["kind": "weekly_all", "group": "weekly", "percent": 39, "resets_at": "2026-11-10T23:00:00.714974+00:00", "scope": NSNull(), "is_active": true],
            ["kind": "weekly_scoped", "group": "weekly", "percent": 0, "scope": ["model": ["id": NSNull(), "display_name": "Fable"], "surface": NSNull()], "is_active": false]
        ]]
        let snapshot = try UsageParser.claude(raw)
        XCTAssertEqual(snapshot.windows.count, 2)
        XCTAssertFalse(snapshot.windows.contains { $0.id == "five_hour" })
        XCTAssertEqual(snapshot.windows.first?.safePercent, 39)
        XCTAssertEqual(snapshot.windows.first?.clockReported, true)
        XCTAssertEqual(snapshot.windows.last?.safePercent, 0)
        XCTAssertNotNil(snapshot.windows.first?.resetsAt)
    }
    func testClaudeEmptyOrMalformedInventoryCannotBecomeFreshSuccess() {
        for raw: [String: Any] in [["limits": []], ["five_hour": NSNull(), "seven_day": NSNull()], ["limits": "changed"],
          ["limits": [["kind": "weekly_all", "group": "weekly", "percent": "39"]]],
          ["seven_day": ["utilization": 25], "limits": [["kind": "new_meter", "group": "yearly", "percent": 20]]]] {
            XCTAssertThrowsError(try UsageParser.claude(raw))
        }
        XCTAssertEqual(try UsageParser.claude(["seven_day": ["utilization": 0]]).windows.first?.safePercent, 0)
    }
    func testQuotaOvershootRemainsReadableWhileDisplayCapsAtExhausted() throws {
        let snapshot = try UsageParser.claude(["limits": [["kind": "weekly_all", "group": "weekly", "percent": 100.5]]])
        XCTAssertEqual(snapshot.windows.first?.usedPercent, 100.5)
        XCTAssertEqual(snapshot.windows.first?.safePercent, 100)
    }
    func testHealthImmediatelyShowsFailureAndAgesEvenWithoutRefreshDelivery() throws {
        var account = AgentAccount(provider: .claude, snapshot: UsageSnapshot(windows: [], updatedAt: now))
        XCTAssertEqual(account.health(at: now), .current)
        account.issue = "Network error with private details"
        XCTAssertEqual(account.health(at: now), .refreshFailed)
        let cache = try XCTUnwrap(WidgetCache.sanitized([account]).first)
        XCTAssertEqual(cache.health(at: now), .refreshFailed)
        XCTAssertFalse(cache.issue!.contains("private"))
        account.needsReport = true; XCTAssertEqual(account.health(at: now), .responseChanged)
        account.needsLogin = true; XCTAssertEqual(account.health(at: now), .reconnect)
        account.needsLogin = false; account.needsReport = nil; account.issue = nil
        XCTAssertEqual(account.health(at: now.addingTimeInterval(1801)), .stale)
        XCTAssertEqual(try JSONDecoder().decode(AgentAccount.self, from: JSONEncoder().encode(account)).health(at: now), .current)
    }
    func testFailureSchemaKeepsStructureButNeverArbitraryValuesOrKeys() throws {
        let secret = "private-user-token@example.test"
        let raw: [String: Any] = ["limits": [["kind": "weekly_all", "group": "weekly", "percent": secret]], secret: ["message": secret, "id": "credential-secret"]]
        let diagnostic = UsageParsingDiagnostic.make(provider: .claude, raw: raw, snapshot: nil)
        let schema = try XCTUnwrap(diagnostic.responseSchema)
        XCTAssertTrue(schema.fields.contains { $0.path == "$.limits[0].percent" && $0.type == .string })
        XCTAssertTrue(schema.fields.contains { $0.discriminator == "weekly_all" })
        let data = try JSONEncoder().encode(diagnostic), text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains(secret)); XCTAssertFalse(text.contains("credential-secret"))
        XCTAssertEqual(try JSONDecoder().decode(UsageParsingDiagnostic.self, from: data).responseSchema, schema)
        XCTAssertEqual(schema.fingerprint, ResponseSchema.capture(raw).fingerprint)
        let bounded = ResponseSchema.capture(["limits": Array(repeating: raw, count: 200)])
        XCTAssertLessThanOrEqual(bounded.fields.count, 120); XCTAssertTrue(bounded.truncated)
    }
    func testFailuresDeduplicateAndOutliveOrdinaryDiagnosticRing() throws {
        let parsing = UsageParsingDiagnostic.make(provider: .claude, raw: ["limits": "changed"], snapshot: nil)
        let event = DiagnosticEvent(date: now, provider: .claude, stage: .usageParsed, parsing: parsing, connection: "private-id")
        var later = event; later.date = now.addingTimeInterval(30)
        var other = event; other.connection = "other-private-id"
        XCTAssertEqual(Diagnostics.retainedFailures([event, later, other], now: now.addingTimeInterval(8 * 86400)).count, 2)
        XCTAssertTrue(Diagnostics.retainedFailures([event], now: now.addingTimeInterval(31 * 86400)).isEmpty)
    }
    @MainActor func testArchivedSchemaSurvivesSuccessfulPollsAndReportIncludesItWithoutAttachment() throws {
        Diagnostics.clear(); defer { Diagnostics.clear() }
        let account = AgentAccount(provider: .claude, label: "Private label")
        Diagnostics.$context.withValue(.init(provider: .claude, accountID: account.id)) {
            Diagnostics.record(.usageParsed, parsing: .make(provider: .claude, raw: ["limits": "private-value"], snapshot: nil))
        }
        for _ in 0..<105 { Diagnostics.record(.http, provider: .codex, status: 200, endpoint: .usage) }
        let bundle = Diagnostics.bundle(accounts: [account])
        XCTAssertEqual(bundle.responseFailures?.count, 1)
        XCTAssertEqual(bundle.responseFailures?.first?.connection, "account-1")
        XCTAssertEqual(bundle.responseFailures?.first?.parsing?.responseSchema?.fields.last?.type, .string)
        let evidence = Diagnostics.issueEvidence(accounts: [account])
        XCTAssertTrue(evidence.contains("$.limits: string"))
        XCTAssertFalse(evidence.contains("private-value")); XCTAssertFalse(evidence.contains(account.id.uuidString)); XCTAssertFalse(evidence.contains(account.label))
    }
    func testRemovedSelectedLimitIsDifferentFromFailedOrStaleUsage() throws {
        let snapshot = try UsageParser.claude(["limits": [["kind": "weekly_all", "group": "weekly", "percent": 39]]], now: now)
        let account = AgentAccount(provider: .claude, snapshot: snapshot, display: .init(rings: [.init(windowID: "five_hour"), .init(windowID: "seven_day")]))
        XCTAssertEqual(account.health(at: now), .limitsChanged)
        XCTAssertNil(account.readings(at: now).first?.percent)
        XCTAssertEqual(account.readings(at: now).last?.percent, 61)
    }
    func testFreshnessWarningIsScheduledAheadAndRearmedOnlyAfterRecovery() throws {
        var account = AgentAccount(provider: .claude, snapshot: UsageSnapshot(windows: [], updatedAt: now))
        let rules = ResetNotificationRules()
        let reminder = try XCTUnwrap(UsageHealthReminderPlan.make(accounts: [account], rules: rules, now: now).first)
        XCTAssertEqual(reminder.date, now.addingTimeInterval(6 * 3600))
        let delivered = [reminder.id: now.addingTimeInterval(-10)]
        XCTAssertFalse(ReminderLedger.shouldAdd(reminder, ledger: delivered, now: now))
        account.issue = "Update failed"
        XCTAssertEqual(UsageHealthReminderPlan.make(accounts: [account], rules: rules, now: now).first?.date, now.addingTimeInterval(3))
        XCTAssertEqual(ReminderLedger.rearmRecovered(delivered, accounts: [account], rules: rules, overrides: [:], now: now), delivered)
        account.issue = nil
        XCTAssertTrue(ReminderLedger.rearmRecovered(delivered, accounts: [account], rules: rules, overrides: [:], now: now).isEmpty)
        var disabled = rules; disabled.staleReadings = false
        XCTAssertTrue(UsageHealthReminderPlan.make(accounts: [account], rules: rules, overrides: ["claude": disabled], now: now).isEmpty)
        let old = try JSONDecoder().decode(ResetNotificationRules.self, from: Data("{}".utf8))
        XCTAssertTrue(old.staleReadings); XCTAssertEqual(old.staleAfterHours, 6)
    }
}
