#if os(macOS)
import Crypto
import EmailVaultCore
import Foundation
import LocalAuthentication

/// Touch ID unlock on top of `BiometricStore`: owns the seal file, the 14-day password rule
/// and the LocalAuthentication prompt. Never decides whether a key is correct; the caller verifies.
@MainActor
final class TouchIDUnlock {
    enum Outcome {
        case unlocked(SymmetricKey, passwordEnteredAt: Date)
        /// User dismissed the prompt or chose to type the password; show nothing.
        case cancelled
        case failed(String)
    }

    let isAvailable = BiometricStore.isAvailable
    private let store: BiometricStore
    /// Identifies the current vault key (changes with the master password).
    private let currentVaultID: () -> String?

    init(dbPath: URL, currentVaultID: @escaping () -> String?) {
        store = BiometricStore(dbPath: dbPath)
        self.currentVaultID = currentVaultID
    }

    var isEnabled: Bool { isAvailable && store.load() != nil }

    func enable(key: SymmetricKey, passwordEnteredAt: Date) throws {
        guard let vaultID = currentVaultID() else { throw BiometricStore.Failure.invalidRecord }
        try store.save(BiometricStore.seal(key: key, vaultID: vaultID, passwordAt: passwordEnteredAt))
    }

    func disable() {
        store.delete()
    }

    /// After the master password was entered or changed: re-seal to `key` and restart the 14-day clock.
    /// Drops the seal if it can no longer be updated.
    func passwordEntered(key: SymmetricKey) {
        guard let record = store.load() else { return }
        guard let vaultID = currentVaultID(),
              let resealed = try? BiometricStore.reseal(record, key: key, vaultID: vaultID, passwordAt: Date()),
              (try? store.save(resealed)) != nil
        else {
            disable()
            return
        }
    }

    /// Prompt for Touch ID and recover the vault key. `verify` must confirm the key opens the vault.
    func unlock(verify: (SymmetricKey) -> Bool) async -> Outcome {
        guard let record = store.load() else { return .cancelled }
        guard record.vaultID == currentVaultID() else {
            disable()
            return .failed(tr("主密码已变更，Touch ID 已关闭。请用主密码解锁后重新开启。"))
        }
        guard !BiometricStore.passwordExpired(record) else {
            return .failed(tr("已超过 14 天未输入主密码，请输入一次主密码。"))
        }

        let context = LAContext()
        context.localizedFallbackTitle = tr("输入主密码")
        do {
            try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics, localizedReason: tr("解锁 Email Vault")
            )
        } catch let error as LAError where [.userCancel, .userFallback, .systemCancel, .appCancel].contains(error.code) {
            return .cancelled
        } catch {
            return .failed(trf("Touch ID 不可用：%@", error.localizedDescription))
        }

        guard let key = try? BiometricStore.open(record, context: context), verify(key) else {
            disable()
            return .failed(tr("Touch ID 凭据已失效（可能指纹有变动），已关闭。请用主密码解锁后重新开启。"))
        }
        return .unlocked(key, passwordEnteredAt: record.passwordAt)
    }
}
#endif
