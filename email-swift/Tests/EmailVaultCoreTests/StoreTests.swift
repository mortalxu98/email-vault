import XCTest
import Crypto
import GRDB
@testable import EmailVaultCore

final class StoreTests: XCTestCase {
    private var tmpDir: URL!
    private var store: Store!
    private var key: SymmetricKey!

    override func setUpWithError() throws {
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("email-vault-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let dbPath = tmpDir.appendingPathComponent("vault.db")
        setenv("EMAIL_VAULT_DB", dbPath.path, 1)
        store = try Store(path: dbPath)
        let params = try KdfParams.fromJSON(
            #"{"salt": "00112233445566778899aabbccddeeff", "time_cost": 3, "memory_cost": 65536, "parallelism": 4}"#
        )
        key = try VaultCrypto.deriveKey(password: "test-master-123", params: params)
    }

    override func tearDownWithError() throws {
        store = nil
        try? FileManager.default.removeItem(at: tmpDir)
        unsetenv("EMAIL_VAULT_DB")
    }

    func testUnlockHappyPathAndWrongPassword() throws {
        let vault = Vault(store: store)
        XCTAssertFalse(try vault.isInitialized())
        _ = try vault.initialize(password: "correct horse battery")
        XCTAssertTrue(try vault.isInitialized())
        let unlocked = try vault.unlock(password: "correct horse battery")
        // re-derive and decrypt a field
        let enc = try VaultCrypto.encrypt("secret", with: unlocked)
        XCTAssertEqual(try VaultCrypto.decrypt(enc, with: unlocked), "secret")
        XCTAssertThrowsError(try vault.unlock(password: "wrong-password")) { err in
            XCTAssertEqual(err as? VaultError, .invalidMasterPassword)
        }
        XCTAssertThrowsError(try vault.initialize(password: "another")) { err in
            XCTAssertEqual(err as? VaultError, .alreadyInitialized)
        }
    }

    func testBlankPasswordDoesNotOverwrite() throws {
        let enc = try VaultCrypto.encrypt("keep-me", with: key)
        let eid = try store.createEmail(address: "a@gmail.com", note: "", passwordEnc: enc)
        // nil passwordEnc => COALESCE keeps old
        try store.updateEmail(id: eid, address: "a@gmail.com", note: "n", passwordEnc: nil)
        let blob = try store.getEmailPassword(eid)
        XCTAssertEqual(try VaultCrypto.decrypt(blob!, with: key), "keep-me")

        let aEnc = try VaultCrypto.encrypt("old", with: key)
        let aid = try store.createAccount(
            emailId: eid, platform: "Claude", category: "ai",
            username: "", url: "", note: "", passwordEnc: aEnc
        )
        try store.updateAccount(
            id: aid, platform: "Claude", category: "ai",
            username: "", url: "", note: "", passwordEnc: nil, renewal: nil
        )
        XCTAssertEqual(try VaultCrypto.decrypt(try store.getAccountPassword(aid)!, with: key), "old")

        let newEnc = try VaultCrypto.encrypt("new", with: key)
        try store.updateAccount(
            id: aid, platform: "Claude", category: "ai",
            username: "", url: "", note: "", passwordEnc: newEnc, renewal: nil
        )
        XCTAssertEqual(try VaultCrypto.decrypt(try store.getAccountPassword(aid)!, with: key), "new")
    }

    func testCascadeDelete() throws {
        let eid = try store.createEmail(address: "a@gmail.com", note: "", passwordEnc: nil)
        _ = try store.createAccount(
            emailId: eid, platform: "ChatGPT", category: "ai",
            username: "", url: "", note: "", passwordEnc: nil
        )
        XCTAssertEqual(try store.listAccounts(emailId: eid).count, 1)
        try store.deleteEmail(eid)
        XCTAssertEqual(try store.listAccounts(emailId: eid).count, 0)
        XCTAssertNil(try store.getEmail(eid))
    }

    func testLikeEscape() throws {
        _ = try store.createEmail(address: "a@gmail.com", note: "100%_done", passwordEnc: nil)
        // Searching for literal % should not match everything
        _ = try store.listEmails(query: "%")
        // Python test expects no match for q=%25 which is "%"
        // Our email note contains "%", so searching for "%" SHOULD find it via escaped pattern.
        // The Python test searches q=%25 (URL-decoded "%") against address/note/platform —
        // address "a@gmail.com" has no %, note is empty in that test. Here note has %.
        // Match Python test: email with empty note, query "%" finds nothing.
        try store.deleteEmail(try store.listEmails()[0].id)
        _ = try store.createEmail(address: "a@gmail.com", note: "", passwordEnc: nil)
        XCTAssertTrue(try store.listEmails(query: "%").isEmpty)
        XCTAssertTrue(try store.listEmails(query: "_").isEmpty)
        // Unescaped would treat % as wildcard; escaped finds literal only
        _ = try store.createEmail(address: "b@gmail.com", note: "100%_done", passwordEnc: nil)
        let found = try store.listEmails(query: "100%")
        XCTAssertEqual(found.map(\.address), ["b@gmail.com"])
    }

    func testLikePatternEscapes() {
        XCTAssertEqual(Store.likePattern("a%b_c\\d"), "%a\\%b\\_c\\\\d%")
    }

    func testDuplicateEmailRejected() throws {
        _ = try store.createEmail(address: "a@gmail.com", note: "", passwordEnc: nil)
        XCTAssertThrowsError(try store.createEmail(address: "A@Gmail.com", note: "", passwordEnc: nil)) { err in
            guard case StoreError.duplicateEmail = err else {
                return XCTFail("expected duplicateEmail, got \(err)")
            }
        }
    }

    func testPasswordsEncryptedAtRest() throws {
        let secret = "mail-secret-123"
        let enc = try VaultCrypto.encrypt(secret, with: key)
        _ = try store.createEmail(address: "a@gmail.com", note: "", passwordEnc: enc)
        let raw = try Data(contentsOf: store.path)
        XCTAssertFalse(raw.contains(Data(secret.utf8)))
        // address stays searchable (may appear in sqlite pages)
        XCTAssertTrue(raw.contains(Data("a@gmail.com".utf8)))
    }

    func testRenewalRoundTripAndClear() throws {
        let eid = try store.createEmail(address: "r@gmail.com", note: "", passwordEnc: nil)
        let renewal = Renewal(dueDate: "2026-12-01", cycle: .yearly, amount: "¥99", leadDays: 10)
        let aid = try store.createAccount(
            emailId: eid, platform: "ZoroCloud", category: "other",
            username: "", url: "", note: "", passwordEnc: nil, renewal: renewal
        )
        XCTAssertEqual(try store.getAccount(aid)?.renewal, renewal)
        XCTAssertEqual(try store.listRenewals().map(\.id), [aid])

        try store.setRenewal(accountId: aid, renewal: nil)
        XCTAssertNil(try store.getAccount(aid)?.renewal)
        XCTAssertTrue(try store.listRenewals().isEmpty)
    }

    func testMigrationAddsRenewalColumnsAndBacksUp() throws {
        let dir = tmpDir.appendingPathComponent("old", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbPath = dir.appendingPathComponent("vault.db")
        let legacy = try DatabaseQueue(path: dbPath.path)
        try legacy.write { db in
            try db.execute(sql: Store.schema)
            try db.execute(sql: "INSERT INTO emails (address) VALUES ('old@gmail.com')")
            try db.execute(sql: "INSERT INTO accounts (email_id, platform) VALUES (1, 'GitHub')")
        }
        try legacy.close()

        let migrated = try Store(path: dbPath)
        XCTAssertNil(try migrated.listAccounts(emailId: 1).first?.renewal)
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("backups").path)
        XCTAssertEqual(backups.count, 1)

        // Reopening must not migrate or back up again.
        _ = try Store(path: dbPath)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("backups").path).count, 1)
    }

    func testRenewalDueAndAdvance() throws {
        let today = try XCTUnwrap(Renewal.parse("2026-01-31"))
        let r = Renewal(dueDate: "2026-02-05", cycle: .monthly, leadDays: 7)
        XCTAssertEqual(r.daysUntilDue(today: today), 5)
        XCTAssertTrue(r.isDue(today: today))
        XCTAssertFalse(Renewal(dueDate: "2026-03-01", leadDays: 7).isDue(today: today))
        XCTAssertEqual(Renewal(dueDate: "2026-01-20").daysUntilDue(today: today), -11)

        XCTAssertEqual(Renewal(dueDate: "2026-01-31", cycle: .monthly).renewed()?.dueDate, "2026-02-28")
        XCTAssertEqual(Renewal(dueDate: "2024-02-29", cycle: .yearly).renewed()?.dueDate, "2025-02-28")
        XCTAssertNil(Renewal(dueDate: "2026-01-31", cycle: .once).renewed())
    }
}
