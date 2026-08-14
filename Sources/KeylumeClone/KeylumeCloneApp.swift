import AppKit
import Observation
import SwiftUI

@main
struct KeylumeCloneApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(model: AppModel.shared)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppModel.shared.start()
        statusItemController = StatusItemController(model: AppModel.shared)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { AppModel.shared.showCoachingHistory() }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AppModel.shared.syncDockBadge()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { AppModel.shared.handle(url: url) }
    }
}

@MainActor
private final class StatusItemController: NSObject {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 390, height: 365)
        popover.contentViewController = NSHostingController(rootView: CoachingInboxPopover(model: model))

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp])
            button.imagePosition = .imageLeading
        }
        observePresentationState()
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func observePresentationState() {
        withObservationTracking {
            updatePresentation()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observePresentationState()
            }
        }
    }

    private func updatePresentation() {
        guard let button = statusItem.button else { return }
        let unreadCount = model.unreadCoachingCount
        let hasHistoryError = model.coachingHistoryError != nil
        let needsAccessibility = model.accessibilityStatus != .granted
        let iconState: MenuBarIconState
        if hasHistoryError || needsAccessibility {
            iconState = .attention
        } else if unreadCount > 0, model.preferences.menuGreenHighlightEnabled {
            iconState = .unread
        } else {
            iconState = .neutral
        }

        button.image = MenuBarStatusIcon.make(state: iconState)
        let title = model.preferences.menuUnreadCountEnabled && unreadCount > 0 ? " \(unreadCount)" : ""
        let tintColor: NSColor? = switch iconState {
        case .neutral: nil
        case .unread: .systemGreen
        case .attention: .systemOrange
        }
        button.contentTintColor = tintColor
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.foregroundColor: tintColor ?? NSColor.labelColor]
        )
        button.toolTip = accessibilityLabel(
            unreadCount: unreadCount,
            hasHistoryError: hasHistoryError,
            needsAccessibility: needsAccessibility
        )
        button.setAccessibilityLabel(button.toolTip)
    }

    private func accessibilityLabel(
        unreadCount: Int,
        hasHistoryError: Bool,
        needsAccessibility: Bool
    ) -> String {
        if hasHistoryError { return "Keylume Clone, coaching history error" }
        if needsAccessibility {
            return "Keylume Clone, Accessibility permission required, \(unreadCount) unread coaching items"
        }
        return unreadCount == 0
            ? "Keylume Clone, no unread coaching"
            : "Keylume Clone, \(unreadCount) unread coaching items"
    }
}
