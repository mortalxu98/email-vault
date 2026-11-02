#if os(macOS)
import AppKit
import Crypto
import EmailVaultCore
import Foundation
import SwiftUI

/// Validation failures surfaced to editor sheets.
enum EditError: LocalizedError {
    case emptyAddress
    case emptyPlatform
    case duplicateEmail

    var errorDescription: String? {
        switch self {
        case .emptyAddress: return tr("邮箱地址不能为空")
        case .emptyPlatform: return tr("平台名称不能为空")
        case .duplicateEmail: return L10n.duplicateEmail
        }
    }
}

/// Editable account fields; trimmed and normalized by `AppModel.saveAccount`.
struct AccountDraft {
    var platform = ""
    var category = "other"
    var username = ""
    var url = ""
    var note = ""
    var renewal: Renewal?
}

/// App state and the only place that talks to the store. Views read published state and call
/// methods here; they never touch `Store` or the vault key directly.
@MainActor
final class AppModel: ObservableObject {
    enum AccountViewMode: String {
        case grid, list
    }

    // MARK: Published state

    @Published private(set) var isUnlocked = false
    @Published private(set) var needsSetup = false
    @Published private(set) var isBusy = false
    @Published private(set) var touchIDEnabled = false

    @Published private(set) var selectedEmailId: Int64?
    @Published private(set) var selectedEmail: EmailRecord?
    @Published private(set) var emails: [EmailRecord] = []
    @Published private(set) var accounts: [AccountRecord] = []
    @Published private(set) var searchAccounts: [AccountRecord] = []
    @Published private(set) var stats: Stats?
    /// Renewals inside their reminder window or overdue.
    @Published private(set) var dueRenewals: [AccountRecord] = []
    @Published private(set) var allRenewals: [AccountRecord] = []
    @Published private(set) var recentAccounts: [AccountRecord] = []

    @Published var searchQuery = ""
    @Published var categoryFilter = "all"
    @Published var accountViewMode: AccountViewMode = .grid
    @Published var errorMessage: String?
    @Published private(set) var toastMessage: String?

    // Requests from menu commands to views.
    @Published var requestNewEmail = false
    @Published var requestNewAccount = false
    @Published var focusSearch = false
    @Published var showChangePassword = false
    @Published var showExportCSV = false

    /// Set when the database could not be opened; the UI shows it and nothing else.
    let launchError: String?
    var touchIDAvailable: Bool { touchID?.isAvailable ?? false }

    // MARK: Private state

    // Non-nil unless `launchError` is set, in which case no view can reach code that uses them.
    private var store: Store!
    private var vault: Vault!
    private var touchID: TouchIDUnlock?
    private var key: SymmetricKey?
    /// When the master password was last typed; drives the 14-day Touch ID rule.
    private var passwordEnteredAt: Date?
    private var touchIDTriedSinceLock = false

    private let idleTimeout: TimeInterval = 10 * 60
    private var lastActivity = Date()
    private var idleTimer: Timer?
    private var toastWorkItem: DispatchWorkItem?
    private var systemLockObservers: [(NotificationCenter, NSObjectProtocol)] = []
    private static let viewModeKey = "email-vault:view"

    init() {
        do {
            let store = try Store()
            let vault = Vault(store: store)
            self.store = store
            self.vault = vault
            touchID = TouchIDUnlock(dbPath: store.path) {
                (try? store.getMeta(VaultCrypto.metaVerifier)).flatMap { $0 }
                    .map(BiometricStore.vaultID(verifierHex:))
            }
            needsSetup = !(try vault.isInitialized())
            launchError = nil
        } catch {
            launchError = error.localizedDescription
        }
        touchIDEnabled = touchID?.isEnabled ?? false
        if let saved = UserDefaults.standard.string(forKey: Self.viewModeKey) {
            accountViewMode = AccountViewMode(rawValue: saved) ?? .grid
        }
        installSystemLockObservers()
    }

    var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Setup, unlock, lock

    func setup(password: String, confirm: String) async {
        errorMessage = nil
        if password.count < 8 {
            errorMessage = L10n.passwordTooShort
            return
        }
        if password != confirm {
            errorMessage = L10n.passwordMismatch
            return
        }
        await runBusy {
            let vault = self.vault!
            do {
                let key = try await Task.detached(priority: .userInitiated) {
                    try vault.initialize(password: password)
                }.value
                self.passwordEnteredAt = Date()
                self.needsSetup = false
                self.finishUnlock(key: key)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func unlock(password: String) async {
        errorMessage = nil
        await runBusy {
            do {
                let key = try await self.deriveKey(password: password)
                self.passwordEnteredAt = Date()
                self.touchID?.passwordEntered(key: key)
                self.finishUnlock(key: key)
            } catch VaultError.invalidMasterPassword {
                await Self.failureDelay()
                self.errorMessage = L10n.wrongPassword
            } catch {
                self.errorMessage = trf("解锁失败：%@", "\(error)")
            }
        }
    }

    func lock() {
        Clipboard.clearConcealed()
        key = nil
        isUnlocked = false
        showChangePassword = false
        showExportCSV = false
        touchIDTriedSinceLock = false
        selectedEmailId = nil
        selectedEmail = nil
        emails = []
        accounts = []
        searchAccounts = []
        stats = nil
        dueRenewals = []
        allRenewals = []
        recentAccounts = []
        idleTimer?.invalidate()
        idleTimer = nil
    }

    /// Record user activity; the vault locks after `idleTimeout` without any.
    func touch() {
        lastActivity = Date()
    }

    private func finishUnlock(key: SymmetricKey) {
        self.key = key
        isUnlocked = true
        touch()
        startIdleWatcher()
        refresh()
    }

    private func deriveKey(password: String) async throws -> SymmetricKey {
        let vault = self.vault!
        return try await Task.detached(priority: .userInitiated) {
            try vault.unlock(password: password)
        }.value
    }

    /// Slow down password guessing after a failure.
    private static func failureDelay() async {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    private func runBusy(_ work: () async -> Void) async {
        isBusy = true
        defer { isBusy = false }
        await work()
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

    // MARK: - Navigation and loading

    func refresh() {
        touch()
        guard isUnlocked else { return }
        do {
            let query = trimmedQuery
            emails = try store.listEmails(query: query)
            searchAccounts = query.isEmpty ? [] : try store.searchAccounts(query: query)
            stats = try store.stats()
            allRenewals = try store.listRenewals()
            let now = Date()
            dueRenewals = allRenewals.filter { $0.renewal?.isDue(today: now) == true }
            recentAccounts = try store.recentAccounts(limit: 6)
            if let id = selectedEmailId {
                selectedEmail = try store.getEmail(id)
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

    /// Leave search and show one email.
    func openEmail(_ id: Int64) {
        searchQuery = ""
        selectEmail(id)
    }

    func goHome() {
        searchQuery = ""
        selectEmail(nil)
    }

    func setViewMode(_ mode: AccountViewMode) {
        accountViewMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.viewModeKey)
    }

    func platformCatalog() -> [PlatformCatalog.CatalogEntry] {
        let user = (try? store.distinctPlatforms()) ?? []
        return PlatformCatalog.catalog(userPlatforms: user.map { ($0.0, $0.1, $0.2) })
    }

    // MARK: - Editing

    /// Create or update an email. A blank `password` keeps the stored one; `secret == nil` keeps
    /// the stored secure note and an empty string removes it.
    func saveEmail(_ existing: EmailRecord?, address: String, note: String, password: String, secret: String?) throws {
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else { throw EditError.emptyAddress }
        let passwordEnc = try encrypt(password)
        do {
            let id: Int64
            if let existing {
                id = existing.id
                try store.updateEmail(id: id, address: address, note: note, passwordEnc: passwordEnc)
            } else {
                id = try store.createEmail(address: address, note: note, passwordEnc: passwordEnc)
            }
            if let secret {
                try store.setEmailSecret(id, secretEnc: try encrypt(secret))
            }
            selectEmail(id)
        } catch StoreError.duplicateEmail {
            throw EditError.duplicateEmail
        }
    }

    /// Create or update an account; same `password` / `secret` rules as `saveEmail`.
    func saveAccount(_ existing: AccountRecord?, emailId: Int64, draft: AccountDraft, password: String, secret: String?) throws {
        let platform = draft.platform.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !platform.isEmpty else { throw EditError.emptyPlatform }
        let username = draft.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URLNormalizer.normalize(draft.url)
        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let passwordEnc = try encrypt(password)

        let id: Int64
        if let existing {
            id = existing.id
            try store.updateAccount(
                id: id, platform: platform, category: draft.category, username: username,
                url: url, note: note, passwordEnc: passwordEnc, renewal: draft.renewal
            )
        } else {
            id = try store.createAccount(
                emailId: emailId, platform: platform, category: draft.category, username: username,
                url: url, note: note, passwordEnc: passwordEnc, renewal: draft.renewal
            )
        }
        if let secret {
            try store.setAccountSecret(id, secretEnc: try encrypt(secret))
        }
        refresh()
    }

    func deleteEmail(_ email: EmailRecord) {
        perform { try store.deleteEmail(email.id) }
        selectEmail(nil)
    }

    func deleteAccount(_ account: AccountRecord) {
        perform { try store.deleteAccount(account.id) }
        refresh()
    }

    /// Roll the due date forward one cycle, or drop a one-off reminder.
    func markRenewed(_ account: AccountRecord) {
        guard let renewal = account.renewal else { return }
        let next = renewal.renewed()
        guard perform({ try store.setRenewal(accountId: account.id, renewal: next) }) else { return }
        showToast(next.map { trf("已续费，下次到期 %@", $0.dueDate) } ?? tr("已移除提醒"))
        refresh()
    }

    /// Run a store write, reporting failures instead of swallowing them.
    @discardableResult
    private func perform(_ write: () throws -> Void) -> Bool {
        touch()
        do {
            try write()
            return true
        } catch {
            errorMessage = error.localizedDescription
            showToast(error.localizedDescription)
            return false
        }
    }

    // MARK: - Secrets

    func emailPassword(_ email: EmailRecord) throws -> String? {
        try decrypt { try store.getEmailPassword(email.id) }
    }

    func emailSecret(_ email: EmailRecord) throws -> String? {
        try decrypt { try store.getEmailSecret(email.id) }
    }

    func accountPassword(_ account: AccountRecord) throws -> String? {
        try decrypt { try store.getAccountPassword(account.id) }
    }

    func accountSecret(_ account: AccountRecord) throws -> String? {
        try decrypt { try store.getAccountSecret(account.id) }
    }

    func copy(_ text: String, conceal: Bool) {
        Clipboard.copy(text, conceal: conceal)
        showToast(L10n.copied)
        touch()
    }

    /// Ciphertext for `text`, or nil when it is blank.
    private func encrypt(_ text: String) throws -> Data? {
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

    // MARK: - Master password, export

    /// Returns an error message, or nil on success.
    func changePassword(current: String, new: String, confirm: String) async -> String? {
        touch()
        guard new.count >= 8 else { return L10n.passwordTooShort }
        guard new == confirm else { return L10n.passwordMismatch }
        guard new != current else { return tr("新密码不能与当前密码相同。") }
        isBusy = true
        defer { isBusy = false }
        do {
            let vault = self.vault!
            let newKey = try await Task.detached(priority: .userInitiated) {
                try vault.changePassword(current: current, new: new)
            }.value
            // The vault may have locked (sleep etc.) while re-encrypting.
            if isUnlocked { key = newKey }
            passwordEnteredAt = Date()
            touchID?.passwordEntered(key: newKey)
            showToast(tr("主密码已修改"))
            return nil
        } catch VaultError.invalidMasterPassword {
            await Self.failureDelay()
            return tr("当前主密码错误。")
        } catch {
            return trf("修改失败，数据未改动：%@", "\(error)")
        }
    }

    /// Re-check the master password before a sensitive action.
    func verifyMasterPassword(_ password: String) async -> Bool {
        touch()
        if (try? await deriveKey(password: password)) != nil { return true }
        await Self.failureDelay()
        return false
    }

    /// Write every secret in clear text to `url` (0600).
    func exportCSV(to url: URL) throws {
        touch()
        guard let key else { throw VaultError.invalidMasterPassword }
        try CSVExporter.write(CSVExporter.export(store: store, key: key), to: url)
        showToast(tr("CSV 已导出，用完请删除"))
    }

    func exportBackup(to url: URL) throws {
        touch()
        try store.export(to: url)
        showToast(tr("备份已保存"))
    }

    // MARK: - Touch ID

    func setTouchIDEnabled(_ enabled: Bool) {
        touch()
        guard let touchID else { return }
        if enabled {
            guard let key else { return }
            do {
                try touchID.enable(key: key, passwordEnteredAt: passwordEnteredAt ?? Date())
                showToast(tr("已开启 Touch ID 解锁"))
            } catch {
                errorMessage = trf("开启 Touch ID 失败：%@", error.localizedDescription)
                showToast(tr("开启 Touch ID 失败"))
            }
        } else {
            touchID.disable()
        }
        touchIDEnabled = touchID.isEnabled
    }

    /// Prompt once per lock, only while the app is frontmost.
    func autoTouchID() {
        guard touchIDEnabled, !isUnlocked, !isBusy, !touchIDTriedSinceLock, NSApp.isActive else { return }
        touchIDTriedSinceLock = true
        Task { await unlockWithTouchID() }
    }

    func unlockWithTouchID() async {
        guard let touchID else { return }
        errorMessage = nil
        let vault = self.vault!
        let outcome = await touchID.unlock { vault.verify(key: $0) }
        touchIDEnabled = touchID.isEnabled
        switch outcome {
        case let .unlocked(key, enteredAt):
            passwordEnteredAt = enteredAt
            finishUnlock(key: key)
        case .cancelled:
            break
        case let .failed(message):
            errorMessage = message
        }
    }

    // MARK: - Toast

    func showToast(_ text: String) {
        toastMessage = text
        toastWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.toastMessage = nil
        }
        toastWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: item)
    }
}
#endif
