import Foundation
import Observation

@MainActor
@Observable
final class AppPreferences {
    private enum Key {
        static let selectedChannels = "selectedNotificationChannels"
        static let showInDockAndSwitcher = "showInDockAndSwitcher"
    }

    private let defaults: UserDefaults

    var selectedChannels: Set<NotificationChannel> {
        didSet { persistChannels() }
    }

    var showInDockAndSwitcher: Bool {
        didSet { defaults.set(showInDockAndSwitcher, forKey: Key.showInDockAndSwitcher) }
    }

    init(defaults: UserDefaults = .standard, legacyDefaults: [UserDefaults] = []) {
        self.defaults = defaults
        let currentChannels = defaults.array(forKey: Key.selectedChannels) as? [String]
        let legacyChannels = legacyDefaults.lazy.compactMap {
            $0.array(forKey: Key.selectedChannels) as? [String]
        }.first
        let channelsWereNormalized: Bool
        if let rawChannels = currentChannels ?? legacyChannels {
            let decodedChannels = Set(rawChannels.compactMap(NotificationChannel.init(rawValue:)))
            let normalizedChannels = PresentationOverlapPolicy.normalized(decodedChannels)
            selectedChannels = normalizedChannels
            channelsWereNormalized = normalizedChannels != decodedChannels
        } else {
            selectedChannels = [.topRightToast, .dockBadge]
            channelsWereNormalized = false
        }

        if defaults.object(forKey: Key.showInDockAndSwitcher) != nil {
            showInDockAndSwitcher = defaults.bool(forKey: Key.showInDockAndSwitcher)
        } else if let legacyPresenceDefaults = legacyDefaults.first(where: {
            $0.object(forKey: Key.showInDockAndSwitcher) != nil
        }) {
            showInDockAndSwitcher = legacyPresenceDefaults.bool(forKey: Key.showInDockAndSwitcher)
        } else {
            showInDockAndSwitcher = true
        }

        if (currentChannels == nil && legacyChannels != nil) || channelsWereNormalized {
            persistChannels()
        }
        if defaults.object(forKey: Key.showInDockAndSwitcher) == nil,
           legacyDefaults.contains(where: { $0.object(forKey: Key.showInDockAndSwitcher) != nil }) {
            defaults.set(showInDockAndSwitcher, forKey: Key.showInDockAndSwitcher)
        }
    }

    func set(_ channel: NotificationChannel, enabled: Bool) {
        if enabled {
            selectedChannels = PresentationOverlapPolicy.selecting(channel, in: selectedChannels)
        } else {
            selectedChannels.remove(channel)
        }
    }

    private func persistChannels() {
        defaults.set(selectedChannels.map(\.rawValue).sorted(), forKey: Key.selectedChannels)
    }
}
