#if os(macOS)
import EmailVaultCore
import Foundation

/// Shared UI strings (see Localization.swift for how lookup works).
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
#endif
