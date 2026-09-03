import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum StandardWindowControlKind: Equatable, Sendable {
    case close
    case minimize
    case fullScreen
}

struct WindowControlState: Equatable, Sendable {
    let present: Bool
    let minimized: Bool?
    let frame: CGRect?
}

enum WindowControlPolicy {
    static func event(
        kind: StandardWindowControlKind,
        applicationName: String,
        shortcut: String,
        pre: WindowControlState,
        post: WindowControlState,
        pointer: CGPoint
    ) -> CoachingEvent? {
        let completed: Bool
        let title: String
        switch kind {
        case .minimize:
            completed = pre.minimized == false && post.present && post.minimized == true
            title = "Minimize Window"
        case .close:
            completed = pre.present && !post.present
            title = "Close Window"
        case .fullScreen:
            if let before = pre.frame, let after = post.frame {
                completed = post.present && (abs(before.width - after.width) > 20 || abs(before.height - after.height) > 20)
            } else {
                completed = false
            }
            title = "Enter Full Screen"
        }
        guard completed else { return nil }
        return CoachingEvent(
            applicationName: applicationName,
            actionTitle: title,
            shortcut: shortcut,
            pointerX: pointer.x,
            pointerY: pointer.y
        )
    }
}

final class StandardWindowControlMonitor {
    private final class Session {
        let kind: StandardWindowControlKind
        let applicationName: String
        let bundleIdentifier: String
        let application: AXUIElement
        let window: AXUIElement
        let buttonFrame: CGRect
        let preState: WindowControlState
        let shortcut: String
        let pointerDown: CGPoint
        let downTimestamp: TimeInterval
        var maximumTravel: CGFloat = 0

        init(kind: StandardWindowControlKind, applicationName: String, bundleIdentifier: String,
             application: AXUIElement, window: AXUIElement, buttonFrame: CGRect,
             preState: WindowControlState, shortcut: String, pointerDown: CGPoint,
             downTimestamp: TimeInterval) {
            self.kind = kind
            self.applicationName = applicationName
            self.bundleIdentifier = bundleIdentifier
            self.application = application
            self.window = window
            self.buttonFrame = buttonFrame
            self.preState = preState
            self.shortcut = shortcut
            self.pointerDown = pointerDown
            self.downTimestamp = downTimestamp
        }
    }

    var onEvent: ((CoachingEvent) -> Void)?
    // Keep AX access serialized with the snapshotter. AppKit can service a
    // hit-test against our own SwiftUI hierarchy in-process.
    private let queue = DispatchQueue.main
    private var session: Session?

    func receive(_ sample: PointerSample) {
        queue.async { [weak self] in self?.handle(sample) }
    }

    func cancel() {
        queue.async { [weak self] in self?.session = nil }
    }

    private func handle(_ sample: PointerSample) {
        switch sample.phase {
        case .down:
            begin(sample)
        case .dragged:
            guard let session else { return }
            session.maximumTravel = max(
                session.maximumTravel,
                hypot(sample.location.x - session.pointerDown.x, sample.location.y - session.pointerDown.y)
            )
        case .up:
            finishGesture(sample)
        case .cancelled:
            session = nil
        }
    }

    private func begin(_ sample: PointerSample) {
        session = nil
        guard relevantModifiers(in: sample.modifiers).isEmpty,
              let hit = element(at: sample.location),
              let kind = controlKind(hit),
              let window = containingWindow(for: hit),
              let frame = frame(of: hit) else { return }

        var pid: pid_t = 0
        guard AXUIElementGetPid(hit, &pid) == .success,
              let running = NSRunningApplication(processIdentifier: pid),
              let bundle = running.bundleIdentifier,
              bundle != "co.serp.shortcutcoach",
              NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }

        let application = AXUIElementCreateApplication(pid)
        let pre = state(of: window, in: application)
        guard pre.present else { return }
        let shortcut = liveShortcut(for: kind, in: application)
            ?? fallbackShortcut(for: kind, bundleIdentifier: bundle)
        session = Session(
            kind: kind,
            applicationName: running.localizedName ?? "Current app",
            bundleIdentifier: bundle,
            application: application,
            window: window,
            buttonFrame: frame,
            preState: pre,
            shortcut: shortcut,
            pointerDown: sample.location,
            downTimestamp: sample.timestamp
        )
    }

    private func finishGesture(_ sample: PointerSample) {
        guard let current = session else { return }
        guard relevantModifiers(in: sample.modifiers).isEmpty,
              sample.timestamp - current.downTimestamp <= 1.5,
              current.maximumTravel <= 4,
              current.buttonFrame.insetBy(dx: -2, dy: -2).contains(sample.location) else {
            session = nil
            return
        }

        queue.asyncAfter(deadline: .now() + 0.35) { [weak self, weak current] in
            guard let self, let current, self.session === current else { return }
            if let event = WindowControlPolicy.event(
                kind: current.kind,
                applicationName: current.applicationName,
                shortcut: current.shortcut,
                pre: current.preState,
                post: self.state(of: current.window, in: current.application),
                pointer: current.pointerDown
            ) {
                self.session = nil
                DispatchQueue.main.async { [weak self] in self?.onEvent?(event) }
                return
            }
            self.queue.asyncAfter(deadline: .now() + 0.65) { [weak self, weak current] in
                guard let self, let current, self.session === current else { return }
                let event = WindowControlPolicy.event(
                    kind: current.kind,
                    applicationName: current.applicationName,
                    shortcut: current.shortcut,
                    pre: current.preState,
                    post: self.state(of: current.window, in: current.application),
                    pointer: current.pointerDown
                )
                self.session = nil
                if let event { DispatchQueue.main.async { [weak self] in self?.onEvent?(event) } }
            }
        }
    }

    private func relevantModifiers(in flags: CGEventFlags) -> CGEventFlags {
        flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
    }

    private func controlKind(_ element: AXUIElement) -> StandardWindowControlKind? {
        guard (attribute(kAXRoleAttribute, from: element) as String?) == kAXButtonRole as String,
              actions(of: element).contains(kAXPressAction as String),
              let subrole: String = attribute(kAXSubroleAttribute, from: element) else { return nil }
        switch subrole {
        case "AXCloseButton": return .close
        case "AXMinimizeButton": return .minimize
        case "AXFullScreenButton", "AXZoomButton": return .fullScreen
        default: return nil
        }
    }

    private func state(of window: AXUIElement, in application: AXUIElement) -> WindowControlState {
        let present = applicationWindows(application).contains { CFEqual($0, window) }
        return WindowControlState(
            present: present,
            minimized: attribute(kAXMinimizedAttribute, from: window),
            frame: frame(of: window)
        )
    }

    private func liveShortcut(for kind: StandardWindowControlKind, in application: AXUIElement) -> String? {
        guard let menuBar: AXUIElement = attribute(kAXMenuBarAttribute, from: application) else { return nil }
        var frontier = [menuBar]
        var visited = 0
        var matches: [String] = []
        while !frontier.isEmpty && visited < 600 {
            let element = frontier.removeFirst()
            visited += 1
            if (attribute(kAXRoleAttribute, from: element) as String?) == kAXMenuItemRole as String,
               (attribute(kAXEnabledAttribute, from: element) as Bool?) != false,
               let title: String = attribute(kAXTitleAttribute, from: element),
               menuTitle(title, matches: kind),
               let command: String = attribute(kAXMenuItemCmdCharAttribute, from: element) {
                let modifiers: NSNumber? = attribute(kAXMenuItemCmdModifiersAttribute, from: element)
                let raw = modifiers?.intValue ?? 0
                if raw & ~0x0F == 0 { matches.append(ShortcutFormatter.format(command: command, modifiers: raw)) }
            }
            let children: [AXUIElement] = attribute(kAXChildrenAttribute, from: element) ?? []
            frontier.append(contentsOf: children)
        }
        return Set(matches).count == 1 ? matches.first : nil
    }

    private func menuTitle(_ title: String, matches kind: StandardWindowControlKind) -> Bool {
        let normalized = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch kind {
        case .minimize: return normalized == "minimize" || normalized == "miniaturize"
        case .close: return normalized == "close window" || normalized == "close"
        case .fullScreen: return normalized == "enter full screen" || normalized == "exit full screen"
        }
    }

    private func fallbackShortcut(for kind: StandardWindowControlKind, bundleIdentifier: String) -> String {
        switch kind {
        case .minimize: return "⌘M"
        case .close: return bundleIdentifier == "com.google.Chrome" ? "⇧⌘W" : "⌘W"
        case .fullScreen: return "⌃⌘F"
        }
    }

    private func element(at point: CGPoint) -> AXUIElement? {
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &element) == .success else { return nil }
        return element
    }

    private func containingWindow(for element: AXUIElement) -> AXUIElement? {
        if let window: AXUIElement = attribute(kAXWindowAttribute, from: element) { return window }
        var cursor = element
        for _ in 0..<12 {
            if (attribute(kAXRoleAttribute, from: cursor) as String?) == kAXWindowRole as String { return cursor }
            guard let parent: AXUIElement = attribute(kAXParentAttribute, from: cursor) else { return nil }
            cursor = parent
        }
        return nil
    }

    private func applicationWindows(_ application: AXUIElement) -> [AXUIElement] {
        attribute(kAXWindowsAttribute, from: application) ?? []
    }

    private func actions(of element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return names as? [String] ?? []
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let origin = pointAttribute(kAXPositionAttribute, from: element),
              let size = sizeAttribute(kAXSizeAttribute, from: element) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private func copyAttribute(_ name: String, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private func attribute<T>(_ name: String, from element: AXUIElement) -> T? {
        copyAttribute(name, from: element) as? T
    }

    private func pointAttribute(_ name: String, from element: AXUIElement) -> CGPoint? {
        guard let raw = copyAttribute(name, from: element), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var value = CGPoint.zero
        return AXValueGetValue(raw as! AXValue, .cgPoint, &value) ? value : nil
    }

    private func sizeAttribute(_ name: String, from element: AXUIElement) -> CGSize? {
        guard let raw = copyAttribute(name, from: element), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var value = CGSize.zero
        return AXValueGetValue(raw as! AXValue, .cgSize, &value) ? value : nil
    }
}
