import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let releaseLane: ReleaseLane
    let preferences: AppPreferences
    let inbox: InboxStore

    private let delivery: NotificationDeliveryService
    private let detector: ManualActionDetector
    private let presenceController: any AppPresenceControlling

    private(set) var lastReport: DeliveryReport?
    private(set) var isStarted = false

    var unreadCount: Int { inbox.unreadCount }
    var isAccessibilityTrusted: Bool { detector.isAccessibilityTrusted }
    var isInputMonitoringAuthorized: Bool { detector.isInputMonitoringAuthorized }
    var detectorStatus: ManualActionDetector.Status {
        releaseLane.supportsManualActionDetection ? detector.status : .stopped
    }

    convenience init() {
        self.init(
            releaseLane: .current,
            preferences: AppPreferences(
                defaults: .standard,
                legacyDefaults: ProductIdentity.legacyBundleIdentifiers.compactMap(UserDefaults.init(suiteName:))
            ),
            inbox: InboxStore(),
            presenceController: AppPresenceController(),
            detector: ManualActionDetector(),
            presenter: PresentationWindowController()
        )
    }

    init(
        releaseLane: ReleaseLane,
        preferences: AppPreferences,
        inbox: InboxStore,
        presenceController: any AppPresenceControlling,
        detector: ManualActionDetector,
        presenter: PresentationWindowController
    ) {
        self.releaseLane = releaseLane
        self.preferences = preferences
        self.inbox = inbox
        self.presenceController = presenceController
        self.detector = detector

        var adapters: [NotificationChannel: any ChannelDelivering] = [
            .nativeBanner: NativeNotificationAdapter(),
            .dockBadge: DockBadgeAdapter { inbox.unreadCount },
            .dockBounce: DockBounceAdapter(),
            .sound: SoundAdapter()
        ]
        for channel in NotificationChannel.allCases where adapters[channel] == nil {
            adapters[channel] = PanelChannelAdapter(channel: channel, presenter: presenter)
        }
        delivery = NotificationDeliveryService(inbox: inbox, adapters: adapters)

        detector.onEvent = { [weak self] event in
            Task { @MainActor in
                await self?.deliver(event)
            }
        }
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        presenceController.apply(showInDockAndSwitcher: preferences.showInDockAndSwitcher)
        if releaseLane.supportsManualActionDetection {
            detector.start()
        }
        refreshDockBadge()
    }

    func requestAccessibilityPermission() {
        guard releaseLane.supportsManualActionDetection else { return }
        detector.requestAccessibilityPermission()
    }

    func requestInputMonitoringPermission() {
        guard releaseLane.supportsManualActionDetection else { return }
        detector.requestInputMonitoringPermission()
    }

    func retryDetection() {
        guard releaseLane.supportsManualActionDetection else { return }
        detector.start()
    }

    func deliverSample(channel: NotificationChannel? = nil) async {
        let channels = channel.map { Set([$0]) } ?? preferences.selectedChannels
        await deliver(.sample, through: channels)
    }

    func setChannel(_ channel: NotificationChannel, enabled: Bool) {
        preferences.set(channel, enabled: enabled)
    }

    func setShowInDockAndSwitcher(_ show: Bool) {
        preferences.showInDockAndSwitcher = show
        presenceController.apply(showInDockAndSwitcher: show)
    }

    func markRead(_ id: UUID) {
        inbox.markRead(id)
        refreshDockBadge()
    }

    func markAllRead() {
        inbox.markAllRead()
        refreshDockBadge()
    }

    func clearHistory() {
        inbox.clear()
        refreshDockBadge()
    }

    private func deliver(_ event: CoachingEvent, through channels: Set<NotificationChannel>? = nil) async {
        let selected = channels ?? preferences.selectedChannels
        lastReport = await delivery.deliver(event, through: selected)
        refreshDockBadge()
    }

    private func refreshDockBadge() {
        guard preferences.selectedChannels.contains(.dockBadge), inbox.unreadCount > 0 else {
            NSApplication.shared.dockTile.badgeLabel = nil
            return
        }
        NSApplication.shared.dockTile.badgeLabel = String(inbox.unreadCount)
    }
}
