import Foundation
import CryptoKit

/// Response structure only. Never retain arbitrary strings, numbers or dynamic keys.
struct ResponseSchema: Codable, Equatable {
    struct Field: Codable, Equatable {
        var path: String
        var type: DiagnosticValueType
        var discriminator: String?
    }
    var fields: [Field]
    var truncated: Bool
    var fingerprint: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return SHA256.hash(data: (try? encoder.encode(self)) ?? Data()).prefix(12).map { String(format: "%02x", $0) }.joined()
    }
    static func capture(_ raw: Any) -> Self {
        let known = Set(("limits kind group percent utilization resets_at five_hour seven_day seven_day_opus seven_day_sonnet seven_day_cowork seven_day_oauth_apps scope model surface id display_name duration duration_seconds limit_window_seconds spend used limit balance amount_minor currency exponent enabled disabled_reason extra_usage is_enabled used_credits monthly_limit decimal_places seven_day_breakdown rows key cedar_ember eligible grants resets_left resets_total paused usable_now starts_at ends_at clears rate_limit primary_window secondary_window used_percent reset_at credits has_credits unlimited balance quota_snapshots buckets remainingFraction remainingAmount remaining_detail remaining modes pro_search type status data error code message config creditUsagePercent currentPeriod planUsage totalPercentUsed autoPercentUsed apiPercentUsed billingCycleStart billingCycleEnd usages usage boosterWallet userStatus planStatus dailyQuotaRemainingPercent weeklyQuotaRemainingPercent").split(separator: " ").map(String.init))
        let priority = ["limits", "rate_limit", "config", "buckets", "quota_snapshots", "planUsage", "usages", "usage", "modes", "userStatus", "data", "five_hour", "seven_day"]
        let tags: [String: Set<String>] = ["kind": ["session", "weekly_all", "weekly_scoped"], "group": ["session", "weekly"]]
        var fields: [Field] = [], truncated = false
        func walk(_ value: Any, path: String, key: String, depth: Int) {
            guard fields.count < 120 else { truncated = true; return }
            let tag = (value as? String).flatMap { tags[key]?.contains($0) == true ? $0 : nil }
            fields.append(Field(path: path, type: UsageParsingDiagnostic.type(value), discriminator: tag))
            guard depth < 6 else { if value is [String: Any] || value is [Any] { truncated = true }; return }
            if let object = value as? [String: Any] {
                let keys = object.keys.sorted {
                    let a = priority.firstIndex(of: $0) ?? (known.contains($0) ? 100 : 200)
                    let b = priority.firstIndex(of: $1) ?? (known.contains($1) ? 100 : 200)
                    return a == b ? $0 < $1 : a < b
                }
                for key in keys.prefix(120) {
                    let name = known.contains(key) ? key : "field_" + SHA256.hash(data: Data(key.utf8)).prefix(6).map { String(format: "%02x", $0) }.joined()
                    walk(object[key]!, path: path + "." + name, key: key, depth: depth + 1)
                }
                if object.count > 120 { truncated = true }
            } else if let values = value as? [Any] {
                for (index, entry) in values.prefix(3).enumerated() { walk(entry, path: path + "[\(index)]", key: "", depth: depth + 1) }
                if values.count > 3 { truncated = true }
            }
        }
        walk(raw, path: "$", key: "", depth: 0)
        return Self(fields: fields, truncated: truncated)
    }
}
