#if os(macOS)
import Crypto
import Foundation
import LocalAuthentication
import Security

/// Touch ID unlock: the vault key is sealed to a Secure Enclave P-256 key (ECDH + HKDF + AES-GCM).
/// The SE key requires biometry (current enrollment) for every private-key use; only its opaque,
/// device-bound blob is stored, next to the DB as `<db name>.touchid.json` (0600).
public struct BiometricStore: Sendable {
    public struct Record: Codable, Equatable, Sendable {
        public var version: Int
        /// `SecureEnclave.P256.KeyAgreement.PrivateKey.dataRepresentation` (only usable on this Mac).
        public var seKey: Data
        public var ephemeralPublicKey: Data
        public var sealedKey: Data
        /// SHA-256 of `meta.key_verifier`; a mismatch means the master password changed elsewhere.
        public var vaultID: String
        /// Last time the master password itself was entered.
        public var passwordAt: Date
    }

    public enum Failure: Error, Equatable, Sendable {
        case unavailable
        case invalidRecord
    }

    /// Master password must be re-entered at least this often.
    public static let passwordInterval: TimeInterval = 14 * 24 * 3600
    private static let hkdfSalt = Data("email-vault-touchid-v1".utf8)

    public let url: URL

    public init(dbPath: URL) {
        let name = dbPath.deletingPathExtension().lastPathComponent
        url = dbPath.deletingLastPathComponent().appendingPathComponent("\(name).touchid.json")
    }

    public static var isAvailable: Bool {
        var error: NSError?
        return SecureEnclave.isAvailable
            && LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    public static func vaultID(verifierHex: String) -> String {
        SHA256.hash(data: Data(verifierHex.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    public static func passwordExpired(_ record: Record, now: Date = Date()) -> Bool {
        now.timeIntervalSince(record.passwordAt) >= passwordInterval
    }

    // MARK: - file

    public func load() -> Record? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode(Record.self, from: data)
    }

    public func save(_ record: Record) throws {
        try Self.encoder.encode(record).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func delete() {
        try? FileManager.default.removeItem(at: url)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    // MARK: - sealing

    /// New Secure Enclave key bound to the current fingerprints; seals `key` to it. No prompt.
    public static func seal(key: SymmetricKey, vaultID: String, passwordAt: Date) throws -> Record {
        guard SecureEnclave.isAvailable else { throw Failure.unavailable }
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            &error
        ) else {
            throw error!.takeRetainedValue() as Error
        }
        let se = try SecureEnclave.P256.KeyAgreement.PrivateKey(accessControl: access)
        return try reseal(key: key, seKey: se.dataRepresentation, sePublicKey: se.publicKey,
                          vaultID: vaultID, passwordAt: passwordAt)
    }

    /// Re-seal a (new) vault key to the existing SE key. Uses only the public key, so no prompt.
    public static func reseal(_ record: Record, key: SymmetricKey, vaultID: String, passwordAt: Date) throws -> Record {
        let se = try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: record.seKey)
        return try reseal(key: key, seKey: record.seKey, sePublicKey: se.publicKey,
                          vaultID: vaultID, passwordAt: passwordAt)
    }

    private static func reseal(
        key: SymmetricKey, seKey: Data, sePublicKey: P256.KeyAgreement.PublicKey,
        vaultID: String, passwordAt: Date
    ) throws -> Record {
        let ephemeral = P256.KeyAgreement.PrivateKey()
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: sePublicKey)
        let wrapKey = derive(shared, ephemeral: ephemeral.publicKey, se: sePublicKey)
        let raw = key.withUnsafeBytes { Data($0) }
        guard let sealed = try AES.GCM.seal(raw, using: wrapKey).combined else {
            throw Failure.invalidRecord
        }
        return Record(
            version: 1, seKey: seKey, ephemeralPublicKey: ephemeral.publicKey.x963Representation,
            sealedKey: sealed, vaultID: vaultID, passwordAt: passwordAt
        )
    }

    /// Recover the vault key. `context` should already be authenticated via `evaluatePolicy`.
    public static func open(_ record: Record, context: LAContext) throws -> SymmetricKey {
        let se = try SecureEnclave.P256.KeyAgreement.PrivateKey(
            dataRepresentation: record.seKey, authenticationContext: context
        )
        let ephemeral = try P256.KeyAgreement.PublicKey(x963Representation: record.ephemeralPublicKey)
        let shared = try se.sharedSecretFromKeyAgreement(with: ephemeral)
        let wrapKey = derive(shared, ephemeral: ephemeral, se: se.publicKey)
        let raw = try AES.GCM.open(AES.GCM.SealedBox(combined: record.sealedKey), using: wrapKey)
        return SymmetricKey(data: raw)
    }

    private static func derive(
        _ shared: SharedSecret, ephemeral: P256.KeyAgreement.PublicKey, se: P256.KeyAgreement.PublicKey
    ) -> SymmetricKey {
        shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: hkdfSalt,
            sharedInfo: ephemeral.x963Representation + se.x963Representation,
            outputByteCount: 32
        )
    }
}
#endif
