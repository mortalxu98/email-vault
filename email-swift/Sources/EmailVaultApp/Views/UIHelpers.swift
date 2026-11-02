#if os(macOS)
import SwiftUI
import AppKit
import Foundation
import Security
import EmailVaultCore

enum L10n {
    static func category(_ cat: String) -> String {
        switch cat {
        case "ai": return tr("AI 工具")
        case "social": return tr("社交")
        case "crypto": return tr("加密货币")
        case "other": return tr("其他")
        case "all": return tr("全部")
        default: return cat
        }
    }

    static let copied = tr("已复制到剪贴板")
    static let copyFailed = tr("复制失败")
    static let searchPlaceholder = tr("搜索邮箱或平台")
    static let newEmail = tr("新增邮箱")
    static let newService = tr("新增服务")
    static let edit = tr("编辑")
    static let delete = tr("删除")
    static let cancel = tr("取消")
    static let save = tr("保存")
    static let lock = tr("锁定")
    static let exportBackup = tr("导出备份")
    static let unlock = tr("解锁")
    static let unlocking = tr("解锁中…")
    static let createVault = tr("创建保险箱")
    static let masterPassword = tr("主密码")
    static let confirmPassword = tr("确认密码")
    static let emails = tr("邮箱")
    static let services = tr("关联服务")
    static let noPassword = tr("未设密码")
    static let welcomeTitle = tr("欢迎使用 Email Vault")
    static let welcomeBody = tr("先在左侧新增一个邮箱，再记录它注册过的平台")
    static let noServices = tr("这个邮箱还没有关联服务")
    static let noServicesHint = tr("点「新增服务」，输入平台名会自动补全")
    static let noSearchResults = tr("没有找到匹配的服务")
    static let selectEmail = tr("选择一个邮箱")
    static let selectEmailHint = tr("从左侧选择地址，或新增一个")
    static let usedBefore = tr("已用过")
    static let platform = tr("平台")
    static let username = tr("用户名")
    static let password = tr("密码")
    static let url = tr("网址")
    static let emailPassword = tr("邮箱密码")
    static let notePlaintext = tr("备注为明文保存；密码、助记词、恢复码请放「安全备注」。")
    static let secureNote = tr("安全备注")
    static let leaveBlankKeep = tr("留空则不修改")
    static let optionalPassword = tr("可留空")
    static let wrongPassword = tr("主密码错误。")
    static let decryptFailed = tr("解密失败：数据损坏或密钥不匹配")
    static let passwordTooShort = tr("密码至少 8 个字符。")
    static let passwordMismatch = tr("两次输入的密码不一致。")
    static let duplicateEmail = tr("该邮箱地址已存在。")

    static func renewalCycle(_ cycle: RenewalCycle) -> String {
        switch cycle {
        case .once: return tr("一次性")
        case .monthly: return tr("每月")
        case .yearly: return tr("每年")
        }
    }

    static func renewalDue(_ days: Int) -> String {
        switch days {
        case ..<0: return trf("已过期 %ld 天", -days)
        case 0: return tr("今天到期")
        case 1: return tr("明天到期")
        default: return trf("%ld 天后到期", days)
        }
    }
}

/// Strip https:// / http:// and trailing slashes for compact display.
func displayURL(_ raw: String) -> String {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if let r = s.range(of: "://") {
        s = String(s[r.upperBound...])
    }
    while s.hasSuffix("/") { s.removeLast() }
    return s
}

func sanitizedURL(_ raw: String) -> URL? {
    let s = URLNormalizer.normalize(raw)
    return s.isEmpty ? nil : URL(string: s)
}

func categoryColor(_ cat: String) -> Color {
    switch cat {
    case "ai": return .purple
    case "social": return .blue
    case "crypto": return .orange
    default: return .gray
    }
}

/// Unbiased random password (matches web app.js).
enum PasswordGenerator {
    static let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%^&*-_=+")
    static let length = 20

    static func generate() -> String {
        var out: [Character] = []
        out.reserveCapacity(length)
        let n = chars.count
        let limit = 256 - (256 % n)
        while out.count < length {
            var bytes = [UInt8](repeating: 0, count: length * 2)
            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            guard status == errSecSuccess else {
                fatalError("SecRandomCopyBytes failed: \(status)")
            }
            for b in bytes where out.count < length {
                if Int(b) < limit {
                    out.append(chars[Int(b) % n])
                }
            }
        }
        return String(out)
    }
}

/// Secure field with an eye button to show/hide the text; keeps focus when toggling.
struct RevealableSecureField: View {
    let placeholder: String
    @Binding var text: String
    @State private var visible = false
    @FocusState private var focused: Bool

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if visible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .focused($focused)
            Button {
                visible.toggle()
                focused = true
            } label: {
                Image(systemName: visible ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .help(visible ? tr("隐藏") : tr("显示"))
        }
    }
}

struct ToastOverlay: View {
    let message: String?

    var body: some View {
        VStack {
            Spacer()
            if let message {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 8, y: 2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 28)
            }
        }
        .animation(.easeOut(duration: 0.2), value: message)
        .allowsHitTesting(false)
    }
}

/// Activity monitors so idle lock resets on mouse/keyboard like the web app.
struct IdleActivityMonitor: ViewModifier {
    @EnvironmentObject var model: AppModel

    func body(content: Content) -> some View {
        content
            .background(IdleMonitorInstaller(onActivity: { model.touch() }))
    }
}

private struct IdleMonitorInstaller: NSViewRepresentable {
    let onActivity: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install(onActivity)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var monitors: [Any] = []

        func install(_ onActivity: @escaping () -> Void) {
            teardown()
            let mask: NSEvent.EventTypeMask = [
                .keyDown, .keyUp,
                .leftMouseDown, .rightMouseDown, .otherMouseDown,
                .mouseMoved, .leftMouseDragged, .rightMouseDragged,
                .scrollWheel, .flagsChanged,
            ]
            if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
                onActivity()
                return event
            }) {
                monitors.append(local)
            }
        }

        func teardown() {
            for m in monitors {
                NSEvent.removeMonitor(m)
            }
            monitors.removeAll()
        }
    }
}

extension View {
    func idleActivityTracking() -> some View {
        modifier(IdleActivityMonitor())
    }
}
#endif
