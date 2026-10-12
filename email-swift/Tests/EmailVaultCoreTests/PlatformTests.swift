import XCTest
@testable import EmailVaultCore

final class PlatformTests: XCTestCase {
    func testKnownProviderLogos() {
        for address in ["a@gmail.com", "a@outlook.com", "a@proton.me", "a@icloud.com", "a@qq.com"] {
            let pv = PlatformCatalog.provider(for: address)
            XCTAssertNotNil(pv.logo, address)
        }
    }

    func testProviderFallbacks() {
        XCTAssertNil(PlatformCatalog.provider(for: "a@163.com").logo)
        let unknown = PlatformCatalog.provider(for: "a@Example.ORG")
        XCTAssertNil(unknown.logo)
        XCTAssertEqual(unknown.initial, "E")
        XCTAssertTrue(unknown.css.hasPrefix("av-"))
    }

    func testPlatformLogoMatching() {
        XCTAssertEqual(PlatformCatalog.platformLogo(platform: "ChatGPT"), "openai")
        XCTAssertEqual(PlatformCatalog.platformLogo(platform: "B 站"), "bilibili")
        XCTAssertEqual(
            PlatformCatalog.platformLogo(platform: "GitHub Copilot", url: "https://github.com/features/copilot"),
            "githubcopilot"
        )
        XCTAssertEqual(PlatformCatalog.platformLogo(platform: "Copilot"), "microsoft")
        XCTAssertEqual(
            PlatformCatalog.platformLogo(platform: "My Gemini", url: "https://gemini.google.com/app"),
            "gemini"
        )
        XCTAssertEqual(
            PlatformCatalog.platformLogo(platform: "工作号", url: "https://www.x.com/home"),
            "x"
        )
        XCTAssertNil(PlatformCatalog.platformLogo(platform: "Something", url: "https://evilx.com"))
        XCTAssertNil(PlatformCatalog.platformLogo(platform: "Grok"))
    }

    func testCryptoPlatforms() {
        XCTAssertEqual(PlatformCatalog.platformLogo(platform: "OKEx"), "okx")
        XCTAssertEqual(PlatformCatalog.platformLogo(platform: "欧易"), "okx")
        XCTAssertEqual(
            PlatformCatalog.platformLogo(platform: "交易所", url: "https://www.binance.com/zh-CN"),
            "binance"
        )
    }

    func testApplePlatformsShareOneLogo() {
        for name in ["Apple", "apple id", "苹果", "App Store", "iCloud"] {
            XCTAssertEqual(PlatformCatalog.platformLogo(platform: name), "apple", name)
        }
        XCTAssertEqual(
            PlatformCatalog.platformLogo(platform: "账号", url: "https://appleid.apple.com/"),
            "apple"
        )
        XCTAssertEqual(
            PlatformCatalog.platformLogo(platform: "某账号", url: "https://apps.apple.com/"),
            "apple"
        )
    }

    func testGoogleAccountVsProducts() {
        XCTAssertEqual(PlatformCatalog.platformLogo(platform: "Google"), "google")
        XCTAssertEqual(PlatformCatalog.platformLogo(platform: "谷歌账号"), "google")
        XCTAssertEqual(
            PlatformCatalog.platformLogo(platform: "账号", url: "https://accounts.google.com/"),
            "google"
        )
        XCTAssertEqual(
            PlatformCatalog.platformLogo(platform: "某账号", url: "https://gemini.google.com/"),
            "gemini"
        )
    }

    func testICloudMailUsesAppleLogo() {
        for address in ["a@icloud.com", "a@me.com", "a@mac.com"] {
            XCTAssertEqual(PlatformCatalog.provider(for: address).logo, "apple")
        }
    }

    func testMetaFamilySharesOneLogo() {
        for name in ["Meta", "Meta AI", "Messenger", "Llama"] {
            XCTAssertEqual(PlatformCatalog.platformLogo(platform: name), "meta", name)
        }
        for url in [
            "https://accountscenter.meta.com/",
            "https://www.meta.ai/",
            "https://messenger.com",
        ] {
            XCTAssertEqual(PlatformCatalog.platformLogo(platform: "某账号", url: url), "meta", url)
        }
        XCTAssertEqual(PlatformCatalog.platformLogo(platform: "脸书"), "facebook")
    }

    func testCatalogEntriesHaveUrlAndKeys() {
        let entries = Dictionary(uniqueKeysWithValues: PlatformCatalog.catalog(userPlatforms: []).map { ($0.name, $0) })
        XCTAssertEqual(entries["Bybit"]?.url, "https://bybit.com")
        XCTAssertNil(entries["Bybit"]?.logo)
        XCTAssertTrue(entries["OKX"]?.keys.contains("okex") ?? false)
    }

    func testAutocompleteScoring() {
        let catalog = PlatformCatalog.catalog(userPlatforms: [
            (name: "My Private Forum", category: "other", url: "https://forum.example.org"),
        ])
        let b = PlatformCatalog.matches(query: "b", in: catalog)
        XCTAssertFalse(b.isEmpty)
        // single char: name prefix only — Bybit, Bitget, Binance, B 站...
        XCTAssertTrue(b.allSatisfy { PlatformCatalog.norm($0.name).hasPrefix("b") })
        XCTAssertLessThanOrEqual(b.count, 8)

        let by = PlatformCatalog.matches(query: "by", in: catalog)
        XCTAssertEqual(by.first?.name, "Bybit")

        let mine = PlatformCatalog.matches(query: "my private", in: catalog)
        XCTAssertEqual(mine.first?.name, "My Private Forum")
        XCTAssertTrue(mine.first?.mine ?? false)
    }

    func testColorIndexStable() {
        // Must match Python zlib.crc32(text.lower().encode()) % 8
        XCTAssertEqual(PlatformCatalog.colorIndex("example.org"), PlatformCatalog.colorIndex("Example.ORG"))
    }
}
