import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class ManualActionDetector {
    enum Status: Equatable {
        case stopped
        case permissionRequired
        case monitoring
        case failed(String)
    }

    private(set) var status: Status = .stopped
    var onEvent: ((CoachingEvent) -> Void)?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastSignature: String?
    private var lastEmission = Date.distantPast

    var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func start() {
        stop()
        guard AXIsProcessTrusted() else {
            status = .permissionRequired
            return
        }

        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        let callback: CGEventTapCallBack = { _, _, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let detector = Unmanaged<ManualActionDetector>.fromOpaque(userInfo).takeUnretainedValue()
            let location = event.location
            MainActor.assumeIsolated {
                detector.inspectElement(at: location)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            status = .failed("macOS did not create the Accessibility event monitor")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        status = .monitoring
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        runLoopSource = nil
        eventTap = nil
        status = .stopped
    }

    private func inspectElement(at point: CGPoint) {
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element) == .success,
              let element,
              stringAttribute(kAXRoleAttribute, from: element) == kAXMenuItemRole as String,
              let title = stringAttribute(kAXTitleAttribute, from: element),
              !title.isEmpty,
              let command = stringAttribute(kAXMenuItemCmdCharAttribute, from: element),
              !command.isEmpty else { return }

        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Current app"
        let shortcut = formattedShortcut(command: command, element: element)
        let signature = "\(appName)|\(title)|\(shortcut)"
        guard signature != lastSignature || Date().timeIntervalSince(lastEmission) > 1 else { return }
        lastSignature = signature
        lastEmission = Date()
        onEvent?(CoachingEvent(
            applicationName: appName,
            actionTitle: title,
            shortcut: shortcut,
            pointerX: point.x,
            pointerY: point.y
        ))
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func formattedShortcut(command: String, element: AXUIElement) -> String {
        var modifiersValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXMenuItemCmdModifiersAttribute as CFString, &modifiersValue)
        let modifiers = (modifiersValue as? NSNumber)?.intValue ?? 0
        return ShortcutFormatter.format(command: command, modifiers: modifiers)
    }
}
