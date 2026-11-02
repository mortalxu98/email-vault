#if os(macOS)
import AppKit
import SwiftUI

struct SetupView: View {
    @EnvironmentObject var model: AppModel
    @State private var password = ""
    @State private var confirm = ""

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)
            Text("Email Vault")
                .font(.largeTitle.bold())
            Text(tr("设置主密码"))
                .font(.title2)
            Text(tr("至少 8 个字符。遗忘后无法恢复加密数据。"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            RevealableSecureField(L10n.masterPassword, text: $password)
                .frame(maxWidth: 320)
                .disabled(model.isBusy)
            RevealableSecureField(L10n.confirmPassword, text: $confirm)
                .frame(maxWidth: 320)
                .disabled(model.isBusy)
                .onSubmit { Task { await create() } }
            if let err = model.errorMessage {
                Text(err).foregroundStyle(.red)
            }
            Button(model.isBusy ? tr("创建中…") : L10n.createVault) {
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
