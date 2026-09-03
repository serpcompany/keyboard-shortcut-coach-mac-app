import CoreGraphics
import Foundation

struct ActionCorrelator {
    let maximumDuration: TimeInterval
    let deduplicationWindow: TimeInterval
    private(set) var candidate: ManualActionCandidate?
    private(set) var downTimestamp: TimeInterval = 0
    private(set) var dragDistance: CGFloat = 0
    private var lastSignature: String?
    private var lastEmissionTimestamp: TimeInterval = -.infinity

    init(maximumDuration: TimeInterval = 1.5, deduplicationWindow: TimeInterval = 1) {
        self.maximumDuration = maximumDuration
        self.deduplicationWindow = deduplicationWindow
    }

    mutating func begin(_ candidate: ManualActionCandidate, at timestamp: TimeInterval, modifiers: CGEventFlags) {
        guard modifiers.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty else { cancel(); return }
        self.candidate = candidate
        downTimestamp = timestamp
        dragDistance = 0
    }

    mutating func observeDrag(to point: CGPoint) {
        guard let candidate else { return }
        dragDistance = max(dragDistance, hypot(point.x - candidate.point.x, point.y - candidate.point.y))
    }

    mutating func markDragged() { dragDistance = .infinity }
    mutating func cancel() { candidate = nil; dragDistance = 0 }

    mutating func acceptsMouseUp(_ sample: PointerSample, hit: AccessibilitySnapshot?) -> Bool {
        guard let candidate, dragDistance <= 4,
              sample.timestamp - downTimestamp <= maximumDuration,
              sample.modifiers.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty,
              candidate.targetFrame?.contains(sample.location) != false,
              hit?.bundleIdentifier == candidate.preSnapshot.bundleIdentifier else { cancel(); return false }
        return true
    }

    mutating func verify(post: AccessibilitySnapshot, at timestamp: TimeInterval) -> CoachingEvent? {
        guard let candidate else { return nil }
        defer { cancel() }
        guard post.bundleIdentifier == candidate.preSnapshot.bundleIdentifier,
              let preTabs = candidate.preSnapshot.tabs, let postTabs = post.tabs,
              preTabs.containerToken == postTabs.containerToken else { return nil }
        let output: (String, String)?
        switch candidate.kind {
        case .chromeNewTab where postTabs.tabs.count == preTabs.tabs.count + 1:
            output = ("New Tab", ChromeShortcutCatalog.newTab)
        case .chromeCloseActiveTab(let token)
            where postTabs.tabs.count == preTabs.tabs.count - 1 && !postTabs.tabs.contains(where: { $0.token == token }):
            output = ("Close Tab", ChromeShortcutCatalog.closeTab)
        case .chromeSelectTab(let token, let index, let count)
            where postTabs.tabs.count == count && postTabs.tabs.first(where: { $0.token == token })?.selected == true:
            output = ("Select Tab \(index)", ChromeShortcutCatalog.selectTab(index: index))
        case .chromeSettings(let initialTabCount)
            where postTabs.tabs.count > initialTabCount:
            output = ("Settings", "⌘,")
        default: output = nil
        }
        guard let output else { return nil }
        let signature = "\(candidate.applicationName)|\(output.0)|\(output.1)"
        guard signature != lastSignature || timestamp - lastEmissionTimestamp > deduplicationWindow else { return nil }
        lastSignature = signature
        lastEmissionTimestamp = timestamp
        return CoachingEvent(applicationName: candidate.applicationName, actionTitle: output.0,
                             shortcut: output.1, pointerX: candidate.point.x, pointerY: candidate.point.y)
    }
}
