import Foundation

public enum CryptoError: Error, Equatable, Sendable {
    case invalidHex
    case argon2Failed(Int32)
    case decryptionFailed
    case missingSealedBox
}
