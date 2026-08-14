import AppKit
import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppPreferences {
    private enum Key {
        static let triggerKey = "triggerKey"
        static let holdDuration = "holdDuration"
        static let appearance = "appearance"
        static let launchAtLogin = "launchAtLogin"
        static let automaticUpdates = "automaticUpdates"
        static let excludedApps = "excludedApps"
        static let coachingEnabled = "coachingEnabled"
        static let alwaysShowNudges = "alwaysShowNudges"
        static let maxNudgesPerHour = "maxNudgesPerHour"
        static let quietHoursEnabled = "quietHoursEnabled"
        static let quietHoursStart = "quietHoursStart"
        static let quietHoursEnd = "quietHoursEnd"
        static let dismissedShortcuts = "dismissedShortcuts"
        static let contextualToastEnabled = "contextualToastEnabled"
        static let nativeNotificationsEnabled = "nativeNotificationsEnabled"
        static let soundEnabled = "soundEnabled"
        static let soundVolume = "soundVolume"
        static let menuUnreadCountEnabled = "menuUnreadCountEnabled"
        static let menuGreenHighlightEnabled = "menuGreenHighlightEnabled"
        static let dockBadgeEnabled = "dockBadgeEnabled"
        static let dockBounceEnabled = "dockBounceEnabled"
        static let onboardingComplete = "hasCompletedOnboarding"
    }

    private let defaults: UserDefaults

    var triggerKey: TriggerKey { didSet { defaults.set(triggerKey.rawValue, forKey: Key.triggerKey) } }
    var holdDuration: Double { didSet { defaults.set(holdDuration, forKey: Key.holdDuration) } }
    var appearance: AppAppearance { didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) } }
    var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Key.launchAtLogin)
            updateLoginItem()
        }
    }
    var automaticUpdates: Bool { didSet { defaults.set(automaticUpdates, forKey: Key.automaticUpdates) } }
    var excludedApps: [String] { didSet { defaults.set(excludedApps, forKey: Key.excludedApps) } }
    var coachingEnabled: Bool { didSet { defaults.set(coachingEnabled, forKey: Key.coachingEnabled) } }
    var alwaysShowNudges: Bool { didSet { defaults.set(alwaysShowNudges, forKey: Key.alwaysShowNudges) } }
    var maxNudgesPerHour: Double { didSet { defaults.set(maxNudgesPerHour, forKey: Key.maxNudgesPerHour) } }
    var quietHoursEnabled: Bool { didSet { defaults.set(quietHoursEnabled, forKey: Key.quietHoursEnabled) } }
    var quietHoursStart: Date { didSet { defaults.set(quietHoursStart, forKey: Key.quietHoursStart) } }
    var quietHoursEnd: Date { didSet { defaults.set(quietHoursEnd, forKey: Key.quietHoursEnd) } }
    var dismissedShortcuts: Set<String> { didSet { defaults.set(Array(dismissedShortcuts), forKey: Key.dismissedShortcuts) } }
    var contextualToastEnabled: Bool { didSet { defaults.set(contextualToastEnabled, forKey: Key.contextualToastEnabled) } }
    var nativeNotificationsEnabled: Bool { didSet { defaults.set(nativeNotificationsEnabled, forKey: Key.nativeNotificationsEnabled) } }
    var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) } }
    var soundVolume: Double { didSet { defaults.set(soundVolume, forKey: Key.soundVolume) } }
    var menuUnreadCountEnabled: Bool { didSet { defaults.set(menuUnreadCountEnabled, forKey: Key.menuUnreadCountEnabled) } }
    var menuGreenHighlightEnabled: Bool { didSet { defaults.set(menuGreenHighlightEnabled, forKey: Key.menuGreenHighlightEnabled) } }
    var dockBadgeEnabled: Bool { didSet { defaults.set(dockBadgeEnabled, forKey: Key.dockBadgeEnabled) } }
    var dockBounceEnabled: Bool { didSet { defaults.set(dockBounceEnabled, forKey: Key.dockBounceEnabled) } }
    var onboardingComplete: Bool { didSet { defaults.set(onboardingComplete, forKey: Key.onboardingComplete) } }
    var loginItemError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        triggerKey = TriggerKey(rawValue: defaults.string(forKey: Key.triggerKey) ?? "") ?? .rightCommand
        let storedHold = defaults.object(forKey: Key.holdDuration) as? Double
        holdDuration = storedHold ?? 1.5
        appearance = AppAppearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        automaticUpdates = defaults.bool(forKey: Key.automaticUpdates)
        excludedApps = defaults.stringArray(forKey: Key.excludedApps) ?? []
        coachingEnabled = defaults.object(forKey: Key.coachingEnabled) as? Bool ?? true
        alwaysShowNudges = defaults.bool(forKey: Key.alwaysShowNudges)
        let storedMax = defaults.object(forKey: Key.maxNudgesPerHour) as? Double
        maxNudgesPerHour = storedMax ?? 20
        quietHoursEnabled = defaults.bool(forKey: Key.quietHoursEnabled)
        quietHoursStart = defaults.object(forKey: Key.quietHoursStart) as? Date ?? Calendar.current.date(from: DateComponents(hour: 22)) ?? .now
        quietHoursEnd = defaults.object(forKey: Key.quietHoursEnd) as? Date ?? Calendar.current.date(from: DateComponents(hour: 7)) ?? .now
        dismissedShortcuts = Set(defaults.stringArray(forKey: Key.dismissedShortcuts) ?? [])
        contextualToastEnabled = defaults.object(forKey: Key.contextualToastEnabled) as? Bool ?? true
        nativeNotificationsEnabled = defaults.bool(forKey: Key.nativeNotificationsEnabled)
        soundEnabled = defaults.bool(forKey: Key.soundEnabled)
        soundVolume = defaults.object(forKey: Key.soundVolume) as? Double ?? 0.7
        menuUnreadCountEnabled = defaults.object(forKey: Key.menuUnreadCountEnabled) as? Bool ?? true
        menuGreenHighlightEnabled = defaults.object(forKey: Key.menuGreenHighlightEnabled) as? Bool ?? true
        dockBadgeEnabled = defaults.object(forKey: Key.dockBadgeEnabled) as? Bool ?? true
        dockBounceEnabled = defaults.object(forKey: Key.dockBounceEnabled) as? Bool ?? true
        onboardingComplete = defaults.bool(forKey: Key.onboardingComplete)
    }

    func addExcludedApplication(_ bundleIdentifier: String) {
        guard !excludedApps.contains(bundleIdentifier) else { return }
        excludedApps.append(bundleIdentifier)
    }

    func removeExcludedApplication(_ bundleIdentifier: String) {
        excludedApps.removeAll { $0 == bundleIdentifier }
    }

    func resetDismissedShortcuts() {
        dismissedShortcuts = []
    }

    func dismiss(_ shortcut: AppShortcut) {
        dismissedShortcuts.insert(shortcut.dismissalKey)
    }

    func dismiss(key: String) {
        dismissedShortcuts.insert(key)
    }

    func restore(key: String) {
        dismissedShortcuts.remove(key)
    }

    func isQuiet(at date: Date = .now) -> Bool {
        guard quietHoursEnabled else { return false }
        let calendar = Calendar.current
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let start = calendar.component(.hour, from: quietHoursStart) * 60 + calendar.component(.minute, from: quietHoursStart)
        let end = calendar.component(.hour, from: quietHoursEnd) * 60 + calendar.component(.minute, from: quietHoursEnd)
        return start <= end ? (start...end).contains(minute) : minute >= start || minute <= end
    }

    private func updateLoginItem() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
    }
}
