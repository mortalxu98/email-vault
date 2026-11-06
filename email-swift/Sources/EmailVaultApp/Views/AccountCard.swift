#if os(macOS)
import AppKit
import EmailVaultCore
import SwiftUI

extension AccountRecord {
    /// Brand icon key resolved from the platform name or URL.
    var logoKey: String? {
        PlatformCatalog.platformLogo(platform: platform, url: url)
    }
}

/// Grid card for one account.
struct AccountCard: View {
    @EnvironmentObject var model: AppModel
    let account: AccountRecord
    var showEmail = false
    @State private var revealed: String?
    @State private var showEdit = false
    @State private var showDelete = false
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AvatarView(text: account.platform, logo: account.logoKey, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.platform).fontWeight(.semibold)
                    CategoryTag(category: account.category)
                }
                Spacer()
                HoverActions(visible: hovering, onEdit: { showEdit = true }, onDelete: { showDelete = true })
            }
            if showEmail {
                EmailLink(account: account)
            }
            if !account.username.isEmpty {
                Button(account.username) { model.copy(account.username, conceal: false) }
                    .buttonStyle(.plain)
            }
            SecretRow(hasPassword: account.hasPassword, revealed: $revealed) {
                try model.accountPassword(account)
            }
            if let url = sanitizedURL(account.url) {
                Link(displayURL(account.url), destination: url)
                    .lineLimit(1)
                    .font(.caption)
            }
            if !account.note.isEmpty {
                Text(account.note).font(.caption).foregroundStyle(.secondary)
            }
            if account.hasSecret {
                SecureNoteRow { try model.accountSecret(account) }
            }
            if let renewal = account.renewal {
                RenewalBadge(renewal: renewal)
            }
        }
        .padding(14)
        .vaultCard()
        .onHover { hovering = $0 }
        .modifier(AccountActions(account: account, showEdit: $showEdit, showDelete: $showDelete))
    }
}

/// Compact table row: platform | email | username | password | url | actions.
struct AccountListRow: View {
    @EnvironmentObject var model: AppModel
    let account: AccountRecord
    var showEmail = false
    @State private var revealed: String?
    @State private var showEdit = false
    @State private var showDelete = false
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            platformColumn
                .frame(minWidth: 140, maxWidth: 200, alignment: .leading)
            if showEmail {
                EmailLink(account: account)
                    .lineLimit(1)
                    .frame(minWidth: 120, maxWidth: 180, alignment: .leading)
            }
            Group {
                if account.username.isEmpty {
                    placeholder
                } else {
                    Button(account.username) { model.copy(account.username, conceal: false) }
                        .buttonStyle(.plain)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            SecretRow(hasPassword: account.hasPassword, revealed: $revealed) {
                try model.accountPassword(account)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if let url = sanitizedURL(account.url) {
                    Link(displayURL(account.url), destination: url)
                } else if account.url.isEmpty {
                    placeholder
                } else {
                    Text(displayURL(account.url))
                }
            }
            .lineLimit(1)
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)

            HoverActions(visible: hovering, onEdit: { showEdit = true }, onDelete: { showDelete = true })
                .frame(width: AccountListHeader.actionsWidth)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(hovering ? Color.primary.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .modifier(AccountActions(account: account, showEdit: $showEdit, showDelete: $showDelete))
    }

    private var platformColumn: some View {
        HStack(spacing: 8) {
            AvatarView(text: account.platform, logo: account.logoKey, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(account.platform)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if account.hasSecret {
                        Image(systemName: "lock.doc")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .help(tr("有安全备注，切到卡片视图查看"))
                    }
                }
                Text(L10n.category(account.category))
                    .font(.caption2)
                    .foregroundStyle(categoryColor(account.category))
                if let renewal = account.renewal {
                    RenewalBadge(renewal: renewal, compact: true)
                }
            }
        }
    }

    private var placeholder: some View {
        Text("—").foregroundStyle(.tertiary)
    }
}

struct AccountListHeader: View {
    static let actionsWidth: CGFloat = 56
    var showEmail = false

    var body: some View {
        HStack(spacing: 12) {
            Text(L10n.platform)
                .frame(minWidth: 140, maxWidth: 200, alignment: .leading)
            if showEmail {
                Text(L10n.emails)
                    .frame(minWidth: 120, maxWidth: 180, alignment: .leading)
            }
            Text(L10n.username).frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.password).frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.url).frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: Self.actionsWidth)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04))
    }
}

/// Cards in a grid or rows in a table, per the user's view mode.
struct ServicesGrid: View {
    @EnvironmentObject var model: AppModel
    let accounts: [AccountRecord]
    var showEmail = false

    var body: some View {
        if model.accountViewMode == .grid {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(accounts) { account in
                    AccountCard(account: account, showEmail: showEmail)
                }
            }
        } else {
            VStack(spacing: 0) {
                AccountListHeader(showEmail: showEmail)
                ForEach(accounts) { account in
                    AccountListRow(account: account, showEmail: showEmail)
                    if account.id != accounts.last?.id {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .vaultCard()
        }
    }
}

/// Masked password with reveal and copy buttons.
struct SecretRow: View {
    @EnvironmentObject var model: AppModel
    let hasPassword: Bool
    @Binding var revealed: String?
    let load: () throws -> String?

    var body: some View {
        HStack(spacing: 6) {
            if hasPassword {
                Text(revealed ?? "••••••••")
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                Button {
                    revealed = revealed == nil ? try? load() : nil
                } label: {
                    Image(systemName: revealed == nil ? "eye" : "eye.slash")
                }
                .buttonStyle(.borderless)
                .help(revealed == nil ? tr("显示") : tr("隐藏"))
                Button {
                    if let secret = revealed ?? (try? load()) {
                        model.copy(secret, conceal: true)
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help(tr("复制"))
            } else {
                Text(L10n.noPassword).foregroundStyle(.secondary).font(.caption)
            }
        }
    }
}

// MARK: - Shared pieces

/// Edit sheet, delete confirmation and right-click menu for an account.
private struct AccountActions: ViewModifier {
    @EnvironmentObject var model: AppModel
    let account: AccountRecord
    @Binding var showEdit: Bool
    @Binding var showDelete: Bool

    func body(content: Content) -> some View {
        content
            .contextMenu { contextMenu }
            .sheet(isPresented: $showEdit) {
                AccountEditorSheet(emailId: account.emailId, account: account)
            }
            .confirmationDialog(trf("删除 %@？", account.platform), isPresented: $showDelete) {
                Button(L10n.delete, role: .destructive) { model.deleteAccount(account) }
            }
    }

    @ViewBuilder
    private var contextMenu: some View {
        if !account.username.isEmpty {
            Button(tr("复制用户名")) { model.copy(account.username, conceal: false) }
        }
        if account.hasPassword {
            Button(tr("复制密码")) { copySecret { try model.accountPassword(account) } }
        }
        if account.hasSecret {
            Button(tr("复制安全备注")) { copySecret { try model.accountSecret(account) } }
        }
        if let url = sanitizedURL(account.url) {
            Button(tr("打开网址")) { NSWorkspace.shared.open(url) }
        }
        Divider()
        Button(L10n.edit) { showEdit = true }
        Button(L10n.delete, role: .destructive) { showDelete = true }
    }

    private func copySecret(_ load: () throws -> String?) {
        if let secret = try? load() {
            model.copy(secret, conceal: true)
        }
    }
}

/// Edit / delete buttons that appear on hover.
private struct HoverActions: View {
    let visible: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onEdit) { Image(systemName: "pencil") }
                .help(L10n.edit)
            Button(action: onDelete) { Image(systemName: "trash") }
                .help(L10n.delete)
        }
        .buttonStyle(.borderless)
        .font(.caption)
        .opacity(visible ? 1 : 0)
    }
}

/// The account's email address; jumps to that email.
private struct EmailLink: View {
    @EnvironmentObject var model: AppModel
    let account: AccountRecord

    var body: some View {
        Button(account.emailAddress) { model.openEmail(account.emailId) }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

/// Small colored category label.
struct CategoryTag: View {
    let category: String

    var body: some View {
        Text(L10n.category(category))
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(categoryColor(category).opacity(0.2))
            .cornerRadius(4)
    }
}
#endif
