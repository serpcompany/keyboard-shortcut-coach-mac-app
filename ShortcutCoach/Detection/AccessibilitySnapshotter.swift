import AppKit
import ApplicationServices
import Foundation

struct AXFrameSnapshot: Codable, Equatable, Sendable {
    let x: Double, y: Double, width: Double, height: Double
    func contains(_ point: CGPoint, tolerance: Double = 2) -> Bool {
        point.x >= x - tolerance && point.x <= x + width + tolerance &&
        point.y >= y - tolerance && point.y <= y + height + tolerance
    }
}

struct AXNodeSnapshot: Codable, Equatable, Sendable {
    let token: String
    let role: String?
    let subrole: String?
    let title: String?
    let elementDescription: String?
    let identifier: String?
    let value: String?
    let selected: Bool?
    let enabled: Bool?
    let actions: [String]
    let frame: AXFrameSnapshot?
    let menuShortcut: String?
}

struct ChromeTabState: Codable, Equatable, Sendable {
    let containerToken: String
    let tabs: [AXNodeSnapshot]
}

struct AccessibilitySnapshot: Codable, Equatable, Sendable {
    let pid: Int32
    let bundleIdentifier: String?
    let applicationName: String
    let hit: AXNodeSnapshot
    let ancestors: [AXNodeSnapshot]
    let tabs: ChromeTabState?
    var hitAndAncestors: [AXNodeSnapshot] { [hit] + ancestors }
}

final class AccessibilitySnapshotter {
    // AppKit's in-process accessibility implementation is main-thread-bound.
    // A global click can land on Shortcut Coach itself, so all AX hit-testing
    // must share the main queue rather than racing from detector worker queues.
    private let queue = DispatchQueue.main

    func snapshot(at point: CGPoint, completion: @escaping (AccessibilitySnapshot?) -> Void) {
        queue.async {
            let result = self.makeSnapshot(at: point)
            completion(result)
        }
    }

    private func makeSnapshot(at point: CGPoint) -> AccessibilitySnapshot? {
        var rawHit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &rawHit) == .success,
              let hit = rawHit else { return nil }
        var pid: pid_t = 0
        guard AXUIElementGetPid(hit, &pid) == .success else { return nil }
        let app = NSRunningApplication(processIdentifier: pid)
        let bundleIdentifier = app?.bundleIdentifier
        let applicationElement = AXUIElementCreateApplication(pid)
        var ancestors: [(AXUIElement, AXNodeSnapshot)] = []
        var cursor = hit
        for _ in 0..<8 {
            guard let parent: AXUIElement = attribute(kAXParentAttribute, from: cursor) else { break }
            let node = nodeSnapshot(parent)
            ancestors.append((parent, node))
            cursor = parent
            if node.role == kAXApplicationRole as String { break }
        }
        let chromeTabs = bundleIdentifier.map(ChromeActionAdapter.bundleIdentifiers.contains) == true
            ? tabState(hit: hit, ancestors: ancestors, application: applicationElement) : nil
        return AccessibilitySnapshot(pid: pid, bundleIdentifier: bundleIdentifier,
                                     applicationName: app?.localizedName ?? "Current app",
                                     hit: nodeSnapshot(hit), ancestors: ancestors.map(\.1),
                                     tabs: chromeTabs)
    }

    private func tabState(hit: AXUIElement, ancestors: [(AXUIElement, AXNodeSnapshot)], application: AXUIElement) -> ChromeTabState? {
        let candidates = [hit] + ancestors.map(\.0) + [application]
        for candidate in candidates {
            if let state = tabState(fromContainer: candidate) { return state }
        }
        for root in candidates.prefix(4) {
            var frontier = children(of: root)
            var visited = 0
            while !frontier.isEmpty && visited < 400 {
                let element = frontier.removeFirst()
                visited += 1
                if let state = tabState(fromContainer: element) { return state }
                if visited < 300 { frontier.append(contentsOf: children(of: element)) }
            }
        }
        return nil
    }

    private func tabState(fromContainer element: AXUIElement) -> ChromeTabState? {
        let tabNodes = children(of: element).map(nodeSnapshot).filter {
            $0.role == kAXRadioButtonRole as String || $0.role == "AXTab"
        }
        guard !tabNodes.isEmpty, tabNodes.contains(where: { $0.selected == true || $0.value == "1" }) else { return nil }
        return ChromeTabState(containerToken: token(for: element), tabs: tabNodes)
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        attribute(kAXChildrenAttribute, from: element) ?? []
    }

    private func nodeSnapshot(_ element: AXUIElement) -> AXNodeSnapshot {
        let position = pointAttribute(kAXPositionAttribute, from: element)
        let size = sizeAttribute(kAXSizeAttribute, from: element)
        let selected: Bool? = attribute(kAXSelectedAttribute, from: element)
        let rawValue = copyAttribute(kAXValueAttribute, from: element)
        let valueString: String?
        if let string = rawValue as? String { valueString = string }
        else if let number = rawValue as? NSNumber { valueString = number.stringValue }
        else { valueString = nil }
        var actionNames: CFArray?
        let actions = AXUIElementCopyActionNames(element, &actionNames) == .success ? (actionNames as? [String] ?? []) : []
        let command: String? = attribute(kAXMenuItemCmdCharAttribute, from: element)
        let modifiers: NSNumber? = attribute(kAXMenuItemCmdModifiersAttribute, from: element)
        return AXNodeSnapshot(
            token: token(for: element), role: attribute(kAXRoleAttribute, from: element),
            subrole: attribute(kAXSubroleAttribute, from: element), title: attribute(kAXTitleAttribute, from: element),
            elementDescription: attribute(kAXDescriptionAttribute, from: element), identifier: attribute(kAXIdentifierAttribute, from: element),
            value: valueString, selected: selected ?? ((rawValue as? NSNumber)?.boolValue),
            enabled: attribute(kAXEnabledAttribute, from: element), actions: actions.sorted(),
            frame: position.flatMap { origin in size.map { AXFrameSnapshot(x: origin.x, y: origin.y, width: $0.width, height: $0.height) } },
            menuShortcut: command.map { ShortcutFormatter.format(command: $0, modifiers: modifiers?.intValue ?? 0) }
        )
    }

    private func token(for element: AXUIElement) -> String { String(CFHash(element), radix: 16) }
    private func copyAttribute(_ name: String, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    private func attribute<T>(_ name: String, from element: AXUIElement) -> T? { copyAttribute(name, from: element) as? T }
    private func pointAttribute(_ name: String, from element: AXUIElement) -> CGPoint? {
        guard let raw = copyAttribute(name, from: element), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var result = CGPoint.zero
        return AXValueGetValue(raw as! AXValue, .cgPoint, &result) ? result : nil
    }
    private func sizeAttribute(_ name: String, from element: AXUIElement) -> CGSize? {
        guard let raw = copyAttribute(name, from: element), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var result = CGSize.zero
        return AXValueGetValue(raw as! AXValue, .cgSize, &result) ? result : nil
    }
}
