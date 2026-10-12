import Foundation
import Crypto

/// AES-256-GCM field encryption. Storage format = nonce(12) || ciphertext || tag(16),
/// identical to CryptoKit / swift-crypto `AES.GCM.SealedBox.combined`.
public enum FieldCrypto {
    public static let nonceLength = 12
    public static let tagLength = 16

    public static func encrypt(key: SymmetricKey, plaintext: String) throws -> Data {
        let sealed = try AES.GCM.seal(Data(plaintext.utf8), using: key)
        guard let combined = sealed.combined else {
            throw CryptoError.missingSealedBox
        }
        return combined
    }

    /// Encrypt with a fixed nonce (for test vectors only).
    public static func encrypt(key: SymmetricKey, plaintext: String, nonce: AES.GCM.Nonce) throws -> Data {
        let sealed = try AES.GCM.seal(Data(plaintext.utf8), using: key, nonce: nonce)
        guard let combined = sealed.combined else {
            throw CryptoError.missingSealedBox
        }
        return combined
    }

    public static func decrypt(key: SymmetricKey, blob: Data) throws -> String {
        do {
            let box = try AES.GCM.SealedBox(combined: blob)
            let plain = try AES.GCM.open(box, using: key)
            guard let text = String(data: plain, encoding: .utf8) else {
                throw CryptoError.decryptionFailed
            }
            return text
        } catch is CryptoError {
            throw CryptoError.decryptionFailed
        } catch {
            throw CryptoError.decryptionFailed
        }
    }
}
