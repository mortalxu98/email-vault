import XCTest
@testable import EmailVaultCore

final class URLNormalizerTests: XCTestCase {
    func testNormalizeURL() {
        let cases: [(String, String)] = [
            ("", ""),
            ("   ", ""),
            ("example.com", "https://example.com"),
            ("  example.com/login  ", "https://example.com/login"),
            ("http://example.com", "http://example.com"),
            ("HTTPS://Example.com", "HTTPS://Example.com"),
            ("ftp://example.com", ""),
            ("file:///etc/passwd", ""),
            ("javascript://alert(1)", ""),
            ("javascript:alert(1)", "https://javascript:alert(1)"),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(URLNormalizer.normalize(input), expected, "input: \(input)")
        }
    }
}
