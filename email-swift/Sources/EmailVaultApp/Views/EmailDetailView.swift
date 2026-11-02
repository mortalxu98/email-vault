#if os(macOS)
import SwiftUI
import AppKit
import EmailVaultCore

struct EmailDetailView: View {
    @EnvironmentObject var model: AppModel
    let email: EmailRecord
    @State private var showEdit = false
    @State private var showDelete = false
    @State private var showNewAccount = false
    @State private var revealedPassword: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                servicesSection
            }
            .padding()
        }
        .sheet(isPresented: $showEdit) {
            EmailEditorSheet(email: email)
        }
        .sheet(isPresented: $showNewAccount) {
            AccountEditorSheet(emailId: email.id, account: nil)
        }
        .confirmationDialog(
            trf("删除 %@？将同时删除 %ld 个服务。", email.address, email.accountCount),
            isPresented: $showDelete,
            titleVisibility: .visible
        ) {
            Button(L10n.delete, role: .destructive) { model.deleteEmail(email) }
        }
        .onChange(of: model.requestNewAccount) { _, v in
            if v {
                showNewAccount = true
                model.requestNewAccount = false
            }
        }
        .onChange(of: email.id) { _, _ in
            revealedPassword = nil
        }
    }

    private var header: some View {
        let provider = PlatformCatalog.provider(for: email.address)
        return HStack(alignment: .top, spacing: 16) {
            AvatarView(text: email.address, logo: provider.logo, size: 64)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(email.address).font(.title2.bold())
                    Button {
                        model.copy(email.address, conceal: false)
                    } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless)
                }
                Text(provider.name)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .cornerRadius(4)
                Text("\(email.accountCount) \(L10n.services)")
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(L10n.emailPassword)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecretRow(hasPassword: email.hasPassword, revealed: $revealedPassword) {
                        try model.emailPassword(email)
                    }
                }
                if !email.note.isEmpty {
                    Text(email.note).foregroundStyle(.secondary)
                }
                if email.hasSecret {
                    SecureNoteRow { try model.emailSecret(email) }
                        .id(email.id)
                }
                Text(L10n.notePlaintext)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button(L10n.edit) { showEdit = true }
            Menu {
                Button(role: .destructive) {
                    showDelete = true
                } label: {
                    Label(tr("删除邮箱…"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(tr("更多"))
        }
        .padding(20)
        .background(.quaternary.opacity(0.35))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .cornerRadius(14)
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                categoryChips
                Spacer()
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
                .help(tr("卡片 / 列表"))
                Button {
                    showNewAccount = true
                } label: {
                    Label(L10n.newService, systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            let filtered = model.accounts.filter {
                model.categoryFilter == "all" || $0.category == model.categoryFilter
            }
            if filtered.isEmpty {
                EmptyStateView(
                    systemImage: "square.stack.3d.up",
                    title: L10n.noServices,
                    subtitle: L10n.noServicesHint
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ServicesGrid(accounts: filtered)
            }
        }
    }

    private var categoryChips: some View {
        HStack {
            chip("all", L10n.category("all"), model.accounts.count)
            ForEach(["ai", "social", "crypto", "other"], id: \.self) { cat in
                let n = model.accounts.filter { $0.category == cat }.count
                if n > 0 {
                    chip(cat, L10n.category(cat), n)
                }
            }
        }
    }

    private func chip(_ id: String, _ title: String, _ count: Int) -> some View {
        Button("\(title) (\(count))") {
            model.categoryFilter = id
        }
        .buttonStyle(.bordered)
        .tint(model.categoryFilter == id ? .accentColor : .gray)
    }
}

struct StatCard: View {
    let title: String
    let value: Int
    var color: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text("\(value)").font(.title2.bold())
        }
        .padding(10)
        .frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4))
        .cornerRadius(10)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var subtitle: String? = nil
    var big: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: big ? 36 : 28))
                .foregroundStyle(.secondary)
                .padding(big ? 18 : 14)
                .background(Color.primary.opacity(0.05))
                .clipShape(Circle())
            Text(title).font(big ? .title3.weight(.semibold) : .body.weight(.medium))
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(big ? 64 : 24)
    }
}
#endif
