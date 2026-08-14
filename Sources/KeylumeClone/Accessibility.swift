import AppKit
import ApplicationServices
import Foundation

enum AccessibilityStatus: Equatable {
    case granted
    case denied
}

struct AccessibilityManager {
    var status: AccessibilityStatus { AXIsProcessTrusted() ? .granted : .denied }

    func request() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
final class MenuReader {
    private var actionElements: [String: AXUIElement] = [:]

    func readShortcuts(for application: NSRunningApplication) -> [AppShortcut] {
        guard application.bundleIdentifier != nil else { return [] }
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let menuBar: AXUIElement = attribute(appElement, kAXMenuBarAttribute) else { return [] }

        var result: [AppShortcut] = []
        var actions: [String: AXUIElement] = [:]
        for topLevel in children(of: menuBar) {
            let category = string(topLevel, kAXTitleAttribute)
            guard !category.isEmpty else { continue }
            for menu in children(of: topLevel) {
                walk(
                    menu,
                    application: application,
                    category: category,
                    path: [category],
                    result: &result,
                    actions: &actions
                )
            }
        }
        actionElements = actions
        return result
    }

    func execute(_ shortcut: AppShortcut) -> Bool {
        guard let element = actionElements[shortcut.id] else { return false }
        return AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    func shortcut(at point: CGPoint, application: NSRunningApplication) -> AppShortcut? {
        var rawElement: AXUIElement?
        let systemWide = AXUIElementCreateSystemWide()
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &rawElement) == .success,
              let element = rawElement,
              string(element, kAXRoleAttribute) == kAXMenuItemRole
        else { return nil }
        return shortcut(from: element, application: application, category: menuCategory(for: element), path: menuPath(for: element))
    }

    private func walk(
        _ element: AXUIElement,
        application: NSRunningApplication,
        category: String,
        path: [String],
        result: inout [AppShortcut],
        actions: inout [String: AXUIElement]
    ) {
        let role = string(element, kAXRoleAttribute)
        let title = string(element, kAXTitleAttribute)
        let nextPath = title.isEmpty ? path : path + [title]

        if role == kAXMenuItemRole,
           let shortcut = shortcut(from: element, application: application, category: category, path: nextPath) {
            result.append(shortcut)
            actions[shortcut.id] = element
        }
        for child in children(of: element) {
            walk(child, application: application, category: category, path: nextPath, result: &result, actions: &actions)
        }
    }

    private func shortcut(
        from element: AXUIElement,
        application: NSRunningApplication,
        category: String,
        path: [String]
    ) -> AppShortcut? {
        guard let bundleIdentifier = application.bundleIdentifier else { return nil }
        let title = string(element, kAXTitleAttribute)
        guard !title.isEmpty else { return nil }

        let commandCharacter = string(element, kAXMenuItemCmdCharAttribute)
        let glyph: Int? = attribute(element, kAXMenuItemCmdGlyphAttribute)
        guard let key = normalizedKey(character: commandCharacter, glyph: glyph), !key.isEmpty else { return nil }

        let rawModifiers: Int = attribute(element, kAXMenuItemCmdModifiersAttribute) ?? 0
        let modifiers = ShortcutModifiers(axMenuItemModifiers: rawModifiers)

        return AppShortcut(
            appBundleIdentifier: bundleIdentifier,
            appName: application.localizedName ?? bundleIdentifier,
            category: category,
            title: title,
            key: key,
            modifiers: modifiers,
            menuPath: path
        )
    }

    private func normalizedKey(character: String, glyph: Int?) -> String? {
        if !character.isEmpty { return character == "\r" ? "↩" : character }
        guard let glyph else { return nil }
        return [
            1: "⇥", 2: "⇤", 3: "↩", 4: "⌫", 5: "⌦", 6: "⌤", 9: "⎋",
            10: "←", 11: "→", 12: "↑", 13: "↓", 16: "⇞", 17: "⇟",
            18: "↖", 19: "↘", 23: "⌧", 28: "␣"
        ][glyph] ?? "F\(glyph)"
    }

    private func menuCategory(for element: AXUIElement) -> String {
        menuPath(for: element).first ?? "Menu"
    }

    private func menuPath(for element: AXUIElement) -> [String] {
        var path: [String] = []
        var current: AXUIElement? = element
        while let item = current {
            let title = string(item, kAXTitleAttribute)
            if !title.isEmpty { path.insert(title, at: 0) }
            current = attribute(item, kAXParentAttribute)
        }
        return path
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) ?? []
    }

    private func string(_ element: AXUIElement, _ name: String) -> String {
        attribute(element, name) ?? ""
    }

    private func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
