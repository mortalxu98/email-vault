#if os(macOS)
import SwiftUI
import AppKit
import EmailVaultCore

struct AvatarView: View {
    let text: String
    var logo: String?
    var size: CGFloat = 32
    var wide: Bool = false

    private static let palette: [Color] = [
        .red, .orange, .yellow, .green, .mint, .cyan, .blue, .purple,
    ]

    /// Marks rendered as template (black path) so they adapt in dark mode.
    private static let templateLogos: Set<String> = [
        "apple", "x", "github", "threads", "medium", "notion", "ollama",
        "elevenlabs", "cursor", "poe", "suno", "replicate", "okx", "githubcopilot",
    ]

    var body: some View {
        ZStack {
            if let logo, let image = BrandIcon.image(named: logo) {
                image
                    .resizable()
                    .renderingMode(Self.templateLogos.contains(logo) ? .template : .original)
                    .foregroundStyle(.primary)
                    .aspectRatio(contentMode: wide ? .fill : .fit)
                    .padding(wide ? 2 : size * 0.18)
            } else {
                Text(initial)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .background(
            logo == nil
                ? Self.palette[PlatformCatalog.colorIndex(text) % 8]
                : Color(nsColor: .controlBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.22)
                .stroke(logo != nil ? Color.primary.opacity(0.08) : .clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    }

    private var initial: String {
        let t = text.trimmingCharacters(in: .whitespaces)
        if let at = t.firstIndex(of: "@") {
            let local = t[..<at]
            return local.first.map { String($0).uppercased() } ?? "?"
        }
        return t.first.map { String($0).uppercased() } ?? "?"
    }
}

/// Loads `brand-<logo>.pdf` from the app resource bundle (extracted from BrandIcons/_brand_icons.html).
enum BrandIcon {
    private static var cache: [String: Image] = [:]

    static func image(named logo: String) -> Image? {
        if let cached = cache[logo] { return cached }
        let name = "brand-\(logo)"
        if let nsImage = loadNSImage(name: name) {
            let image = Image(nsImage: nsImage)
            cache[logo] = image
            return image
        }
        return nil
    }

    private static func loadNSImage(name: String) -> NSImage? {
        // 1) App Contents/Resources/BrandIcons (scripts/build.sh).
        if let res = Bundle.main.resourceURL?
            .appendingPathComponent("BrandIcons", isDirectory: true)
            .appendingPathComponent("\(name).pdf"),
           let img = NSImage(contentsOf: res) {
            return img
        }
        // 2) SPM Bundle.module, only outside a .app (`swift run`): its accessor
        //    fatalErrors when the bundle is missing, which it is inside dist/*.app.
        if Bundle.main.bundleURL.pathExtension != "app" {
            let moduleCandidates: [URL?] = [
                Bundle.module.url(forResource: name, withExtension: "pdf", subdirectory: "BrandIcons"),
                Bundle.module.url(forResource: name, withExtension: "pdf"),
            ]
            for url in moduleCandidates.compactMap({ $0 }) {
                if let img = NSImage(contentsOf: url) { return img }
            }
        }
        // 3) Asset catalog / named image.
        return NSImage(named: name)
    }
}
#endif
