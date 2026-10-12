#if os(macOS)
import SwiftUI
import EmailVaultCore

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.needsSetup {
                SetupView()
            } else if !model.isUnlocked {
                UnlockView()
            } else {
                MainView()
            }
        }
        .overlay(alignment: .bottom) {
            ToastOverlay(message: model.toastMessage)
        }
        .preferredColorScheme(nil)
    }
}
#endif
