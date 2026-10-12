import Foundation

/// Matches Python `app._normalize_url`: default to https:// and drop non-web schemes.
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

    /// Scheme as parsed by Python `urllib.parse.urlsplit` (lowercased), or "" if none.
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
