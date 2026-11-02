#if os(macOS)
import SwiftUI
import EmailVaultCore

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
                        load: { try account.flatMap { try model.accountSecret($0) } }
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
                        AvatarView(text: entry.name, logo: entry.logo, size: 22)
                        Text(entry.name)
                            .foregroundStyle(.primary)
                        CategoryTag(category: entry.category)
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
        let renewal = renewOn
            ? Renewal(
                dueDate: Renewal.format(renewDate),
                cycle: renewCycle,
                amount: renewAmount.trimmingCharacters(in: .whitespacesAndNewlines),
                leadDays: renewLead
            )
            : nil
        let draft = AccountDraft(
            platform: platform, category: category, username: username,
            url: url, note: note, renewal: renewal
        )
        do {
            try model.saveAccount(
                account, emailId: emailId, draft: draft, password: password,
                secret: secretLoaded ? secret : nil
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
#endif
