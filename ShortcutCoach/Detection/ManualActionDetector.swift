import ApplicationServices
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
    private let monitor: PointerEventMonitor
    private let snapshotter: AccessibilitySnapshotter
    private let chromeAdapter = ChromeActionAdapter()
    private let windowControlMonitor = StandardWindowControlMonitor()
    private let finderTrashMonitor = FinderTrashMonitor()
    private var correlator = ActionCorrelator()
    private var generation = 0
    private var downSnapshotPending = false
    private var bufferedMouseUp: PointerSample?
    private var bufferedDragLocations: [CGPoint] = []
    private var lastMenuSignature: String?
    private var lastMenuEmission = Date.distantPast

    var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    init(monitor: PointerEventMonitor = PointerEventMonitor(), snapshotter: AccessibilitySnapshotter = AccessibilitySnapshotter()) {
        self.monitor = monitor
        self.snapshotter = snapshotter
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func start() {
        stop()
        guard AXIsProcessTrusted() else {
            status = .permissionRequired
            return
        }

        monitor.onSample = { [weak self] sample in
            self?.windowControlMonitor.receive(sample)
            self?.finderTrashMonitor.receive(sample)
            DispatchQueue.main.async { self?.receive(sample) }
        }
        monitor.onTapRecovered = { [weak self] in
            self?.windowControlMonitor.cancel()
            self?.finderTrashMonitor.cancel()
            DispatchQueue.main.async { self?.correlator.cancel() }
        }
        windowControlMonitor.onEvent = { [weak self] event in self?.onEvent?(event) }
        finderTrashMonitor.onEvent = { [weak self] event in self?.onEvent?(event) }
        guard monitor.start() else {
            status = .failed("macOS did not create the Accessibility event monitor")
            return
        }
        status = .monitoring
    }

    func stop() {
        monitor.stop()
        windowControlMonitor.cancel()
        finderTrashMonitor.cancel()
        correlator.cancel()
        downSnapshotPending = false
        bufferedMouseUp = nil
        bufferedDragLocations.removeAll()
        generation += 1
        status = .stopped
    }

    private func receive(_ sample: PointerSample) {
        switch sample.phase {
        case .dragged:
            if downSnapshotPending {
                bufferedDragLocations.append(sample.location)
            } else {
                correlator.observeDrag(to: sample.location)
            }
        case .cancelled: correlator.cancel()
        case .down:
            downSnapshotPending = true
            bufferedMouseUp = nil
            bufferedDragLocations.removeAll()
            let currentGeneration = generation
            snapshotter.snapshot(at: sample.location) { [weak self] snapshot in
                guard let self, self.generation == currentGeneration else { return }
                self.downSnapshotPending = false
                guard let snapshot else {
                    self.bufferedMouseUp = nil
                    self.bufferedDragLocations.removeAll()
                    return
                }
                if let shortcut = snapshot.hit.menuShortcut,
                   snapshot.hit.role == kAXMenuItemRole as String,
                   let title = snapshot.hit.title, !title.isEmpty {
                    let signature = "\(snapshot.applicationName)|\(title)|\(shortcut)"
                    if signature != self.lastMenuSignature || Date().timeIntervalSince(self.lastMenuEmission) > 1 {
                        self.lastMenuSignature = signature
                        self.lastMenuEmission = Date()
                        self.onEvent?(CoachingEvent(applicationName: snapshot.applicationName, actionTitle: title,
                                                    shortcut: shortcut, pointerX: sample.location.x, pointerY: sample.location.y))
                    }
                } else if let candidate = self.chromeAdapter.classify(snapshot, point: sample.location) {
                    self.correlator.begin(candidate, at: sample.timestamp, modifiers: sample.modifiers)
                    for location in self.bufferedDragLocations {
                        self.correlator.observeDrag(to: location)
                    }
                    self.bufferedDragLocations.removeAll()
                    if let mouseUp = self.bufferedMouseUp {
                        self.bufferedMouseUp = nil
                        self.handleMouseUp(mouseUp, generation: currentGeneration)
                    }
                }
            }
        case .up:
            if downSnapshotPending {
                bufferedMouseUp = sample
            } else {
                handleMouseUp(sample, generation: generation)
            }
        }
    }

    private func handleMouseUp(_ sample: PointerSample, generation currentGeneration: Int) {
        snapshotter.snapshot(at: sample.location) { [weak self] upSnapshot in
                guard let self, self.generation == currentGeneration,
                      self.correlator.acceptsMouseUp(sample, hit: upSnapshot) else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    self.snapshotter.snapshot(at: sample.location) { [weak self] post in
                        guard let self, self.generation == currentGeneration, let post else {
                            self?.correlator.cancel(); return
                        }
                        if let event = self.correlator.verify(post: post, at: ProcessInfo.processInfo.systemUptime) {
                            self.onEvent?(event)
                        }
                    }
                }
            }
    }
}
