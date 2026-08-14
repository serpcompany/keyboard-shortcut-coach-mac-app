@preconcurrency import AppKit
@preconcurrency import CoreGraphics
import Foundation

@MainActor
final class GlobalEventMonitor {
    var onTriggerChanged: ((Bool) -> Void)?
    var onOtherKey: (() -> Void)?
    var onShortcutUsed: ((String, ShortcutModifiers) -> Void)?
    var onMenuAction: ((AppShortcut, CGPoint) -> Void)?

    private let menuReader: MenuReader
    private let triggerKey: () -> TriggerKey
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var trackingMenuClick = false
    private var trackingApplication: NSRunningApplication?

    init(menuReader: MenuReader, triggerKey: @escaping () -> TriggerKey) {
        self.menuReader = menuReader
        self.triggerKey = triggerKey
    }

    func start() -> Bool {
        guard eventTap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<GlobalEventMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                MainActor.assumeIsolated {
                    monitor.handle(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: pointer
        ) else { return false }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        runLoopSource = nil
        eventTap = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        if Self.isDisableNotification(type) {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return
        }

        switch type {
        case .flagsChanged:
            guard event.getIntegerValueField(.keyboardEventKeycode) == Int64(triggerKey().keyCode) else { return }
            onTriggerChanged?(event.flags.contains(.maskCommand))
        case .keyDown:
            onOtherKey?()
            var length = 0
            var buffer = [UniChar](repeating: 0, count: 8)
            event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &length, unicodeString: &buffer)
            let key = String(utf16CodeUnits: buffer, count: length).uppercased()
            guard !key.isEmpty else { return }
            onShortcutUsed?(key, ShortcutModifiers(eventFlags: event.flags))
        case .leftMouseDown:
            let point = event.location
            if point.y <= max(36, NSStatusBar.system.thickness + 4) {
                trackingMenuClick = true
                trackingApplication = NSWorkspace.shared.frontmostApplication
            }
        case .leftMouseUp:
            guard trackingMenuClick, let application = trackingApplication else { return }
            if let shortcut = menuReader.shortcut(at: event.location, application: application) {
                trackingMenuClick = false
                trackingApplication = nil
                onMenuAction?(shortcut, event.location)
            } else if event.location.y > max(36, NSStatusBar.system.thickness + 4) {
                trackingMenuClick = false
                trackingApplication = nil
            }
        default:
            break
        }
    }

    static func isDisableNotification(_ type: CGEventType) -> Bool {
        type == .tapDisabledByTimeout || type == .tapDisabledByUserInput
    }
}
