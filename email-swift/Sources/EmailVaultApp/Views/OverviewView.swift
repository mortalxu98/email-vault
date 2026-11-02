#if os(macOS)
import SwiftUI
import EmailVaultCore

/// Home page when no email is selected: vault stats, renewals, recent changes.
struct OverviewView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("总览").font(.largeTitle.bold())
                statsRow
                renewalsSection
                recentSection
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var statsRow: some View {
        let s = model.stats
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], alignment: .leading, spacing: 12) {
            StatCard(title: L10n.emails, value: s?.emails ?? 0, color: .accentColor)
            StatCard(title: L10n.services, value: s?.accounts ?? 0, color: .teal)
            StatCard(title: L10n.noPassword, value: s?.withoutPassword ?? 0, color: .secondary)
            StatCard(title: "续费项", value: model.allRenewals.count, color: .orange)
            ForEach(["ai", "social", "crypto", "other"], id: \.self) { cat in
                if let n = s?.byCategory[cat], n > 0 {
                    StatCard(title: L10n.category(cat), value: n, color: categoryColor(cat))
                }
            }
        }
    }

    private var renewalsSection: some View {
        OverviewSection(title: "续费", systemImage: "calendar.badge.clock") {
            if model.allRenewals.isEmpty {
                Text("还没有续费项。编辑服务时打开「续费提醒」即可。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
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
        OverviewSection(title: "最近修改", systemImage: "clock.arrow.circlepath") {
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

private struct OverviewSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            VStack(spacing: 0) { content }
                .background(.quaternary.opacity(0.35))
                .cornerRadius(10)
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
        let logo = PlatformCatalog.platformLogo(platform: account.platform, url: account.url)
        Button {
            model.selectEmail(account.emailId)
        } label: {
            HStack(spacing: 12) {
                AvatarView(
                    text: account.platform,
                    logo: logo,
                    size: 28,
                    wide: PlatformCatalog.wideLogos.contains(logo ?? "")
                )
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
