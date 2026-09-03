import Foundation

@MainActor
final class ManualActionDetector {
    enum Status: Equatable {
        case stopped
        case permissionRequired
        case monitoring
        case failed(String)
    }

    private(set) var status: Status = .stopped
    var onEvent: ((CoachingEvent) -> Void)?
    var isAccessibilityTrusted: Bool { false }

    func requestAccessibilityPermission() {}
    func start() { status = .stopped }
    func stop() { status = .stopped }
}
