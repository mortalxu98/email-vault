#if os(macOS)
import SwiftUI
import EmailVaultCore

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if let launchError = model.launchError {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle.fill",
                    title: tr("无法打开数据库"),
                    subtitle: launchError,
                    big: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.needsSetup {
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
