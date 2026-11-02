import Foundation

#if os(macOS)
import SwiftUI
import EmailVaultCore

@main
struct EmailVaultApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .frame(minWidth: 760, minHeight: 560)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(tr("关于 Email Vault")) { AppInfo.showAbout() }
                Button(tr("检查更新…")) { AppInfo.checkForUpdates() }
            }
            CommandGroup(replacing: .newItem) {
                Button(L10n.newEmail) {
                    appModel.requestNewEmail = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button(L10n.newService) {
                    appModel.requestNewAccount = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu(tr("保险箱")) {
                Button(L10n.lock) {
                    appModel.lock()
                }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(!appModel.isUnlocked)
                Button(tr("修改主密码…")) {
                    appModel.showChangePassword = true
                }
                .disabled(!appModel.isUnlocked)
                Button(tr("聚焦搜索")) {
                    appModel.focusSearch = true
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}

#else
@main
struct EmailVaultCLI {
    static func main() {
        fputs("Email Vault is a macOS 14+ SwiftUI app. Build and run on a Mac.\n", stderr)
        exit(1)
    }
}
#endif
