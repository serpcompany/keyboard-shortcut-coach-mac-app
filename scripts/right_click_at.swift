import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 3,
      let x = Double(CommandLine.arguments[1]),
      let y = Double(CommandLine.arguments[2]) else {
    fputs("usage: right_click_at <x> <y>\n", stderr)
    exit(64)
}

let point = CGPoint(x: x, y: y)
let source = CGEventSource(stateID: .hidSystemState)
for type in [CGEventType.mouseMoved, .rightMouseDown, .rightMouseUp] {
    guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .right) else {
        fputs("Unable to create mouse event\n", stderr)
        exit(1)
    }
    event.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.05)
}
