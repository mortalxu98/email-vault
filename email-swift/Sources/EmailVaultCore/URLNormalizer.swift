import Foundation

/// Normalizes a user-entered URL: defaults to https:// and drops non-web schemes.
public enum URLNormalizer {
    public static func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            return ""
        }
        if !value.contains("://") {
            value = "https://\(value)"
        }
        let scheme = self.scheme(of: value)
        return scheme == "http" || scheme == "https" ? value : ""
    }

    /// Lowercased URL scheme per RFC 3986 (`scheme ":"`), or "" if none.
    static func scheme(of value: String) -> String {
        guard let colon = value.firstIndex(of: ":") else {
            return ""
        }
        let candidate = value[..<colon]
        guard let first = candidate.first, first.isASCII, first.isLetter else {
            return ""
        }
        let allowed = candidate.allSatisfy { ch in
            ch.isASCII && (ch.isLetter || ch.isNumber || ch == "+" || ch == "-" || ch == ".")
        }
        return allowed ? candidate.lowercased() : ""
    }
}
