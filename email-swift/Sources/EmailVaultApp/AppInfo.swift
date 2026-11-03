#if os(macOS)
import AppKit
import Foundation

/// App metadata, the About panel and the update check entry point.
enum AppInfo {
    static let repositoryURL = URL(string: "https://github.com/opsfantasy/email-vault")!
    /// The app never touches the network, so checking for updates opens this page in the browser.
    static let latestReleaseURL = URL(string: "https://github.com/opsfantasy/email-vault/releases/latest")!

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    static func showAbout() {
        let credits = NSMutableAttributedString(
            string: tr("本地加密的邮箱与平台账号保险箱\n"),
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        credits.append(NSAttributedString(
            string: "GitHub",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .link: repositoryURL]
        ))
        credits.append(NSAttributedString(
            string: " · MIT License",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        ))
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centered, range: NSRange(location: 0, length: credits.length))

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationVersion: version,
            .version: build,
            .credits: credits,
        ])
    }

    static func checkForUpdates() {
        NSWorkspace.shared.open(latestReleaseURL)
    }
}
#endif
