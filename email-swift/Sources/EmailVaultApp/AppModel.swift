#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import Crypto
import EmailVaultCore
import LocalAuthentication

@MainActor
final class AppModel: ObservableObject {
    @Published var isUnlocked = false
    @Published var needsSetup = false
    @Published var selectedEmailId: Int64?
    @Published var selectedEmail: EmailRecord?
    @Published var searchQuery = ""
    @Published var emails: [EmailRecord] = []
    @Published var accounts: [AccountRecord] = []
    @Published var searchAccounts: [AccountRecord] = []
    /// Accounts whose renewal is within its reminder window or overdue.
    @Published var dueRenewals: [AccountRecord] = []
    /// Overview page data.
    @Published var allRenewals: [AccountRecord] = []
    @Published var recentAccounts: [AccountRecord] = []
    @Published var stats: Stats?
    @Published var errorMessage: String?
    @Published var toastMessage: String?
    @Published var requestNewEmail = false
    @Published var requestNewAccount = false
    @Published var focusSearch = false
    @Published var accountViewMode: AccountViewMode = .grid
    @Published var categoryFilter: String = "all"
    @Published var isBusy = false
    @Published var showChangePassword = false
    @Published var showExportCSV = false
    @Published var touchIDEnabled = false
    let touchIDAvailable = BiometricStore.isAvailable

    enum AccountViewMode: String {
        case grid, list
    }

    private(set) var store: Store!
    private(set) var vault: Vault!
    private(set) var key: SymmetricKey?
    private var lastActivity = Date()
    private var idleTimer: Timer?
    private var toastWorkItem: DispatchWorkItem?
    private var systemLockObservers: [(NotificationCenter, NSObjectProtocol)] = []
    private var biometric: BiometricStore?
    /// When the master password was last typed (drives the 14-day Touch ID re-prompt).
    private var passwordEnteredAt: Date?
    private var touchIDTriedSinceLock = false
    let idleTimeout: TimeInterval = 10 * 60

    init() {
        do {
            store = try Store()
            vault = Vault(store: store)
            biometric = BiometricStore(dbPath: store.path)
            needsSetup = !(try vault.isInitialized())
            touchIDEnabled = touchIDAvailable && biometric?.load() != nil
            if let saved = UserDefaults.standard.string(forKey: "email-vault:view") {
                accountViewMode = AccountViewMode(rawValue: saved) ?? .grid
            }
        } catch {
            errorMessage = error.localizedDescription
            needsSetup = true
        }
        installSystemLockObservers()
    }

    /// Lock immediately on sleep, screen lock, screensaver, display sleep or user switch.
    private func installSystemLockObservers() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        let events: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.willSleepNotification),
            (workspace, NSWorkspace.screensDidSleepNotification),
            (workspace, NSWorkspace.sessionDidResignActiveNotification),
            (distributed, Notification.Name("com.apple.screenIsLocked")),
            (distributed, Notification.Name("com.apple.screensaver.didstart")),
        ]
        for (center, name) in events {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.isUnlocked else { return }
                    self.lock()
                }
            }
            systemLockObservers.append((center, token))
        }
    }

    var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func touch() {
        lastActivity = Date()
    }

    func showToast(_ text: String) {
        toastMessage = text
        toastWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.toastMessage = nil
        }
        toastWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: item)
    }

    func copy(_ text: String, conceal: Bool) {
        Clipboard.copy(text, conceal: conceal)
        showToast(L10n.copied)
        touch()
    }

    func setup(password: String, confirm: String) async {
        errorMessage = nil
        guard password.count >= 8 else {
            errorMessage = L10n.passwordTooShort
            return
        }
        guard password == confirm else {
            errorMessage = L10n.passwordMismatch
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let vault = self.vault!
            let k = try await Task.detached(priority: .userInitiated) {
                try vault.initialize(password: password)
            }.value
            passwordEnteredAt = Date()
            finishUnlock(key: k)
            needsSetup = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unlock(password: String) async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            let vault = self.vault!
            let k = try await Task.detached(priority: .userInitiated) {
                try vault.unlock(password: password)
            }.value
            passwordEnteredAt = Date()
            refreshTouchIDRecord(key: k)
            finishUnlock(key: k)
        } catch VaultError.invalidMasterPassword {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            errorMessage = L10n.wrongPassword
        } catch {
            errorMessage = "解锁失败：\(error)"
        }
    }

    private func finishUnlock(key: SymmetricKey) {
        self.key = key
        isUnlocked = true
        touch()
        startIdleWatcher()
        refresh()
    }

    func lock() {
        Clipboard.clearConcealed()
        showChangePassword = false
        showExportCSV = false
        touchIDTriedSinceLock = false
        key = nil
        isUnlocked = false
        emails = []
        accounts = []
        searchAccounts = []
        dueRenewals = []
        allRenewals = []
        recentAccounts = []
        stats = nil
        selectedEmailId = nil
        selectedEmail = nil
        idleTimer?.invalidate()
        idleTimer = nil
    }

    private func startIdleWatcher() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isUnlocked else { return }
                if Date().timeIntervalSince(self.lastActivity) > self.idleTimeout {
                    self.lock()
                }
            }
        }
    }

    func refresh() {
        touch()
        guard isUnlocked else { return }
        do {
            let query = trimmedQuery
            emails = try store.listEmails(query: query)
            stats = try store.stats()
            let now = Date()
            allRenewals = try store.listRenewals()
            dueRenewals = allRenewals.filter { $0.renewal?.isDue(today: now) == true }
            recentAccounts = try store.recentAccounts(limit: 6)
            if !query.isEmpty {
                searchAccounts = try store.searchAccounts(query: query)
            } else {
                searchAccounts = []
            }
            if let id = selectedEmailId {
                if let e = emails.first(where: { $0.id == id }) {
                    selectedEmail = e
                } else {
                    selectedEmail = try store.listEmails(query: "").first { $0.id == id }
                }
                accounts = try store.listAccounts(emailId: id)
            } else {
                selectedEmail = nil
                accounts = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectEmail(_ id: Int64?) {
        selectedEmailId = id
        categoryFilter = "all"
        refresh()
    }

    func decryptEmailPassword(_ id: Int64) throws -> String? {
        touch()
        guard let key else { return nil }
        do {
            guard let blob = try store.getEmailPassword(id) else { return nil }
            return try VaultCrypto.decrypt(blob, with: key)
        } catch {
            showToast(L10n.decryptFailed)
            throw error
        }
    }

    func decryptAccountPassword(_ id: Int64) throws -> String? {
        touch()
        guard let key else { return nil }
        do {
            guard let blob = try store.getAccountPassword(id) else { return nil }
            return try VaultCrypto.decrypt(blob, with: key)
        } catch {
            showToast(L10n.decryptFailed)
            throw error
        }
    }

    func decryptEmailSecret(_ id: Int64) throws -> String? {
        try decrypt { try store.getEmailSecret(id) }
    }

    func decryptAccountSecret(_ id: Int64) throws -> String? {
        try decrypt { try store.getAccountSecret(id) }
    }

    /// Encrypt a secure note; blank text means "remove" (nil).
    func encryptSecret(_ text: String) throws -> Data? {
        guard let key else { throw VaultError.invalidMasterPassword }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : try VaultCrypto.encrypt(trimmed, with: key)
    }

    private func decrypt(_ fetch: () throws -> Data?) throws -> String? {
        touch()
        guard let key else { return nil }
        do {
            guard let blob = try fetch() else { return nil }
            return try VaultCrypto.decrypt(blob, with: key)
        } catch {
            showToast(L10n.decryptFailed)
            throw error
        }
    }

    func platformCatalog() -> [PlatformCatalog.CatalogEntry] {
        let user = (try? store.distinctPlatforms()) ?? []
        return PlatformCatalog.catalog(userPlatforms: user.map { ($0.0, $0.1, $0.2) })
    }

    func goHome() {
        searchQuery = ""
        selectEmail(nil)
    }

    func setViewMode(_ mode: AccountViewMode) {
        accountViewMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "email-vault:view")
    }

    /// Returns an error message, or nil on success.
    func changePassword(current: String, new: String, confirm: String) async -> String? {
        touch()
        guard new.count >= 8 else { return L10n.passwordTooShort }
        guard new == confirm else { return L10n.passwordMismatch }
        guard new != current else { return "新密码不能与当前密码相同。" }
        isBusy = true
        defer { isBusy = false }
        do {
            let vault = self.vault!
            let k = try await Task.detached(priority: .userInitiated) {
                try vault.changePassword(current: current, new: new)
            }.value
            // Vault may have been locked (sleep etc.) while re-encrypting.
            if isUnlocked { key = k }
            passwordEnteredAt = Date()
            refreshTouchIDRecord(key: k)
            touch()
            showToast("主密码已修改")
            return nil
        } catch VaultError.invalidMasterPassword {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return "当前主密码错误。"
        } catch {
            return "修改失败，数据未改动：\(error)"
        }
    }

    // MARK: - Touch ID

    private func currentVaultID() -> String? {
        (try? store.getMeta(VaultCrypto.metaVerifier)).flatMap { $0 }.map(BiometricStore.vaultID(verifierHex:))
    }

    /// After a master-password unlock or change: re-seal to the current key and reset the 14-day clock.
    private func refreshTouchIDRecord(key: SymmetricKey) {
        guard let biometric, let record = biometric.load(), let vaultID = currentVaultID() else { return }
        do {
            try biometric.save(BiometricStore.reseal(record, key: key, vaultID: vaultID, passwordAt: Date()))
        } catch {
            disableTouchID()
        }
    }

    func enableTouchID() {
        touch()
        guard let biometric, let key, let vaultID = currentVaultID() else { return }
        do {
            let record = try BiometricStore.seal(key: key, vaultID: vaultID, passwordAt: passwordEnteredAt ?? Date())
            try biometric.save(record)
            touchIDEnabled = true
            showToast("已开启 Touch ID 解锁")
        } catch {
            errorMessage = "开启 Touch ID 失败：\(error.localizedDescription)"
            showToast("开启 Touch ID 失败")
        }
    }

    func disableTouchID() {
        biometric?.delete()
        touchIDEnabled = false
    }

    /// Prompt once per lock, only while the app is frontmost.
    func autoTouchID() {
        guard touchIDEnabled, !isUnlocked, !isBusy, !touchIDTriedSinceLock, NSApp.isActive else { return }
        touchIDTriedSinceLock = true
        Task { await unlockWithTouchID() }
    }

    func unlockWithTouchID() async {
        errorMessage = nil
        guard let biometric, let record = biometric.load() else {
            touchIDEnabled = false
            return
        }
        guard record.vaultID == currentVaultID() else {
            disableTouchID()
            errorMessage = "主密码已变更，Touch ID 已关闭。请用主密码解锁后重新开启。"
            return
        }
        guard !BiometricStore.passwordExpired(record) else {
            errorMessage = "已超过 14 天未输入主密码，请输入一次主密码。"
            return
        }
        let context = LAContext()
        context.localizedFallbackTitle = "输入主密码"
        do {
            try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "解锁 Email Vault")
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .userFallback, .systemCancel, .appCancel:
                break
            default:
                errorMessage = "Touch ID 不可用：\(error.localizedDescription)"
            }
            return
        } catch {
            errorMessage = "Touch ID 不可用：\(error.localizedDescription)"
            return
        }
        guard let k = try? BiometricStore.open(record, context: context), vault.verify(key: k) else {
            disableTouchID()
            errorMessage = "Touch ID 凭据已失效（可能指纹有变动），已关闭。请用主密码解锁后重新开启。"
            return
        }
        passwordEnteredAt = record.passwordAt
        finishUnlock(key: k)
    }

    /// Roll the due date forward one cycle, or drop a one-off reminder.
    func markRenewed(_ account: AccountRecord) {
        touch()
        guard let renewal = account.renewal else { return }
        let next = renewal.renewed()
        do {
            try store.setRenewal(accountId: account.id, renewal: next)
            showToast(next.map { "已续费，下次到期 \($0.dueDate)" } ?? "已移除提醒")
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Re-check the master password before a sensitive action. Slow (Argon2), runs off the main actor.
    func verifyMasterPassword(_ password: String) async -> Bool {
        touch()
        let vault = self.vault!
        let ok = await Task.detached(priority: .userInitiated) {
            (try? vault.unlock(password: password)) != nil
        }.value
        if !ok { try? await Task.sleep(nanoseconds: 1_000_000_000) }
        return ok
    }

    /// Write every secret in clear text to `url` (0600).
    func exportCSV(to url: URL) throws {
        touch()
        guard let key else { throw VaultError.invalidMasterPassword }
        try CSVExporter.write(CSVExporter.export(store: store, key: key), to: url)
        showToast("CSV 已导出，用完请删除")
    }

    func exportBackup(to url: URL) throws {
        touch()
        try store.export(to: url)
        showToast("备份已保存")
    }
}
#endif
