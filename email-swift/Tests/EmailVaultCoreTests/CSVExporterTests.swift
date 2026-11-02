import Crypto
import XCTest
@testable import EmailVaultCore

final class CSVExporterTests: XCTestCase {
    private var tmpDir: URL!
    private var store: Store!
    private let key = SymmetricKey(size: .bits256)

    override func setUpWithError() throws {
        tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("ev-csv-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        store = try Store(path: tmpDir.appendingPathComponent("vault.db"))
    }

    override func tearDownWithError() throws {
        store = nil
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testEscape() {
        XCTAssertEqual(CSVExporter.escape("plain"), "plain")
        XCTAssertEqual(CSVExporter.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(CSVExporter.escape("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(CSVExporter.escape("line1\nline2"), "\"line1\nline2\"")
    }

    func testExportDecryptsEverything() throws {
        let eid = try store.createEmail(address: "a@gmail.com", note: "main", passwordEnc: try VaultCrypto.encrypt("mail-pw", with: key))
        try store.setEmailSecret(eid, secretEnc: try VaultCrypto.encrypt("codes, 1 2 3", with: key))
        let aid = try store.createAccount(
            emailId: eid, platform: "GitHub", category: "other", username: "alex",
            url: "https://github.com", note: "", passwordEnc: try VaultCrypto.encrypt("gh\"pw", with: key),
            renewal: Renewal(dueDate: "2026-12-01", cycle: .yearly, amount: "$4", leadDays: 5)
        )
        try store.setAccountSecret(aid, secretEnc: try VaultCrypto.encrypt("seed\nwords", with: key))
        _ = try store.createEmail(address: "empty@proton.me", note: "", passwordEnc: nil)

        let csv = try CSVExporter.export(store: store, key: key)
        let lines = csv.components(separatedBy: "\r\n")
        XCTAssertEqual(lines[0], CSVExporter.header.joined(separator: ","))
        XCTAssertEqual(
            lines[1],
            "a@gmail.com,mail-pw,main,\"codes, 1 2 3\",GitHub,other,alex,\"gh\"\"pw\",https://github.com,,\"seed\nwords\",2026-12-01,yearly,$4,5"
        )
        XCTAssertEqual(lines[2], "empty@proton.me" + String(repeating: ",", count: CSVExporter.header.count - 1))
        XCTAssertEqual(lines.last, "")
    }

    func testWriteUses0600() throws {
        let url = tmpDir.appendingPathComponent("export.csv")
        try CSVExporter.write("x\r\n", to: url)
        let perms = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        XCTAssertEqual(perms, 0o600)
        try CSVExporter.write("y\r\n", to: url)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "y\r\n")
    }
}
