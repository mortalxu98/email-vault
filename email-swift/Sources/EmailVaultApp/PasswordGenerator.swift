#if os(macOS)
import Foundation
import Security

/// Random 20-character password from an unambiguous alphabet, using rejection sampling to avoid modulo bias.
enum PasswordGenerator {
    static let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%^&*-_=+")
    static let length = 20

    static func generate() -> String {
        var out: [Character] = []
        out.reserveCapacity(length)
        let n = chars.count
        let limit = 256 - (256 % n)
        while out.count < length {
            var bytes = [UInt8](repeating: 0, count: length * 2)
            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            guard status == errSecSuccess else {
                fatalError("SecRandomCopyBytes failed: \(status)")
            }
            for b in bytes where out.count < length {
                if Int(b) < limit {
                    out.append(chars[Int(b) % n])
                }
            }
        }
        return String(out)
    }
}
#endif
