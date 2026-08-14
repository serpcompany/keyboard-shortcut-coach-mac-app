import AppKit
import Foundation
import UserNotifications

enum CoachingEventSource: String, Codable, CaseIterable, Sendable {
    case menuBar = "menu-bar"
    case tabStrip = "tab-strip"
    case toolbar
    case contextMenu = "context-menu"
    case test
}

enum CoachingEventState: String, Codable, Sendable {
    case unread
    case seen
    case dismissed
    case learned
}

enum CoachingSurface: String, Codable, Hashable, Sendable {
    case history
    case toast
    case menuBar
    case dockBadge
    case dockAttention
    case nativeNotification
    case sound
}

enum CoachingDeliveryOutcome: String, Codable, CaseIterable, Sendable {
    case stored
    case shown
    case submittedToSystem = "submitted-to-system"
    case suppressedCooldown = "suppressed-cooldown"
    case suppressedHourlyCap = "suppressed-hourly-cap"
    case suppressedQuietHours = "suppressed-quiet-hours"
    case suppressedDisabled = "suppressed-disabled"
    case suppressedExcludedApp = "suppressed-excluded-app"
    case suppressedDismissedShortcut = "suppressed-dismissed-shortcut"
    case suppressedAppActive = "suppressed-app-active"
    case suppressedRateLimit = "suppressed-rate-limit"
    case blockedPermission = "blocked-permission"
    case presentationFailed = "presentation-failed"
}

struct CoachingSurfaceDelivery: Codable, Hashable, Sendable {
    let outcome: CoachingDeliveryOutcome
    let attemptedAt: Date
    let detail: String?
}

struct CoachingEvent: Identifiable, Codable, Hashable, Sendable {
    static let currentSchemaVersion = 1

    let id: UUID
    let timestamp: Date
    let appBundleIdentifier: String
    let appName: String
    let actionTitle: String
    let menuPath: [String]
    let normalizedShortcut: String
    let shortcutDisplay: String
    let source: CoachingEventSource
    let dismissalKey: String
    var state: CoachingEventState
    var deliveries: [CoachingSurface: CoachingSurfaceDelivery]
    let schemaVersion: Int

    init(shortcut: AppShortcut, source: CoachingEventSource, timestamp: Date = .now, id: UUID = UUID()) {
        self.id = id
        self.timestamp = timestamp
        appBundleIdentifier = shortcut.appBundleIdentifier
        appName = shortcut.appName
        actionTitle = shortcut.title
        menuPath = shortcut.menuPath
        normalizedShortcut = "\(shortcut.modifiers.rawValue):\(shortcut.key.uppercased())"
        shortcutDisplay = shortcut.display
        self.source = source
        dismissalKey = shortcut.dismissalKey
        state = .unread
        deliveries = [
            .history: CoachingSurfaceDelivery(outcome: .stored, attemptedAt: timestamp, detail: nil)
        ]
        schemaVersion = Self.currentSchemaVersion
    }

    var isUnread: Bool { state == .unread }
    var searchableText: String {
        ([appName, actionTitle, shortcutDisplay] + menuPath).joined(separator: " ")
    }
}

struct CoachingHistoryEnvelope: Codable, Sendable {
    let schemaVersion: Int
    var events: [CoachingEvent]
}

actor CoachingHistoryStore {
    private let fileURL: URL
    private let maxItems: Int
    private let retentionInterval: TimeInterval
    private let now: @Sendable () -> Date
    private var events: [CoachingEvent] = []
    private var hasLoaded = false

    init(
        fileURL: URL? = nil,
        maxItems: Int = 500,
        retentionDays: Int = 30,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appending(path: "KeylumeClone", directoryHint: .isDirectory)
            self.fileURL = base.appending(path: "coaching-history.json")
        }
        self.maxItems = maxItems
        retentionInterval = TimeInterval(retentionDays * 86_400)
        self.now = now
    }

    func load() throws -> [CoachingEvent] {
        if hasLoaded { return newestFirst(events) }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            events = []
            hasLoaded = true
            return events
        }
        let data = try Data(contentsOf: fileURL)
        if let envelope = try? JSONDecoder().decode(CoachingHistoryEnvelope.self, from: data) {
            events = envelope.events
        } else {
            events = try JSONDecoder().decode([CoachingEvent].self, from: data)
        }
        events = retained(events)
        hasLoaded = true
        try persist()
        return newestFirst(events)
    }

    func append(_ event: CoachingEvent) throws -> [CoachingEvent] {
        _ = try load()
        guard !events.contains(where: { $0.id == event.id }) else { return newestFirst(events) }
        events.append(event)
        events = retained(events)
        try persist()
        return newestFirst(events)
    }

    func replace(_ event: CoachingEvent) throws -> [CoachingEvent] {
        _ = try load()
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return newestFirst(events) }
        events[index] = event
        events = retained(events)
        try persist()
        return newestFirst(events)
    }

    func setState(id: UUID, state: CoachingEventState) throws -> [CoachingEvent] {
        _ = try load()
        guard let index = events.firstIndex(where: { $0.id == id }) else { return newestFirst(events) }
        events[index].state = state
        try persist()
        return newestFirst(events)
    }

    func markAllSeen() throws -> [CoachingEvent] {
        _ = try load()
        for index in events.indices where events[index].state == .unread {
            events[index].state = .seen
        }
        try persist()
        return newestFirst(events)
    }

    func replaceAll(_ updated: [CoachingEvent]) throws -> [CoachingEvent] {
        _ = try load()
        var seen = Set<UUID>()
        events = updated.filter { seen.insert($0.id).inserted }
        events = retained(events)
        try persist()
        return newestFirst(events)
    }

    func clear() throws -> [CoachingEvent] {
        events = []
        hasLoaded = true
        try persist()
        return []
    }

    private func retained(_ source: [CoachingEvent]) -> [CoachingEvent] {
        let cutoff = now().addingTimeInterval(-retentionInterval)
        return Array(newestFirst(source.filter { $0.timestamp >= cutoff }).prefix(maxItems))
    }

    private func newestFirst(_ source: [CoachingEvent]) -> [CoachingEvent] {
        source.sorted { $0.timestamp > $1.timestamp }
    }

    private func persist() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let envelope = CoachingHistoryEnvelope(schemaVersion: CoachingEvent.currentSchemaVersion, events: newestFirst(events))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(envelope).write(to: fileURL, options: .atomic)
    }
}

struct CoachingPresentationPolicy {
    static func toastOutcome(
        enabled: Bool,
        quiet: Bool,
        excluded: Bool,
        dismissed: Bool,
        hourlyCount: Int,
        hourlyCap: Int,
        elapsedSinceLast: TimeInterval?,
        alwaysShow: Bool
    ) -> CoachingDeliveryOutcome {
        if !enabled { return .suppressedDisabled }
        if quiet { return .suppressedQuietHours }
        if excluded { return .suppressedExcludedApp }
        if dismissed { return .suppressedDismissedShortcut }
        if hourlyCount >= hourlyCap { return .suppressedHourlyCap }
        if !alwaysShow, let elapsedSinceLast, elapsedSinceLast < 15 { return .suppressedCooldown }
        return .shown
    }
}

struct DockAttentionPolicy {
    private(set) var lastRequestDate: Date?

    mutating func outcome(
        now: Date,
        enabled: Bool,
        appIsActive: Bool,
        quiet: Bool,
        coachingEnabled: Bool
    ) -> CoachingDeliveryOutcome {
        if !enabled || !coachingEnabled { return .suppressedDisabled }
        if quiet { return .suppressedQuietHours }
        if appIsActive { return .suppressedAppActive }
        if let lastRequestDate, now.timeIntervalSince(lastRequestDate) < 300 { return .suppressedRateLimit }
        lastRequestDate = now
        return .shown
    }
}

@MainActor
final class DockAttentionPresenter {
    private var requestID: Int?
    private var policy = DockAttentionPolicy()

    func updateBadge(unreadCount: Int, enabled: Bool) {
        NSApp.dockTile.badgeLabel = enabled && unreadCount > 0 ? String(unreadCount) : nil
    }

    func presentIfEligible(now: Date, preferences: AppPreferences) -> CoachingDeliveryOutcome {
        let outcome = policy.outcome(
            now: now,
            enabled: preferences.dockBounceEnabled,
            appIsActive: NSApp.isActive,
            quiet: preferences.isQuiet(at: now),
            coachingEnabled: preferences.coachingEnabled
        )
        guard outcome == .shown else { return outcome }
        requestID = NSApp.requestUserAttention(.informationalRequest)
        if let requestID {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                NSApp.cancelUserAttentionRequest(requestID)
            }
        }
        return outcome
    }

    func cancelAttention() {
        if let requestID { NSApp.cancelUserAttentionRequest(requestID) }
        requestID = nil
    }
}

@MainActor
final class CoachingSoundPresenter {
    func play(volume: Double) -> CoachingDeliveryOutcome {
        guard let sound = NSSound(named: NSSound.Name("Glass")) else { return .presentationFailed }
        sound.volume = Float(min(max(volume, 0), 1))
        return sound.play() ? .shown : .presentationFailed
    }
}

@MainActor
enum CandidateAppIcon {
    static func make() -> NSImage {
        NSImage(size: NSSize(width: 512, height: 512), flipped: false) { rect in
            let outer = NSBezierPath(roundedRect: rect.insetBy(dx: 24, dy: 24), xRadius: 112, yRadius: 112)
            NSGradient(colors: [
                NSColor(calibratedRed: 0.08, green: 0.52, blue: 0.42, alpha: 1),
                NSColor(calibratedRed: 0.06, green: 0.22, blue: 0.30, alpha: 1)
            ])?.draw(in: outer, angle: -55)
            NSColor.white.withAlphaComponent(0.95).setFill()
            let keyboard = NSBezierPath(roundedRect: NSRect(x: 100, y: 145, width: 312, height: 222), xRadius: 38, yRadius: 38)
            keyboard.fill()
            NSColor(calibratedRed: 0.06, green: 0.28, blue: 0.29, alpha: 1).setFill()
            for row in 0..<3 {
                for column in 0..<5 {
                    let key = NSBezierPath(roundedRect: NSRect(
                        x: 128 + CGFloat(column * 54),
                        y: 300 - CGFloat(row * 56),
                        width: 36,
                        height: 32
                    ), xRadius: 8, yRadius: 8)
                    key.fill()
                }
            }
            NSBezierPath(roundedRect: NSRect(x: 176, y: 172, width: 160, height: 30), xRadius: 8, yRadius: 8).fill()
            return true
        }
    }
}

enum MenuBarIconState: Equatable {
    case neutral
    case unread
    case attention
}

@MainActor
enum MenuBarStatusIcon {
    static func make(state: MenuBarIconState) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        defer { image.unlockFocus() }
        let color: NSColor = switch state {
        case .neutral: .black
        case .unread: .systemGreen
        case .attention: .systemOrange
        }
        color.setStroke()
        color.setFill()
        let keyboard = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 3.5, width: 15, height: 11), xRadius: 2.5, yRadius: 2.5)
        keyboard.lineWidth = 1.7
        keyboard.stroke()
        for column in 0..<3 {
            NSBezierPath(roundedRect: NSRect(x: 4 + CGFloat(column * 4), y: 9.5, width: 2, height: 2), xRadius: 0.5, yRadius: 0.5).fill()
        }
        NSBezierPath(roundedRect: NSRect(x: 5.5, y: 6, width: 7, height: 1.8), xRadius: 0.8, yRadius: 0.8).fill()
        image.isTemplate = state == .neutral
        return image
    }
}

@MainActor
final class NativeNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    var onEventActivated: ((UUID) -> Void)?
    private var center: UNUserNotificationCenter?
    private var submitted = Set<UUID>()

    init(center: UNUserNotificationCenter? = nil) {
        self.center = center
        super.init()
        center?.delegate = self
    }

    func requestAuthorization() async -> Bool {
        let center = notificationCenter()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func submit(_ event: CoachingEvent) async -> CoachingDeliveryOutcome {
        let center = notificationCenter()
        guard submitted.insert(event.id).inserted else { return .submittedToSystem }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            submitted.remove(event.id)
            return .blockedPermission
        }
        let content = UNMutableNotificationContent()
        content.title = "Shortcut coaching"
        content.subtitle = event.appName
        content.body = "Use (event.shortcutDisplay) for (event.actionTitle)."
        content.userInfo = ["coachingEventID": event.id.uuidString]
        do {
            try await center.add(UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: nil))
            return .submittedToSystem
        } catch {
            submitted.remove(event.id)
            return .presentationFailed
        }
    }

    func statusLabel() async -> String {
        let settings = await notificationCenter().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return "Not requested"
        case .denied: return "Denied"
        case .provisional: return "Quiet delivery"
        case .authorized:
            return settings.alertSetting == .disabled ? "Authorized · banners off" : "Authorized"
        case .ephemeral: return "Temporary authorization"
        @unknown default: return "Unknown"
        }
    }

    private func notificationCenter() -> UNUserNotificationCenter {
        if let center { return center }
        let resolved = UNUserNotificationCenter.current()
        resolved.delegate = self
        center = resolved
        return resolved
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let value = response.notification.request.content.userInfo["coachingEventID"] as? String,
              let id = UUID(uuidString: value)
        else { return }
        await MainActor.run { onEventActivated?(id) }
    }
}
