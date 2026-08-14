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

private func coachingShortcut(title: String = "New Window", key: String = "N") -> AppShortcut {
    AppShortcut(
        appBundleIdentifier: "com.example.Browser",
        appName: "Browser",
        category: "File",
        title: title,
        key: key,
        modifiers: [.command],
        menuPath: ["File", title]
    )
}

@Test func coachingEventStoresNormalizedShortcutValue() {
    let event = CoachingEvent(shortcut: coachingShortcut(key: "n"), source: .menuBar)
    #expect(event.normalizedShortcut == "1:N")
}

@Test func coachingHistoryPersistsAndDeduplicatesByEventID() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let fileURL = directory.appending(path: "coaching-history.json")
    let event = CoachingEvent(shortcut: coachingShortcut(), source: .menuBar, timestamp: Date(timeIntervalSince1970: 1_800_000_000))
    let store = CoachingHistoryStore(fileURL: fileURL, now: { Date(timeIntervalSince1970: 1_800_000_100) })

    _ = try await store.append(event)
    _ = try await store.append(event)
    let reloaded = try await CoachingHistoryStore(
        fileURL: fileURL,
        now: { Date(timeIntervalSince1970: 1_800_000_100) }
    ).load()

    #expect(reloaded == [event])
}

@Test func coachingAppendLoadsExistingHistoryBeforeFirstMutation() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let fileURL = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        .appending(path: "coaching-history.json")
    let originalStore = CoachingHistoryStore(fileURL: fileURL, now: { now })
    let original = CoachingEvent(shortcut: coachingShortcut(title: "Original"), source: .menuBar, timestamp: now.addingTimeInterval(-1))
    _ = try await originalStore.append(original)

    let relaunchedStore = CoachingHistoryStore(fileURL: fileURL, now: { now })
    let newEvent = CoachingEvent(shortcut: coachingShortcut(title: "New"), source: .test, timestamp: now)
    let events = try await relaunchedStore.append(newEvent)

    #expect(events.map(\.actionTitle) == ["New", "Original"])
}

@Test func coachingHistoryMigratesLegacyArrayEnvelope() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let fileURL = directory.appending(path: "coaching-history.json")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let event = CoachingEvent(shortcut: coachingShortcut(), source: .menuBar, timestamp: Date(timeIntervalSince1970: 1_800_000_000))
    try JSONEncoder().encode([event]).write(to: fileURL)

    let loaded = try await CoachingHistoryStore(
        fileURL: fileURL,
        now: { Date(timeIntervalSince1970: 1_800_000_100) }
    ).load()
    let envelope = try JSONDecoder().decode(CoachingHistoryEnvelope.self, from: Data(contentsOf: fileURL))

    #expect(loaded == [event])
    #expect(envelope.schemaVersion == CoachingEvent.currentSchemaVersion)
}

@Test func coachingHistoryAppliesAgeAndCountRetention() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let fileURL = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        .appending(path: "coaching-history.json")
    let store = CoachingHistoryStore(fileURL: fileURL, maxItems: 2, retentionDays: 30, now: { now })
    let old = CoachingEvent(shortcut: coachingShortcut(title: "Old"), source: .menuBar, timestamp: now.addingTimeInterval(-31 * 86_400))
    let first = CoachingEvent(shortcut: coachingShortcut(title: "First"), source: .menuBar, timestamp: now.addingTimeInterval(-3))
    let second = CoachingEvent(shortcut: coachingShortcut(title: "Second"), source: .menuBar, timestamp: now.addingTimeInterval(-2))
    let third = CoachingEvent(shortcut: coachingShortcut(title: "Third"), source: .menuBar, timestamp: now.addingTimeInterval(-1))

    for event in [old, first, second, third] { _ = try await store.append(event) }
    let loaded = try await store.load()

    #expect(loaded.map(\.actionTitle) == ["Third", "Second"])
}

@Test func coachingReadStateSurvivesStoreReplacementAndClear() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let fileURL = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        .appending(path: "coaching-history.json")
    let store = CoachingHistoryStore(fileURL: fileURL, now: { now })
    var event = CoachingEvent(shortcut: coachingShortcut(), source: .menuBar, timestamp: now)
    _ = try await store.append(event)
    event.state = .seen
    _ = try await store.replace(event)

    #expect(try await store.load().count(where: \.isUnread) == 0)
    #expect(try await store.clear().isEmpty)
    #expect(try await store.replace(event).isEmpty)
    #expect(try await store.load().isEmpty)
}

@Test func atomicReadMutationDoesNotDropAnEventAppendedAfterTheSnapshot() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let fileURL = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        .appending(path: "coaching-history.json")
    let store = CoachingHistoryStore(fileURL: fileURL, now: { now })
    let first = CoachingEvent(shortcut: coachingShortcut(title: "First"), source: .menuBar, timestamp: now.addingTimeInterval(-1))
    let second = CoachingEvent(shortcut: coachingShortcut(title: "Second"), source: .menuBar, timestamp: now)
    _ = try await store.append(first)
    _ = try await store.append(second)

    let events = try await store.setState(id: first.id, state: .seen)

    #expect(events.count == 2)
    #expect(events.first(where: { $0.id == first.id })?.state == .seen)
    #expect(events.first(where: { $0.id == second.id })?.state == .unread)
}

@Test func toastPolicyReportsEverySuppressionInsteadOfDroppingEvent() {
    #expect(CoachingPresentationPolicy.toastOutcome(
        enabled: false, quiet: false, excluded: false, dismissed: false,
        hourlyCount: 0, hourlyCap: 20, elapsedSinceLast: nil, alwaysShow: false
    ) == .suppressedDisabled)
    #expect(CoachingPresentationPolicy.toastOutcome(
        enabled: true, quiet: true, excluded: false, dismissed: false,
        hourlyCount: 0, hourlyCap: 20, elapsedSinceLast: nil, alwaysShow: false
    ) == .suppressedQuietHours)
    #expect(CoachingPresentationPolicy.toastOutcome(
        enabled: true, quiet: false, excluded: true, dismissed: false,
        hourlyCount: 0, hourlyCap: 20, elapsedSinceLast: nil, alwaysShow: false
    ) == .suppressedExcludedApp)
    #expect(CoachingPresentationPolicy.toastOutcome(
        enabled: true, quiet: false, excluded: false, dismissed: true,
        hourlyCount: 0, hourlyCap: 20, elapsedSinceLast: nil, alwaysShow: false
    ) == .suppressedDismissedShortcut)
    #expect(CoachingPresentationPolicy.toastOutcome(
        enabled: true, quiet: false, excluded: false, dismissed: false,
        hourlyCount: 20, hourlyCap: 20, elapsedSinceLast: nil, alwaysShow: false
    ) == .suppressedHourlyCap)
    #expect(CoachingPresentationPolicy.toastOutcome(
        enabled: true, quiet: false, excluded: false, dismissed: false,
        hourlyCount: 1, hourlyCap: 20, elapsedSinceLast: 5, alwaysShow: false
    ) == .suppressedCooldown)
}

@Test func dockAttentionIsBoundedAndRespectsActiveQuietAndDisabledStates() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var policy = DockAttentionPolicy()

    #expect(policy.outcome(now: now, enabled: true, appIsActive: false, quiet: false, coachingEnabled: true) == .shown)
    #expect(policy.outcome(now: now.addingTimeInterval(60), enabled: true, appIsActive: false, quiet: false, coachingEnabled: true) == .suppressedRateLimit)
    #expect(policy.outcome(now: now.addingTimeInterval(301), enabled: true, appIsActive: true, quiet: false, coachingEnabled: true) == .suppressedAppActive)
    #expect(policy.outcome(now: now.addingTimeInterval(301), enabled: true, appIsActive: false, quiet: true, coachingEnabled: true) == .suppressedQuietHours)
    #expect(policy.outcome(now: now.addingTimeInterval(301), enabled: false, appIsActive: false, quiet: false, coachingEnabled: true) == .suppressedDisabled)
}

@MainActor
@Test func notificationAttentionPreferencesPersistWithSafeDefaults() {
    let suite = "KeylumeCloneTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let defaultsPreferences = AppPreferences(defaults: defaults)
    #expect(defaultsPreferences.contextualToastEnabled)
    #expect(defaultsPreferences.menuUnreadCountEnabled)
    #expect(defaultsPreferences.menuGreenHighlightEnabled)
    #expect(defaultsPreferences.dockBadgeEnabled)
    #expect(defaultsPreferences.dockBounceEnabled)
    #expect(!defaultsPreferences.nativeNotificationsEnabled)
    #expect(!defaultsPreferences.soundEnabled)

    defaultsPreferences.nativeNotificationsEnabled = true
    defaultsPreferences.soundEnabled = true
    defaultsPreferences.soundVolume = 0.35
    defaultsPreferences.dockBounceEnabled = false
    let reloaded = AppPreferences(defaults: defaults)
    #expect(reloaded.nativeNotificationsEnabled)
    #expect(reloaded.soundEnabled)
    #expect(reloaded.soundVolume == 0.35)
    #expect(!reloaded.dockBounceEnabled)
}
