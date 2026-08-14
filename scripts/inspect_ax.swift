import ApplicationServices
import Foundation

private func attribute<T>(_ element: AXUIElement, _ name: String, as: T.Type = T.self) -> T? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value as? T
}

private func stringAttribute(_ element: AXUIElement, _ name: String) -> String {
    attribute(element, name, as: String.self) ?? ""
}

private func describe(_ element: AXUIElement, depth: Int, maxDepth: Int, seen: inout Set<CFHashCode>) {
    let hash = CFHash(element)
    guard !seen.contains(hash) else { return }
    seen.insert(hash)

    let role = stringAttribute(element, kAXRoleAttribute)
    let subrole = stringAttribute(element, kAXSubroleAttribute)
    let title = stringAttribute(element, kAXTitleAttribute)
    let description = stringAttribute(element, kAXDescriptionAttribute)
    let help = stringAttribute(element, kAXHelpAttribute)
    let value = stringAttribute(element, kAXValueAttribute)
    print("\(String(repeating: "  ", count: depth))role=\(role) subrole=\(subrole) title=\(title) description=\(description) help=\(help) value=\(value)")

    guard depth < maxDepth else { return }
    let children = attribute(element, kAXChildrenAttribute, as: [AXUIElement].self) ?? []
    for child in children {
        describe(child, depth: depth + 1, maxDepth: maxDepth, seen: &seen)
    }
}

let arguments = CommandLine.arguments.dropFirst()
guard let pidArgument = arguments.first, let pid = pid_t(pidArgument) else {
    fputs("usage: inspect_ax <pid> [max-depth]\n", stderr)
    exit(64)
}
let maxDepth = arguments.dropFirst().first.flatMap(Int.init) ?? 8
var seen = Set<CFHashCode>()
describe(AXUIElementCreateApplication(pid), depth: 0, maxDepth: maxDepth, seen: &seen)
