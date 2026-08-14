import CoreGraphics
import Foundation

enum PresentationMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case topCenterPresence
    case compactExpandedShelf
    case cursorHalo
    case statusFeedback
    case pointerCard
    case decisionBanner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topCenterPresence: "Top-center presence"
        case .compactExpandedShelf: "Compact → Expanded shelf"
        case .cursorHalo: "Cursor opportunity halo"
        case .statusFeedback: "Status feedback"
        case .pointerCard: "Pointer-anchored card"
        case .decisionBanner: "Actionable decision banner"
        }
    }
}

enum PointerCoordinateSpace: Sendable {
    case appKit
    case quartz
}

struct CoachingEvent: Identifiable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let shortcut: AppShortcut
    let pointerLocation: CGPoint
    let pointerCoordinateSpace: PointerCoordinateSpace
    let isLocalPreview: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        shortcut: AppShortcut,
        pointerLocation: CGPoint,
        pointerCoordinateSpace: PointerCoordinateSpace = .appKit,
        isLocalPreview: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.shortcut = shortcut
        self.pointerLocation = pointerLocation
        self.pointerCoordinateSpace = pointerCoordinateSpace
        self.isLocalPreview = isLocalPreview
    }
}

enum PresentationPhase: Equatable, Sendable {
    case idle
    case evaluating
    case presenting
    case success
    case paused(String)
    case permissionRequired
    case failed(String)

    var accessibilityDescription: String {
        switch self {
        case .idle: "Ready"
        case .evaluating: "Checking for a shortcut"
        case .presenting: "Shortcut coaching available"
        case .success: "Shortcut coaching recorded"
        case .paused(let reason): "Coaching paused: \(reason)"
        case .permissionRequired: "Accessibility permission required"
        case .failed(let reason): "Unable to present coaching: \(reason)"
        }
    }
}

enum PresentationSuppression: String, Equatable, Sendable {
    case duplicate
    case cooldown
    case disabled
    case quietHours
    case noValidPlacement
}

enum PresentationOutcome: Equatable, Sendable {
    case shown(PresentationMode)
    case suppressed(PresentationMode, PresentationSuppression)
    case failed(PresentationMode)
}

enum CoachingAction: String, CaseIterable, Equatable, Sendable {
    case practiceShortcut
    case gotIt
    case notNow
    case stopSuggesting
    case openSettings

    var title: String {
        switch self {
        case .practiceShortcut: "Practice Shortcut"
        case .gotIt: "Got It"
        case .notNow: "Not Now"
        case .stopSuggesting: "Stop Suggesting"
        case .openSettings: "Coaching Settings"
        }
    }
}

struct CoachingDecisionState: Equatable, Sendable {
    var isUnread = true
    var deferredUntil: Date?
    var isSuppressed = false

    mutating func apply(_ action: CoachingAction, now: Date) {
        switch action {
        case .practiceShortcut, .gotIt:
            isUnread = false
            deferredUntil = nil
        case .notNow:
            isUnread = true
            deferredUntil = now.addingTimeInterval(3600)
        case .stopSuggesting:
            isUnread = false
            deferredUntil = nil
            isSuppressed = true
        case .openSettings:
            break
        }
    }
}

struct PresentationStateMachine: Equatable, Sendable {
    private(set) var phase: PresentationPhase = .idle

    mutating func begin() { phase = .evaluating }
    mutating func present() { phase = .presenting }
    mutating func resolve() { phase = .success }
    mutating func pause(reason: String) { phase = .paused(reason) }
    mutating func fail(reason: String) { phase = .failed(reason) }
    mutating func reset() { phase = .idle }
}

struct PresentationPolicy: Sendable {
    var cooldown: TimeInterval = 15
    private var deliveries: [String: Date] = [:]

    init(cooldown: TimeInterval = 15) {
        self.cooldown = cooldown
    }

    mutating func decision(
        eventID: UUID,
        mode: PresentationMode,
        now: Date,
        enabled: Bool,
        quiet: Bool,
        bypassCooldown: Bool = false
    ) -> PresentationSuppression? {
        guard enabled else { return .disabled }
        guard !quiet else { return .quietHours }
        let key = "\(eventID.uuidString)|\(mode.rawValue)"
        if deliveries[key] != nil { return .duplicate }
        if !bypassCooldown,
           deliveries.contains(where: { storedKey, date in
               storedKey.hasSuffix("|\(mode.rawValue)") && now.timeIntervalSince(date) < cooldown
           }) {
            return .cooldown
        }
        deliveries[key] = now
        return nil
    }
}

enum PresentationPlacement {
    static func topCenter(size: CGSize, visibleFrame: CGRect, topInset: CGFloat = 12) -> CGRect? {
        guard size.width <= visibleFrame.width, size.height + topInset <= visibleFrame.height else { return nil }
        return CGRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.maxY - size.height - topInset,
            width: size.width,
            height: size.height
        )
    }

    static func pointerCard(
        anchor: CGPoint,
        size: CGSize,
        visibleFrame: CGRect,
        hotspotRadius: CGFloat = 22,
        margin: CGFloat = 12
    ) -> CGRect? {
        guard size.width + margin * 2 <= visibleFrame.width,
              size.height + margin * 2 <= visibleFrame.height,
              visibleFrame.contains(anchor)
        else { return nil }

        let rightX = anchor.x + hotspotRadius
        let leftX = anchor.x - hotspotRadius - size.width
        let upperY = anchor.y + hotspotRadius
        let lowerY = anchor.y - hotspotRadius - size.height
        let x = rightX + size.width <= visibleFrame.maxX - margin ? rightX : leftX
        let y = upperY + size.height <= visibleFrame.maxY - margin ? upperY : lowerY
        let candidate = CGRect(x: x, y: y, width: size.width, height: size.height)
        let clampedX = min(max(candidate.minX, visibleFrame.minX + margin), visibleFrame.maxX - size.width - margin)
        let clampedY = min(max(candidate.minY, visibleFrame.minY + margin), visibleFrame.maxY - size.height - margin)
        return CGRect(x: clampedX, y: clampedY, width: size.width, height: size.height)
    }
}

enum PresentationSemantics {
    static func label(for event: CoachingEvent, phase: PresentationPhase) -> String {
        "\(phase.accessibilityDescription). \(event.shortcut.title): \(event.shortcut.display)."
    }

    static let decisionActionOrder: [CoachingAction] = [.practiceShortcut, .notNow, .gotIt, .stopSuggesting]
}
