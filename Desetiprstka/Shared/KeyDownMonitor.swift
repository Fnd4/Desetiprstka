import AppKit
import SwiftUI

/// Zachytává stisky kláves v okně aplikace.
///
/// Spolehlivější než focus v SwiftUI: funguje bez ohledu na to,
/// který prvek má zrovna fokus, a stisky neprojdou do jiných ovládacích prvků.
private struct KeyDownMonitor: ViewModifier {
    /// Vrací `true`, pokud byl stisk zpracován (a nemá jít dál).
    let handler: @MainActor (NSEvent) -> Bool
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    let consumed = MainActor.assumeIsolated { handler(event) }
                    return consumed ? nil : event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }
}

extension View {
    func onKeyDown(_ handler: @escaping @MainActor (NSEvent) -> Bool) -> some View {
        modifier(KeyDownMonitor(handler: handler))
    }
}
