#if os(macOS)
import SwiftUI

struct UnlockView: View {
    @EnvironmentObject var model: AppModel
    @State private var password = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Email Vault")
                .font(.largeTitle.bold())
            Text(L10n.unlock)
                .font(.title2)
            RevealableSecureField(L10n.masterPassword, text: $password)
                .frame(maxWidth: 320)
                .onSubmit { Task { await unlock() } }
                .disabled(model.isBusy)
            if let err = model.errorMessage {
                Text(err).foregroundStyle(.red)
            }
            Button(model.isBusy ? L10n.unlocking : L10n.unlock) {
                Task { await unlock() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(model.isBusy || password.isEmpty)
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

    private func unlock() async {
        await model.unlock(password: password)
        if model.isUnlocked { password = "" }
    }
}
#endif
