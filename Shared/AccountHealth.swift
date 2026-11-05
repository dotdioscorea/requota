import Foundation

enum AccountHealth: String, Codable {
    case current, stale, refreshFailed, responseChanged, reconnect, noReading, limitsChanged
    var title: String {
        switch self {
        case .current: return "Up to date"
        case .stale: return "Out of date"
        case .refreshFailed: return "Update failed"
        case .responseChanged: return "Usage unavailable"
        case .reconnect: return "Sign in again"
        case .noReading: return "No reading"
        case .limitsChanged: return "Limits changed"
        }
    }
    var needsAttention: Bool { self != .current }
}
extension AgentAccount {
    func health(at now: Date = .now) -> AccountHealth {
        if needsLogin { return .reconnect }
        if needsReport == true { return .responseChanged }
        if issue != nil { return .refreshFailed }
        guard let snapshot else { return .noReading }
        if snapshot.isStale(at: now) { return .stale }
        if displaySettings.rings.contains(where: { ring in !snapshot.windows.contains(where: { $0.id == ring.windowID }) }) { return .limitsChanged }
        return .current
    }
}
