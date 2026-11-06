#if os(macOS)
import SwiftUI
import EmailVaultCore

/// Home page when no email is selected: vault stats, renewals, recent changes.
struct OverviewView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(tr("总览"))
                    .font(.system(size: 28, weight: .bold))
                hero
                renewalsSection
                recentSection
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                BigStat(title: L10n.emails, value: model.stats?.emails ?? 0)
                BigStat(title: L10n.services, value: model.stats?.accounts ?? 0)
            }
            attentionCard
        }
    }

    private var attentionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(attentionTitle)
                .font(.headline)
            if model.dueRenewals.isEmpty {
                Text(tr("没有需要处理的续费"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(model.dueRenewals) { account in
                    OverviewRow(account: account) {
                        if let renewal = account.renewal {
                            RenewalBadge(renewal: renewal)
                        }
                    }
                    if account.id != model.dueRenewals.last?.id {
                        Divider().padding(.leading, 40)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vaultCard()
    }

    private var attentionTitle: String {
        let count = model.dueRenewals.count
        if count == 0 { return tr("需要处理") }
        return trf("需要处理 · %ld", count)
    }

    private var renewalsSection: some View {
        OverviewSection(title: tr("续费"), systemImage: "calendar.badge.clock") {
            if model.allRenewals.isEmpty {
                Text(tr("还没有续费项。编辑服务时打开「续费提醒」即可。"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(14)
            } else {
                ForEach(model.allRenewals) { account in
                    OverviewRow(account: account) {
                        if let renewal = account.renewal {
                            RenewalBadge(renewal: renewal)
                        }
                    }
                    if account.id != model.allRenewals.last?.id { Divider().padding(.leading, 48) }
                }
            }
        }
    }

    private var recentSection: some View {
        OverviewSection(title: tr("最近修改"), systemImage: "clock.arrow.circlepath") {
            if model.recentAccounts.isEmpty {
                Text(tr("还没有最近修改"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(14)
            } else {
                ForEach(model.recentAccounts) { account in
                    OverviewRow(account: account) {
                        Text(L10n.category(account.category))
                            .font(.caption)
                            .foregroundStyle(categoryColor(account.category))
                    }
                    if account.id != model.recentAccounts.last?.id { Divider().padding(.leading, 48) }
                }
            }
        }
    }
}

private struct BigStat: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 28, weight: .bold))
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .vaultCard()
    }
}

private struct OverviewSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            VStack(spacing: 0) { content }
                .vaultCard()
        }
    }
}

/// Clickable account row that jumps to its email.
private struct OverviewRow<Trailing: View>: View {
    @EnvironmentObject var model: AppModel
    let account: AccountRecord
    @ViewBuilder let trailing: Trailing
    @State private var hovering = false

    var body: some View {
        Button {
            model.selectEmail(account.emailId)
        } label: {
            HStack(spacing: 12) {
                AvatarView(text: account.platform, logo: account.logoKey, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(account.platform).fontWeight(.medium)
                    Text(account.emailAddress).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                trailing
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(hovering ? Color.primary.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
#endif
