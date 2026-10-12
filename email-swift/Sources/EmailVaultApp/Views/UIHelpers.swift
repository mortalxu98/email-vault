#if os(macOS)
import SwiftUI
import AppKit
import Foundation
import Security
import EmailVaultCore

enum L10n {
    static func category(_ cat: String) -> String {
        switch cat {
        case "ai": return "AI 工具"
        case "social": return "社交"
        case "crypto": return "加密货币"
        case "other": return "其他"
        case "all": return "全部"
        default: return cat
        }
    }

    static let copied = "已复制到剪贴板"
    static let copyFailed = "复制失败"
    static let searchPlaceholder = "搜索邮箱或平台"
    static let newEmail = "新增邮箱"
    static let newService = "新增服务"
    static let edit = "编辑"
    static let delete = "删除"
    static let cancel = "取消"
    static let save = "保存"
    static let lock = "锁定"
    static let exportBackup = "导出备份"
    static let unlock = "解锁"
    static let unlocking = "解锁中…"
    static let createVault = "创建保险箱"
    static let masterPassword = "主密码"
    static let confirmPassword = "确认密码"
    static let emails = "邮箱"
    static let services = "关联服务"
    static let noPassword = "未设密码"
    static let welcomeTitle = "欢迎使用 Email Vault"
    static let welcomeBody = "先在左侧新增一个邮箱，再记录它注册过的平台"
    static let noServices = "这个邮箱还没有关联服务"
    static let noServicesHint = "点「新增服务」，输入平台名会自动补全"
    static let noSearchResults = "没有找到匹配的服务"
    static let selectEmail = "选择一个邮箱"
    static let selectEmailHint = "从左侧选择地址，或新增一个"
    static let usedBefore = "已用过"
    static let platform = "平台"
    static let username = "用户名"
    static let password = "密码"
    static let url = "网址"
    static let emailPassword = "邮箱密码"
    static let notePlaintext = "备注为明文保存，请勿写入密码。"
    static let leaveBlankKeep = "留空则不修改"
    static let optionalPassword = "可留空"
    static let wrongPassword = "主密码错误。"
    static let decryptFailed = "解密失败：数据损坏或密钥不匹配"
    static let passwordTooShort = "密码至少 8 个字符。"
    static let passwordMismatch = "两次输入的密码不一致。"
    static let duplicateEmail = "该邮箱地址已存在。"
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
