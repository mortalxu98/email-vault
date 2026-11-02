import Foundation

public let avatarPaletteSize = 8

public struct Provider: Equatable, Sendable, Hashable {
    public var name: String
    public var initial: String
    public var css: String
    public var logo: String?

    public init(name: String, initial: String, css: String, logo: String? = nil) {
        self.name = name
        self.initial = initial
        self.css = css
        self.logo = logo
    }
}

public struct Platform: Equatable, Sendable, Hashable {
    public var name: String
    public var category: String
    public var domains: [String]
    public var aliases: [String]
    public var logo: String?

    public init(name: String, category: String, domains: [String], aliases: [String] = [], logo: String? = nil) {
        self.name = name
        self.category = category
        self.domains = domains
        self.aliases = aliases
        self.logo = logo
    }

    /// Default URL for autocomplete fill-in.
    public var defaultURL: String {
        guard let first = domains.first else { return "" }
        return "https://\(first)"
    }
}

public enum PlatformCatalog {
    /// Horizontal marks that need more of the avatar to stay legible.
    public static let wideLogos: Set<String> = ["okx", "meta"]

    public static let platforms: [Platform] = [
        // AI
        Platform(name: "ChatGPT", category: "ai", domains: ["chatgpt.com", "openai.com", "sora.com"], aliases: ["openai", "sora", "dall-e", "dalle"], logo: "openai"),
        Platform(name: "Claude", category: "ai", domains: ["claude.ai", "claude.com"], aliases: ["claudecode", "claude.ai"], logo: "claude"),
        Platform(name: "Anthropic Console", category: "ai", domains: ["console.anthropic.com", "anthropic.com"], aliases: ["anthropic", "anthropicapi"], logo: "anthropic"),
        Platform(name: "Gemini", category: "ai", domains: ["gemini.google.com", "aistudio.google.com"], aliases: ["googlegemini", "bard", "aistudio", "googleaistudio"], logo: "gemini"),
        Platform(name: "GitHub Copilot", category: "ai", domains: [], aliases: [], logo: "githubcopilot"),
        Platform(name: "Copilot", category: "ai", domains: ["copilot.microsoft.com"], aliases: ["microsoftcopilot", "bingcopilot"], logo: "microsoft"),
        Platform(name: "Cursor", category: "ai", domains: ["cursor.com", "cursor.sh"], logo: "cursor"),
        Platform(name: "Perplexity", category: "ai", domains: ["perplexity.ai"], logo: "perplexity"),
        Platform(name: "Midjourney", category: "ai", domains: ["midjourney.com"], aliases: ["mj"], logo: "midjourney"),
        Platform(name: "Notion", category: "ai", domains: ["notion.so", "notion.com"], aliases: ["notionai"], logo: "notion"),
        Platform(name: "Hugging Face", category: "ai", domains: ["huggingface.co"], aliases: ["hf"], logo: "huggingface"),
        Platform(name: "Poe", category: "ai", domains: ["poe.com"], logo: "poe"),
        Platform(name: "ElevenLabs", category: "ai", domains: ["elevenlabs.io"], logo: "elevenlabs"),
        Platform(name: "Kimi", category: "ai", domains: ["kimi.com", "kimi.moonshot.cn", "moonshot.cn"], aliases: ["moonshot", "月之暗面"], logo: "kimi"),
        Platform(name: "通义千问", category: "ai", domains: ["tongyi.aliyun.com", "qwen.ai", "qianwen.com"], aliases: ["qwen", "通义", "tongyi"], logo: "qwen"),
        Platform(name: "DeepSeek", category: "ai", domains: ["deepseek.com"], logo: "deepseek"),
        Platform(name: "Mistral", category: "ai", domains: ["mistral.ai"], aliases: ["mistralai", "lechat"], logo: "mistral"),
        Platform(name: "Suno", category: "ai", domains: ["suno.com", "suno.ai"], logo: "suno"),
        Platform(name: "Replicate", category: "ai", domains: ["replicate.com"], logo: "replicate"),
        Platform(name: "Ollama", category: "ai", domains: ["ollama.com"], logo: "ollama"),
        Platform(name: "Grok", category: "ai", domains: ["grok.com"], aliases: ["xai"]),
        Platform(name: "Runway", category: "ai", domains: ["runwayml.com"], aliases: ["runwayml"]),
        Platform(name: "Character.AI", category: "ai", domains: ["character.ai"], aliases: ["characterai", "c.ai"]),
        Platform(name: "豆包", category: "ai", domains: ["doubao.com"], aliases: ["doubao"]),
        Platform(name: "文心一言", category: "ai", domains: ["yiyan.baidu.com"], aliases: ["wenxin", "ernie", "文心"]),
        // social
        Platform(name: "X", category: "social", domains: ["x.com", "twitter.com"], aliases: ["twitter", "推特"], logo: "x"),
        Platform(name: "Instagram", category: "social", domains: ["instagram.com"], aliases: ["ins", "ig"], logo: "instagram"),
        Platform(name: "Facebook", category: "social", domains: ["facebook.com"], aliases: ["fb", "脸书"], logo: "facebook"),
        Platform(name: "Meta", category: "social", domains: ["accountscenter.meta.com", "meta.com", "meta.ai", "messenger.com"], aliases: ["meta账号", "metaaccount", "accountscenter", "账户中心", "metaai", "llama", "messenger", "fbmessenger"], logo: "meta"),
        Platform(name: "Threads", category: "social", domains: ["threads.net", "threads.com"], logo: "threads"),
        Platform(name: "Reddit", category: "social", domains: ["reddit.com"], logo: "reddit"),
        Platform(name: "YouTube", category: "social", domains: ["youtube.com"], aliases: ["油管"], logo: "youtube"),
        Platform(name: "TikTok", category: "social", domains: ["tiktok.com"], logo: "tiktok"),
        Platform(name: "抖音", category: "social", domains: ["douyin.com"], aliases: ["douyin"], logo: "tiktok"),
        Platform(name: "Discord", category: "social", domains: ["discord.com", "discord.gg"], logo: "discord"),
        Platform(name: "Telegram", category: "social", domains: ["telegram.org", "t.me"], aliases: ["tg", "电报"], logo: "telegram"),
        Platform(name: "WhatsApp", category: "social", domains: ["whatsapp.com"], logo: "whatsapp"),
        Platform(name: "LinkedIn", category: "social", domains: ["linkedin.com"], aliases: ["领英"], logo: "linkedin"),
        Platform(name: "Mastodon", category: "social", domains: ["mastodon.social"], logo: "mastodon"),
        Platform(name: "Bluesky", category: "social", domains: ["bsky.app"], aliases: ["bsky"], logo: "bluesky"),
        Platform(name: "Pinterest", category: "social", domains: ["pinterest.com"], logo: "pinterest"),
        Platform(name: "Snapchat", category: "social", domains: ["snapchat.com"], logo: "snapchat"),
        Platform(name: "小红书", category: "social", domains: ["xiaohongshu.com"], aliases: ["xiaohongshu", "rednote"], logo: "xiaohongshu"),
        Platform(name: "微博", category: "social", domains: ["weibo.com"], aliases: ["新浪微博", "weibo"], logo: "weibo"),
        Platform(name: "B 站", category: "social", domains: ["bilibili.com"], aliases: ["bilibili", "哔哩哔哩"], logo: "bilibili"),
        Platform(name: "知乎", category: "social", domains: ["zhihu.com"], aliases: ["zhihu"], logo: "zhihu"),
        Platform(name: "豆瓣", category: "social", domains: ["douban.com"], aliases: ["douban"], logo: "douban"),
        Platform(name: "微信", category: "social", domains: ["weixin.qq.com", "wechat.com"], aliases: ["wechat", "weixin"], logo: "wechat"),
        Platform(name: "Twitch", category: "social", domains: ["twitch.tv"], logo: "twitch"),
        Platform(name: "Medium", category: "social", domains: ["medium.com"], logo: "medium"),
        Platform(name: "Quora", category: "social", domains: ["quora.com"], logo: "quora"),
        // crypto
        Platform(name: "OKX", category: "crypto", domains: ["okx.com", "okex.com"], aliases: ["okex", "欧易"], logo: "okx"),
        Platform(name: "Binance", category: "crypto", domains: ["binance.com"], aliases: ["币安"], logo: "binance"),
        Platform(name: "Bybit", category: "crypto", domains: ["bybit.com"]),
        Platform(name: "Bitget", category: "crypto", domains: ["bitget.com"]),
        Platform(name: "Gate", category: "crypto", domains: ["gate.io", "gate.com"], aliases: ["gate.io", "芝麻开门"]),
        Platform(name: "HTX", category: "crypto", domains: ["htx.com", "huobi.com"], aliases: ["huobi", "火币"]),
        Platform(name: "MEXC", category: "crypto", domains: ["mexc.com"], aliases: ["抹茶"]),
        Platform(name: "KuCoin", category: "crypto", domains: ["kucoin.com"], aliases: ["库币"], logo: "kucoin"),
        Platform(name: "Kraken", category: "crypto", domains: ["kraken.com"], logo: "kraken"),
        Platform(name: "Coinbase", category: "crypto", domains: ["coinbase.com"]),
        Platform(name: "Bitfinex", category: "crypto", domains: ["bitfinex.com"]),
        Platform(name: "MetaMask", category: "crypto", domains: ["metamask.io"], aliases: ["小狐狸"], logo: "metamask"),
        Platform(name: "Trust Wallet", category: "crypto", domains: ["trustwallet.com"], aliases: ["trust"]),
        Platform(name: "Phantom", category: "crypto", domains: ["phantom.app", "phantom.com"]),
        Platform(name: "OKX Wallet", category: "crypto", domains: ["web3.okx.com"], aliases: ["okxweb3", "欧易钱包"], logo: "okx"),
        Platform(name: "Ledger", category: "crypto", domains: ["ledger.com"]),
        Platform(name: "Trezor", category: "crypto", domains: ["trezor.io"], logo: "trezor"),
        // other
        Platform(name: "Slack", category: "other", domains: ["slack.com"], logo: "slack"),
        Platform(name: "GitHub", category: "other", domains: ["github.com"], logo: "github"),
        Platform(name: "ZoroCloud", category: "other", domains: ["zorocloud.com"], aliases: ["zoro"]),
        Platform(name: "Spotify", category: "other", domains: ["spotify.com"], logo: "spotify"),
        Platform(name: "Apple", category: "other", domains: ["apple.com", "icloud.com"], aliases: ["appleid", "appleaccount", "苹果", "苹果账号", "appstore", "苹果商店", "icloud"], logo: "apple"),
        Platform(name: "Google", category: "other", domains: ["accounts.google.com", "google.com"], aliases: ["googleaccount", "google账号", "谷歌", "谷歌账号"], logo: "google"),
    ]

    /// Lowercase and drop whitespace, so "B 站" == "b站".
    public static func norm(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace }
    }

    private static let providersByDomain: [String: Provider] = {
        var map: [String: Provider] = [:]
        let entries: [([String], Provider)] = [
            (["gmail.com", "googlemail.com"], Provider(name: "Gmail", initial: "G", css: "pv-gmail", logo: "gmail")),
            (["outlook.com", "hotmail.com", "live.com", "msn.com"], Provider(name: "Outlook", initial: "O", css: "pv-outlook", logo: "microsoft")),
            (["proton.me", "protonmail.com", "pm.me"], Provider(name: "Proton", initial: "P", css: "pv-proton", logo: "proton")),
            (["icloud.com", "me.com", "mac.com"], Provider(name: "iCloud", initial: "i", css: "pv-icloud", logo: "apple")),
            (["qq.com", "foxmail.com"], Provider(name: "QQ", initial: "Q", css: "pv-qq", logo: "qq")),
            (["163.com", "126.com", "yeah.net"], Provider(name: "网易", initial: "网", css: "pv-netease")),
            (["yahoo.com"], Provider(name: "Yahoo", initial: "Y", css: "pv-yahoo")),
        ]
        for (domains, provider) in entries {
            for d in domains { map[d] = provider }
        }
        return map
    }()

    private static let byName: [String: Platform] = {
        var map: [String: Platform] = [:]
        for p in platforms {
            map[norm(p.name)] = p
            for a in p.aliases { map[norm(a)] = p }
        }
        return map
    }()

    private static let byDomain: [String: Platform] = {
        var map: [String: Platform] = [:]
        for p in platforms {
            for d in p.domains { map[d] = p }
        }
        return map
    }()

    public static func colorIndex(_ text: String) -> Int {
        Int(CRC32.hash(text.lowercased()) % UInt32(avatarPaletteSize))
    }

    public static func provider(for address: String) -> Provider {
        let domain = address.split(separator: "@").last.map(String.init)?.lowercased() ?? ""
        if let known = providersByDomain[domain] {
            return known
        }
        let initial = domain.first.map { String($0).uppercased() } ?? "?"
        return Provider(name: domain, initial: initial, css: "av-\(colorIndex(domain))")
    }

    public static func groupByProvider<E>(_ emails: [E], address: (E) -> String) -> [(Provider, [E])] {
        var groups: [String: (Provider, [E])] = [:]
        for email in emails {
            let pv = provider(for: address(email))
            var entry = groups[pv.name] ?? (pv, [])
            entry.1.append(email)
            groups[pv.name] = entry
        }
        return groups.values.sorted { a, b in
            if a.1.count != b.1.count { return a.1.count > b.1.count }
            return a.0.name.lowercased() < b.0.name.lowercased()
        }
    }

    public static func splitAddress(_ address: String) -> (local: String, domain: String) {
        if let at = address.lastIndex(of: "@") {
            let local = String(address[..<at])
            let domain = String(address[at...])
            return (local, domain)
        }
        return (address, "")
    }

    /// Logo key: exact name/alias first, then URL domain from most specific parent.
    public static func platformLogo(platform: String, url: String = "") -> String? {
        if let known = byName[norm(platform)] {
            return known.logo
        }
        var host = URL(string: url)?.host?.lowercased() ?? ""
        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        let parts = host.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return nil }
        for i in 0..<(parts.count - 1) {
            let candidate = parts[i...].joined(separator: ".")
            if let known = byDomain[candidate] {
                return known.logo
            }
        }
        return nil
    }

    public struct CatalogEntry: Equatable, Sendable {
        public var name: String
        public var category: String
        public var url: String
        public var keys: [String]
        public var logo: String?
        public var mine: Bool

        public init(name: String, category: String, url: String, keys: [String], logo: String?, mine: Bool = false) {
            self.name = name
            self.category = category
            self.url = url
            self.keys = keys
            self.logo = logo
            self.mine = mine
        }
    }

    /// Autocomplete entries: built-in platforms plus the user's own.
    public static func catalog(userPlatforms: [(name: String, category: String, url: String)]) -> [CatalogEntry] {
        var entries: [CatalogEntry] = platforms.map { p in
            var keySet = Set([norm(p.name)])
            for a in p.aliases { keySet.insert(norm(a)) }
            return CatalogEntry(
                name: p.name,
                category: p.category,
                url: p.defaultURL,
                keys: keySet.sorted(),
                logo: p.logo
            )
        }
        for (name, category, url) in userPlatforms {
            if byName[norm(name)] != nil { continue }
            entries.append(CatalogEntry(
                name: name,
                category: category,
                url: url,
                keys: [norm(name)],
                logo: platformLogo(platform: name, url: url),
                mine: true
            ))
        }
        return entries
    }

    // MARK: - Autocomplete scoring

    public static let suggestLimit = 8

    /// 0: name prefix, 1: alias prefix, 2: substring; nil: no match.
    public static func score(entry: CatalogEntry, query: String) -> Int? {
        let q = norm(query)
        guard !q.isEmpty else { return nil }
        let name = norm(entry.name)
        if name.hasPrefix(q) { return 0 }
        if entry.keys.contains(where: { $0.hasPrefix(q) }) { return 1 }
        if entry.keys.contains(where: { $0.contains(q) }) { return 2 }
        return nil
    }

    public static func matches(query: String, in catalog: [CatalogEntry]) -> [CatalogEntry] {
        let q = norm(query)
        guard !q.isEmpty else { return [] }
        return catalog
            .compactMap { entry -> (CatalogEntry, Int)? in
                guard let s = score(entry: entry, query: q) else { return nil }
                // Single character only matches name prefixes.
                if q.count == 1 && s != 0 { return nil }
                return (entry, s)
            }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 < b.1 }
                if a.0.mine != b.0.mine { return a.0.mine && !b.0.mine }
                return a.0.name.localizedStandardCompare(b.0.name) == .orderedAscending
            }
            .prefix(suggestLimit)
            .map(\.0)
    }
}
