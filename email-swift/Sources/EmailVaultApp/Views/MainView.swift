#if os(macOS)
import SwiftUI
import AppKit
import EmailVaultCore

struct MainView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
        } detail: {
            VStack(spacing: 0) {
                if !model.trimmedQuery.isEmpty {
                    if !model.dueRenewals.isEmpty { RenewalBanner() }
                    SearchResultsView()
                } else if let email = model.selectedEmail {
                    if !model.dueRenewals.isEmpty { RenewalBanner() }
                    EmailDetailView(email: email)
                } else if model.emails.isEmpty {
                    EmptyStateView(
                        systemImage: "envelope.fill",
                        title: L10n.welcomeTitle,
                        subtitle: L10n.welcomeBody,
                        big: true
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    OverviewView()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        model.goHome()
                    } label: {
                        Label("总览", systemImage: "house")
                    }
                    .help("总览")
                    Menu {
                        Button("导出备份…") { exportBackup() }
                        Button("导出 CSV（明文）…") { model.showExportCSV = true }
                        Button("修改主密码…") { model.showChangePassword = true }
                        if model.touchIDAvailable {
                            Divider()
                            Toggle("使用 Touch ID 解锁", isOn: Binding(
                                get: { model.touchIDEnabled },
                                set: { $0 ? model.enableTouchID() : model.disableTouchID() }
                            ))
                        }
                    } label: {
                        Label("更多", systemImage: "ellipsis.circle")
                    }
                    .help("更多")
                    Button {
                        model.lock()
                    } label: {
                        Label(L10n.lock, systemImage: "lock")
                    }
                    .help("锁定（⌘L）")
                }
            }
        }
        .sheet(isPresented: $model.showChangePassword) {
            ChangePasswordSheet()
        }
        .sheet(isPresented: $model.showExportCSV) {
            ExportCSVSheet()
        }
        .onAppear { model.refresh() }
        .onChange(of: model.searchQuery) { _, q in
            model.refresh()
        }
        .idleActivityTracking()
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "email-vault-backup-\(Renewal.format(Date())).db"
        panel.allowedContentTypes = [.data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.exportBackup(to: url)
        } catch {
            model.errorMessage = error.localizedDescription
            model.showToast("导出失败")
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var model: AppModel
    @State private var showNewEmail = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(L10n.searchPlaceholder, text: $model.searchQuery)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                if !model.searchQuery.isEmpty {
                    Button {
                        model.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.5))
            .cornerRadius(8)
            .padding([.horizontal, .top], 8)

            Button {
                showNewEmail = true
            } label: {
                Label(L10n.newEmail, systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(8)

            if grouped.isEmpty {
                Text(model.trimmedQuery.isEmpty ? "还没有邮箱" : "没有匹配的邮箱")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                Spacer()
            } else {
                List(selection: Binding(
                    get: { model.selectedEmailId },
                    set: { model.selectEmail($0) }
                )) {
                    ForEach(grouped, id: \.0.name) { provider, emails in
                        Section(provider.name) {
                            ForEach(emails) { email in
                                EmailRow(email: email, provider: provider)
                                    .tag(email.id)
                                    .listRowBackground(
                                        selectionBar(for: email.id)
                                    )
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .onChange(of: model.focusSearch) { _, v in
            if v {
                searchFocused = true
                model.focusSearch = false
            }
        }
        .onChange(of: model.requestNewEmail) { _, v in
            if v {
                showNewEmail = true
                model.requestNewEmail = false
            }
        }
        .sheet(isPresented: $showNewEmail) {
            EmailEditorSheet(email: nil)
        }
    }

    private var grouped: [(Provider, [EmailRecord])] {
        PlatformCatalog.groupByProvider(model.emails, address: \.address)
    }

    @ViewBuilder
    private func selectionBar(for id: Int64) -> some View {
        if model.selectedEmailId == id {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)
                Color.accentColor.opacity(0.12)
            }
        } else {
            Color.clear
        }
    }
}

struct EmailRow: View {
    let email: EmailRecord
    let provider: Provider

    var body: some View {
        HStack(spacing: 8) {
            AvatarView(text: email.address, logo: provider.logo, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                let parts = PlatformCatalog.splitAddress(email.address)
                Text(parts.local).fontWeight(.medium)
                Text(parts.domain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(email.accountCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
