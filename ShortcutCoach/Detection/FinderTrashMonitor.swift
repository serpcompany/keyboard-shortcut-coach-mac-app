import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum FinderTrashItemEligibility: String, Equatable, Sendable {
    case supportedRegularItem
    case multipleSelection
    case volume
    case alias
    case lockedOrImmutable
    case externalOrNetwork
    case readOnly
    case unknown
}

enum FinderTrashPostcondition: String, Equatable, Sendable {
    case removedFromOriginalParent
    case stillPresent
    case inaccessible
}

struct FinderTrashObservation: Equatable, Sendable {
    let itemEligibility: FinderTrashItemEligibility
    let releasedOnDockTrash: Bool
    let meaningfulDrag: Bool
    let modifiersPresent: Bool
    let postcondition: FinderTrashPostcondition
}

enum FinderTrashPolicy {
    static func event(from observation: FinderTrashObservation) -> CoachingEvent? {
        guard observation.itemEligibility == .supportedRegularItem,
              observation.releasedOnDockTrash,
              observation.meaningfulDrag,
              !observation.modifiersPresent,
              observation.postcondition == .removedFromOriginalParent else { return nil }
        return CoachingEvent(applicationName: "Finder", actionTitle: "Move to Trash", shortcut: "⌘⌫")
    }
}

final class FinderTrashMonitor {
    private enum SelectionStatus { case exactlyOne, multiple, unknown }

    private final class Session {
        let source: AXUIElement
        let parent: AXUIElement?
        let itemEligibility: FinderTrashItemEligibility
        let down: CGPoint
        var modifiersPresent: Bool
        var maximumTravel: CGFloat = 0

        init(source: AXUIElement, parent: AXUIElement?, itemEligibility: FinderTrashItemEligibility,
             down: CGPoint, modifiersPresent: Bool) {
            self.source = source
            self.parent = parent
            self.itemEligibility = itemEligibility
            self.down = down
            self.modifiersPresent = modifiersPresent
        }
    }

    var onEvent: ((CoachingEvent) -> Void)?
    // Keep AX access serialized with every other detector path.
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
            session.modifiersPresent = session.modifiersPresent || hasModifiers(sample.modifiers)
            session.maximumTravel = max(session.maximumTravel, hypot(sample.location.x - session.down.x, sample.location.y - session.down.y))
        case .up:
            guard let current = session else { return }
            let targetIsTrash = isDockTrash(at: sample.location)
            let modified = current.modifiersPresent || hasModifiers(sample.modifiers)
            let meaningful = current.maximumTravel >= 8
            queue.asyncAfter(deadline: .now() + 0.45) { [weak self, weak current] in
                guard let self, let current, self.session === current else { return }
                let observation = FinderTrashObservation(
                    itemEligibility: current.itemEligibility,
                    releasedOnDockTrash: targetIsTrash,
                    meaningfulDrag: meaningful,
                    modifiersPresent: modified,
                    postcondition: self.postcondition(for: current)
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
              isFinderItem(hit) else { return }
        let parent: AXUIElement? = attribute(kAXParentAttribute, from: hit)
        let eligibility = itemEligibility(of: hit, parent: parent)
        guard eligibility == .supportedRegularItem else { return }
        session = Session(source: hit, parent: parent, itemEligibility: eligibility,
                          down: sample.location, modifiersPresent: false)
    }

    private func isFinderItem(_ element: AXUIElement) -> Bool {
        guard let role: String = attribute(kAXRoleAttribute, from: element) else { return false }
        return [kAXImageRole as String, kAXRowRole as String, kAXCellRole as String].contains(role)
    }

    private func itemEligibility(of element: AXUIElement, parent: AXUIElement?) -> FinderTrashItemEligibility {
        switch settledSelectionStatus(element, parent: parent) {
        case .multiple: return .multipleSelection
        case .unknown: return .unknown
        case .exactlyOne: break
        }
        guard let url = elementURL(element), url.isFileURL,
              let values = try? url.resourceValues(forKeys: [
                .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .isAliasFileKey,
                .isVolumeKey, .isWritableKey, .volumeIsLocalKey, .volumeIsReadOnlyKey,
                .isUserImmutableKey, .isSystemImmutableKey
              ]) else { return .unknown }
        if values.isVolume == true { return .volume }
        if values.isAliasFile == true || values.isSymbolicLink == true { return .alias }
        if values.isUserImmutable == true || values.isSystemImmutable == true { return .lockedOrImmutable }
        guard values.volumeIsLocal == true else { return .externalOrNetwork }
        guard values.isWritable == true, values.volumeIsReadOnly == false else { return .readOnly }
        guard values.isRegularFile == true || values.isDirectory == true else { return .unknown }
        return .supportedRegularItem
    }

    private func settledSelectionStatus(_ element: AXUIElement, parent: AXUIElement?) -> SelectionStatus {
        if let selected: Bool = attribute(kAXSelectedAttribute, from: element), !selected { return .unknown }
        var cursor = parent
        for _ in 0..<8 {
            guard let candidate = cursor else { break }
            if let selected: [AXUIElement] = attribute(kAXSelectedChildrenAttribute, from: candidate) {
                if selected.count > 1 { return .multiple }
                return selected.count == 1 && selected.contains { CFEqual($0, element) } ? .exactlyOne : .unknown
            }
            cursor = attribute(kAXParentAttribute, from: candidate)
        }
        return .unknown
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

    private func postcondition(for session: Session) -> FinderTrashPostcondition {
        guard let parent = session.parent else { return .inaccessible }
        var rawChildren: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute as CFString, &rawChildren) == .success,
              let children = rawChildren as? [AXUIElement] else { return .inaccessible }
        return children.contains { CFEqual($0, session.source) } ? .stillPresent : .removedFromOriginalParent
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
