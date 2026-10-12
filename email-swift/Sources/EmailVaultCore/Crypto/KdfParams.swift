import Foundation

/// Argon2id parameters stored in `meta.kdf_params` as JSON.
/// Keys match the Python original: salt, time_cost, memory_cost, parallelism.
public struct KdfParams: Codable, Equatable, Sendable {
    public var salt: String
    public var timeCost: Int
    public var memoryCost: Int
    public var parallelism: Int

    public static let saltLength = 16
    public static let keyLength = 32

    enum CodingKeys: String, CodingKey {
        case salt
        case timeCost = "time_cost"
        case memoryCost = "memory_cost"
        case parallelism
    }

    public init(salt: String, timeCost: Int = 3, memoryCost: Int = 64 * 1024, parallelism: Int = 4) {
        self.salt = salt
        self.timeCost = timeCost
        self.memoryCost = memoryCost
        self.parallelism = parallelism
    }

    public static func generate() -> KdfParams {
        var bytes = [UInt8](repeating: 0, count: saltLength)
        var rng = SystemRandomNumberGenerator()
        for i in 0..<bytes.count {
            bytes[i] = UInt8.random(in: 0...255, using: &rng)
        }
        return KdfParams(salt: Data(bytes).hexString)
    }

    public func toJSON() throws -> String {
        let data = try JSONEncoder().encode(self)
        return String(data: data, encoding: .utf8)!
    }

    public static func fromJSON(_ raw: String) throws -> KdfParams {
        try JSONDecoder().decode(KdfParams.self, from: Data(raw.utf8))
    }
}
