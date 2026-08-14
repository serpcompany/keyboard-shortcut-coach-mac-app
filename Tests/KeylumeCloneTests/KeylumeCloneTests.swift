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

private func presentationTestShortcut() -> AppShortcut {
    AppShortcut(
        appBundleIdentifier: "com.example.Editor",
        appName: "Editor",
        category: "File",
        title: "New Window",
        key: "N",
        modifiers: [.command],
        menuPath: ["File", "New Window"]
    )
}

@Test func presentationStateMachineHasBoundedExplicitStates() {
    var machine = PresentationStateMachine()
    #expect(machine.phase == .idle)
    machine.begin()
    #expect(machine.phase == .evaluating)
    machine.present()
    #expect(machine.phase == .presenting)
    machine.resolve()
    #expect(machine.phase == .success)
    machine.pause(reason: "quiet hours")
    #expect(machine.phase == .paused("quiet hours"))
    machine.fail(reason: "placement")
    #expect(machine.phase == .failed("placement"))
    machine.reset()
    #expect(machine.phase == .idle)
}

@MainActor
@Test func presentationDismissalDoesNotCancelActiveStateTransition() {
    let registry = PresentationTaskRegistry()
    let transition = Task<Void, Never> { await Task.yield() }
    let dismissal = Task<Void, Never> { await Task.yield() }

    registry.replaceTransition(for: .compactExpandedShelf, with: transition)
    registry.replaceDismissal(for: .compactExpandedShelf, with: dismissal)

    #expect(!transition.isCancelled)
    registry.cancel(for: .compactExpandedShelf)
    #expect(transition.isCancelled)
    #expect(dismissal.isCancelled)
}

@Test func presentationPolicyFansOutOnceAndSuppressesDuplicates() {
    var policy = PresentationPolicy(cooldown: 15)
    let eventID = UUID()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    #expect(policy.decision(eventID: eventID, mode: .cursorHalo, now: now, enabled: true, quiet: false) == nil)
    #expect(policy.decision(eventID: eventID, mode: .pointerCard, now: now, enabled: true, quiet: false) == nil)
    #expect(policy.decision(eventID: eventID, mode: .cursorHalo, now: now, enabled: true, quiet: false) == .duplicate)
}

@Test func presentationPolicyHandlesCooldownDisabledAndQuietHours() {
    var policy = PresentationPolicy(cooldown: 15)
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    #expect(policy.decision(eventID: UUID(), mode: .cursorHalo, now: now, enabled: false, quiet: false) == .disabled)
    #expect(policy.decision(eventID: UUID(), mode: .cursorHalo, now: now, enabled: true, quiet: true) == .quietHours)
    #expect(policy.decision(eventID: UUID(), mode: .cursorHalo, now: now, enabled: true, quiet: false) == nil)
    #expect(policy.decision(eventID: UUID(), mode: .cursorHalo, now: now.addingTimeInterval(5), enabled: true, quiet: false) == .cooldown)
    #expect(policy.decision(eventID: UUID(), mode: .cursorHalo, now: now.addingTimeInterval(16), enabled: true, quiet: false) == nil)
}

@Test func pointerPlacementFlipsAtEveryEdgeAndSupportsNegativeOrigins() throws {
    let visible = CGRect(x: -1920, y: -300, width: 1920, height: 1080)
    let size = CGSize(width: 360, height: 110)
    let anchors = [
        CGPoint(x: visible.minX + 1, y: visible.minY + 1),
        CGPoint(x: visible.maxX - 1, y: visible.minY + 1),
        CGPoint(x: visible.minX + 1, y: visible.maxY - 1),
        CGPoint(x: visible.maxX - 1, y: visible.maxY - 1)
    ]

    for anchor in anchors {
        let frame = try #require(PresentationPlacement.pointerCard(anchor: anchor, size: size, visibleFrame: visible))
        #expect(frame.minX >= visible.minX)
        #expect(frame.maxX <= visible.maxX)
        #expect(frame.minY >= visible.minY)
        #expect(frame.maxY <= visible.maxY)
        #expect(!frame.contains(anchor))
    }
}

@Test func placementFailsWhenDisplayCannotSafelyFitSurface() {
    let tiny = CGRect(x: 0, y: 0, width: 200, height: 100)
    #expect(PresentationPlacement.topCenter(size: CGSize(width: 300, height: 50), visibleFrame: tiny) == nil)
    #expect(PresentationPlacement.pointerCard(anchor: CGPoint(x: 50, y: 50), size: CGSize(width: 300, height: 80), visibleFrame: tiny) == nil)
}

@Test func topCenterPlacementUsesRequestedDisplay() throws {
    let visible = CGRect(x: 1500, y: 200, width: 1200, height: 800)
    let frame = try #require(PresentationPlacement.topCenter(size: CGSize(width: 400, height: 100), visibleFrame: visible, topInset: 16))
    #expect(frame.midX == visible.midX)
    #expect(frame.maxY == visible.maxY - 16)
}

@Test func actionableBannerDecisionsAreTypedAndDeterministic() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var deferred = CoachingDecisionState()
    deferred.apply(.notNow, now: now)
    #expect(deferred.isUnread)
    #expect(deferred.deferredUntil == now.addingTimeInterval(3600))

    var practiced = CoachingDecisionState()
    practiced.apply(.practiceShortcut, now: now)
    #expect(!practiced.isUnread)

    var suppressed = CoachingDecisionState()
    suppressed.apply(.stopSuggesting, now: now)
    #expect(suppressed.isSuppressed)
    #expect(!suppressed.isUnread)
    #expect(PresentationSemantics.decisionActionOrder == [.practiceShortcut, .notNow, .gotIt, .stopSuggesting])
}

@Test func presentationAccessibilitySemanticsIncludeStateActionAndShortcut() {
    let event = CoachingEvent(
        shortcut: presentationTestShortcut(),
        pointerLocation: .zero,
        isLocalPreview: true
    )
    let label = PresentationSemantics.label(for: event, phase: .permissionRequired)
    #expect(label.contains("Accessibility permission required"))
    #expect(label.contains("New Window"))
    #expect(label.contains("⌘N"))
    #expect(CoachingAction.stopSuggesting.title == "Stop Suggesting")
}

@MainActor
@Test func presentationPreferencesPersistAndResetToSafeDefaults() {
    let suite = "KeylumeCloneTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = AppPreferences(defaults: defaults)
    preferences.pointerCardEnabled = true
    preferences.decisionBannerEnabled = true
    preferences.cursorHaloEnabled = false

    let reloaded = AppPreferences(defaults: defaults)
    #expect(reloaded.pointerCardEnabled)
    #expect(reloaded.decisionBannerEnabled)
    #expect(!reloaded.cursorHaloEnabled)

    reloaded.resetPresentationDefaults()
    #expect(reloaded.topCenterPresenceEnabled)
    #expect(reloaded.compactExpandedShelfEnabled)
    #expect(reloaded.cursorHaloEnabled)
    #expect(reloaded.statusFeedbackEnabled)
    #expect(!reloaded.pointerCardEnabled)
    #expect(!reloaded.decisionBannerEnabled)
}
