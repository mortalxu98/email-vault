import Foundation
import GRDB

/// SQLite persistence for the vault. Schema and migration rules: docs/data-format.md.
public final class Store: @unchecked Sendable {
    public let path: URL
    private let dbQueue: DatabaseQueue

    public static let schema = """
    CREATE TABLE IF NOT EXISTS meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS emails (
        id           INTEGER PRIMARY KEY,
        address      TEXT NOT NULL UNIQUE COLLATE NOCASE,
        password_enc BLOB,
        note         TEXT NOT NULL DEFAULT '',
        created_at   TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
    );
    CREATE TABLE IF NOT EXISTS accounts (
        id           INTEGER PRIMARY KEY,
        email_id     INTEGER NOT NULL REFERENCES emails(id) ON DELETE CASCADE,
        platform     TEXT NOT NULL,
        category     TEXT NOT NULL DEFAULT 'other',
        username     TEXT NOT NULL DEFAULT '',
        password_enc BLOB,
        url          TEXT NOT NULL DEFAULT '',
        note         TEXT NOT NULL DEFAULT '',
        created_at   TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
    );
    CREATE INDEX IF NOT EXISTS idx_accounts_email_id ON accounts(email_id);
    """

    /// Columns added after the original schema. Additive only, so older builds can still open the DB.
    static let addedColumns: [(table: String, name: String, ddl: String)] = [
        ("accounts", "renew_at", "ALTER TABLE accounts ADD COLUMN renew_at TEXT"),
        ("accounts", "renew_cycle", "ALTER TABLE accounts ADD COLUMN renew_cycle TEXT NOT NULL DEFAULT ''"),
        ("accounts", "renew_amount", "ALTER TABLE accounts ADD COLUMN renew_amount TEXT NOT NULL DEFAULT ''"),
        ("accounts", "renew_lead_days", "ALTER TABLE accounts ADD COLUMN renew_lead_days INTEGER NOT NULL DEFAULT 7"),
        ("accounts", "secret_enc", "ALTER TABLE accounts ADD COLUMN secret_enc BLOB"),
        ("emails", "secret_enc", "ALTER TABLE emails ADD COLUMN secret_enc BLOB"),
    ]

    /// Resolve DB path: `EMAIL_VAULT_DB` env wins; otherwise `~/.local/share/email-vault/vault.db`.
    public static func defaultPath() -> URL {
        if let override = ProcessInfo.processInfo.environment["EMAIL_VAULT_DB"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".local/share/email-vault/vault.db")
    }

    public init(path: URL? = nil) throws {
        let resolved = path ?? Store.defaultPath()
        self.path = resolved
        let dir = resolved.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        dbQueue = try DatabaseQueue(path: resolved.path, configuration: config)
        try dbQueue.write { db in
            try db.execute(sql: Store.schema)
        }
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: resolved.path
        )
        try migrate()
    }

    /// Add missing columns. Backs up a non-empty DB to `<db dir>/backups/` first.
    private func migrate() throws {
        let missing = try dbQueue.read { db -> [(table: String, name: String, ddl: String)] in
            var existing: [String: Set<String>] = [:]
            for table in Set(Store.addedColumns.map(\.table)) {
                existing[table] = Set(try db.columns(in: table).map(\.name))
            }
            return Store.addedColumns.filter { existing[$0.table]?.contains($0.name) != true }
        }
        guard !missing.isEmpty else { return }
        try backup(label: "pre-migration")
        try dbQueue.write { db in
            for column in missing {
                try db.execute(sql: column.ddl)
            }
        }
    }

    // MARK: - LIKE escape

    public static func likePattern(_ query: String) -> String {
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return "%\(escaped)%"
    }

    // MARK: - meta

    public func getMeta(_ key: String) throws -> String? {
        try dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = ?", arguments: [key])
        }
    }

    public func setMetaMany(_ values: [String: String]) throws {
        try dbQueue.write { db in
            for (key, value) in values {
                try db.execute(
                    sql: """
                    INSERT INTO meta (key, value) VALUES (?, ?)
                    ON CONFLICT(key) DO UPDATE SET value = excluded.value
                    """,
                    arguments: [key, value]
                )
            }
        }
    }

    // MARK: - emails

    private static let emailColumns = """
        e.id, e.address, e.note, e.password_enc IS NOT NULL AS has_password,
        e.secret_enc IS NOT NULL AS has_secret,
        (SELECT COUNT(*) FROM accounts a WHERE a.email_id = e.id) AS account_count
    """

    private static let accountColumns = """
        a.id, a.email_id, e.address AS email_address, a.platform, a.category,
        a.username, a.password_enc IS NOT NULL AS has_password, a.url, a.note,
        a.renew_at, a.renew_cycle, a.renew_amount, a.renew_lead_days,
        a.secret_enc IS NOT NULL AS has_secret
    """

    public func listEmails(query: String = "") throws -> [EmailRecord] {
        try dbQueue.read { db in
            var sql = "SELECT \(Self.emailColumns) FROM emails e"
            var args: StatementArguments = []
            if !query.isEmpty {
                sql += """
                     WHERE e.address LIKE ? ESCAPE '\\'
                       OR e.note LIKE ? ESCAPE '\\'
                       OR EXISTS (SELECT 1 FROM accounts a
                                  WHERE a.email_id = e.id AND a.platform LIKE ? ESCAPE '\\')
                """
                let p = Store.likePattern(query)
                args = [p, p, p]
            }
            sql += " ORDER BY e.address"
            return try Row.fetchAll(db, sql: sql, arguments: args).map(Self.mapEmail)
        }
    }

    public func getEmail(_ emailId: Int64) throws -> EmailRecord? {
        try dbQueue.read { db in
            try Row.fetchOne(
                db,
                sql: "SELECT \(Self.emailColumns) FROM emails e WHERE e.id = ?",
                arguments: [emailId]
            ).map(Self.mapEmail)
        }
    }

    public func createEmail(address: String, note: String, passwordEnc: Data?) throws -> Int64 {
        do {
            return try dbQueue.write { db in
                try db.execute(
                    sql: "INSERT INTO emails (address, note, password_enc) VALUES (?, ?, ?)",
                    arguments: [address, note, passwordEnc]
                )
                return db.lastInsertedRowID
            }
        } catch let error as DatabaseError where error.resultCode == .SQLITE_CONSTRAINT {
            throw StoreError.duplicateEmail(address)
        }
    }

    /// `passwordEnc == nil` keeps the stored password (`COALESCE`).
    public func updateEmail(id: Int64, address: String, note: String, passwordEnc: Data?) throws {
        do {
            let changed = try dbQueue.write { db -> Int in
                try db.execute(
                    sql: """
                    UPDATE emails
                       SET address = ?, note = ?,
                           password_enc = COALESCE(?, password_enc),
                           updated_at = datetime('now')
                     WHERE id = ?
                    """,
                    arguments: [address, note, passwordEnc, id]
                )
                return db.changesCount
            }
            if changed == 0 { throw StoreError.notFound(id) }
        } catch let error as DatabaseError where error.resultCode == .SQLITE_CONSTRAINT {
            throw StoreError.duplicateEmail(address)
        }
    }

    public func deleteEmail(_ emailId: Int64) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM emails WHERE id = ?", arguments: [emailId])
        }
    }

    public func getEmailPassword(_ emailId: Int64) throws -> Data? {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT password_enc FROM emails WHERE id = ?",
                arguments: [emailId]
            ) else {
                throw StoreError.notFound(emailId)
            }
            return row["password_enc"] as Data?
        }
    }

    // MARK: - secure notes (encrypted)

    public func getEmailSecret(_ emailId: Int64) throws -> Data? {
        try fetchBlob(table: "emails", column: "secret_enc", id: emailId)
    }

    public func getAccountSecret(_ accountId: Int64) throws -> Data? {
        try fetchBlob(table: "accounts", column: "secret_enc", id: accountId)
    }

    /// `secretEnc == nil` removes the secure note.
    public func setEmailSecret(_ emailId: Int64, secretEnc: Data?) throws {
        try setBlob(table: "emails", column: "secret_enc", id: emailId, value: secretEnc)
    }

    /// `secretEnc == nil` removes the secure note.
    public func setAccountSecret(_ accountId: Int64, secretEnc: Data?) throws {
        try setBlob(table: "accounts", column: "secret_enc", id: accountId, value: secretEnc)
    }

    private func fetchBlob(table: String, column: String, id: Int64) throws -> Data? {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db, sql: "SELECT \(column) AS blob FROM \(table) WHERE id = ?", arguments: [id]
            ) else {
                throw StoreError.notFound(id)
            }
            return row["blob"] as Data?
        }
    }

    private func setBlob(table: String, column: String, id: Int64, value: Data?) throws {
        let changed = try dbQueue.write { db -> Int in
            try db.execute(
                sql: "UPDATE \(table) SET \(column) = ?, updated_at = datetime('now') WHERE id = ?",
                arguments: [value, id]
            )
            return db.changesCount
        }
        if changed == 0 { throw StoreError.notFound(id) }
    }

    // MARK: - accounts

    public func listAccounts(emailId: Int64) throws -> [AccountRecord] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT \(Self.accountColumns)
                  FROM accounts a JOIN emails e ON e.id = a.email_id
                 WHERE a.email_id = ?
                 ORDER BY a.category, a.platform COLLATE NOCASE
                """,
                arguments: [emailId]
            ).map(Self.mapAccount)
        }
    }

    public func searchAccounts(query: String) throws -> [AccountRecord] {
        let p = Store.likePattern(query)
        return try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT \(Self.accountColumns)
                  FROM accounts a JOIN emails e ON e.id = a.email_id
                 WHERE a.platform LIKE ? ESCAPE '\\'
                    OR a.username LIKE ? ESCAPE '\\'
                    OR a.note LIKE ? ESCAPE '\\'
                    OR e.address LIKE ? ESCAPE '\\'
                 ORDER BY a.platform COLLATE NOCASE, e.address
                """,
                arguments: [p, p, p, p]
            ).map(Self.mapAccount)
        }
    }

    public func stats() throws -> Stats {
        try dbQueue.read { db in
            let emails = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM emails") ?? 0
            let row = try Row.fetchOne(
                db,
                sql: "SELECT COUNT(*) AS total, COUNT(*) - COUNT(password_enc) AS without_pw FROM accounts"
            )!
            let accounts: Int = row["total"]
            let without: Int = row["without_pw"]
            var byCategory: [String: Int] = [:]
            let catRows = try Row.fetchAll(db, sql: "SELECT category, COUNT(*) AS c FROM accounts GROUP BY category")
            for r in catRows {
                let cat: String = r["category"]
                let c: Int = r["c"]
                byCategory[cat] = c
            }
            return Stats(emails: emails, accounts: accounts, withoutPassword: without, byCategory: byCategory)
        }
    }

    /// (platform, category, url) per platform name from its most recent account.
    public func distinctPlatforms() throws -> [(String, String, String)] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT platform, category, url, MAX(id)
                  FROM accounts GROUP BY lower(platform) ORDER BY platform COLLATE NOCASE
                """
            ).map { row in
                (row["platform"] as String, row["category"] as String, row["url"] as String)
            }
        }
    }

    public func getAccount(_ accountId: Int64) throws -> AccountRecord? {
        try dbQueue.read { db in
            try Row.fetchOne(
                db,
                sql: """
                SELECT \(Self.accountColumns)
                  FROM accounts a JOIN emails e ON e.id = a.email_id
                 WHERE a.id = ?
                """,
                arguments: [accountId]
            ).map(Self.mapAccount)
        }
    }

    public func createAccount(
        emailId: Int64,
        platform: String,
        category: String,
        username: String,
        url: String,
        note: String,
        passwordEnc: Data?,
        renewal: Renewal? = nil
    ) throws -> Int64 {
        let r = Self.renewalArguments(renewal)
        do {
            return try dbQueue.write { db in
                try db.execute(
                    sql: """
                    INSERT INTO accounts
                       (email_id, platform, category, username, url, note, password_enc,
                        renew_at, renew_cycle, renew_amount, renew_lead_days)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [emailId, platform, category, username, url, note, passwordEnc]
                        + r
                )
                return db.lastInsertedRowID
            }
        } catch let error as DatabaseError where error.resultCode == .SQLITE_CONSTRAINT {
            throw StoreError.notFound(emailId)
        }
    }

    /// `passwordEnc == nil` keeps the stored password; `renewal == nil` clears the reminder.
    public func updateAccount(
        id: Int64,
        platform: String,
        category: String,
        username: String,
        url: String,
        note: String,
        passwordEnc: Data?,
        renewal: Renewal?
    ) throws {
        let r = Self.renewalArguments(renewal)
        let changed = try dbQueue.write { db -> Int in
            try db.execute(
                sql: """
                UPDATE accounts
                   SET platform = ?, category = ?, username = ?, url = ?, note = ?,
                       password_enc = COALESCE(?, password_enc),
                       renew_at = ?, renew_cycle = ?, renew_amount = ?, renew_lead_days = ?,
                       updated_at = datetime('now')
                 WHERE id = ?
                """,
                arguments: [platform, category, username, url, note, passwordEnc] + r + [id]
            )
            return db.changesCount
        }
        if changed == 0 { throw StoreError.notFound(id) }
    }

    /// Most recently created or edited accounts.
    public func recentAccounts(limit: Int) throws -> [AccountRecord] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT \(Self.accountColumns)
                  FROM accounts a JOIN emails e ON e.id = a.email_id
                 ORDER BY a.updated_at DESC, a.id DESC
                 LIMIT ?
                """,
                arguments: [limit]
            ).map(Self.mapAccount)
        }
    }

    /// Accounts that have a renewal reminder, earliest due first.
    public func listRenewals() throws -> [AccountRecord] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT \(Self.accountColumns)
                  FROM accounts a JOIN emails e ON e.id = a.email_id
                 WHERE a.renew_at IS NOT NULL
                 ORDER BY a.renew_at, a.platform COLLATE NOCASE
                """
            ).map(Self.mapAccount)
        }
    }

    /// Set or clear only the renewal fields of an account.
    public func setRenewal(accountId: Int64, renewal: Renewal?) throws {
        let r = Self.renewalArguments(renewal)
        let changed = try dbQueue.write { db -> Int in
            try db.execute(
                sql: """
                UPDATE accounts
                   SET renew_at = ?, renew_cycle = ?, renew_amount = ?, renew_lead_days = ?,
                       updated_at = datetime('now')
                 WHERE id = ?
                """,
                arguments: r + [accountId]
            )
            return db.changesCount
        }
        if changed == 0 { throw StoreError.notFound(accountId) }
    }

    public func deleteAccount(_ accountId: Int64) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM accounts WHERE id = ?", arguments: [accountId])
        }
    }

    public func getAccountPassword(_ accountId: Int64) throws -> Data? {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT password_enc FROM accounts WHERE id = ?",
                arguments: [accountId]
            ) else {
                throw StoreError.notFound(accountId)
            }
            return row["password_enc"] as Data?
        }
    }

    // MARK: - backup

    /// Consistent snapshot via SQLite backup API (passwords stay encrypted).
    public func export(to destination: URL) throws {
        // Restrict permissions before any data is written to the file.
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        } else if !fm.createFile(atPath: destination.path, contents: nil, attributes: [.posixPermissions: 0o600]) {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: destination.path])
        }
        try dbQueue.backup(to: DatabaseQueue(path: destination.path))
        try fm.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: destination.path
        )
    }

    /// Snapshot to `<db dir>/backups/<name>-<label>-<date>-<epoch>.db` before a risky write.
    /// Skipped (returns nil) when the vault is empty.
    @discardableResult
    public func backup(label: String) throws -> URL? {
        let hasData = try dbQueue.read { db in
            (try Int.fetchOne(db, sql: "SELECT (SELECT COUNT(*) FROM emails) + (SELECT COUNT(*) FROM meta)") ?? 0) > 0
        }
        guard hasData else { return nil }
        let dir = path.deletingLastPathComponent().appendingPathComponent("backups", isDirectory: true)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
        let stamp = Renewal.format(Date()) + "-" + String(Int(Date().timeIntervalSince1970))
        let name = path.deletingPathExtension().lastPathComponent
        let url = dir.appendingPathComponent("\(name)-\(label)-\(stamp).db")
        try export(to: url)
        return url
    }

    // MARK: - re-encryption

    /// Every column holding AES-GCM ciphertext under the vault key.
    public static let encryptedColumns: [(table: String, column: String)] = [
        ("emails", "password_enc"),
        ("emails", "secret_enc"),
        ("accounts", "password_enc"),
        ("accounts", "secret_enc"),
    ]

    /// Atomically rewrite every encrypted value with `transform` and store new meta (KDF params, verifier).
    /// Any thrown error rolls back the whole transaction.
    public func reencryptAll(meta: [String: String], transform: (Data) throws -> Data) throws {
        try dbQueue.write { db in
            for (table, column) in Self.encryptedColumns {
                let rows = try Row.fetchAll(
                    db, sql: "SELECT id, \(column) AS blob FROM \(table) WHERE \(column) IS NOT NULL"
                )
                for row in rows {
                    let id: Int64 = row["id"]
                    let blob: Data = row["blob"]
                    try db.execute(
                        sql: "UPDATE \(table) SET \(column) = ? WHERE id = ?",
                        arguments: [try transform(blob), id]
                    )
                }
            }
            for (key, value) in meta {
                try db.execute(
                    sql: """
                    INSERT INTO meta (key, value) VALUES (?, ?)
                    ON CONFLICT(key) DO UPDATE SET value = excluded.value
                    """,
                    arguments: [key, value]
                )
            }
        }
    }

    // MARK: - mapping

    private static func mapEmail(_ row: Row) -> EmailRecord {
        EmailRecord(
            id: row["id"],
            address: row["address"],
            note: row["note"],
            hasPassword: (row["has_password"] as Int64) != 0,
            accountCount: Int(row["account_count"] as Int64),
            hasSecret: (row["has_secret"] as Int64) != 0
        )
    }

    private static func mapAccount(_ row: Row) -> AccountRecord {
        AccountRecord(
            id: row["id"],
            emailId: row["email_id"],
            emailAddress: row["email_address"],
            platform: row["platform"],
            category: row["category"],
            username: row["username"],
            hasPassword: (row["has_password"] as Int64) != 0,
            url: row["url"],
            note: row["note"],
            renewal: mapRenewal(row),
            hasSecret: (row["has_secret"] as Int64) != 0
        )
    }

    private static func mapRenewal(_ row: Row) -> Renewal? {
        guard let due = row["renew_at"] as String?, !due.isEmpty else { return nil }
        let cycle = RenewalCycle(rawValue: row["renew_cycle"] as String? ?? "") ?? .once
        return Renewal(
            dueDate: due,
            cycle: cycle,
            amount: row["renew_amount"] as String? ?? "",
            leadDays: row["renew_lead_days"] as Int? ?? Renewal.defaultLeadDays
        )
    }

    private static func renewalArguments(_ renewal: Renewal?) -> StatementArguments {
        guard let renewal else { return [nil, "", "", Renewal.defaultLeadDays] }
        return [renewal.dueDate, renewal.cycle.rawValue, renewal.amount, renewal.leadDays]
    }
}
