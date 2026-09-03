import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case inbox = "History"
    case notifications = "Notification Styles"
    case presence = "App Presence"
    case permissions = "Permissions"
    case diagnostics = "Diagnostics"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .inbox: "clock.arrow.circlepath"
        case .notifications: "bell.badge"
        case .presence: "macwindow"
        case .permissions: "hand.raised"
        case .diagnostics: "stethoscope"
        }
    }
}

struct SettingsRootView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: SettingsSection? = .notifications

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            Group {
                switch selection ?? .notifications {
                case .inbox: HistorySettingsView()
                case .notifications: NotificationStylesView()
                case .presence: AppPresenceSettingsView()
                case .permissions: PermissionSettingsView()
                case .diagnostics: DiagnosticsView()
                }
            }
            .environment(model)
        }
        .navigationTitle("Shortcut Coach")
    }
}

private struct NotificationStylesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                Label("Every coaching event is saved to the inbox first. Enable any combination of additional presentation styles.", systemImage: "tray.full")
                    .foregroundStyle(.secondary)
            }
            Section("Presentation channels") {
                ForEach(NotificationChannel.allCases) { channel in
                    LabeledContent {
                        HStack {
                            Button("Preview") {
                                Task { await model.deliverSample(channel: channel) }
                            }
                            Toggle("Enable \(channel.title)", isOn: Binding(
                                get: { model.preferences.selectedChannels.contains(channel) },
                                set: { model.setChannel(channel, enabled: $0) }
                            ))
                            .labelsHidden()
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(channel.title)
                                Text(channel.summary).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: channel.systemImage).frame(width: 24)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Notification Styles")
    }
}

private struct AppPresenceSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section("macOS surfaces") {
                Toggle("Show in Dock and App Switcher", isOn: Binding(
                    get: { model.preferences.showInDockAndSwitcher },
                    set: { model.setShowInDockAndSwitcher($0) }
                ))
                Text("macOS couples ordinary Dock presence with Cmd-Tab app-switcher presence. The menu-bar item remains available either way.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("App Presence")
    }
}

private struct PermissionSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section("Accessibility") {
                LabeledContent("Status") {
                    Label(model.isAccessibilityTrusted ? "Granted" : "Required", systemImage: model.isAccessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(model.isAccessibilityTrusted ? .green : .orange)
                }
                Text("Accessibility permission lets Shortcut Coach identify supported manually clicked menu commands and Chrome tab controls. Processing stays on this Mac.")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Request Permission") { model.requestAccessibilityPermission() }
                    Button("Retry Detection") { model.retryDetection() }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Permissions")
    }
}

private struct DiagnosticsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section("Detector") {
                LabeledContent("Status", value: detectorDescription)
                Text("A successful test event proves the delivery path. It does not prove manual-action detection; that requires a real click in another app.")
                    .foregroundStyle(.secondary)
            }
            Section("Delivery") {
                Button("Send Test Coaching Event") {
                    Task { await model.deliverSample() }
                }
                if let report = model.lastReport {
                    LabeledContent("Inbox", value: report.inboxRecorded ? "Recorded" : "Failed")
                    ForEach(report.outcomes.keys.sorted(by: { $0.rawValue < $1.rawValue })) { channel in
                        LabeledContent(channel.title, value: outcomeText(report.outcomes[channel]))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Diagnostics")
    }

    private var detectorDescription: String {
        switch model.detectorStatus {
        case .stopped: "Stopped"
        case .permissionRequired: "Accessibility permission required"
        case .monitoring: "Monitoring supported manual pointer actions"
        case .failed(let message): "Failed: \(message)"
        }
    }

    private func outcomeText(_ outcome: DeliveryOutcome?) -> String {
        switch outcome {
        case .delivered: "Delivered"
        case .failed(let message): "Failed: \(message)"
        case nil: "Not attempted"
        }
    }
}

private struct HistorySettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var searchText = ""

    private var filteredEvents: [CoachingEvent] {
        guard !searchText.isEmpty else { return model.inbox.events }
        return model.inbox.events.filter {
            $0.actionTitle.localizedCaseInsensitiveContains(searchText) ||
            $0.applicationName.localizedCaseInsensitiveContains(searchText) ||
            $0.shortcut.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(model.inbox.events.count) events · \(model.unreadCount) unread")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Mark All Read") { model.markAllRead() }.disabled(model.unreadCount == 0)
                Button("Clear History", role: .destructive) { model.clearHistory() }.disabled(model.inbox.events.isEmpty)
            }
            .padding()
            Divider()
            if filteredEvents.isEmpty {
                EmptyInboxView()
            } else {
                List(filteredEvents) { event in
                    CoachingEventRow(event: event)
                        .onTapGesture { model.markRead(event.id) }
                }
                .searchable(text: $searchText)
            }
        }
        .navigationTitle("History")
    }
}
