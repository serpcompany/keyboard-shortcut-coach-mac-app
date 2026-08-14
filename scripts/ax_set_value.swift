import ApplicationServices
import Foundation

private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}

private func find(_ element: AXUIElement, role: String, seen: inout Set<CFHashCode>) -> AXUIElement? {
    let hash = CFHash(element)
    guard seen.insert(hash).inserted else { return nil }
    if attribute(element, kAXRoleAttribute) as? String == role { return element }
    for child in attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
        if let found = find(child, role: role, seen: &seen) { return found }
    }
    return nil
}

guard CommandLine.arguments.count == 4, let pid = pid_t(CommandLine.arguments[1]) else {
    fputs("usage: ax_set_value <pid> <role> <value>\n", stderr)
    exit(64)
}
var seen = Set<CFHashCode>()
guard let element = find(AXUIElementCreateApplication(pid), role: CommandLine.arguments[2], seen: &seen) else {
    fputs("No element with role \(CommandLine.arguments[2])\n", stderr)
    exit(2)
}
let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, CommandLine.arguments[3] as CFTypeRef)
print("result=\(result.rawValue)")
exit(result == .success ? 0 : 1)
