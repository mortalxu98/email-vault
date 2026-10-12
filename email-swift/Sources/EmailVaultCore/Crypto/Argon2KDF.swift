import Foundation
import CArgon2

/// Thin wrapper around the official Argon2 C reference (`argon2id_hash_raw`, version 0x13).
public enum Argon2KDF {
    /// Derive a 32-byte key matching Python `argon2.low_level.hash_secret_raw(..., type=Type.ID)`.
    public static func deriveKey(password: String, params: KdfParams) throws -> Data {
        let passwordData = Data(password.utf8)
        let salt = try Hex.decode(params.salt)
        var out = Data(count: KdfParams.keyLength)

        let rc: Int32 = out.withUnsafeMutableBytes { outBuf in
            passwordData.withUnsafeBytes { pwBuf in
                salt.withUnsafeBytes { saltBuf in
                    argon2id_hash_raw(
                        UInt32(params.timeCost),
                        UInt32(params.memoryCost),
                        UInt32(params.parallelism),
                        pwBuf.baseAddress,
                        passwordData.count,
                        saltBuf.baseAddress,
                        salt.count,
                        outBuf.baseAddress,
                        KdfParams.keyLength
                    )
                }
            }
        }
        guard rc == 0 else {
            throw CryptoError.argon2Failed(rc)
        }
        return out
    }
}
