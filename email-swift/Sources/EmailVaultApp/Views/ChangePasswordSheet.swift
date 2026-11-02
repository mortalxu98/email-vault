#if os(macOS)
import SwiftUI

struct ChangePasswordSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var new = ""
    @State private var confirm = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    RevealableSecureField(tr("当前主密码"), text: $current)
                } header: {
                    Text(tr("修改主密码"))
                }
                Section {
                    RevealableSecureField(tr("新主密码（至少 8 个字符）"), text: $new)
                    RevealableSecureField(L10n.confirmPassword, text: $confirm)
                } footer: {
                    Text(tr("所有密码会用新主密码重新加密。修改前会自动备份数据库到 backups 目录。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .disabled(model.isBusy)

            HStack {
                if let error {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
                Spacer()
                Button(L10n.cancel) { dismiss() }
                    .disabled(model.isBusy)
                Button(model.isBusy ? tr("修改中…") : tr("修改")) {
                    Task { await submit() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isBusy || current.isEmpty || new.isEmpty || confirm.isEmpty)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 440)
    }

    private func submit() async {
        error = nil
        if let message = await model.changePassword(current: current, new: new, confirm: confirm) {
            error = message
        } else {
            current = ""
            new = ""
            confirm = ""
            dismiss()
        }
    }
}
#endif
