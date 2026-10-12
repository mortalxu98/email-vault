// swift-tools-version: 5.9
import PackageDescription

#if os(Linux)
let extraCoreDeps: [Target.Dependency] = ["SQLiteSnapshotStubs"]
let extraTargets: [Target] = [
    .target(
        name: "SQLiteSnapshotStubs",
        publicHeadersPath: "include"
    ),
]
#else
let extraCoreDeps: [Target.Dependency] = []
let extraTargets: [Target] = []
#endif

let package = Package(
    name: "EmailVault",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "EmailVaultCore", targets: ["EmailVaultCore"]),
        .executable(name: "EmailVault", targets: ["EmailVaultApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.8.0"),
    ],
    targets: extraTargets + [
        .target(
            name: "CArgon2",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("blake2"),
                .define("ARGON2_NO_THREADS"),
            ]
        ),
        .target(
            name: "EmailVaultCore",
            dependencies: [
                "CArgon2",
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Crypto", package: "swift-crypto"),
            ] + extraCoreDeps
        ),
        .executableTarget(
            name: "EmailVaultApp",
            dependencies: ["EmailVaultCore"],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "EmailVaultCoreTests",
            dependencies: ["EmailVaultCore"]
        ),
    ]
)
