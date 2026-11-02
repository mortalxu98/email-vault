#if os(macOS)
import AppKit
import Foundation

/// Clipboard helpers: mark secrets as concealed and clear after 30s if unchanged.
enum Clipboard {
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static var clearWorkItem: DispatchWorkItem?
    /// Pasteboard change count right after the last concealed copy.
    private static var concealedChangeCount: Int?

    static func copy(_ text: String, conceal: Bool) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        if conceal {
            pb.setData(Data(), forType: concealedType)
        }
        clearWorkItem?.cancel()
        concealedChangeCount = nil
        guard conceal else { return }
        let changeCount = pb.changeCount
        concealedChangeCount = changeCount
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

    /// Clear the pasteboard now if it still holds our last concealed copy.
    static func clearConcealed() {
        clearWorkItem?.cancel()
        clearWorkItem = nil
        defer { concealedChangeCount = nil }
        let pb = NSPasteboard.general
        guard let count = concealedChangeCount, pb.changeCount == count else { return }
        pb.clearContents()
    }
}
#endif
