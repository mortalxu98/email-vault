#if os(macOS)
import SwiftUI

/// Shared surfaces for the main window. Follows the system appearance; does not force a scheme.
enum VaultChrome {
    static let radius: CGFloat = 16

    static func canvas(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.059, green: 0.078, blue: 0.098)
            : Color(red: 0.957, green: 0.945, blue: 0.918)
    }

    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : .white
    }

    /// Inset control on top of a card (search field).
    static func inset(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : canvas(.light)
    }

    static func shadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .clear : Color.black.opacity(0.06)
    }
}

struct VaultPageBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            VaultChrome.canvas(scheme)
            RadialGradient(
                colors: [
                    Color.accentColor.opacity(scheme == .dark ? 0.28 : 0.16),
                    .clear,
                ],
                center: .top,
                startRadius: 0,
                endRadius: 460
            )
        }
    }
}

private struct VaultCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(VaultChrome.card(scheme))
            .clipShape(RoundedRectangle(cornerRadius: VaultChrome.radius, style: .continuous))
            .shadow(color: VaultChrome.shadow(scheme), radius: 16, y: 8)
    }
}

extension View {
    func vaultCard() -> some View {
        modifier(VaultCardModifier())
    }

    func vaultPage() -> some View {
        background { VaultPageBackground().ignoresSafeArea() }
    }
}
#endif
