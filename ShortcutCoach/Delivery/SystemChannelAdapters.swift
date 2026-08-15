import AppKit
import UserNotifications

enum DeliveryAdapterError: LocalizedError {
    case notificationsDenied

    var errorDescription: String? {
        switch self {
        case .notificationsDenied: "macOS notification permission is not granted"
        }
    }
}

@MainActor
final class NativeNotificationAdapter: ChannelDelivering {
    func deliver(_ event: CoachingEvent) async throws {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        var status = settings.authorizationStatus
        if status == .notDetermined {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            status = (await center.notificationSettings()).authorizationStatus
        }
        guard status == .authorized || status == .provisional else {
            throw DeliveryAdapterError.notificationsDenied
        }

        let content = UNMutableNotificationContent()
        content.title = event.coachingTitle
        content.body = event.coachingBody
        try await center.add(UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: nil))
    }
}

@MainActor
final class DockBadgeAdapter: ChannelDelivering {
    private let unreadCount: () -> Int

    init(unreadCount: @escaping () -> Int) {
        self.unreadCount = unreadCount
    }

    func deliver(_ event: CoachingEvent) async throws {
        NSApplication.shared.dockTile.badgeLabel = String(unreadCount())
    }
}

@MainActor
final class DockBounceAdapter: ChannelDelivering {
    func deliver(_ event: CoachingEvent) async throws {
        NSApplication.shared.requestUserAttention(.informationalRequest)
    }
}

@MainActor
final class SoundAdapter: ChannelDelivering {
    func deliver(_ event: CoachingEvent) async throws {
        NSSound(named: "Glass")?.play()
    }
}

@MainActor
final class PanelChannelAdapter: ChannelDelivering {
    private let channel: NotificationChannel
    private let presenter: PresentationWindowController

    init(channel: NotificationChannel, presenter: PresentationWindowController) {
        self.channel = channel
        self.presenter = presenter
    }

    func deliver(_ event: CoachingEvent) async throws {
        presenter.show(event: event, style: channel)
    }
}
