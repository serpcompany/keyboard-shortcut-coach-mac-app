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
