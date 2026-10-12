#if os(macOS)
import SwiftUI

struct SetupView: View {
    @EnvironmentObject var model: AppModel
    @State private var password = ""
    @State private var confirm = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Email Vault")
                .font(.largeTitle.bold())
            Text("设置主密码")
                .font(.title2)
            Text("至少 8 个字符。遗忘后无法恢复加密数据。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            SecureField(L10n.masterPassword, text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
                .disabled(model.isBusy)
            SecureField(L10n.confirmPassword, text: $confirm)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
                .disabled(model.isBusy)
                .onSubmit { Task { await create() } }
            if let err = model.errorMessage {
                Text(err).foregroundStyle(.red)
            }
            Button(model.isBusy ? "创建中…" : L10n.createVault) {
                Task { await create() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(model.isBusy || password.count < 8)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.12), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func create() async {
        await model.setup(password: password, confirm: confirm)
    }
}
#endif
