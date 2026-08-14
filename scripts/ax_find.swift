import ApplicationServices
import Foundation

private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}

private func text(_ element: AXUIElement, _ name: String) -> String {
    attribute(element, name) as? String ?? ""
}

private func point(_ element: AXUIElement, _ name: String) -> CGPoint? {
    guard let value = attribute(element, name), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var result = CGPoint.zero
    guard AXValueGetValue(value as! AXValue, .cgPoint, &result) else { return nil }
    return result
}

private func size(_ element: AXUIElement, _ name: String) -> CGSize? {
    guard let value = attribute(element, name), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var result = CGSize.zero
    guard AXValueGetValue(value as! AXValue, .cgSize, &result) else { return nil }
    return result
}

private func visit(_ element: AXUIElement, query: String, seen: inout Set<CFHashCode>) {
    let hash = CFHash(element)
    guard seen.insert(hash).inserted else { return }
    let role = text(element, kAXRoleAttribute)
    let subrole = text(element, kAXSubroleAttribute)
    let title = text(element, kAXTitleAttribute)
    let description = text(element, kAXDescriptionAttribute)
    let value = text(element, kAXValueAttribute)
    if [role, subrole, title, description, value].contains(where: { $0.localizedCaseInsensitiveContains(query) }) {
        var names: CFArray?
        AXUIElementCopyActionNames(element, &names)
        let rawValue = attribute(element, kAXValueAttribute).map { String(describing: $0) } ?? "nil"
        print("role=\(role) subrole=\(subrole) title=\(title) description=\(description) value=\(value) rawValue=\(rawValue) position=\(String(describing: point(element, kAXPositionAttribute))) size=\(String(describing: size(element, kAXSizeAttribute))) actions=\(names as? [String] ?? [])")
    }
    for child in attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
        visit(child, query: query, seen: &seen)
    }
}

guard CommandLine.arguments.count == 3, let pid = pid_t(CommandLine.arguments[1]) else {
    fputs("usage: ax_find <pid> <query>\n", stderr)
    exit(64)
}
var seen = Set<CFHashCode>()
visit(AXUIElementCreateApplication(pid), query: CommandLine.arguments[2], seen: &seen)
