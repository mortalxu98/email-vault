#if os(macOS)
import SwiftUI
import Crypto
import EmailVaultCore

struct PasswordFieldRow: View {
    let placeholder: String
    @Binding var password: String
    @State private var visible = false

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if visible {
                    TextField(placeholder, text: $password)
                } else {
                    SecureField(placeholder, text: $password)
                }
            }
            .textFieldStyle(.roundedBorder)
            Button {
                visible.toggle()
            } label: {
                Image(systemName: visible ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .help(visible ? "隐藏" : "显示")
            Button {
                password = PasswordGenerator.generate()
                visible = true
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("生成随机密码")
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
        VStack(alignment: .leading, spacing: 12) {
            Text(email == nil ? L10n.newEmail : "编辑邮箱").font(.headline)
            TextField("邮箱地址", text: $address)
                .textFieldStyle(.roundedBorder)
            PasswordFieldRow(
                placeholder: email == nil ? L10n.optionalPassword : L10n.leaveBlankKeep,
                password: $password
            )
            TextField("备注", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
            Text(L10n.notePlaintext)
                .font(.caption2).foregroundStyle(.secondary)
            Text(L10n.secureNote).font(.subheadline.weight(.medium))
            SecureNoteEditor(
                text: $secret,
                loaded: $secretLoaded,
                hasExisting: email?.hasSecret ?? false,
                load: { try email.flatMap { try model.decryptEmailSecret($0.id) } }
            )
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button(L10n.cancel) { dismiss() }
                Button(L10n.save) { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
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
            error = "邮箱地址不能为空"
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
                let createEnc: Data? = password.isEmpty ? nil : enc
                let id = try model.store.createEmail(address: address, note: note, passwordEnc: createEnc)
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
    @FocusState private var platformFocused: Bool

    private var catalog: [PlatformCatalog.CatalogEntry] { model.platformCatalog() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(account == nil ? L10n.newService : "编辑服务").font(.headline)
            TextField("平台名称", text: $platform)
                .textFieldStyle(.roundedBorder)
                .focused($platformFocused)
                .onChange(of: platform) { _, new in
                    suggestions = PlatformCatalog.matches(query: new, in: catalog)
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

            if !suggestions.isEmpty {
                suggestionList
            }

            Picker("分类", selection: $category) {
                Text(L10n.category("ai")).tag("ai")
                Text(L10n.category("social")).tag("social")
                Text(L10n.category("crypto")).tag("crypto")
                Text(L10n.category("other")).tag("other")
            }
            TextField(L10n.username, text: $username)
                .textFieldStyle(.roundedBorder)
            PasswordFieldRow(
                placeholder: account == nil ? L10n.optionalPassword : L10n.leaveBlankKeep,
                password: $password
            )
            TextField(L10n.url, text: $url)
                .textFieldStyle(.roundedBorder)
            TextField("备注", text: $note)
                .textFieldStyle(.roundedBorder)
            Text(L10n.secureNote).font(.subheadline.weight(.medium))
            SecureNoteEditor(
                text: $secret,
                loaded: $secretLoaded,
                hasExisting: account?.hasSecret ?? false,
                load: { try account.flatMap { try model.decryptAccountSecret($0.id) } }
            )
            RenewalEditorSection(
                enabled: $renewOn,
                dueDate: $renewDate,
                cycle: $renewCycle,
                amount: $renewAmount,
                leadDays: $renewLead
            )
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button(L10n.cancel) { dismiss() }
                Button(L10n.save) { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
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
                    .padding(.vertical, 6)
                    .background(idx == selectedIndex ? Color.accentColor.opacity(0.15) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(.quaternary.opacity(0.5))
        .cornerRadius(6)
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
            error = "平台名称不能为空"
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
                    passwordEnc: password.isEmpty ? nil : enc,
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
                if let s = model.stats {
                    HStack(spacing: 12) {
                        StatCard(title: L10n.emails, value: s.emails, color: .accentColor)
                        StatCard(title: L10n.services, value: s.accounts, color: .teal)
                    }
                }

                if !model.emails.isEmpty {
                    Text("匹配的邮箱（\(model.emails.count)）")
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
                    Text("搜索「\(model.searchQuery)」：\(model.searchAccounts.count) 个服务")
                        .font(.headline)
                    Spacer()
                    if !model.searchAccounts.isEmpty {
                        Picker("视图", selection: Binding(
                            get: { model.accountViewMode },
                            set: { model.setViewMode($0) }
                        )) {
                            Image(systemName: "square.grid.2x2").tag(AppModel.AccountViewMode.grid)
                            Image(systemName: "list.bullet").tag(AppModel.AccountViewMode.list)
                        }
                        .pickerStyle(.segmented)
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
