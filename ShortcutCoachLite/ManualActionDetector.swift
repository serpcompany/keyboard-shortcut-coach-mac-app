import Foundation

@MainActor
final class ManualActionDetector {
    enum RequiredPermission: Equatable {
        case accessibility
        case inputMonitoring
    }

    enum Status: Equatable {
        case stopped
        case permissionRequired([RequiredPermission])
        case monitoring
        case failed(String)
    }

    private(set) var status: Status = .stopped
    var onEvent: ((CoachingEvent) -> Void)?
    var isAccessibilityTrusted: Bool { false }
    var isInputMonitoringAuthorized: Bool { false }

    func requestAccessibilityPermission() {}
    func requestInputMonitoringPermission() {}
    func start() { status = .stopped }
    func stop() { status = .stopped }
}
