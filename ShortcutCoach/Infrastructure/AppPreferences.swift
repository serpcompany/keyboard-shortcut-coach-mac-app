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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let rawChannels = defaults.array(forKey: Key.selectedChannels) as? [String] {
            selectedChannels = Set(rawChannels.compactMap(NotificationChannel.init(rawValue:)))
        } else {
            selectedChannels = [.topRightToast, .dockBadge]
        }

        if defaults.object(forKey: Key.showInDockAndSwitcher) == nil {
            showInDockAndSwitcher = true
        } else {
            showInDockAndSwitcher = defaults.bool(forKey: Key.showInDockAndSwitcher)
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

