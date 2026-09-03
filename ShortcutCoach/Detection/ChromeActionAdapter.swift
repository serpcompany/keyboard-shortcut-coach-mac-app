import ApplicationServices
import CoreGraphics
import Foundation

enum ManualActionKind: Equatable, Sendable {
    case chromeNewTab
    case chromeCloseActiveTab(tabToken: String)
    case chromeSelectTab(tabToken: String, index: Int, tabCount: Int)
}

struct ManualActionCandidate: Equatable, Sendable {
    let kind: ManualActionKind
    let applicationName: String
    let point: CGPoint
    let targetFrame: AXFrameSnapshot?
    let preSnapshot: AccessibilitySnapshot
}

protocol ApplicationActionAdapter {
    func classify(_ snapshot: AccessibilitySnapshot, point: CGPoint) -> ManualActionCandidate?
}

struct ChromeActionAdapter: ApplicationActionAdapter {
    static let bundleIdentifiers: Set<String> = ["com.google.Chrome", "org.chromium.Chromium"]

    func classify(_ snapshot: AccessibilitySnapshot, point: CGPoint) -> ManualActionCandidate? {
        guard let bundle = snapshot.bundleIdentifier, Self.bundleIdentifiers.contains(bundle),
              snapshot.hit.enabled != false, let tabs = snapshot.tabs else { return nil }

        if let tab = tabNode(in: snapshot) {
            if isCloseButton(snapshot.hit) {
                // Chrome's button descendant is safe only for the selected tab.
                guard tab.selected == true else { return nil }
                return candidate(.chromeCloseActiveTab(tabToken: tab.token), snapshot, point)
            }
            guard let index = tabs.tabs.firstIndex(where: { $0.token == tab.token }), tab.selected != true else { return nil }
            let oneBased = index + 1
            guard oneBased <= 8 || oneBased == tabs.tabs.count else { return nil }
            return candidate(.chromeSelectTab(tabToken: tab.token, index: oneBased, tabCount: tabs.tabs.count), snapshot, point)
        }

        if isNewTabButton(snapshot.hit), snapshot.hit.actions.contains(kAXPressAction as String) {
            return candidate(.chromeNewTab, snapshot, point)
        }
        return nil
    }

    private func tabNode(in snapshot: AccessibilitySnapshot) -> AXNodeSnapshot? {
        snapshot.hitAndAncestors.first { $0.role == kAXRadioButtonRole as String || $0.role == "AXTab" }
    }

    private func isNewTabButton(_ node: AXNodeSnapshot) -> Bool {
        guard node.role == kAXButtonRole as String else { return false }
        let semantic = [node.identifier, node.elementDescription, node.title]
            .compactMap { $0?.lowercased().replacingOccurrences(of: " ", with: "") }
        // Names are never sufficient alone: classification also requires bundle identity,
        // button role, AXPress, and a characterized tab container.
        return semantic.contains { value in
            value.contains("newtab") || value.contains("new-tab") || value == "nouvelonglet" || value == "neuertab"
        }
    }

    private func isCloseButton(_ node: AXNodeSnapshot) -> Bool {
        guard node.role == kAXButtonRole as String, node.actions.contains(kAXPressAction as String) else { return false }
        let semantic = [node.identifier, node.elementDescription, node.title]
            .compactMap { $0?.lowercased().replacingOccurrences(of: " ", with: "") }
        return semantic.contains { value in
            value.contains("closetab") || value.contains("tab-close") || value == "close" || value == "fermer" || value == "schließen"
        }
    }

    private func candidate(_ kind: ManualActionKind, _ snapshot: AccessibilitySnapshot, _ point: CGPoint) -> ManualActionCandidate {
        ManualActionCandidate(kind: kind, applicationName: snapshot.applicationName, point: point,
                              targetFrame: snapshot.hit.frame, preSnapshot: snapshot)
    }
}
