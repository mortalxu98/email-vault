#if os(macOS)
import Foundation
import SwiftUI
import Crypto
import EmailVaultCore

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
    @Published var stats: Stats?
    @Published var errorMessage: String?
    @Published var toastMessage: String?
    @Published var requestNewEmail = false
    @Published var requestNewAccount = false
    @Published var focusSearch = false
    @Published var accountViewMode: AccountViewMode = .grid
    @Published var categoryFilter: String = "all"
    @Published var isBusy = false

    enum AccountViewMode: String {
        case grid, list
    }

    private(set) var store: Store!
    private(set) var vault: Vault!
    private(set) var key: SymmetricKey?
    private var lastActivity = Date()
    private var idleTimer: Timer?
    private var toastWorkItem: DispatchWorkItem?
    let idleTimeout: TimeInterval = 10 * 60

    init() {
        do {
            store = try Store()
            vault = Vault(store: store)
            needsSetup = !(try vault.isInitialized())
            if let saved = UserDefaults.standard.string(forKey: "email-vault:view") {
                accountViewMode = AccountViewMode(rawValue: saved) ?? .grid
            }
        } catch {
            errorMessage = error.localizedDescription
            needsSetup = true
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
        key = nil
        isUnlocked = false
        emails = []
        accounts = []
        searchAccounts = []
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

    func platformCatalog() -> [PlatformCatalog.CatalogEntry] {
        let user = (try? store.distinctPlatforms()) ?? []
        return PlatformCatalog.catalog(userPlatforms: user.map { ($0.0, $0.1, $0.2) })
    }

    func setViewMode(_ mode: AccountViewMode) {
        accountViewMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "email-vault:view")
    }

    func exportBackup(to url: URL) throws {
        touch()
        try store.export(to: url)
        showToast("备份已保存")
    }
}
#endif
