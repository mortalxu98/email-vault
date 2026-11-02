#if os(macOS)
import SwiftUI
import EmailVaultCore

/// Read-only secure note: hidden until revealed, copy marks the clipboard concealed.
struct SecureNoteRow: View {
    @EnvironmentObject var model: AppModel
    let load: () throws -> String?
    @State private var revealed: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Label(L10n.secureNote, systemImage: "lock.doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    revealed = revealed == nil ? (try? load()) : nil
                } label: {
                    Image(systemName: revealed == nil ? "eye" : "eye.slash")
                }
                .buttonStyle(.borderless)
                .help(revealed == nil ? tr("显示") : tr("隐藏"))
                Button {
                    if let text = revealed ?? (try? load()) {
                        model.copy(text, conceal: true)
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help(tr("复制"))
            }
            .font(.caption)
            if let revealed {
                Text(revealed)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.5))
                    .cornerRadius(6)
            }
        }
    }
}

/// Editor state for a secure note. Existing notes stay encrypted (and untouched on save)
/// unless the user explicitly decrypts them for editing.
struct SecureNoteEditor: View {
    @Binding var text: String
    @Binding var loaded: Bool
    let hasExisting: Bool
    let load: () throws -> String?

    var body: some View {
        if loaded {
            VStack(alignment: .leading, spacing: 4) {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 56, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                Text(tr("加密保存，适合助记词、恢复码、2FA 密钥。清空即删除。"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack {
                Label(hasExisting ? tr("已有安全备注（加密）") : tr("无"), systemImage: "lock.doc")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(tr("解密编辑")) {
                    if let value = try? load() {
                        text = value
                        loaded = true
                    }
                }
            }
        }
    }
}
#endif
