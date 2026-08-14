import ApplicationServices
import Foundation

private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}

private func string(_ element: AXUIElement, _ name: String) -> String {
    attribute(element, name) as? String ?? ""
}

private func point(_ element: AXUIElement) -> CGPoint? {
    guard let value = attribute(element, kAXPositionAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var result = CGPoint.zero
    return AXValueGetValue(value as! AXValue, .cgPoint, &result) ? result : nil
}

private func walk(_ element: AXUIElement, seen: inout Set<CFHashCode>, visit: (AXUIElement) -> Void) {
    let hash = CFHash(element)
    guard seen.insert(hash).inserted else { return }
    visit(element)
    for child in attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
        walk(child, seen: &seen, visit: visit)
    }
}

guard CommandLine.arguments.count == 4, let pid = pid_t(CommandLine.arguments[1]) else {
    fputs("usage: ax_press_near_label <pid> <exact-label> <target-role>\n", stderr)
    exit(64)
}

let root = AXUIElementCreateApplication(pid)
let label = CommandLine.arguments[2]
let targetRole = CommandLine.arguments[3]
var labelElement: AXUIElement?
var candidates: [AXUIElement] = []
var seen = Set<CFHashCode>()
walk(root, seen: &seen) { element in
    if string(element, kAXValueAttribute) == label || string(element, kAXTitleAttribute) == label {
        labelElement = element
    }
    if string(element, kAXRoleAttribute) == targetRole { candidates.append(element) }
}

guard let labelElement, let labelPoint = point(labelElement) else {
    fputs("Label not found: \(label)\n", stderr)
    exit(2)
}
guard let target = candidates
    .compactMap({ element -> (AXUIElement, CGPoint)? in point(element).map { (element, $0) } })
    .filter({ abs($0.1.y - labelPoint.y) < 24 && $0.1.x > labelPoint.x })
    .min(by: { abs($0.1.y - labelPoint.y) < abs($1.1.y - labelPoint.y) })
else {
    fputs("No nearby \(targetRole) for \(label)\n", stderr)
    exit(3)
}

let result = AXUIElementPerformAction(target.0, kAXPressAction as CFString)
print("label=\(labelPoint) target=\(target.1) result=\(result.rawValue)")
exit(result == .success ? 0 : 1)
