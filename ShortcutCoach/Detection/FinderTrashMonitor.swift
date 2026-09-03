import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct FinderTrashObservation: Equatable, Sendable {
    let sourceIsFinderItem: Bool
    let targetIsDockTrash: Bool
    let meaningfulDrag: Bool
    let modifiersPresent: Bool
    let sourceDisappeared: Bool
}

enum FinderTrashPolicy {
    static func event(from observation: FinderTrashObservation) -> CoachingEvent? {
        guard observation.sourceIsFinderItem,
              observation.targetIsDockTrash,
              observation.meaningfulDrag,
              !observation.modifiersPresent,
              observation.sourceDisappeared else { return nil }
        return CoachingEvent(applicationName: "Finder", actionTitle: "Move to Trash", shortcut: "⌘⌫")
    }
}

final class FinderTrashMonitor {
    private final class Session {
        let source: AXUIElement
        let parent: AXUIElement?
        let down: CGPoint
        let modifiersPresent: Bool
        var maximumTravel: CGFloat = 0
        var sawTrash = false

        init(source: AXUIElement, parent: AXUIElement?, down: CGPoint, modifiersPresent: Bool) {
            self.source = source
            self.parent = parent
            self.down = down
            self.modifiersPresent = modifiersPresent
        }
    }

    var onEvent: ((CoachingEvent) -> Void)?
    private let queue = DispatchQueue(label: "co.serp.shortcutcoach.finder-trash", qos: .userInteractive)
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
            session.maximumTravel = max(session.maximumTravel, hypot(sample.location.x - session.down.x, sample.location.y - session.down.y))
            if isDockTrash(at: sample.location) { session.sawTrash = true }
        case .up:
            guard let current = session else { return }
            let targetIsTrash = current.sawTrash || isDockTrash(at: sample.location)
            let modified = current.modifiersPresent || hasModifiers(sample.modifiers)
            let meaningful = current.maximumTravel >= 8
            queue.asyncAfter(deadline: .now() + 0.45) { [weak self, weak current] in
                guard let self, let current, self.session === current else { return }
                let observation = FinderTrashObservation(
                    sourceIsFinderItem: true,
                    targetIsDockTrash: targetIsTrash,
                    meaningfulDrag: meaningful,
                    modifiersPresent: modified,
                    sourceDisappeared: self.sourceDisappeared(current)
                )
                self.session = nil
                if let event = FinderTrashPolicy.event(from: observation) {
                    DispatchQueue.main.async { [weak self] in self?.onEvent?(event) }
                }
            }
        case .cancelled:
            session = nil
        }
    }

    private func begin(_ sample: PointerSample) {
        session = nil
        guard !hasModifiers(sample.modifiers),
              let hit = element(at: sample.location),
              applicationBundle(for: hit) == "com.apple.finder",
              isFinderItem(hit),
              !isVolume(hit) else { return }
        let parent: AXUIElement? = attribute(kAXParentAttribute, from: hit)
        session = Session(source: hit, parent: parent, down: sample.location, modifiersPresent: false)
    }

    private func isFinderItem(_ element: AXUIElement) -> Bool {
        guard let role: String = attribute(kAXRoleAttribute, from: element) else { return false }
        return [kAXImageRole as String, kAXRowRole as String, kAXCellRole as String].contains(role)
    }

    private func isVolume(_ element: AXUIElement) -> Bool {
        guard let url = elementURL(element),
              let values = try? url.resourceValues(forKeys: [.isVolumeKey]) else { return false }
        return values.isVolume == true
    }

    private func isDockTrash(at point: CGPoint) -> Bool {
        guard let hit = element(at: point), applicationBundle(for: hit) == "com.apple.dock" else { return false }
        var cursor = hit
        for _ in 0..<8 {
            if (attribute(kAXSubroleAttribute, from: cursor) as String?) == kAXTrashDockItemSubrole as String { return true }
            guard let parent: AXUIElement = attribute(kAXParentAttribute, from: cursor) else { break }
            cursor = parent
        }
        return false
    }

    private func sourceDisappeared(_ session: Session) -> Bool {
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(session.source, kAXRoleAttribute as CFString, &role) != .success { return true }
        guard let parent = session.parent else { return false }
        let children: [AXUIElement] = attribute(kAXChildrenAttribute, from: parent) ?? []
        return !children.contains { CFEqual($0, session.source) }
    }

    private func hasModifiers(_ flags: CGEventFlags) -> Bool {
        !flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty
    }

    private func element(at point: CGPoint) -> AXUIElement? {
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &element) == .success else { return nil }
        return element
    }

    private func applicationBundle(for element: AXUIElement) -> String? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    private func elementURL(_ element: AXUIElement) -> URL? {
        if let url: URL = attribute(kAXURLAttribute, from: element) { return url }
        if let value: String = attribute(kAXURLAttribute, from: element) { return URL(string: value) }
        return nil
    }

    private func copyAttribute(_ name: String, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private func attribute<T>(_ name: String, from element: AXUIElement) -> T? {
        copyAttribute(name, from: element) as? T
    }
}
