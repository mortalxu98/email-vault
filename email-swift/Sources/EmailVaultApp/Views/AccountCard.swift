#if os(macOS)
import SwiftUI
import AppKit
import EmailVaultCore

struct AccountCard: View {
    @EnvironmentObject var model: AppModel
    let account: AccountRecord
    var showEmail: Bool = false
    @State private var revealed: String?
    @State private var showEdit = false
    @State private var showDelete = false
    @State private var hovering = false

    private var logoKey: String? {
        PlatformCatalog.platformLogo(platform: account.platform, url: account.url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(categoryColor(account.category))
                .frame(height: 3)
            HStack {
                AvatarView(
                    text: account.platform,
                    logo: logoKey,
                    size: 32,
                    wide: PlatformCatalog.wideLogos.contains(logoKey ?? "")
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.platform).fontWeight(.semibold)
                    Text(L10n.category(account.category))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(categoryColor(account.category).opacity(0.2))
                        .cornerRadius(4)
                }
                Spacer()
                actionButtons
                    .opacity(hovering ? 1 : 0)
            }
            if showEmail {
                Button(account.emailAddress) {
                    model.searchQuery = ""
                    model.selectEmail(account.emailId)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if !account.username.isEmpty {
                Button(account.username) {
                    model.copy(account.username, conceal: false)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
            SecretRow(
                hasPassword: account.hasPassword,
                revealed: $revealed,
                load: { try model.decryptAccountPassword(account.id) },
                onCopy: { model.copy($0, conceal: true) }
            )
            if !account.url.isEmpty, let url = sanitizedURL(account.url) {
                Link(displayURL(account.url), destination: url)
                    .lineLimit(1)
                    .font(.caption)
            }
            if !account.note.isEmpty {
                Text(account.note).font(.caption).foregroundStyle(.secondary)
            }
            if account.hasSecret {
                SecureNoteRow(load: { try model.decryptAccountSecret(account.id) })
            }
            if let renewal = account.renewal {
                RenewalBadge(renewal: renewal)
            }
        }
        .padding(12)
        .background(.background)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary, lineWidth: 1)
        )
        .cornerRadius(10)
        .onHover { hovering = $0 }
        .contextMenu {
            AccountContextMenu(account: account, onEdit: { showEdit = true }, onDelete: { showDelete = true })
        }
        .sheet(isPresented: $showEdit) {
            AccountEditorSheet(emailId: account.emailId, account: account)
        }
        .confirmationDialog(trf("删除 %@？", account.platform), isPresented: $showDelete) {
            Button(L10n.delete, role: .destructive) {
                try? model.store.deleteAccount(account.id)
                model.refresh()
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 4) {
            Button { showEdit = true } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help(L10n.edit)
            Button { showDelete = true } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(L10n.delete)
        }
        .font(.caption)
    }
}

/// Compact table-like row: platform | username | password | url | actions.
struct AccountListRow: View {
    @EnvironmentObject var model: AppModel
    let account: AccountRecord
    var showEmail: Bool = false
    @State private var revealed: String?
    @State private var showEdit = false
    @State private var showDelete = false
    @State private var hovering = false

    private var logoKey: String? {
        PlatformCatalog.platformLogo(platform: account.platform, url: account.url)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Platform
            HStack(spacing: 8) {
                Rectangle()
                    .fill(categoryColor(account.category))
                    .frame(width: 3)
                    .cornerRadius(1.5)
                AvatarView(
                    text: account.platform,
                    logo: logoKey,
                    size: 28,
                    wide: PlatformCatalog.wideLogos.contains(logoKey ?? "")
                )
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
            .frame(minWidth: 140, maxWidth: 200, alignment: .leading)

            if showEmail {
                Button(account.emailAddress) {
                    model.searchQuery = ""
                    model.selectEmail(account.emailId)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 120, maxWidth: 180, alignment: .leading)
            }

            // Username
            Group {
                if account.username.isEmpty {
                    Text("—").foregroundStyle(.tertiary)
                } else {
                    Button(account.username) {
                        model.copy(account.username, conceal: false)
                    }
                    .buttonStyle(.plain)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Password
            SecretRow(
                hasPassword: account.hasPassword,
                revealed: $revealed,
                load: { try model.decryptAccountPassword(account.id) },
                onCopy: { model.copy($0, conceal: true) }
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            // URL
            Group {
                if account.url.isEmpty {
                    Text("—").foregroundStyle(.tertiary)
                } else if let url = sanitizedURL(account.url) {
                    Link(displayURL(account.url), destination: url)
                        .lineLimit(1)
                } else {
                    Text(displayURL(account.url)).lineLimit(1)
                }
            }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Button { showEdit = true } label: { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
                Button { showDelete = true } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
            }
            .opacity(hovering ? 1 : 0)
            .frame(width: 56)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(hovering ? Color.primary.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            AccountContextMenu(account: account, onEdit: { showEdit = true }, onDelete: { showDelete = true })
        }
        .sheet(isPresented: $showEdit) {
            AccountEditorSheet(emailId: account.emailId, account: account)
        }
        .confirmationDialog(trf("删除 %@？", account.platform), isPresented: $showDelete) {
            Button(L10n.delete, role: .destructive) {
                try? model.store.deleteAccount(account.id)
                model.refresh()
            }
        }
    }
}

/// Right-click menu shared by account cards and list rows.
struct AccountContextMenu: View {
    @EnvironmentObject var model: AppModel
    let account: AccountRecord
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        if !account.username.isEmpty {
            Button(tr("复制用户名")) { model.copy(account.username, conceal: false) }
        }
        if account.hasPassword {
            Button(tr("复制密码")) {
                if let pw = try? model.decryptAccountPassword(account.id) {
                    model.copy(pw, conceal: true)
                }
            }
        }
        if account.hasSecret {
            Button(tr("复制安全备注")) {
                if let note = try? model.decryptAccountSecret(account.id) {
                    model.copy(note, conceal: true)
                }
            }
        }
        if let url = sanitizedURL(account.url) {
            Button(tr("打开网址")) { NSWorkspace.shared.open(url) }
        }
        Divider()
        Button(L10n.edit, action: onEdit)
        Button(L10n.delete, role: .destructive, action: onDelete)
    }
}

struct AccountListHeader: View {
    var showEmail: Bool = false

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
            Color.clear.frame(width: 56)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04))
    }
}

struct SecretRow: View {
    let hasPassword: Bool
    @Binding var revealed: String?
    let load: () throws -> String?
    var onCopy: (String) -> Void = { Clipboard.copy($0, conceal: true) }

    var body: some View {
        HStack(spacing: 6) {
            if !hasPassword {
                Text(L10n.noPassword).foregroundStyle(.secondary).font(.caption)
            } else {
                Text(revealed ?? "••••••••")
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                Button {
                    if revealed != nil {
                        revealed = nil
                    } else {
                        revealed = try? load()
                    }
                } label: {
                    Image(systemName: revealed == nil ? "eye" : "eye.slash")
                }
                .buttonStyle(.borderless)
                .help(revealed == nil ? tr("显示") : tr("隐藏"))
                Button {
                    if let pw = (revealed ?? (try? load())) {
                        onCopy(pw)
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help(tr("复制"))
            }
        }
    }
}

struct ServicesGrid: View {
    @EnvironmentObject var model: AppModel
    let accounts: [AccountRecord]
    var showEmail: Bool = false

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
            .background(.background)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.quaternary, lineWidth: 1)
            )
            .cornerRadius(10)
        }
    }
}
#endif
