import Foundation

// UI strings are keyed by their Simplified Chinese source text. `zh-Hans.lproj` is empty, so
// Chinese falls back to the key; `en.lproj/Localizable.strings` holds the English translations.
// Bundles live in email-swift/Localization and are copied into Contents/Resources by build.sh.

/// Localized text for `key` (the Chinese source string); falls back to the key.
func tr(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

/// Localized format string: `%@` for strings, `%ld` for integers.
func trf(_ key: String, _ args: CVarArg...) -> String {
    String(format: tr(key), locale: Locale.current, arguments: args)
}
