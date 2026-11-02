#if os(macOS)
import SwiftUI
import Crypto
import EmailVaultCore

struct PasswordFieldRow: View {
    let label: String
    let placeholder: String
    @Binding var password: String
    @State private var visible = false

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                Group {
                    if visible {
                        TextField(label, text: $password, prompt: Text(placeholder))
                    } else {
                        SecureField(label, text: $password, prompt: Text(placeholder))
                    }
                }
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                Button {
                    visible.toggle()
                } label: {
                    Image(systemName: visible ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(visible ? tr("隐藏") : tr("显示"))
                Button {
                    password = PasswordGenerator.generate()
                    visible = true
                } label: {
                    Image(systemName: "dice")
                }
                .buttonStyle(.borderless)
                .help(tr("生成随机密码"))
            }
        }
    }
}

/// Bottom bar shared by editor sheets: error on the left, actions on the right.
struct SheetActions: View {
    let error: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
        Divider()
        HStack {
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            Spacer()
            Button(L10n.cancel, action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button(L10n.save, action: onSave)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        }
    }
}

struct EmailEditorSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let email: EmailRecord?

    @State private var address = ""
    @State private var note = ""
    @State private var password = ""
    @State private var secret = ""
    @State private var secretLoaded = true
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField(tr("邮箱地址"), text: $address, prompt: Text("name@example.com"))
                    PasswordFieldRow(
                        label: L10n.emailPassword,
                        placeholder: email == nil ? L10n.optionalPassword : L10n.leaveBlankKeep,
                        password: $password
                    )
                } header: {
                    Text(email == nil ? L10n.newEmail : tr("编辑邮箱"))
                }
                Section {
                    TextField(tr("备注"), text: $note, prompt: Text(tr("可选")), axis: .vertical)
                        .lineLimit(1...4)
                } footer: {
                    Text(L10n.notePlaintext).font(.caption).foregroundStyle(.secondary)
                }
                Section(L10n.secureNote) {
                    SecureNoteEditor(
                        text: $secret,
                        loaded: $secretLoaded,
                        hasExisting: email?.hasSecret ?? false,
                        load: { try email.flatMap { try model.decryptEmailSecret($0.id) } }
                    )
                }
            }
            .formStyle(.grouped)
            SheetActions(error: error, onCancel: { dismiss() }, onSave: save)
        }
        .frame(width: 480)
        .frame(minHeight: 360, idealHeight: 460)
        .onAppear {
            if let email {
                address = email.address
                note = email.note
                secretLoaded = !email.hasSecret
            }
        }
    }

    private func save() {
        guard let key = model.key else { return }
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            error = tr("邮箱地址不能为空")
            return
        }
        do {
            let enc: Data? = password.isEmpty ? nil : try VaultCrypto.encrypt(password, with: key)
            let secretEnc = secretLoaded ? try model.encryptSecret(secret) : nil
            if let email {
                try model.store.updateEmail(id: email.id, address: address, note: note, passwordEnc: enc)
                if secretLoaded { try model.store.setEmailSecret(email.id, secretEnc: secretEnc) }
                model.selectEmail(email.id)
            } else {
                let id = try model.store.createEmail(address: address, note: note, passwordEnc: enc)
                if secretEnc != nil { try model.store.setEmailSecret(id, secretEnc: secretEnc) }
                model.selectEmail(id)
            }
            model.refresh()
            dismiss()
        } catch StoreError.duplicateEmail {
            error = L10n.duplicateEmail
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct AccountEditorSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let emailId: Int64
    let account: AccountRecord?

    @State private var platform = ""
    @State private var category = "other"
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    @State private var note = ""
    @State private var secret = ""
    @State private var secretLoaded = true
    @State private var renewOn = false
    @State private var renewDate = Date()
    @State private var renewCycle: RenewalCycle = .yearly
    @State private var renewAmount = ""
    @State private var renewLead = Renewal.defaultLeadDays
    @State private var suggestions: [PlatformCatalog.CatalogEntry] = []
    @State private var selectedIndex = 0
    @State private var autoURL = ""
    @State private var error: String?

    private var catalog: [PlatformCatalog.CatalogEntry] { model.platformCatalog() }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    platformField
                    if !suggestions.isEmpty {
                        suggestionList
                    }
                    Picker(tr("分类"), selection: $category) {
                        Text(L10n.category("ai")).tag("ai")
                        Text(L10n.category("social")).tag("social")
                        Text(L10n.category("crypto")).tag("crypto")
                        Text(L10n.category("other")).tag("other")
                    }
                } header: {
                    Text(account == nil ? L10n.newService : tr("编辑服务"))
                }
                Section(tr("登录信息")) {
                    TextField(L10n.username, text: $username, prompt: Text(tr("可选")))
                    PasswordFieldRow(
                        label: L10n.password,
                        placeholder: account == nil ? L10n.optionalPassword : L10n.leaveBlankKeep,
                        password: $password
                    )
                    TextField(L10n.url, text: $url, prompt: Text("https://"))
                }
                Section {
                    TextField(tr("备注"), text: $note, prompt: Text(tr("可选")), axis: .vertical)
                        .lineLimit(1...3)
                } footer: {
                    Text(L10n.notePlaintext).font(.caption).foregroundStyle(.secondary)
                }
                Section(L10n.secureNote) {
                    SecureNoteEditor(
                        text: $secret,
                        loaded: $secretLoaded,
                        hasExisting: account?.hasSecret ?? false,
                        load: { try account.flatMap { try model.decryptAccountSecret($0.id) } }
                    )
                }
                Section {
                    RenewalEditorSection(
                        enabled: $renewOn,
                        dueDate: $renewDate,
                        cycle: $renewCycle,
                        amount: $renewAmount,
                        leadDays: $renewLead
                    )
                }
            }
            .formStyle(.grouped)
            SheetActions(error: error, onCancel: { dismiss() }, onSave: save)
        }
        .frame(width: 520)
        .frame(minHeight: 400, idealHeight: 540)
        .onAppear {
            if let account {
                platform = account.platform
                category = account.category
                username = account.username
                url = account.url
                note = account.note
                secretLoaded = !account.hasSecret
                if let r = account.renewal {
                    renewOn = true
                    renewDate = Renewal.parse(r.dueDate) ?? Date()
                    renewCycle = r.cycle
                    renewAmount = r.amount
                    renewLead = r.leadDays
                }
            }
        }
    }

    private var platformField: some View {
        TextField(tr("平台名称"), text: $platform, prompt: Text(tr("输入会自动补全")))
            .onChange(of: platform) { _, new in
                suggestions = PlatformCatalog.matches(query: new, in: catalog)
                    .filter { $0.name != new }
                selectedIndex = 0
            }
            .onKeyPress(.downArrow) {
                guard !suggestions.isEmpty else { return .ignored }
                selectedIndex = (selectedIndex + 1) % suggestions.count
                return .handled
            }
            .onKeyPress(.upArrow) {
                guard !suggestions.isEmpty else { return .ignored }
                selectedIndex = (selectedIndex - 1 + suggestions.count) % suggestions.count
                return .handled
            }
            .onKeyPress(.return) {
                guard !suggestions.isEmpty else { return .ignored }
                pick(suggestions[selectedIndex])
                return .handled
            }
            .onKeyPress(.escape) {
                if !suggestions.isEmpty {
                    suggestions = []
                    return .handled
                }
                return .ignored
            }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element.name) { idx, entry in
                Button {
                    pick(entry)
                } label: {
                    HStack(spacing: 8) {
                        AvatarView(
                            text: entry.name,
                            logo: entry.logo,
                            size: 22,
                            wide: PlatformCatalog.wideLogos.contains(entry.logo ?? "")
                        )
                        Text(entry.name)
                            .foregroundStyle(.primary)
                        Text(L10n.category(entry.category))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(categoryColor(entry.category).opacity(0.2))
                            .cornerRadius(4)
                        Spacer()
                        Text(entry.mine ? L10n.usedBefore : displayURL(entry.url))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(idx == selectedIndex ? Color.accentColor.opacity(0.18) : Color.clear)
                    .cornerRadius(5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pick(_ entry: PlatformCatalog.CatalogEntry) {
        platform = entry.name
        category = entry.category
        if url.isEmpty || url == autoURL {
            url = entry.url
            autoURL = entry.url
        }
        suggestions = []
    }

    private func save() {
        guard let key = model.key else { return }
        let platform = platform.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URLNormalizer.normalize(url)
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !platform.isEmpty else {
            error = tr("平台名称不能为空")
            return
        }
        let renewal: Renewal? = renewOn
            ? Renewal(
                dueDate: Renewal.format(renewDate),
                cycle: renewCycle,
                amount: renewAmount.trimmingCharacters(in: .whitespacesAndNewlines),
                leadDays: renewLead
            )
            : nil
        do {
            let enc: Data? = password.isEmpty ? nil : try VaultCrypto.encrypt(password, with: key)
            let secretEnc = secretLoaded ? try model.encryptSecret(secret) : nil
            if let account {
                try model.store.updateAccount(
                    id: account.id, platform: platform, category: category,
                    username: username, url: url, note: note, passwordEnc: enc,
                    renewal: renewal
                )
                if secretLoaded { try model.store.setAccountSecret(account.id, secretEnc: secretEnc) }
            } else {
                let id = try model.store.createAccount(
                    emailId: emailId, platform: platform, category: category,
                    username: username, url: url, note: note,
                    passwordEnc: enc,
                    renewal: renewal
                )
                if secretEnc != nil { try model.store.setAccountSecret(id, secretEnc: secretEnc) }
            }
            model.refresh()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

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
                            model.searchQuery = ""
                            model.selectEmail(email.id)
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
