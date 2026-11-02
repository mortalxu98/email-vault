import XCTest

/// Deliberately failing test used once to prove CI blocks bad changes. Never merge.
final class CIFailureProbeTests: XCTestCase {
    func testCIReportsFailures() {
        XCTAssertEqual(1 + 1, 3, "intentional failure: CI smoke test")
    }
}
