import Foundation
import Crypto

public enum VaultError: Error, Equatable, Sendable {
    case invalidMasterPassword
    case alreadyInitialized
}

/// Derives and verifies the encryption key from the master password.
public final class Vault: @unchecked Sendable {
    private let store: Store
    private let lock = NSLock()

    public init(store: Store) {
        self.store = store
    }

    public func isInitialized() throws -> Bool {
        try store.getMeta(VaultCrypto.metaKdf) != nil
    }

    public func initialize(password: String) throws -> SymmetricKey {
        lock.lock()
        defer { lock.unlock() }
        if try isInitialized() {
            throw VaultError.alreadyInitialized
        }
        let params = KdfParams.generate()
        let key = try VaultCrypto.deriveKey(password: password, params: params)
        let verifier = try VaultCrypto.encrypt(VaultCrypto.verifierPlaintext, with: key)
        try store.setMetaMany([
            VaultCrypto.metaKdf: try params.toJSON(),
            VaultCrypto.metaVerifier: verifier.hexString,
        ])
        return key
    }

    /// Unlock with master password. On failure, caller should delay ~1s before returning to UI.
    public func unlock(password: String) throws -> SymmetricKey {
        guard
            let rawParams = try store.getMeta(VaultCrypto.metaKdf),
            let rawVerifier = try store.getMeta(VaultCrypto.metaVerifier)
        else {
            throw VaultError.invalidMasterPassword
        }
        let params = try KdfParams.fromJSON(rawParams)
        let key = try VaultCrypto.deriveKey(password: password, params: params)
        let blob = try Hex.decode(rawVerifier)
        do {
            let plaintext = try VaultCrypto.decrypt(blob, with: key)
            guard plaintext == VaultCrypto.verifierPlaintext else {
                throw VaultError.invalidMasterPassword
            }
            return key
        } catch {
            throw VaultError.invalidMasterPassword
        }
    }
}
