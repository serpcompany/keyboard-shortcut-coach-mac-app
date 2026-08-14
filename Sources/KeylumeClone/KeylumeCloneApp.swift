import AppKit
import SwiftUI

@main
struct KeylumeCloneApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            CoachingInboxPopover(model: AppModel.shared)
        } label: {
            MenuBarCoachingLabel(model: AppModel.shared)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppModel.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { AppModel.shared.showCoachingHistory() }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AppModel.shared.syncDockBadge()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { AppModel.shared.handle(url: url) }
    }
}
