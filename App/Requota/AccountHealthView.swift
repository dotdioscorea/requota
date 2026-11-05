import SwiftUI

struct AccountHealthLabel: View {
    let account: AgentAccount
    var now = Date.now
    var body: some View {
        if account.health(at: now).needsAttention {
            Label(account.health(at: now).title, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange).font(.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("account-health-" + account.id.uuidString)
        }
    }
}
struct AccountHealthBanner: View {
    let account: AgentAccount
    var report: () -> Void
    var configure: () -> Void
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if account.health(at: context.date).needsAttention {
                VStack(alignment: .leading, spacing: 10) {
                    AccountHealthLabel(account: account, now: context.date)
                    Text(account.issue ?? (account.health(at: context.date) == .limitsChanged ? "The provider no longer reports a selected limit." : "Pull down to update usage.")).font(.subheadline)
                    if let updated = account.snapshot?.updatedAt {
                        Text("Last successful update: \(updated.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                    }
                    if account.needsReport == true { Button("Report problem", action: report) }
                    if account.health(at: context.date) == .limitsChanged { Button("Update display settings", action: configure) }
                }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).panel()
            }
        }
    }
}
