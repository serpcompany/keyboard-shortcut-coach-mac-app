import AppKit
import XCTest
@testable import ShortcutCoach

private final class MemoryPersistence: EventPersistence {
    var stored: [CoachingEvent]
    init(stored: [CoachingEvent] = []) { self.stored = stored }
    func load() throws -> [CoachingEvent] { stored }
    func save(_ events: [CoachingEvent]) throws { stored = events }
}

@MainActor
private final class SpyAdapter: ChannelDelivering {
    private(set) var events: [CoachingEvent] = []
    var error: Error?

    func deliver(_ event: CoachingEvent) async throws {
        if let error { throw error }
        events.append(event)
    }
}

private enum TestError: Error { case expected }

private final class StatusItemActionTarget: NSObject {
    @objc func activate(_ sender: NSStatusBarButton) {}
}

@MainActor
final class ShortcutCoachTests: XCTestCase {
    func testDeliveryRecordsOnceAndFansOutToSelectedChannels() async {
        let persistence = MemoryPersistence()
        let inbox = InboxStore(persistence: persistence)
        let toast = SpyAdapter()
        let sound = SpyAdapter()
        let service = NotificationDeliveryService(inbox: inbox, adapters: [
            .topRightToast: toast,
            .sound: sound
        ])
        let event = CoachingEvent.sample

        let report = await service.deliver(event, through: [.topRightToast, .sound])

        XCTAssertTrue(report.inboxRecorded)
        XCTAssertEqual(inbox.events, [event])
        XCTAssertEqual(persistence.stored, [event])
        XCTAssertEqual(toast.events, [event])
        XCTAssertEqual(sound.events, [event])
        XCTAssertEqual(report.outcomes[.topRightToast], .delivered)
        XCTAssertEqual(report.outcomes[.sound], .delivered)
    }

    func testDeliveryReportsOneAdapterFailureWithoutDroppingHistory() async {
        let inbox = InboxStore(persistence: MemoryPersistence())
        let failing = SpyAdapter()
        failing.error = TestError.expected
        let service = NotificationDeliveryService(inbox: inbox, adapters: [.sound: failing])

        let report = await service.deliver(.sample, through: [.sound])

        XCTAssertTrue(report.inboxRecorded)
        XCTAssertEqual(inbox.events.count, 1)
        guard case .failed = report.outcomes[.sound] else {
            return XCTFail("Expected a per-channel failure")
        }
    }

    func testInboxUnreadAndPersistenceLifecycle() throws {
        let persistence = MemoryPersistence()
        let inbox = InboxStore(persistence: persistence)
        let first = CoachingEvent(applicationName: "Finder", actionTitle: "New Window", shortcut: "⌘N")
        let second = CoachingEvent(applicationName: "Safari", actionTitle: "New Tab", shortcut: "⌘T")

        try inbox.append(first)
        try inbox.append(second)
        XCTAssertEqual(inbox.unreadCount, 2)

        inbox.markRead(first.id)
        XCTAssertEqual(inbox.unreadCount, 1)
        XCTAssertEqual(InboxStore(persistence: persistence).events.count, 2)

        inbox.markAllRead()
        XCTAssertEqual(inbox.unreadCount, 0)

        inbox.clear()
        XCTAssertTrue(persistence.stored.isEmpty)
    }

    func testPreferencesDefaultToVisiblePresenceAndPersistChannelCombinations() {
        let suite = "ShortcutCoachTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = AppPreferences(defaults: defaults)
        XCTAssertTrue(preferences.showInDockAndSwitcher)
        XCTAssertEqual(preferences.selectedChannels, [.topRightToast, .dockBadge])

        preferences.set(.sound, enabled: true)
        preferences.set(.topRightToast, enabled: false)
        preferences.showInDockAndSwitcher = false

        let restored = AppPreferences(defaults: defaults)
        XCTAssertFalse(restored.showInDockAndSwitcher)
        XCTAssertEqual(restored.selectedChannels, [.dockBadge, .sound])
    }

    func testPreferencesMigrateFromEitherPreviousBundleIdentity() {
        for sourceIndex in 0..<2 {
            let currentSuite = "ShortcutCoachTests-current-\(UUID().uuidString)"
            let oldestSuite = "ShortcutCoachTests-oldest-\(UUID().uuidString)"
            let recentSuite = "ShortcutCoachTests-recent-\(UUID().uuidString)"
            let current = UserDefaults(suiteName: currentSuite)!
            let oldest = UserDefaults(suiteName: oldestSuite)!
            let recent = UserDefaults(suiteName: recentSuite)!
            defer {
                current.removePersistentDomain(forName: currentSuite)
                oldest.removePersistentDomain(forName: oldestSuite)
                recent.removePersistentDomain(forName: recentSuite)
            }
            let source = [recent, oldest][sourceIndex]
            source.set([NotificationChannel.topCenterShelf.rawValue, NotificationChannel.sound.rawValue], forKey: "selectedNotificationChannels")
            source.set(false, forKey: "showInDockAndSwitcher")

            let migrated = AppPreferences(defaults: current, legacyDefaults: [recent, oldest])

            XCTAssertEqual(migrated.selectedChannels, [.topCenterShelf, .sound])
            XCTAssertFalse(migrated.showInDockAndSwitcher)
            XCTAssertEqual(current.array(forKey: "selectedNotificationChannels") as? [String], ["sound", "topCenterShelf"])
            XCTAssertEqual(current.bool(forKey: "showInDockAndSwitcher"), false)
        }
    }

    func testSERPBrandingConfiguresTheActualStatusBarButtonContract() {
        XCTAssertEqual(
            ProductIdentity.legacyBundleIdentifiers,
            ["com.serpcompany.shortcutcoach", "co.serp.shortcutcoach"]
        )
        let button = NSStatusBarButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        let target = StatusItemActionTarget()

        StatusItemBranding.configure(
            button,
            target: target,
            action: #selector(StatusItemActionTarget.activate(_:))
        )

        XCTAssertEqual(ProductIdentity.statusItemImageName, "SERPMenuBarMark")
        XCTAssertNotNil(button.image)
        XCTAssertEqual(button.image?.isTemplate, true)
        XCTAssertEqual(button.image?.size, NSSize(width: 17, height: 17))
        // NSStatusBarButton normalizes .imageOnly to .imageOverlaps. The empty
        // title is the observable contract that leaves only the image visible.
        XCTAssertEqual(button.imagePosition, .imageOverlaps)
        XCTAssertEqual(button.title, "")
        XCTAssertEqual(button.toolTip, "Shortcut Coach")
        XCTAssertEqual(button.accessibilityLabel(), "Shortcut Coach")
        XCTAssertTrue(button.target === target)
        XCTAssertEqual(button.action, #selector(StatusItemActionTarget.activate(_:)))
    }

    func testReleaseLanesHaveSeparateIdentitiesAndCapabilities() {
        XCTAssertEqual(ReleaseLane.full.productName, "Shortcut Coach")
        XCTAssertEqual(ReleaseLane.full.bundleIdentifier, "com.serp.shortcutcoach")
        XCTAssertTrue(ReleaseLane.full.supportsManualActionDetection)
        XCTAssertFalse(ReleaseLane.full.showsFullVersionCTA)

        XCTAssertEqual(ReleaseLane.appStoreLite.productName, "Shortcut Coach Lite")
        XCTAssertEqual(ReleaseLane.appStoreLite.bundleIdentifier, "com.serp.shortcutcoach.lite")
        XCTAssertFalse(ReleaseLane.appStoreLite.supportsManualActionDetection)
        XCTAssertTrue(ReleaseLane.appStoreLite.showsFullVersionCTA)
        XCTAssertEqual(ReleaseLane.fullVersionURL.scheme, "https")
    }

    func testLiteShortcutCatalogIsUsefulAndSearchable() {
        XCTAssertGreaterThanOrEqual(ShortcutCatalog.tips.count, 12)
        XCTAssertTrue(ShortcutCatalog.applications.contains("Finder"))
        XCTAssertTrue(ShortcutCatalog.applications.contains("Google Chrome"))
        XCTAssertEqual(
            ShortcutCatalog.matching(searchText: "trash", application: "Finder").map(\.shortcut),
            ["⌘Delete"]
        )
        XCTAssertTrue(
            ShortcutCatalog.matching(searchText: "copy", application: "Safari")
                .contains(where: { $0.applicationName == "General" })
        )
    }

    func testEveryPresentationChannelHasStableCopyAndIdentity() {
        XCTAssertEqual(Set(NotificationChannel.allCases.map(\.id)).count, NotificationChannel.allCases.count)
        for channel in NotificationChannel.allCases {
            XCTAssertFalse(channel.title.isEmpty)
            XCTAssertFalse(channel.summary.isEmpty)
            XCTAssertFalse(channel.systemImage.isEmpty)
        }
    }

    func testShortcutFormatterUsesAccessibilityModifierBits() {
        XCTAssertEqual(ShortcutFormatter.format(command: "n", modifiers: 0), "⌘N")
        XCTAssertEqual(ShortcutFormatter.format(command: "t", modifiers: 1), "⇧⌘T")
        XCTAssertEqual(ShortcutFormatter.format(command: "f", modifiers: 2 | 4), "⌃⌥⌘F")
        XCTAssertEqual(ShortcutFormatter.format(command: "a", modifiers: 8), "A")
    }

    func testCoachingCopyUsesTheDetectedEvent() {
        let event = CoachingEvent(applicationName: "Safari", actionTitle: "New Tab", shortcut: "⌘T")
        XCTAssertEqual(event.coachingTitle, "Try ⌘T next time")
        XCTAssertEqual(event.coachingBody, "New Tab in Safari")
    }
}
