import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.2"

    let preferences: AppPreferences
    let license: LicenseManager
    let accessibility = AccessibilityManager()

    private let menuReader = MenuReader()
    private let usageStore: UsageStore
    private let coachingHistoryStore: CoachingHistoryStore
    private let windows = WindowPresenter()
    private let updateChecker: UpdateChecker
    private let dockAttention = DockAttentionPresenter()
    private let coachingSound = CoachingSoundPresenter()
    private let nativeNotifications = NativeNotificationPresenter()
    private var eventMonitor: GlobalEventMonitor!
    private var activationObserver: NSObjectProtocol?
    private var holdTask: Task<Void, Never>?
    private var accessibilityPollingTask: Task<Void, Never>?
    private var nudgeTimestamps: [Date] = []
    private var lastNudgeDate: Date?
    private var started = false

    var accessibilityStatus: AccessibilityStatus = .denied
    var activeApplicationName = "No active app"
    var activeApplicationIcon: NSImage?
    var shortcuts: [AppShortcut] = []
    var usageRecords: [UsageRecord] = []
    var analytics: AnalyticsSnapshot = .empty
    var coachingEvents: [CoachingEvent] = []
    var coachingHistoryError: String?
    var selectedCoachingEventID: UUID?
    var nativeNotificationStatus = "Not requested"
    var updateStatus: UpdateStatus?
    var updateError: String?

    init(
        preferences: AppPreferences = AppPreferences(),
        license: LicenseManager = LicenseManager(),
        usageStore: UsageStore = UsageStore(),
        coachingHistoryStore: CoachingHistoryStore = CoachingHistoryStore(),
        updateChecker: UpdateChecker = UpdateChecker()
    ) {
        self.preferences = preferences
        self.license = license
        self.usageStore = usageStore
        self.coachingHistoryStore = coachingHistoryStore
        self.updateChecker = updateChecker
        eventMonitor = GlobalEventMonitor(menuReader: menuReader) { [weak preferences] in
            preferences?.triggerKey ?? .rightCommand
        }
        configureEventMonitor()
        nativeNotifications.onEventActivated = { [weak self] id in
            self?.showCoachingHistory(eventID: id)
        }
    }

    func start() {
        guard !started else { return }
        started = true
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.applicationIconImage = CandidateAppIcon.make()
        applyAppearance()
        accessibilityStatus = accessibility.status
        observeApplications()
        refreshActiveApplication()
        startProtectedServicesIfPossible()
        startAccessibilityPolling()
        Task { await loadUsage() }
        Task { await loadCoachingHistory() }
        refreshNativeNotificationStatus()
        if preferences.automaticUpdates { checkForUpdatesInBackground() }

        if !preferences.onboardingComplete {
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                windows.showOnboarding(model: self)
            }
        }
    }

    func requestAccessibility() {
        accessibility.request()
        refreshAccessibility()
    }

    func refreshAccessibility() {
        accessibilityStatus = accessibility.status
        startProtectedServicesIfPossible()
    }

    func openAccessibilitySettings() {
        accessibility.openSystemSettings()
    }

    func completeOnboarding() {
        preferences.onboardingComplete = true
        windows.closeOnboarding()
        refreshAccessibility()
    }

    func showSettings() { windows.showSettings(model: self) }
    func showAnalytics() { windows.showAnalytics(model: self) }
    func showCoachingHistory(eventID: UUID? = nil) {
        selectedCoachingEventID = eventID
        dockAttention.cancelAttention()
        windows.showCoachingHistory(model: self)
    }

    func handle(url: URL) {
        guard url.scheme?.lowercased() == "keylumeclone" else { return }
        switch url.host?.lowercased() {
        case "analytics": showAnalytics()
        case "settings": showSettings()
        case "history":
            let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "event" })?.value.flatMap(UUID.init(uuidString:))
            showCoachingHistory(eventID: id)
        default: break
        }
    }

    func addExcludedApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an app Keylume Clone should ignore."
        if panel.runModal() == .OK,
           let url = panel.url,
           let bundleIdentifier = Bundle(url: url)?.bundleIdentifier {
            preferences.addExcludedApplication(bundleIdentifier)
            refreshActiveApplication()
        }
    }

    func checkForUpdates() {
        updateError = nil
        Task {
            do {
                updateStatus = try await updateChecker.check(currentVersion: Self.version)
                windows.showUpdateResult(status: updateStatus!, error: nil)
            } catch {
                updateError = error.localizedDescription
                windows.showUpdateResult(status: nil, error: error.localizedDescription)
            }
        }
    }

    func activateLicense(_ key: String) -> Bool { license.activate(key) }
    func deactivateLicense() { license.deactivate() }
    func resetDismissedShortcuts() { preferences.resetDismissedShortcuts() }
    func appearanceChanged() { applyAppearance() }

    func dismissOverlay() {
        windows.hideOverlay()
    }

    func refreshAnalytics() {
        analytics = Self.makeAnalytics(records: usageRecords)
    }

    static func makeAnalytics(records: [UsageRecord], now: Date = .now, calendar: Calendar = .current) -> AnalyticsSnapshot {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let previousStart = calendar.date(byAdding: .day, value: -7, to: startOfWeek) ?? startOfWeek
        let current = records.filter { $0.timestamp >= startOfWeek && $0.timestamp <= now }
        let previous = records.filter { $0.timestamp >= previousStart && $0.timestamp < startOfWeek }

        let keyboard = current.filter { $0.method == .keyboard }
        let mouse = current.filter { $0.method == .mouse }

        func summaries(_ source: [UsageRecord], method: UsageMethod) -> [ShortcutUsageSummary] {
            Dictionary(grouping: source.filter { $0.method == method }) {
                "\($0.shortcutDisplay)|\($0.shortcutTitle)"
            }
            .map { _, values in
                let first = values[0]
                return ShortcutUsageSummary(title: first.shortcutTitle, display: first.shortcutDisplay, count: values.count, method: method)
            }
            .sorted { lhs, rhs in lhs.count == rhs.count ? lhs.title < rhs.title : lhs.count > rhs.count }
        }

        let perApp = Dictionary(grouping: current, by: \.appName)
            .map { appName, values in
                AppUsageSummary(
                    appName: appName,
                    keyboardCount: values.filter { $0.method == .keyboard }.count,
                    mouseCount: values.filter { $0.method == .mouse }.count
                )
            }
            .sorted { ($0.keyboardCount + $0.mouseCount) > ($1.keyboardCount + $1.mouseCount) }

        return AnalyticsSnapshot(
            keyboardCount: keyboard.count,
            mouseCount: mouse.count,
            previousKeyboardCount: previous.filter { $0.method == .keyboard }.count,
            mastered: Array(summaries(current, method: .keyboard).prefix(5)),
            toLearn: Array(summaries(current, method: .mouse).prefix(5)),
            perApp: perApp
        )
    }

    private func configureEventMonitor() {
        eventMonitor.onTriggerChanged = { [weak self] isDown in
            Task { @MainActor in self?.triggerChanged(isDown: isDown) }
        }
        eventMonitor.onOtherKey = { [weak self] in
            Task { @MainActor in self?.cancelPendingOverlay() }
        }
        eventMonitor.onShortcutUsed = { [weak self] key, modifiers in
            Task { @MainActor in self?.shortcutUsed(key: key, modifiers: modifiers) }
        }
        eventMonitor.onMenuAction = { [weak self] shortcut in
            Task { @MainActor in self?.menuAction(shortcut) }
        }
    }

    private func startProtectedServicesIfPossible() {
        guard accessibilityStatus == .granted else {
            eventMonitor.stop()
            return
        }
        if !eventMonitor.start() { updateError = "Unable to start the global event monitor." }
    }

    private func observeApplications() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshActiveApplication() }
        }
    }

    private func refreshActiveApplication() {
        guard let application = NSWorkspace.shared.frontmostApplication else { return }
        let bundleIdentifier = application.bundleIdentifier ?? ""
        activeApplicationName = application.localizedName ?? bundleIdentifier
        activeApplicationIcon = application.bundleURL.flatMap { NSWorkspace.shared.icon(forFile: $0.path) }
        if bundleIdentifier == Bundle.main.bundleIdentifier || preferences.excludedApps.contains(bundleIdentifier) {
            shortcuts = []
        } else {
            shortcuts = menuReader.readShortcuts(for: application)
        }
    }

    private func triggerChanged(isDown: Bool) {
        if isDown {
            holdTask?.cancel()
            let duration = preferences.holdDuration
            holdTask = Task {
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                refreshActiveApplication()
                windows.showOverlay(model: self)
            }
        } else {
            holdTask?.cancel()
            holdTask = nil
        }
    }

    private func cancelPendingOverlay() {
        holdTask?.cancel()
        holdTask = nil
    }

    private func shortcutUsed(key: String, modifiers: ShortcutModifiers) {
        let normalizedModifiers = modifiers.intersection([.command, .shift, .option, .control, .function])
        guard let shortcut = shortcuts.first(where: {
            $0.key.uppercased() == key && $0.modifiers == normalizedModifiers
        }) else { return }
        record(shortcut, method: .keyboard)
    }

    private func menuAction(_ shortcut: AppShortcut) {
        record(shortcut, method: .mouse)
        Task {
            await createAndDeliverCoachingEvent(shortcut: shortcut, source: .menuBar)
        }
    }

    // Internal so the production rate-limit state machine can be exercised
    // deterministically without waiting for wall-clock time in UI tests.
    func shouldShowNudge(now: Date = .now) -> Bool {
        nudgeTimestamps.removeAll { now.timeIntervalSince($0) >= 3600 }
        let outcome = CoachingPresentationPolicy.toastOutcome(
            enabled: preferences.coachingEnabled && preferences.contextualToastEnabled,
            quiet: preferences.isQuiet(at: now),
            excluded: false,
            dismissed: false,
            hourlyCount: nudgeTimestamps.count,
            hourlyCap: Int(preferences.maxNudgesPerHour),
            elapsedSinceLast: lastNudgeDate.map { now.timeIntervalSince($0) },
            alwaysShow: preferences.alwaysShowNudges
        )
        guard outcome == .shown else { return false }
        nudgeTimestamps.append(now)
        lastNudgeDate = now
        return true
    }

    var unreadCoachingCount: Int { coachingEvents.count(where: \.isUnread) }
    var recentCoachingEvents: [CoachingEvent] { Array(coachingEvents.prefix(6)) }

    func sendTestCoachingEvent() {
        let shortcut = AppShortcut(
            appBundleIdentifier: Bundle.main.bundleIdentifier ?? "co.serp.KeylumeClone",
            appName: "Keylume Clone Demo",
            category: "Demo",
            title: "Open Coaching History",
            key: "H",
            modifiers: [.command, .shift],
            menuPath: ["Demo", "Open Coaching History"]
        )
        Task { await createAndDeliverCoachingEvent(shortcut: shortcut, source: .test) }
    }

    func markAllCoachingSeen() {
        for index in coachingEvents.indices where coachingEvents[index].state == .unread {
            coachingEvents[index].state = .seen
        }
        persistMarkAllSeen()
    }

    func setCoachingEvent(_ id: UUID, seen: Bool) {
        setCoachingEventState(id, state: seen ? .seen : .unread)
    }

    func dismissShortcut(for event: CoachingEvent) {
        preferences.dismiss(key: event.dismissalKey)
        setCoachingEventState(event.id, state: .dismissed)
    }

    func restoreShortcut(for event: CoachingEvent) {
        preferences.restore(key: event.dismissalKey)
        setCoachingEventState(event.id, state: .seen)
    }

    func clearCoachingHistory() {
        Task {
            do {
                coachingEvents = try await coachingHistoryStore.clear()
                syncDockBadge()
            } catch {
                coachingHistoryError = "Unable to clear coaching history: \(error.localizedDescription)"
            }
        }
    }

    func requestNativeNotificationAuthorization() {
        Task {
            preferences.nativeNotificationsEnabled = await nativeNotifications.requestAuthorization()
            nativeNotificationStatus = await nativeNotifications.statusLabel()
        }
    }

    func refreshNativeNotificationStatus() {
        Task { nativeNotificationStatus = await nativeNotifications.statusLabel() }
    }

    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    func execute(_ shortcut: AppShortcut) {
        guard menuReader.execute(shortcut) else { return }
        record(shortcut, method: .keyboard)
        dismissOverlay()
    }

    private func record(_ shortcut: AppShortcut, method: UsageMethod) {
        let record = UsageRecord(shortcut: shortcut, method: method)
        Task {
            do {
                usageRecords = try await usageStore.append(record)
                refreshAnalytics()
            } catch {
                updateError = "Unable to save usage: \(error.localizedDescription)"
            }
        }
    }

    private func loadUsage() async {
        do {
            usageRecords = try await usageStore.load()
            refreshAnalytics()
        } catch {
            updateError = "Unable to load usage: \(error.localizedDescription)"
        }
    }

    private func loadCoachingHistory() async {
        do {
            coachingEvents = try await coachingHistoryStore.load()
            coachingHistoryError = nil
            syncDockBadge()
        } catch {
            coachingHistoryError = "Unable to load coaching history: \(error.localizedDescription)"
            coachingEvents = []
            syncDockBadge()
        }
    }

    private func createAndDeliverCoachingEvent(shortcut: AppShortcut, source: CoachingEventSource, now: Date = .now) async {
        var event = CoachingEvent(shortcut: shortcut, source: source, timestamp: now)
        do {
            coachingEvents = try await coachingHistoryStore.append(event)
        } catch {
            coachingHistoryError = "Unable to save coaching history: \(error.localizedDescription)"
            return
        }
        syncDockBadge()

        nudgeTimestamps.removeAll { now.timeIntervalSince($0) >= 3600 }
        let toastOutcome = CoachingPresentationPolicy.toastOutcome(
            enabled: preferences.coachingEnabled && preferences.contextualToastEnabled,
            quiet: preferences.isQuiet(at: now),
            excluded: preferences.excludedApps.contains(shortcut.appBundleIdentifier),
            dismissed: preferences.dismissedShortcuts.contains(shortcut.dismissalKey),
            hourlyCount: nudgeTimestamps.count,
            hourlyCap: Int(preferences.maxNudgesPerHour),
            elapsedSinceLast: lastNudgeDate.map { now.timeIntervalSince($0) },
            alwaysShow: preferences.alwaysShowNudges
        )
        event.deliveries[.toast] = CoachingSurfaceDelivery(outcome: toastOutcome, attemptedAt: now, detail: nil)
        if toastOutcome == .shown {
            nudgeTimestamps.append(now)
            lastNudgeDate = now
            windows.showToast(shortcut: shortcut) { [weak self] in
                guard let self else { return }
                self.dismissShortcut(for: event)
            }
        }

        event.deliveries[.menuBar] = CoachingSurfaceDelivery(outcome: .shown, attemptedAt: now, detail: nil)
        event.deliveries[.dockBadge] = CoachingSurfaceDelivery(
            outcome: preferences.dockBadgeEnabled ? .shown : .suppressedDisabled,
            attemptedAt: now,
            detail: nil
        )
        let bounceOutcome = dockAttention.presentIfEligible(now: now, preferences: preferences)
        event.deliveries[.dockAttention] = CoachingSurfaceDelivery(outcome: bounceOutcome, attemptedAt: now, detail: nil)

        if preferences.nativeNotificationsEnabled {
            let nativeOutcome = await nativeNotifications.submit(event)
            event.deliveries[.nativeNotification] = CoachingSurfaceDelivery(
                outcome: nativeOutcome,
                attemptedAt: now,
                detail: nativeOutcome == .submittedToSystem ? "The system accepted the request; visible banner delivery is not observable." : nil
            )
        } else {
            event.deliveries[.nativeNotification] = CoachingSurfaceDelivery(outcome: .suppressedDisabled, attemptedAt: now, detail: nil)
        }
        let soundOutcome = preferences.soundEnabled
            ? coachingSound.play(volume: preferences.soundVolume)
            : .suppressedDisabled
        event.deliveries[.sound] = CoachingSurfaceDelivery(outcome: soundOutcome, attemptedAt: now, detail: nil)
        do {
            coachingEvents = try await coachingHistoryStore.replace(event)
            syncDockBadge()
        } catch {
            coachingHistoryError = "Unable to update coaching delivery outcomes: \(error.localizedDescription)"
        }
    }

    private func setCoachingEventState(_ id: UUID, state: CoachingEventState) {
        if let index = coachingEvents.firstIndex(where: { $0.id == id }) {
            coachingEvents[index].state = state
        }
        syncDockBadge()
        Task {
            do {
                coachingEvents = try await coachingHistoryStore.setState(id: id, state: state)
                syncDockBadge()
            } catch {
                coachingHistoryError = "Unable to update coaching history: \(error.localizedDescription)"
            }
        }
    }

    private func persistMarkAllSeen() {
        syncDockBadge()
        Task {
            do {
                coachingEvents = try await coachingHistoryStore.markAllSeen()
                syncDockBadge()
            } catch {
                coachingHistoryError = "Unable to update coaching history: \(error.localizedDescription)"
            }
        }
    }

    func syncDockBadge() {
        dockAttention.updateBadge(unreadCount: unreadCoachingCount, enabled: preferences.dockBadgeEnabled)
    }

    private func applyAppearance() {
        NSApplication.shared.appearance = switch preferences.appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    private func checkForUpdatesInBackground() {
        Task {
            do {
                updateStatus = try await updateChecker.check(currentVersion: Self.version)
            } catch {
                updateError = error.localizedDescription
            }
        }
    }

    private func startAccessibilityPolling() {
        accessibilityPollingTask?.cancel()
        accessibilityPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                let newStatus = accessibility.status
                if newStatus != accessibilityStatus {
                    accessibilityStatus = newStatus
                    startProtectedServicesIfPossible()
                    if newStatus == .granted { refreshActiveApplication() }
                }
            }
        }
    }
}
