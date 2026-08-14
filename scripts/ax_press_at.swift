import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 3,
      let x = Float(CommandLine.arguments[1]),
      let y = Float(CommandLine.arguments[2])
else {
    fputs("usage: ax_press_at <x> <y>\n", stderr)
    exit(64)
}

var element: AXUIElement?
let system = AXUIElementCreateSystemWide()
guard AXUIElementCopyElementAtPosition(system, x, y, &element) == .success, let element else {
    fputs("No accessibility element at \(x),\(y)\n", stderr)
    exit(2)
}
var roleValue: CFTypeRef?
AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
print("role=\(roleValue as? String ?? "") result=\(result.rawValue)")
exit(result == .success ? 0 : 1)
