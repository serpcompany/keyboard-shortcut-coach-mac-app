import AppKit
import Foundation

enum TriggerKey: String, CaseIterable, Codable, Identifiable {
    case rightCommand
    case leftCommand

    var id: String { rawValue }
    var keyCode: CGKeyCode { self == .rightCommand ? 54 : 55 }
    var label: String { self == .rightCommand ? "Right ⌘ Command" : "Left ⌘ Command" }
}

enum AppAppearance: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let command = Self(rawValue: 1 << 0)
    static let shift = Self(rawValue: 1 << 1)
    static let option = Self(rawValue: 1 << 2)
    static let control = Self(rawValue: 1 << 3)
    static let function = Self(rawValue: 1 << 4)

    var symbols: [String] {
        var result: [String] = []
        if contains(.control) { result.append("⌃") }
        if contains(.option) { result.append("⌥") }
        if contains(.shift) { result.append("⇧") }
        if contains(.command) { result.append("⌘") }
        if contains(.function) { result.append("fn") }
        return result
    }

    var display: String { symbols.joined() }

    init(eventFlags: CGEventFlags) {
        var value: ShortcutModifiers = []
        if eventFlags.contains(.maskCommand) { value.insert(.command) }
        if eventFlags.contains(.maskShift) { value.insert(.shift) }
        if eventFlags.contains(.maskAlternate) { value.insert(.option) }
        if eventFlags.contains(.maskControl) { value.insert(.control) }
        if eventFlags.contains(.maskSecondaryFn) { value.insert(.function) }
        self = value
    }

    init(axMenuItemModifiers rawValue: Int) {
        // Keylume's observable overlay treats AX menu shortcuts as Command-based,
        // including items whose AX "no Command" bit is set.
        var value: ShortcutModifiers = [.command]
        if rawValue & (1 << 0) != 0 { value.insert(.shift) }
        if rawValue & (1 << 1) != 0 { value.insert(.option) }
        if rawValue & (1 << 2) != 0 { value.insert(.control) }
        self = value
    }
}

struct AppShortcut: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let appBundleIdentifier: String
    let appName: String
    let category: String
    let title: String
    let key: String
    let modifiers: ShortcutModifiers
    let menuPath: [String]

    init(
        appBundleIdentifier: String,
        appName: String,
        category: String,
        title: String,
        key: String,
        modifiers: ShortcutModifiers,
        menuPath: [String]
    ) {
        self.appBundleIdentifier = appBundleIdentifier
        self.appName = appName
        self.category = category
        self.title = title
        self.key = key
        self.modifiers = modifiers
        self.menuPath = menuPath
        id = ([appBundleIdentifier] + menuPath + [key, String(modifiers.rawValue)]).joined(separator: "\u{1F}")
    }

    var display: String { modifiers.display + key.uppercased() }
    var menuLocation: String { menuPath.dropLast().joined(separator: " › ") }
    var dismissalKey: String { "\(appBundleIdentifier)|\(title)|\(display)" }
}

enum UsageMethod: String, Codable, Sendable {
    case keyboard
    case mouse
}

struct UsageRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let timestamp: Date
    let appBundleIdentifier: String
    let appName: String
    let shortcutTitle: String
    let shortcutDisplay: String
    let method: UsageMethod

    init(shortcut: AppShortcut, method: UsageMethod, timestamp: Date = .now, id: UUID = UUID()) {
        self.id = id
        self.timestamp = timestamp
        appBundleIdentifier = shortcut.appBundleIdentifier
        appName = shortcut.appName
        shortcutTitle = shortcut.title
        shortcutDisplay = shortcut.display
        self.method = method
    }
}

struct AppUsageSummary: Identifiable, Hashable {
    let appName: String
    let keyboardCount: Int
    let mouseCount: Int
    var id: String { appName }
}

struct ShortcutUsageSummary: Identifiable, Hashable {
    let title: String
    let display: String
    let count: Int
    let method: UsageMethod
    var id: String { "\(method.rawValue)|\(display)|\(title)" }
}

struct AnalyticsSnapshot: Equatable {
    let keyboardCount: Int
    let mouseCount: Int
    let previousKeyboardCount: Int
    let mastered: [ShortcutUsageSummary]
    let toLearn: [ShortcutUsageSummary]
    let perApp: [AppUsageSummary]

    var total: Int { keyboardCount + mouseCount }
    var keyboardRatio: Int { total == 0 ? 0 : Int((Double(keyboardCount) / Double(total) * 100).rounded()) }
    var changePercent: Int {
        guard previousKeyboardCount > 0 else { return keyboardCount > 0 ? 100 : 0 }
        return Int(((Double(keyboardCount - previousKeyboardCount) / Double(previousKeyboardCount)) * 100).rounded())
    }
    var topShortcut: ShortcutUsageSummary? { mastered.first }
}

extension AnalyticsSnapshot {
    static let empty = AnalyticsSnapshot(
        keyboardCount: 0,
        mouseCount: 0,
        previousKeyboardCount: 0,
        mastered: [],
        toLearn: [],
        perApp: []
    )
}
