import XCTest
import Crypto
@testable import EmailVaultCore

final class CryptoTests: XCTestCase {
    /// Exact vectors from docs/data-format.md
    private let master = "test-master-123"
    private let paramsJSON = #"{"salt": "00112233445566778899aabbccddeeff", "time_cost": 3, "memory_cost": 65536, "parallelism": 4}"#
    private let expectedKeyHex = "4cf81a5f663c93d65bbd014cd37f286547b700ee06382a23ffdd425d698f22b3"
    private let ciphertextHex = "0102030405060708090a0b0c84795e1334ccf22ad386a44db5211e03d3020877c74a13e8b2a06dc8ae824bcc"
    private let plaintext = "hello-密码-123"
    private let verifierHex = "0102030405060708090a0b0c8971531637cc61e4200d70e1ee755e59aaffb193fd025682de2292f0a15416805052e0352f149a"

    func testDeriveKeyMatchesVector() throws {
        let params = try KdfParams.fromJSON(paramsJSON)
        let key = try Argon2KDF.deriveKey(password: master, params: params)
        XCTAssertEqual(key.hexString, expectedKeyHex)
    }

    func testDecryptCiphertextVector() throws {
        let key = SymmetricKey(data: try Hex.decode(expectedKeyHex))
        let blob = try Hex.decode(ciphertextHex)
        let result = try FieldCrypto.decrypt(key: key, blob: blob)
        XCTAssertEqual(result, plaintext)
    }

    func testDecryptVerifierVector() throws {
        let key = SymmetricKey(data: try Hex.decode(expectedKeyHex))
        let blob = try Hex.decode(verifierHex)
        let result = try FieldCrypto.decrypt(key: key, blob: blob)
        XCTAssertEqual(result, VaultCrypto.verifierPlaintext)
    }

    func testEncryptRoundtrip() throws {
        let key = SymmetricKey(data: try Hex.decode(expectedKeyHex))
        let blob = try FieldCrypto.encrypt(key: key, plaintext: plaintext)
        XCTAssertEqual(try FieldCrypto.decrypt(key: key, blob: blob), plaintext)
        // combined = nonce(12) + ciphertext + tag(16)
        XCTAssertGreaterThanOrEqual(blob.count, 12 + 16)
    }

    func testEncryptWithFixedNonceMatchesVector() throws {
        let key = SymmetricKey(data: try Hex.decode(expectedKeyHex))
        let nonceData = try Hex.decode("0102030405060708090a0b0c")
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let blob = try FieldCrypto.encrypt(key: key, plaintext: plaintext, nonce: nonce)
        XCTAssertEqual(blob.hexString, ciphertextHex)
    }

    func testWrongKeyFailsDecrypt() throws {
        let key = SymmetricKey(data: Data(repeating: 0, count: 32))
        let blob = try Hex.decode(ciphertextHex)
        XCTAssertThrowsError(try FieldCrypto.decrypt(key: key, blob: blob))
    }
}
