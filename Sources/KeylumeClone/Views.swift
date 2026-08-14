import AppKit
import Observation
import SwiftUI

struct StatusMenu: View {
    let model: AppModel

    var body: some View {
        Label("Keylume Clone", systemImage: "keyboard")
            .font(.headline)
        Text("v\(AppModel.version)")
        Divider()
        Label("Watching: \(model.activeApplicationName)", systemImage: "eye")
        Divider()
        Button("Analytics…", systemImage: "chart.bar", action: model.showAnalytics)
        Button("Settings…", systemImage: "gear", action: model.showSettings)
            .keyboardShortcut(",", modifiers: .command)
        Menu("Presentation Showcase", systemImage: "sparkles") {
            ForEach(PresentationMode.allCases) { mode in
                Button(mode.title) { model.previewPresentation(mode) }
            }
            Divider()
            Button("Run All Six Modes", systemImage: "play.fill", action: model.runPresentationShowcase)
            Button("Hide Showcase", systemImage: "xmark", action: model.dismissPresentationShowcase)
        }
        Button("Check for Updates…", systemImage: "arrow.triangle.2.circlepath", action: model.checkForUpdates)
        Divider()
        Label(model.license.state.menuLabel, systemImage: "clock")
        Divider()
        Button("Quit Keylume Clone") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}

struct OnboardingView: View {
    let model: AppModel
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            switch page {
            case 0: OnboardingWelcomePage()
            case 1: OnboardingAccessibilityPage(model: model)
            case 2: OnboardingHowItWorksPage()
            default: OnboardingTrialPage()
            }
            OnboardingFooter(
                page: page,
                back: { page = max(0, page - 1) },
                next: advance
            )
        }
        .frame(width: 520, height: 420)
    }

    private func advance() {
        if page == 3 { model.completeOnboarding() } else { page += 1 }
    }
}

private struct OnboardingWelcomePage: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            Text("Welcome to Keylume Clone").font(.largeTitle.bold())
            Text("Discover keyboard shortcuts for any app.\nLearn them naturally, one nudge at a time.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}

private struct OnboardingAccessibilityPage: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 58))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Accessibility Access").font(.largeTitle.bold())
            Text("Keylume Clone reads menu shortcuts from other apps.\nThis requires accessibility access in System Settings.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Text("System Settings").onboardingChip()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                Text("Privacy & Security").onboardingChip()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                Text("Accessibility").onboardingChip()
            }
            if model.accessibilityStatus == .granted {
                Label("Access granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.headline)
            } else {
                Button("Enable Accessibility") {
                    model.requestAccessibility()
                    model.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
    }
}

private struct OnboardingHowItWorksPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Text("How It Works").font(.largeTitle.bold()).frame(maxWidth: .infinity)
            OnboardingFeature(icon: "command.square.fill", color: .blue, title: "Hold ⌘ to see shortcuts", detail: "Hold the right Command key for 1.5 seconds while any app is active.")
            OnboardingFeature(icon: "lightbulb.fill", color: .yellow, title: "Learn while you work", detail: "When you click a menu item that has a shortcut, Keylume Clone gently reminds you.")
            OnboardingFeature(icon: "chart.bar.fill", color: .green, title: "Track your progress", detail: "See your keyboard vs. mouse usage and which shortcuts to learn next.")
            Spacer()
        }
        .padding(.horizontal, 54)
    }
}

private struct OnboardingFeature: View {
    let icon: String
    let color: Color
    let title: LocalizedStringResource
    let detail: LocalizedStringResource

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            Image(systemName: icon).font(.title).foregroundStyle(color).frame(width: 34).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingTrialPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "gift.fill").font(.system(size: 58)).foregroundStyle(.blue).accessibilityHidden(true)
            Text("Enjoy 14 Days Free").font(.largeTitle.bold())
            Text("After your trial, unlock Keylume Clone for a one-time purchase — yours forever.")
                .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack { Text("✓  All features included").onboardingChip(); Text("✓  No credit card needed").onboardingChip() }
            HStack { Text("✓  One-time payment").onboardingChip(); Text("✓  Lifetime updates").onboardingChip() }
            Spacer()
        }
    }
}

private struct OnboardingFooter: View {
    let page: Int
    let back: () -> Void
    let next: () -> Void

    var body: some View {
        HStack {
            Button("Back", action: back).opacity(page == 0 ? 0 : 1).disabled(page == 0)
            Spacer()
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { index in
                    Circle().fill(index == page ? Color.blue : Color.secondary.opacity(0.35)).frame(width: 8, height: 8)
                }
            }
            Spacer()
            Button(page == 3 ? "Start Using Keylume Clone" : "Next", action: next)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }
}

private extension View {
    func onboardingChip() -> some View {
        padding(.horizontal, 12).padding(.vertical, 6).background(.quaternary, in: .rect(cornerRadius: 8))
    }
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General"
    case coaching = "Coaching"
    case about = "About"
    var id: String { rawValue }
}

struct SettingsView: View {
    let model: AppModel
    @Bindable private var preferences: AppPreferences
    @State private var selectedPane = SettingsPane.general

    init(model: AppModel) {
        self.model = model
        preferences = model.preferences
    }

    var body: some View {
        VStack(spacing: 4) {
            Picker("Settings", selection: $selectedPane) {
                ForEach(SettingsPane.allCases) { pane in Text(pane.rawValue).tag(pane) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .focusable(false)
            .frame(width: 240)
            .offset(y: -32)

            switch selectedPane {
            case .general: GeneralSettingsPane(model: model, preferences: preferences)
            case .coaching: CoachingSettingsPane(model: model, preferences: preferences, reset: model.resetDismissedShortcuts)
            case .about: AboutSettingsPane(model: model)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .padding(.top, 12)
        .frame(width: 480, height: 560)
    }
}

private struct GeneralSettingsPane: View {
    let model: AppModel
    @Bindable var preferences: AppPreferences
    @FocusState private var triggerFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 0) {
                HStack {
                    Text("Trigger key")
                    Spacer()
                    Picker("Trigger key", selection: $preferences.triggerKey) {
                        ForEach(TriggerKey.allCases) { Text($0.label).tag($0) }
                    }.labelsHidden().frame(width: 170).focused($triggerFocused).defaultFocus($triggerFocused, true)
                }.settingsRow()
                Divider()
                HStack {
                    Text("Hold duration")
                    Spacer()
                    HStack {
                        Slider(value: $preferences.holdDuration, in: 0.5...3, step: 0.1).frame(width: 120)
                        Text(preferences.holdDuration, format: .number.precision(.fractionLength(1))).monospacedDigit()
                        Text("s")
                    }
                }.settingsRow()
                Divider()
                HStack {
                    Text("Appearance")
                    Spacer()
                    Picker("Appearance", selection: $preferences.appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.label).tag($0) }
                    }.labelsHidden().frame(width: 120).onChange(of: preferences.appearance) { model.appearanceChanged() }
                }.settingsRow()
                Divider()
                HStack {
                    Text("Launch at login")
                    Spacer()
                    Toggle("Launch at login", isOn: $preferences.launchAtLogin).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                }.settingsRow()
                Divider()
                HStack {
                    Text("Automatically check for updates")
                    Spacer()
                    Toggle("Automatically check for updates", isOn: $preferences.automaticUpdates).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                }.settingsRow()
            }.settingsCard()

            Text("Excluded Apps").font(.headline).padding(.top, 11).padding(.bottom, -8)
            VStack(alignment: .leading, spacing: 0) {
                if preferences.excludedApps.isEmpty {
                    Text("No apps excluded").foregroundStyle(.secondary).settingsRow()
                } else {
                    ForEach(preferences.excludedApps, id: \.self) { identifier in
                        HStack {
                            Text(identifier)
                            Spacer()
                            Button("Remove", systemImage: "minus.circle") { preferences.removeExcludedApplication(identifier) }.labelStyle(.iconOnly)
                        }.settingsRow()
                    }
                }
                Divider()
                Button("Add App…", systemImage: "plus", action: model.addExcludedApplication)
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .focusable(false)
                    .settingsRow()
            }.padding(.vertical, 4).settingsCard()
            if let error = preferences.loginItemError { Text(error).font(.caption).foregroundStyle(.red) }
        }
    }
}

private struct CoachingSettingsPane: View {
    let model: AppModel
    @Bindable var preferences: AppPreferences
    let reset: () -> Void

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 0) {
                HStack {
                    Text("Enable coaching nudges")
                    Spacer()
                    Toggle("Enable coaching nudges", isOn: $preferences.coachingEnabled).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                }.settingsRow()
                Text("Keylume Clone will suggest keyboard shortcuts when you click menu items")
                    .font(.caption).foregroundStyle(.secondary).settingsRow()
                Divider()
                HStack {
                    Text("Always show nudges")
                    Spacer()
                    Toggle("Always show nudges", isOn: $preferences.alwaysShowNudges).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                }.settingsRow()
                Divider()
                HStack {
                    Text("Max nudges per hour")
                    Spacer()
                    HStack {
                        Slider(value: $preferences.maxNudgesPerHour, in: 1...60, step: 1).frame(width: 120)
                        Text(Int(preferences.maxNudgesPerHour), format: .number).monospacedDigit().frame(width: 28)
                    }
                }.settingsRow()
                Divider()
                Button("Reset dismissed shortcuts", systemImage: "arrow.counterclockwise", action: reset).settingsRow()
            }.settingsCard()
            Text("Quiet Hours").font(.headline)
            VStack(spacing: 0) {
                HStack {
                    Text("Enable quiet hours")
                    Spacer()
                    Toggle("Enable quiet hours", isOn: $preferences.quietHoursEnabled).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                }.settingsRow()
                if preferences.quietHoursEnabled {
                    Divider()
                    HStack { Text("From"); Spacer(); DatePicker("From", selection: $preferences.quietHoursStart, displayedComponents: .hourAndMinute).labelsHidden() }.settingsRow()
                    Divider()
                    HStack { Text("Until"); Spacer(); DatePicker("Until", selection: $preferences.quietHoursEnd, displayedComponents: .hourAndMinute).labelsHidden() }.settingsRow()
                }
            }.settingsCard()

            HStack {
                Text("Presentation Modes").font(.headline)
                Spacer()
                Button("Run All", systemImage: "play.fill", action: model.runPresentationShowcase)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            Text("These local previews use the real presentation path and do not add analytics.")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                presentationRow("Top-center presence", isOn: $preferences.topCenterPresenceEnabled, mode: .topCenterPresence)
                Divider()
                presentationRow("Compact → Expanded shelf", isOn: $preferences.compactExpandedShelfEnabled, mode: .compactExpandedShelf)
                Divider()
                presentationRow("Cursor opportunity halo", isOn: $preferences.cursorHaloEnabled, mode: .cursorHalo)
                Divider()
                presentationRow("Status feedback", isOn: $preferences.statusFeedbackEnabled, mode: .statusFeedback)
                Divider()
                presentationRow("Pointer-anchored card", isOn: $preferences.pointerCardEnabled, mode: .pointerCard)
                Divider()
                presentationRow("Decision banner", isOn: $preferences.decisionBannerEnabled, mode: .decisionBanner)
                Divider()
                Button("Reset presentation defaults", systemImage: "arrow.counterclockwise", action: preferences.resetPresentationDefaults)
                    .settingsRow()
            }
            .settingsCard()
        }
        .padding(.bottom, 8)
        }
    }

    private func presentationRow(_ title: String, isOn: Binding<Bool>, mode: PresentationMode) -> some View {
        HStack {
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
            Spacer()
            Button("Preview") { model.previewPresentation(mode) }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .settingsRow()
    }
}

private struct AboutSettingsPane: View {
    let model: AppModel
    @State private var licenseKey = ""

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 58)).foregroundStyle(.blue).accessibilityHidden(true)
            Text("Keylume Clone").font(.title.bold())
            Text("Version \(AppModel.version)").foregroundStyle(.secondary)
            Text("Made with ♥ for macOS").foregroundStyle(.secondary)
            HStack {
                Button("Project README", systemImage: "doc.text") { openBundledDocument("README.md") }
                Button("Privacy", systemImage: "hand.raised") { openBundledDocument("privacy.md") }
            }.buttonStyle(.link)
            Label(model.license.state.menuLabel, systemImage: "clock")
                .padding(.horizontal, 14).padding(.vertical, 7).background(.quaternary, in: Capsule())
            if model.license.state == .licensed {
                Button("Deactivate License", action: model.deactivateLicense)
            } else {
                HStack {
                    TextField("KEYLUME-XXXX-XXXX-XXXX", text: $licenseKey)
                    Button("Activate") { _ = model.activateLicense(licenseKey) }.disabled(licenseKey.isEmpty)
                }.frame(width: 320)
            }
            if let error = model.license.activationError { Text(error).foregroundStyle(.red).font(.caption) }
            Spacer()
        }
    }

    private func openBundledDocument(_ name: String) {
        guard let url = Bundle.main.resourceURL?.appending(path: name),
              FileManager.default.fileExists(atPath: url.path)
        else { return }
        NSWorkspace.shared.open(url)
    }
}

private extension View {
    func settingsRow() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }
    func settingsCard() -> some View { background(Color.white.opacity(0.03), in: .rect(cornerRadius: 12)) }
}

@MainActor
@Observable
private final class OverlaySearchModel {
    let source: [AppShortcut]
    var query = "" { didSet { recompute() } }
    private(set) var grouped: [(category: String, shortcuts: [AppShortcut])] = []

    init(source: [AppShortcut]) {
        self.source = source
        recompute()
    }

    private func recompute() {
        let filtered = query.isEmpty ? source : source.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.category.localizedCaseInsensitiveContains(query) || $0.display.localizedCaseInsensitiveContains(query)
        }
        var order: [String] = []
        var buckets: [String: [AppShortcut]] = [:]
        for shortcut in filtered {
            if buckets[shortcut.category] == nil { order.append(shortcut.category) }
            buckets[shortcut.category, default: []].append(shortcut)
        }
        grouped = order.map { ($0, buckets[$0] ?? []) }
    }
}

struct ShortcutOverlayView: View {
    let model: AppModel
    @State private var search: OverlaySearchModel

    init(model: AppModel) {
        self.model = model
        _search = State(initialValue: OverlaySearchModel(source: model.shortcuts))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Group {
                    if let icon = model.activeApplicationIcon { Image(nsImage: icon).resizable() }
                    else { Image(systemName: "app.fill").resizable() }
                }.scaledToFit().frame(width: 34, height: 34)
                VStack(alignment: .leading) {
                    Text(model.activeApplicationName).font(.title2.bold())
                    Text("\(model.shortcuts.count) keyboard shortcuts").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close", systemImage: "xmark.circle.fill", action: model.dismissOverlay)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
                    .help("Dismiss (Esc)")
            }.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)
            MacSearchField(text: $search.query, placeholder: "Search shortcuts…")
                .padding(.horizontal, 16).padding(.bottom, 12)
            Divider()
            if search.grouped.isEmpty {
                ContentUnavailableView(
                    search.query.isEmpty ? "No shortcuts found" : "No shortcuts match \"\(search.query)\"",
                    systemImage: "magnifyingglass",
                    description: Text(search.query.isEmpty ? "This app does not expose menu shortcuts." : "Try a different search term")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(search.grouped, id: \.category) { group in
                            ShortcutCategorySection(category: group.category, shortcuts: group.shortcuts, execute: model.execute)
                        }
                    }.padding(18)
                }
            }
        }
        .frame(width: 660, height: 532)
        .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: 16))
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(.quaternary) }
    }
}

private struct ShortcutCategorySection: View {
    let category: String
    let shortcuts: [AppShortcut]
    let execute: (AppShortcut) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category).font(.headline).foregroundStyle(.secondary).padding(.vertical, 8)
            ForEach(shortcuts) { shortcut in ShortcutRow(shortcut: shortcut) { execute(shortcut) } }
        }
    }
}

private struct ShortcutRow: View {
    let shortcut: AppShortcut
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(shortcut.menuLocation).font(.caption).foregroundStyle(.tertiary).lineLimit(1).frame(width: 40, alignment: .leading)
                Text(shortcut.title).foregroundStyle(.primary)
                Spacer()
                KeycapSequence(display: shortcut.display)
            }.padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(shortcut.menuLocation), \(shortcut.title), \((shortcut.modifiers.symbols + [shortcut.key.uppercased()]).joined(separator: ", "))"
        )
    }
}

private struct MacSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.sendsSearchStringImmediately = true
        field.focusRingType = .none
        field.delegate = context.coordinator
        DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) { _text = text }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            text = field.stringValue
        }
    }
}

private struct KeycapSequence: View {
    let display: String
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(display.enumerated()), id: \.offset) { _, character in
                Text(String(character)).font(.system(.body, design: .rounded).weight(.semibold))
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Color.black.opacity(0.12), in: .rect(cornerRadius: 6))
                    .overlay { RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.10)) }
            }
        }
    }
}

struct CoachingToastView: View {
    let shortcut: AppShortcut
    let onClose: () -> Void
    let onDismissPermanently: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(.blue).frame(width: 3, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text("Keyboard shortcut available").font(.headline).foregroundStyle(.secondary)
                HStack(spacing: 8) { Text("Use"); Text(shortcut.display).keycap(); Text("instead") }.font(.system(size: 16))
            }
            Spacer()
            Button("Close", systemImage: "xmark.circle.fill", action: onClose).labelStyle(.iconOnly).buttonStyle(.plain).font(.title2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(width: 380, height: 62)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
        .compositingGroup().clipShape(.rect(cornerRadius: 14))
        .contextMenu { Button("Don't show for this shortcut", action: onDismissPermanently) }
    }
}

private extension View {
    func keycap() -> some View { padding(.horizontal, 8).padding(.vertical, 4).background(.blue.opacity(0.18), in: .rect(cornerRadius: 6)).foregroundStyle(.blue) }
}

struct AnalyticsDashboardView: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                AnalyticsHeader(refresh: model.refreshAnalytics)
                ThisWeekSection(snapshot: model.analytics)
                ShortcutSummarySection(title: "Mastered Shortcuts", subtitle: "You're using these like a pro.", icon: "checkmark.seal.fill", color: .blue, summaries: model.analytics.mastered, countSuffix: "uses")
                ShortcutSummarySection(title: "Learn These Next", subtitle: "You reached for the mouse when a shortcut was available.", icon: "lightbulb.fill", color: .yellow, summaries: model.analytics.toLearn, countSuffix: "missed")
                PerAppSection(summaries: model.analytics.perApp)
            }.padding(20)
        }
        .frame(width: 500, height: 600)
    }
}

private struct AnalyticsHeader: View {
    let refresh: () -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading) { Text("Your Shortcut Progress").font(.title2.bold()); Text("This week's usage summary").foregroundStyle(.secondary) }
            Spacer()
            Button("Refresh", systemImage: "arrow.clockwise", action: refresh).labelStyle(.iconOnly).buttonStyle(.plain).font(.title2).foregroundStyle(.secondary)
        }
    }
}

private struct ThisWeekSection: View {
    let snapshot: AnalyticsSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("This Week", systemImage: "calendar").font(.headline)
            HStack(spacing: 12) {
                StatCard(icon: "keyboard", value: "\(snapshot.keyboardCount)", label: "Keyboard", color: .blue)
                StatCard(icon: "cursorarrow.click", value: "\(snapshot.mouseCount)", label: "Mouse Clicks", color: .secondary)
                StatCard(icon: "arrow.up.right", value: "\(snapshot.changePercent >= 0 ? "+" : "")\(snapshot.changePercent)%", label: "vs last week", color: .green)
            }
            HStack { Text("Keyboard ratio"); Spacer(); Text("\(snapshot.keyboardRatio)%").monospacedDigit() }.foregroundStyle(.secondary).font(.caption.bold())
            ProgressView(value: Double(snapshot.keyboardRatio), total: 100).tint(.blue)
            if let top = snapshot.topShortcut {
                HStack { Image(systemName: "star.fill").foregroundStyle(.yellow); Text("Top shortcut: \(top.title) (\(top.display))").foregroundStyle(.secondary) }
            }
        }
    }
}

private struct StatCard: View {
    let icon: String, value: String, label: String
    let color: Color
    var body: some View {
        VStack(spacing: 8) { Image(systemName: icon); Text(value).font(.title.bold()).monospacedDigit(); Text(label).font(.caption.bold()).foregroundStyle(.secondary) }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.06), in: .rect(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06)) }
    }
}

private struct ShortcutSummarySection: View {
    let title, subtitle, icon: String
    let color: Color
    let summaries: [ShortcutUsageSummary]
    let countSuffix: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: icon).foregroundStyle(.secondary); Text(title).font(.headline) }
            Text(subtitle).foregroundStyle(.secondary)
            if summaries.isEmpty { Text("No usage yet").foregroundStyle(.tertiary).padding(.vertical, 8) }
            ForEach(summaries) { summary in
                HStack {
                    Image(systemName: icon).foregroundStyle(color).frame(width: 20)
                    Text(summary.display).keycap()
                    Text(summary.title)
                    Spacer()
                    Text("\(summary.count) \(countSuffix)").foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct PerAppSection: View {
    let summaries: [AppUsageSummary]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Per App", systemImage: "square.grid.2x2").font(.headline)
            ForEach(summaries) { summary in
                HStack { Text(summary.appName); Spacer(); Image(systemName: "keyboard.fill"); Text(summary.keyboardCount, format: .number); Text("/"); Image(systemName: "computermouse.fill"); Text(summary.mouseCount, format: .number) }
            }
        }
    }
}
