#if os(macOS)
import SwiftUI
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
#endif
