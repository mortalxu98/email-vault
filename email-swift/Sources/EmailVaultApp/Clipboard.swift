#if os(macOS)
import AppKit
import Foundation

/// Clipboard helpers: mark secrets as concealed and clear after 30s if unchanged.
enum Clipboard {
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static var clearWorkItem: DispatchWorkItem?

    static func copy(_ text: String, conceal: Bool) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        if conceal {
            pb.setData(Data(), forType: concealedType)
        }
        clearWorkItem?.cancel()
        guard conceal else { return }
        let changeCount = pb.changeCount
        let item = DispatchWorkItem {
            let pb = NSPasteboard.general
            guard pb.changeCount == changeCount else { return }
            if pb.string(forType: .string) == text {
                pb.clearContents()
            }
        }
        clearWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: item)
    }
}
#endif
