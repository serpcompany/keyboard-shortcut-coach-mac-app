import AppKit
import SwiftUI

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class WindowPresenter {
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var analyticsWindow: NSWindow?
    private var coachingHistoryWindow: NSWindow?
    private var overlayPanel: NSPanel?
    private var toastPanel: NSPanel?
    private var toastDismissTask: Task<Void, Never>?

    func showOnboarding(model: AppModel) {
        let window = onboardingWindow ?? makeWindow(
            title: "Welcome to Keylume Clone",
            size: CGSize(width: 520, height: 420),
            content: OnboardingView(model: model)
        )
        onboardingWindow = window
        present(window)
    }

    func closeOnboarding() {
        onboardingWindow?.close()
    }

    func showSettings(model: AppModel) {
        if settingsWindow == nil {
            let window = makeWindow(
                title: "Keylume Clone Settings",
                size: CGSize(width: 520, height: 500),
                content: SettingsView(model: model)
            )
            window.styleMask.insert(.fullSizeContentView)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            settingsWindow = window
        }
        guard let window = settingsWindow else { return }
        present(window)
    }

    func showAnalytics(model: AppModel) {
        model.refreshAnalytics()
        let window = analyticsWindow ?? makeWindow(
            title: "Shortcut Analytics",
            size: CGSize(width: 500, height: 600),
            content: AnalyticsDashboardView(model: model)
        )
        analyticsWindow = window
        present(window)
    }

    func showCoachingHistory(model: AppModel) {
        let window = coachingHistoryWindow ?? makeWindow(
            title: "Coaching History",
            size: CGSize(width: 820, height: 580),
            content: CoachingHistoryView(model: model)
        )
        window.styleMask.insert(.resizable)
        window.minSize = CGSize(width: 680, height: 460)
        coachingHistoryWindow = window
        present(window)
    }

    func showOverlay(model: AppModel) {
        if overlayPanel == nil {
            let panel = KeyablePanel(
                contentRect: NSRect(origin: .zero, size: CGSize(width: 660, height: 532)),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            overlayPanel = panel
        }
        guard let panel = overlayPanel else { return }
        panel.contentView = NSHostingView(rootView: ShortcutOverlayView(model: model))
        panel.setContentSize(CGSize(width: 660, height: 532))
        panel.center()
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
    }

    func hideOverlay() {
        overlayPanel?.orderOut(nil)
    }

    func showToast(shortcut: AppShortcut, dismissPermanently: @escaping () -> Void) {
        toastDismissTask?.cancel()
        if toastPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: CGSize(width: 380, height: 62)),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .statusBar
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            panel.hidesOnDeactivate = false
            toastPanel = panel
        }
        guard let panel = toastPanel, let screen = NSScreen.main else { return }
        panel.contentView = NSHostingView(rootView: CoachingToastView(
            shortcut: shortcut,
            onClose: { [weak panel] in panel?.orderOut(nil) },
            onDismissPermanently: dismissPermanently
        ))
        panel.setContentSize(CGSize(width: 380, height: 62))
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.maxX - 400, y: visible.maxY - 82))
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            panel.orderOut(nil)
        }
    }

    func showUpdateResult(status: UpdateStatus?, error: String?) {
        let alert = NSAlert()
        if let error {
            alert.alertStyle = .warning
            alert.messageText = "Unable to Check for Updates"
            alert.informativeText = error
        } else if let status, status.updateAvailable {
            alert.messageText = "An Update Is Available"
            alert.informativeText = "Keylume Clone \(status.latestVersion) is available."
            if let url = status.downloadURL {
                alert.addButton(withTitle: "Download")
                alert.addButton(withTitle: "Later")
                if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(url) }
                return
            }
        } else {
            alert.messageText = "You're Up to Date"
            alert.informativeText = "Keylume Clone \(status?.currentVersion ?? AppModel.version) is the latest configured version."
        }
        alert.runModal()
    }

    private func makeWindow<Content: View>(title: String, size: CGSize, content: Content) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = NSHostingView(rootView: content)
        window.setContentSize(size)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func present(_ window: NSWindow) {
        NSApplication.shared.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}
