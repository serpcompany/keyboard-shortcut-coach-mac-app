import SwiftUI

@main
struct ShortcutCoachApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Shortcut Coach", id: "main") {
            SettingsRootView()
                .environment(model)
                .task { model.start() }
                .modifier(OpenMainWindowListener())
        }
        .defaultSize(width: 920, height: 640)
        .commands {
            CommandGroup(replacing: .appSettings) {
                OpenMainWindowButton(title: "Settings…")
                    .keyboardShortcut(",", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuInboxView()
                .environment(model)
                .task { model.start() }
        } label: {
            Label(
                model.unreadCount == 0 ? "Shortcut Coach" : "Shortcut Coach, \(model.unreadCount) unread",
                systemImage: model.unreadCount == 0 ? "keyboard" : "keyboard.badge.ellipsis"
            )
        }
        .menuBarExtraStyle(.window)
    }
}

private struct OpenMainWindowListener: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}

private struct OpenMainWindowButton: View {
    let title: String
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(title) {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
