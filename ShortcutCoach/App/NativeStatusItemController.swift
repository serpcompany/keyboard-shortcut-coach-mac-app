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
            let image = NSImage(named: ProductIdentity.statusItemImageName)
            image?.isTemplate = true
            image?.size = NSSize(width: 17, height: 17)
            button.image = image
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = ProductIdentity.productName
            button.setAccessibilityLabel(ProductIdentity.accessibilityName)
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
