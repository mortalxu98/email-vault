import Foundation

public struct Stats: Equatable, Sendable {
    public var emails: Int
    public var accounts: Int
    public var withoutPassword: Int
    public var byCategory: [String: Int]

    public init(emails: Int, accounts: Int, withoutPassword: Int, byCategory: [String: Int]) {
        self.emails = emails
        self.accounts = accounts
        self.withoutPassword = withoutPassword
        self.byCategory = byCategory
    }
}

public struct EmailRecord: Identifiable, Equatable, Sendable {
    public var id: Int64
    public var address: String
    public var note: String
    public var hasPassword: Bool
    public var accountCount: Int
    public var hasSecret: Bool

    public init(id: Int64, address: String, note: String, hasPassword: Bool, accountCount: Int, hasSecret: Bool = false) {
        self.id = id
        self.address = address
        self.note = note
        self.hasPassword = hasPassword
        self.accountCount = accountCount
        self.hasSecret = hasSecret
    }
}

public struct AccountRecord: Identifiable, Equatable, Sendable {
    public var id: Int64
    public var emailId: Int64
    public var emailAddress: String
    public var platform: String
    public var category: String
    public var username: String
    public var hasPassword: Bool
    public var url: String
    public var note: String
    public var renewal: Renewal?
    public var hasSecret: Bool

    public init(
        id: Int64,
        emailId: Int64,
        emailAddress: String,
        platform: String,
        category: String,
        username: String,
        hasPassword: Bool,
        url: String,
        note: String,
        renewal: Renewal? = nil,
        hasSecret: Bool = false
    ) {
        self.id = id
        self.emailId = emailId
        self.emailAddress = emailAddress
        self.platform = platform
        self.category = category
        self.username = username
        self.hasPassword = hasPassword
        self.url = url
        self.note = note
        self.renewal = renewal
        self.hasSecret = hasSecret
    }
}

public enum StoreError: Error, Equatable, Sendable {
    case duplicateEmail(String)
    case notFound(Int64)
    case notInitialized
}
