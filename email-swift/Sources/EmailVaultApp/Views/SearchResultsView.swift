#if os(macOS)
import SwiftUI
import EmailVaultCore

struct SearchResultsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !model.emails.isEmpty {
                    Text(trf("匹配的邮箱（%ld）", model.emails.count))
                        .font(.headline)
                    ForEach(model.emails) { email in
                        Button {
                            model.openEmail(email.id)
                        } label: {
                            HStack(spacing: 10) {
                                let provider = PlatformCatalog.provider(for: email.address)
                                AvatarView(text: email.address, logo: provider.logo, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(email.address).fontWeight(.medium)
                                    Text("\(email.accountCount) \(L10n.services) · \(provider.name)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(.quaternary.opacity(0.35))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Text(trf("搜索「%@」：%ld 个服务", model.searchQuery, model.searchAccounts.count))
                        .font(.headline)
                    Spacer()
                    if !model.searchAccounts.isEmpty {
                        Picker(tr("视图"), selection: Binding(
                            get: { model.accountViewMode },
                            set: { model.setViewMode($0) }
                        )) {
                            Image(systemName: "square.grid.2x2").tag(AppModel.AccountViewMode.grid)
                            Image(systemName: "list.bullet").tag(AppModel.AccountViewMode.list)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 80)
                    }
                }

                if model.searchAccounts.isEmpty && model.emails.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: L10n.noSearchResults
                    )
                    .frame(maxWidth: .infinity)
                } else if !model.searchAccounts.isEmpty {
                    ServicesGrid(accounts: model.searchAccounts, showEmail: true)
                }
            }
            .padding()
        }
    }
}
#endif
