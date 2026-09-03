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

    init(defaults: UserDefaults = .standard, legacyDefaults: UserDefaults? = nil) {
        self.defaults = defaults
        let currentChannels = defaults.array(forKey: Key.selectedChannels) as? [String]
        let legacyChannels = legacyDefaults?.array(forKey: Key.selectedChannels) as? [String]
        if let rawChannels = currentChannels ?? legacyChannels {
            selectedChannels = Set(rawChannels.compactMap(NotificationChannel.init(rawValue:)))
        } else {
            selectedChannels = [.topRightToast, .dockBadge]
        }

        if defaults.object(forKey: Key.showInDockAndSwitcher) != nil {
            showInDockAndSwitcher = defaults.bool(forKey: Key.showInDockAndSwitcher)
        } else if let legacyDefaults, legacyDefaults.object(forKey: Key.showInDockAndSwitcher) != nil {
            showInDockAndSwitcher = legacyDefaults.bool(forKey: Key.showInDockAndSwitcher)
        } else {
            showInDockAndSwitcher = true
        }

        if currentChannels == nil, legacyChannels != nil {
            persistChannels()
        }
        if defaults.object(forKey: Key.showInDockAndSwitcher) == nil,
           legacyDefaults?.object(forKey: Key.showInDockAndSwitcher) != nil {
            defaults.set(showInDockAndSwitcher, forKey: Key.showInDockAndSwitcher)
        }
    }

    func set(_ channel: NotificationChannel, enabled: Bool) {
        if enabled {
            selectedChannels.insert(channel)
        } else {
            selectedChannels.remove(channel)
        }
    }

    private func persistChannels() {
        defaults.set(selectedChannels.map(\.rawValue).sorted(), forKey: Key.selectedChannels)
    }
}
