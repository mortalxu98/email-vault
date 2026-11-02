#if os(macOS)
import AppKit
import SwiftUI

/// Resets the idle-lock timer on any local mouse or keyboard event.
struct IdleActivityMonitor: ViewModifier {
    @EnvironmentObject var model: AppModel

    func body(content: Content) -> some View {
        content
            .background(IdleMonitorInstaller(onActivity: { model.touch() }))
    }
}

private struct IdleMonitorInstaller: NSViewRepresentable {
    let onActivity: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install(onActivity)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var monitors: [Any] = []

        func install(_ onActivity: @escaping () -> Void) {
            teardown()
            let mask: NSEvent.EventTypeMask = [
                .keyDown, .keyUp,
                .leftMouseDown, .rightMouseDown, .otherMouseDown,
                .mouseMoved, .leftMouseDragged, .rightMouseDragged,
                .scrollWheel, .flagsChanged,
            ]
            if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
                onActivity()
                return event
            }) {
                monitors.append(local)
            }
        }

        func teardown() {
            for m in monitors {
                NSEvent.removeMonitor(m)
            }
            monitors.removeAll()
        }
    }
}

extension View {
    func idleActivityTracking() -> some View {
        modifier(IdleActivityMonitor())
    }
}
#endif
