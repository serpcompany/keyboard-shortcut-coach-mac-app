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
    private var overlayPanel: NSPanel?
    private var toastPanel: NSPanel?
    private var toastDismissTask: Task<Void, Never>?
    private var presentationPanels: [PresentationMode: NSPanel] = [:]
    private var presentationTasks: [PresentationMode: Task<Void, Never>] = [:]
    private var screenObserver: NSObjectProtocol?

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.dismissPresentationPanels() }
        }
    }

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
                size: CGSize(width: 480, height: 560),
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

    @discardableResult
    func showPresentation(
        event: CoachingEvent,
        mode: PresentationMode,
        action: @escaping (CoachingAction) -> Void
    ) -> Bool {
        presentationTasks[mode]?.cancel()
        let pointer = appKitPoint(for: event)
        guard let screen = screen(containing: pointer) ?? NSScreen.main else { return false }

        switch mode {
        case .topCenterPresence:
            return showTopPanel(
                mode: mode,
                size: CGSize(width: 284, height: 44),
                screen: screen,
                view: AnyView(CoachingShelfView(event: event, style: .compact, action: action)),
                duration: 4
            )
        case .compactExpandedShelf:
            guard showTopPanel(
                mode: mode,
                size: CGSize(width: 284, height: 44),
                screen: screen,
                view: AnyView(CoachingShelfView(event: event, style: .compact, action: action)),
                duration: nil
            ) else { return false }
            presentationTasks[mode] = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled, let self else { return }
                _ = self.showTopPanel(
                    mode: mode,
                    size: CGSize(width: 486, height: 104),
                    screen: screen,
                    view: AnyView(CoachingShelfView(event: event, style: .expanded, action: action)),
                    duration: 4
                )
            }
            return true
        case .cursorHalo:
            let size = CGSize(width: 82, height: 82)
            let frame = CGRect(x: pointer.x - 41, y: pointer.y - 41, width: size.width, height: size.height)
            guard screen.frame.intersects(frame) else { return false }
            let panel = panel(for: mode, interactive: false, shadow: false)
            panel.contentView = NSHostingView(rootView: CursorOpportunityHaloView(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion))
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
            scheduleDismiss(mode, after: 1.35)
            return true
        case .statusFeedback:
            guard showTopPanel(
                mode: mode,
                size: CGSize(width: 348, height: 64),
                screen: screen,
                view: AnyView(CoachingStatusView(event: event, phase: .evaluating)),
                duration: nil
            ) else { return false }
            presentationTasks[mode] = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.1))
                guard !Task.isCancelled, let self else { return }
                _ = self.showTopPanel(
                    mode: mode,
                    size: CGSize(width: 348, height: 64),
                    screen: screen,
                    view: AnyView(CoachingStatusView(event: event, phase: .success)),
                    duration: 2.4
                )
            }
            return true
        case .pointerCard:
            let size = CGSize(width: 370, height: 112)
            guard let frame = PresentationPlacement.pointerCard(anchor: pointer, size: size, visibleFrame: screen.visibleFrame) else { return false }
            let panel = panel(for: mode, interactive: true)
            panel.contentView = NSHostingView(rootView: PointerCoachingCardView(event: event, action: action))
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
            scheduleDismiss(mode, after: 5)
            return true
        case .decisionBanner:
            return showTopPanel(
                mode: mode,
                size: CGSize(width: min(760, screen.visibleFrame.width - 32), height: 150),
                screen: screen,
                view: AnyView(CoachingDecisionBannerView(event: event, action: action)),
                duration: 8,
                interactive: true
            )
        }
    }

    func dismissPresentationPanels() {
        presentationTasks.values.forEach { $0.cancel() }
        presentationTasks.removeAll()
        presentationPanels.values.forEach { $0.orderOut(nil) }
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

    private func panel(for mode: PresentationMode, interactive: Bool, shadow: Bool = true) -> NSPanel {
        if let existing = presentationPanels[mode] {
            existing.ignoresMouseEvents = !interactive
            return existing
        }
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = shadow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = !interactive
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        presentationPanels[mode] = panel
        return panel
    }

    private func showTopPanel(
        mode: PresentationMode,
        size: CGSize,
        screen: NSScreen,
        view: AnyView,
        duration: TimeInterval?,
        interactive: Bool = false
    ) -> Bool {
        guard let frame = PresentationPlacement.topCenter(size: size, visibleFrame: screen.visibleFrame, topInset: 10) else { return false }
        let panel = panel(for: mode, interactive: interactive)
        panel.contentView = NSHostingView(rootView: view)
        panel.setFrame(frame, display: true, animate: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        panel.orderFrontRegardless()
        if let duration { scheduleDismiss(mode, after: duration) }
        return true
    }

    private func scheduleDismiss(_ mode: PresentationMode, after duration: TimeInterval) {
        presentationTasks[mode]?.cancel()
        presentationTasks[mode] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.presentationPanels[mode]?.orderOut(nil)
        }
    }

    private func appKitPoint(for event: CoachingEvent) -> CGPoint {
        guard event.pointerCoordinateSpace == .quartz,
              let mainFrame = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame ?? NSScreen.main?.frame
        else { return event.pointerLocation }
        return CGPoint(x: event.pointerLocation.x, y: mainFrame.maxY - event.pointerLocation.y)
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func present(_ window: NSWindow) {
        NSApplication.shared.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}
