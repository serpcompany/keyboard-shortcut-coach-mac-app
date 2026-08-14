import ApplicationServices
import Foundation

private func attribute<T>(_ element: AXUIElement, _ name: String, as: T.Type = T.self) -> T? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value as? T
}

private func find(_ element: AXUIElement, title: String, seen: inout Set<CFHashCode>) -> AXUIElement? {
    let hash = CFHash(element)
    guard !seen.contains(hash) else { return nil }
    seen.insert(hash)

    let elementTitle = attribute(element, kAXTitleAttribute, as: String.self) ?? ""
    let elementDescription = attribute(element, kAXDescriptionAttribute, as: String.self) ?? ""
    let elementValue = attribute(element, kAXValueAttribute, as: String.self) ?? ""
    if elementTitle == title || elementDescription == title || elementValue == title { return element }

    for child in attribute(element, kAXChildrenAttribute, as: [AXUIElement].self) ?? [] {
        if let match = find(child, title: title, seen: &seen) { return match }
    }
    return nil
}

guard CommandLine.arguments.count >= 3, let pid = pid_t(CommandLine.arguments[1]) else {
    fputs("usage: ax_action <pid> <exact-title> [action]\n", stderr)
    exit(64)
}

let title = CommandLine.arguments[2]
let action = CommandLine.arguments.count >= 4 ? CommandLine.arguments[3] : kAXPressAction
var seen = Set<CFHashCode>()
guard let element = find(AXUIElementCreateApplication(pid), title: title, seen: &seen) else {
    fputs("No accessibility element has title: \(title)\n", stderr)
    exit(2)
}

let result = AXUIElementPerformAction(element, action as CFString)
guard result == .success else {
    fputs("AX action \(action) failed for \(title): \(result.rawValue)\n", stderr)
    exit(1)
}
print("Performed \(action) on \(title)")
