import Foundation
import CryptoKit
import Testing
@testable import KeylumeClone

@Test func shortcutModifiersUseMacOrdering() {
    let modifiers: ShortcutModifiers = [.command, .shift, .option, .control]
    #expect(modifiers.display == "⌃⌥⇧⌘")
}

@Test func accessibilityMenuModifiersFollowAXBitLayout() {
    #expect(ShortcutModifiers(axMenuItemModifiers: 0) == [.command])
    #expect(ShortcutModifiers(axMenuItemModifiers: 3) == [.command, .shift, .option])
    #expect(ShortcutModifiers(axMenuItemModifiers: 8) == [.command])
    #expect(ShortcutModifiers(axMenuItemModifiers: 12) == [.command, .control])
}

@MainActor
@Test func analyticsSeparatesKeyboardAndMouseUsage() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let calendar = Calendar.current
    let shortcut = AppShortcut(
        appBundleIdentifier: "com.example.Editor",
        appName: "Editor",
        category: "File",
        title: "Open…",
        key: "O",
        modifiers: [.command],
        menuPath: ["File", "Open…"]
    )
    let records = [
        UsageRecord(shortcut: shortcut, method: .keyboard, timestamp: now.addingTimeInterval(-60)),
        UsageRecord(shortcut: shortcut, method: .mouse, timestamp: now.addingTimeInterval(-30))
    ]

    let result = AppModel.makeAnalytics(records: records, now: now, calendar: calendar)

    #expect(result.keyboardCount == 1)
    #expect(result.mouseCount == 1)
    #expect(result.keyboardRatio == 50)
    #expect(result.mastered.first?.title == "Open…")
    #expect(result.toLearn.first?.title == "Open…")
}

@Test func usageStorePersistsRecords() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        .appending(path: "usage.json")
    let shortcut = AppShortcut(
        appBundleIdentifier: "com.example.Editor",
        appName: "Editor",
        category: "File",
        title: "Save",
        key: "S",
        modifiers: [.command],
        menuPath: ["File", "Save"]
    )
    let store = UsageStore(fileURL: fileURL)

    _ = try await store.append(UsageRecord(shortcut: shortcut, method: .keyboard))
    let reloaded = try await UsageStore(fileURL: fileURL).load()

    #expect(reloaded.count == 1)
    #expect(reloaded[0].shortcutTitle == "Save")
}

@MainActor
@Test func trialExpiresAndIndependentLicenseActivates() {
    let suite = "KeylumeCloneTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let manager = LicenseManager(defaults: defaults, now: start)
    #expect(manager.state == .trial(daysRemaining: 14))

    manager.refresh(now: start.addingTimeInterval(14 * 86_400))
    #expect(manager.state == .expired)

    let payload = "ABCDEFGH"
    let checksum = SHA256.hash(data: Data(payload.utf8)).prefix(2).map { String(format: "%02X", $0) }.joined()
    #expect(manager.activate("KEYLUME-ABCD-EFGH-\(checksum)"))
    #expect(manager.state == .licensed)
}

@Test func noUpdateFeedReportsCurrentVersion() async throws {
    let status = try await UpdateChecker(feedURL: nil).check(currentVersion: "1.1.2")
    #expect(status.latestVersion == "1.1.2")
    #expect(!status.updateAvailable)
}

@MainActor
@Test func quietHoursHandleOvernightRanges() {
    let suite = "KeylumeCloneTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let calendar = Calendar.current
    let preferences = AppPreferences(defaults: defaults)
    preferences.quietHoursEnabled = true
    preferences.quietHoursStart = calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 22))!
    preferences.quietHoursEnd = calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 7))!

    #expect(preferences.isQuiet(at: calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 23))!))
    #expect(preferences.isQuiet(at: calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 6))!))
    #expect(!preferences.isQuiet(at: calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 12))!))
}

@MainActor
@Test func dismissedShortcutPersistsAcrossPreferenceInstances() {
    let suite = "KeylumeCloneTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let shortcut = AppShortcut(
        appBundleIdentifier: "com.example.Editor",
        appName: "Editor",
        category: "File",
        title: "New Tab",
        key: "T",
        modifiers: [.command],
        menuPath: ["File", "New Tab"]
    )
    AppPreferences(defaults: defaults).dismiss(shortcut)

    #expect(AppPreferences(defaults: defaults).dismissedShortcuts.contains(shortcut.dismissalKey))
}

@MainActor
@Test func nudgePolicyEnforcesMinimumIntervalAndHourlyCap() {
    let suite = "KeylumeCloneTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = AppPreferences(defaults: defaults)
    preferences.maxNudgesPerHour = 2
    preferences.alwaysShowNudges = false
    let model = AppModel(preferences: preferences)
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    #expect(model.shouldShowNudge(now: start))
    #expect(!model.shouldShowNudge(now: start.addingTimeInterval(10)))
    #expect(model.shouldShowNudge(now: start.addingTimeInterval(16)))
    #expect(!model.shouldShowNudge(now: start.addingTimeInterval(32)))
    #expect(model.shouldShowNudge(now: start.addingTimeInterval(3_601)))
}

@MainActor
@Test func generalAndCoachingPreferencesPersist() {
    let suite = "KeylumeCloneTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = AppPreferences(defaults: defaults)
    preferences.automaticUpdates = true
    preferences.coachingEnabled = false
    preferences.alwaysShowNudges = true
    preferences.maxNudgesPerHour = 7
    preferences.addExcludedApplication("com.example.Editor")

    let reloaded = AppPreferences(defaults: defaults)
    #expect(reloaded.automaticUpdates)
    #expect(!reloaded.coachingEnabled)
    #expect(reloaded.alwaysShowNudges)
    #expect(reloaded.maxNudgesPerHour == 7)
    #expect(reloaded.excludedApps == ["com.example.Editor"])

    reloaded.removeExcludedApplication("com.example.Editor")
    #expect(AppPreferences(defaults: defaults).excludedApps.isEmpty)
}

@MainActor
@Test func eventTapDisableNotificationsRouteToRecovery() {
    #expect(GlobalEventMonitor.isDisableNotification(.tapDisabledByTimeout))
    #expect(GlobalEventMonitor.isDisableNotification(.tapDisabledByUserInput))
    #expect(!GlobalEventMonitor.isDisableNotification(.keyDown))
}
