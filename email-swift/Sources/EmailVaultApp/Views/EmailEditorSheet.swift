#if os(macOS)
import SwiftUI
import EmailVaultCore

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
                        load: { try email.flatMap { try model.emailSecret($0) } }
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
        do {
            try model.saveEmail(
                email, address: address, note: note, password: password,
                secret: secretLoaded ? secret : nil
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
#endif
