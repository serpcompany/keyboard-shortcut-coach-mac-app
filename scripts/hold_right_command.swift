import CoreGraphics
import Foundation

let seconds = CommandLine.arguments.dropFirst().first.flatMap(Double.init) ?? 3.0
let source = CGEventSource(stateID: .hidSystemState)
let rightCommandKeyCode: CGKeyCode = 54

guard
    let down = CGEvent(keyboardEventSource: source, virtualKey: rightCommandKeyCode, keyDown: true),
    let up = CGEvent(keyboardEventSource: source, virtualKey: rightCommandKeyCode, keyDown: false)
else {
    fputs("Unable to construct Command-key events\n", stderr)
    exit(1)
}

down.flags = .maskCommand
down.post(tap: .cghidEventTap)
Thread.sleep(forTimeInterval: seconds)
up.flags = []
up.post(tap: .cghidEventTap)
