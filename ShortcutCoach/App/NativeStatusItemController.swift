import AppKit
import SwiftUI

@MainActor
final class NativeStatusItemController: NSObject {
    static let shared = NativeStatusItemController()

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    func install(model: AppModel) {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.isVisible = true
        if let button = item.button {
            button.image = nil
            button.title = "SC"
            button.font = .systemFont(ofSize: 10, weight: .bold)
            button.toolTip = "Shortcut Coach"
            button.setAccessibilityLabel("Shortcut Coach")
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 410, height: 500)
        popover.contentViewController = NSHostingController(
            rootView: MenuInboxView().environment(model)
        )
        statusItem = item
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
