import AppKit
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case library = "Shortcut Library"
    case inbox = "History"
    case notifications = "Presentation Channels"
    case presence = "App Presence"
    case permissions = "Permissions"
    case diagnostics = "Diagnostics"
    case about = "About"
    case upgrade = "Full Version"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .library: "keyboard"
        case .inbox: "clock.arrow.circlepath"
        case .notifications: "bell.badge"
        case .presence: "macwindow"
        case .permissions: "hand.raised"
        case .diagnostics: "stethoscope"
        case .about: "info.circle"
        case .upgrade: "arrow.up.right.square"
        }
    }

    static func available(for lane: ReleaseLane) -> [SettingsSection] {
        if lane == .appStoreLite {
            return [.library, .notifications, .presence, .upgrade, .about]
        }
        return [.inbox, .notifications, .presence, .permissions, .diagnostics, .about]
    }
}

struct SettingsRootView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: SettingsSection?

    init() {
        _selection = State(initialValue: ReleaseLane.current == .appStoreLite ? .library : .notifications)
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.available(for: model.releaseLane), selection: $selection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            Group {
                switch selection ?? (model.releaseLane == .appStoreLite ? .library : .notifications) {
                case .library: ShortcutLibraryView()
                case .inbox: HistorySettingsView()
                case .notifications: PresentationChannelsView()
                case .presence: AppPresenceSettingsView()
                case .permissions: PermissionSettingsView()
                case .diagnostics: DiagnosticsView()
                case .about: AboutView()
                case .upgrade: FullVersionView()
                }
            }
            .environment(model)
        }
        .navigationTitle(model.releaseLane.productName)
    }
}

private struct ShortcutLibraryView: View {
    @State private var searchText = ""
    @State private var selectedApplication: String? = nil
    @State private var lastExternalApplication: String?

    private var results: [ShortcutTip] {
        ShortcutCatalog.matching(searchText: searchText, application: selectedApplication)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Application", selection: $selectedApplication) {
                    Text("All Apps").tag(String?.none)
                    ForEach(ShortcutCatalog.applications, id: \.self) { application in
                        Text(application).tag(Optional(application))
                    }
                }
                .frame(width: 260)
                Spacer()
                if let lastExternalApplication {
                    Text("Last active: \(lastExternalApplication)")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            Divider()
            List(results) { tip in
                LabeledContent {
                    Text(tip.shortcut)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tip.actionTitle)
                        Text(tip.applicationName).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .searchable(text: $searchText, prompt: "Search actions or shortcuts")
        }
        .navigationTitle("Shortcut Library")
        .onAppear { captureExternalApplication(NSWorkspace.shared.frontmostApplication) }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)) { note in
            captureExternalApplication(note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
        }
    }

    private func captureExternalApplication(_ application: NSRunningApplication?) {
        guard let application,
              application.bundleIdentifier != Bundle.main.bundleIdentifier,
              let name = application.localizedName else { return }
        lastExternalApplication = name
        if ShortcutCatalog.applications.contains(name) {
            selectedApplication = name
        }
    }
}

private struct FullVersionView: View {
    var body: some View {
        VStack(spacing: 22) {
            Image(ProductIdentity.inAppBrandImageName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.primary)
                .frame(width: 92, height: 92)
                .accessibilityHidden(true)
            Text("Real-time click coaching")
                .font(.largeTitle.bold())
            Text("The full version can recognize supported actions in apps like Finder and Chrome, then show the keyboard shortcut you could use next time.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)
            Link(destination: ReleaseLane.fullVersionURL) {
                Label("Explore Shortcut Coach", systemImage: "arrow.up.right")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            Text("Opens the SERP website. Nothing is downloaded automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
        .navigationTitle("Full Version")
    }
}

private struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(ProductIdentity.inAppBrandImageName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.primary)
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)
            Text(ReleaseLane.current.productName)
                .font(.largeTitle.bold())
            Text("Turn manual actions into keyboard-shortcut habits.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Version \(version)")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("SERP · © 2026")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
        .navigationTitle("About")
        .accessibilityElement(children: .combine)
    }
}

private struct PresentationChannelsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                Label("Every coaching event is saved to the inbox first. Enable any combination of additional presentation channels.", systemImage: "tray.full")
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
        .navigationTitle("Presentation Channels")
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
            Section("Input Monitoring") {
                LabeledContent("Status") {
                    Label(model.isInputMonitoringAuthorized ? "Granted" : "Required", systemImage: model.isInputMonitoringAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(model.isInputMonitoringAuthorized ? .green : .orange)
                }
                Text("Input Monitoring permission lets Shortcut Coach passively observe mouse clicks. It never modifies or suppresses your input.")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Request Permission") { model.requestInputMonitoringPermission() }
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
        case .permissionRequired(let permissions):
            switch permissions {
            case [.accessibility]: "Accessibility permission required"
            case [.inputMonitoring]: "Input Monitoring permission required"
            default: "Accessibility and Input Monitoring permissions required"
            }
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
