#if os(macOS)
import SwiftUI
import AppKit
import Foundation
import EmailVaultCore

/// Strip https:// / http:// and trailing slashes for compact display.
func displayURL(_ raw: String) -> String {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if let r = s.range(of: "://") {
        s = String(s[r.upperBound...])
    }
    while s.hasSuffix("/") { s.removeLast() }
    return s
}

func sanitizedURL(_ raw: String) -> URL? {
    let s = URLNormalizer.normalize(raw)
    return s.isEmpty ? nil : URL(string: s)
}

func categoryColor(_ cat: String) -> Color {
    switch cat {
    case "ai": return .purple
    case "social": return .blue
    case "crypto": return .orange
    default: return .gray
    }
}

/// Secure field with an eye button to show/hide the text; keeps focus when toggling.
struct RevealableSecureField: View {
    let placeholder: String
    @Binding var text: String
    @State private var visible = false
    @FocusState private var focused: Bool

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if visible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .focused($focused)
            Button {
                visible.toggle()
                focused = true
            } label: {
                Image(systemName: visible ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .help(visible ? tr("隐藏") : tr("显示"))
        }
    }
}

struct ToastOverlay: View {
    let message: String?

    var body: some View {
        VStack {
            Spacer()
            if let message {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 8, y: 2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 28)
            }
        }
        .animation(.easeOut(duration: 0.2), value: message)
        .allowsHitTesting(false)
    }
}

#endif
