import Crypto
import Foundation

/// Plaintext CSV export of the whole vault (RFC 4180). One row per account; emails without
/// accounts get a single row with empty account columns. The result contains every secret in
/// clear text — callers must re-authenticate first and write it with 0600 permissions.
public enum CSVExporter {
    public static let header = [
        "email", "email_password", "email_note", "email_secure_note",
        "platform", "category", "username", "password", "url", "note", "secure_note",
        "renew_at", "renew_cycle", "renew_amount", "renew_lead_days",
    ]

    public static func export(store: Store, key: SymmetricKey) throws -> String {
        func open(_ blob: Data?) throws -> String {
            guard let blob else { return "" }
            return try VaultCrypto.decrypt(blob, with: key)
        }

        var rows: [[String]] = [header]
        for email in try store.listEmails() {
            let emailFields = [
                email.address,
                try open(store.getEmailPassword(email.id)),
                email.note,
                try open(store.getEmailSecret(email.id)),
            ]
            let accounts = try store.listAccounts(emailId: email.id)
            if accounts.isEmpty {
                rows.append(emailFields + Array(repeating: "", count: header.count - emailFields.count))
                continue
            }
            for account in accounts {
                let renewal = account.renewal
                rows.append(emailFields + [
                    account.platform,
                    account.category,
                    account.username,
                    try open(store.getAccountPassword(account.id)),
                    account.url,
                    account.note,
                    try open(store.getAccountSecret(account.id)),
                    renewal?.dueDate ?? "",
                    renewal?.cycle.rawValue ?? "",
                    renewal?.amount ?? "",
                    renewal.map { String($0.leadDays) } ?? "",
                ])
            }
        }
        return rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /// Quote fields containing a comma, quote, CR or LF; double embedded quotes.
    public static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Write `contents` to `url`, creating the file 0600 before any data lands in it.
    public static func write(_ contents: String, to url: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } else if !fm.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data(contents.utf8))
    }
}
