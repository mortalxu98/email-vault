#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import EmailVaultCore

/// Plaintext CSV export, gated by re-entering the master password.
struct ExportCSVSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var error: String?
    @State private var working = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Label {
                        Text(LocalizedStringKey(tr("导出的 CSV 包含**所有密码和安全备注的明文**。任何能读到这个文件的人或程序都能看到它们。请只在迁移数据时使用，用完立即删除，不要放进云盘或发给别人。")))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                } header: {
                    Text(tr("导出 CSV（明文）"))
                }
                Section {
                    RevealableSecureField(L10n.masterPassword, text: $password)
                        .onSubmit { Task { await submit() } }
                } footer: {
                    Text(tr("需要再次输入主密码确认。日常备份请用「导出备份」，备份文件里的密码保持加密。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .disabled(working)

            Divider()
            HStack {
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
                Spacer()
                Button(L10n.cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(working)
                Button(working ? tr("验证中…") : tr("导出…")) { Task { await submit() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(working || password.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 460)
    }

    private func submit() async {
        error = nil
        working = true
        let ok = await model.verifyMasterPassword(password)
        working = false
        guard ok else {
            error = L10n.wrongPassword
            return
        }
        password = ""
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "email-vault-export-\(Renewal.format(Date())).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.exportCSV(to: url)
            dismiss()
        } catch {
            self.error = trf("导出失败：%@", error.localizedDescription)
        }
    }
}
#endif
