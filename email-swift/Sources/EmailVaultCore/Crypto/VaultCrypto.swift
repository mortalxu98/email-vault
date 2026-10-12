import Foundation
import Crypto

/// High-level crypto helpers matching `email_vault.crypto` / `email_vault.auth`.
public enum VaultCrypto {
    public static let verifierPlaintext = "email-vault-verifier-v1"
    public static let metaKdf = "kdf_params"
    public static let metaVerifier = "key_verifier"

    public static func deriveKey(password: String, params: KdfParams) throws -> SymmetricKey {
        let raw = try Argon2KDF.deriveKey(password: password, params: params)
        return SymmetricKey(data: raw)
    }

    public static func encrypt(_ plaintext: String, with key: SymmetricKey) throws -> Data {
        try FieldCrypto.encrypt(key: key, plaintext: plaintext)
    }

    public static func decrypt(_ blob: Data, with key: SymmetricKey) throws -> String {
        try FieldCrypto.decrypt(key: key, blob: blob)
    }
}
