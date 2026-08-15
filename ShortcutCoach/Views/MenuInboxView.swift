import AppKit
import SwiftUI

struct MenuInboxView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.inbox.events.isEmpty {
                EmptyInboxView().frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.inbox.events.prefix(30)) { event in
                            Button {
                                model.markRead(event.id)
                            } label: {
                                CoachingEventRow(event: event)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 14)
                            Divider().padding(.leading, 34)
                        }
                    }
                }
            }
            Divider()
            footer
        }
        .frame(width: 410, height: 500)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Coaching Inbox").font(.headline)
                Text(model.unreadCount == 0 ? "You're caught up" : "\(model.unreadCount) unread")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Mark All Read") { model.markAllRead() }
                .disabled(model.unreadCount == 0)
        }
        .padding(14)
    }

    private var footer: some View {
        HStack {
            Button("Send Test") {
                Task { await model.deliverSample() }
            }
            Spacer()
            Button("Open Settings…") {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        .padding(12)
    }
}

