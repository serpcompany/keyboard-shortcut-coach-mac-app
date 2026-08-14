import Foundation
import Observation

@MainActor
@Observable
final class PresentationCoordinator {
    private let presenter: WindowPresenter
    private let preferences: AppPreferences
    private let dismissShortcut: (AppShortcut) -> Void
    private let openSettings: () -> Void
    private var policy = PresentationPolicy()

    private(set) var phase: PresentationPhase = .idle
    private(set) var outcomes: [UUID: [PresentationOutcome]] = [:]
    private(set) var lastAction: CoachingAction?
    private(set) var decisionStates: [UUID: CoachingDecisionState] = [:]

    init(
        presenter: WindowPresenter,
        preferences: AppPreferences,
        dismissShortcut: @escaping (AppShortcut) -> Void,
        openSettings: @escaping () -> Void
    ) {
        self.presenter = presenter
        self.preferences = preferences
        self.dismissShortcut = dismissShortcut
        self.openSettings = openSettings
    }

    func present(_ event: CoachingEvent, mode: PresentationMode, preview: Bool = false) {
        var machine = PresentationStateMachine()
        machine.begin()
        phase = machine.phase

        if let suppression = policy.decision(
            eventID: event.id,
            mode: mode,
            now: .now,
            enabled: preview || preferences.isPresentationEnabled(mode),
            quiet: !preview && preferences.isQuiet(),
            bypassCooldown: preview
        ) {
            outcomes[event.id, default: []].append(.suppressed(mode, suppression))
            machine.pause(reason: suppression.rawValue)
            phase = machine.phase
            return
        }

        let shown = presenter.showPresentation(event: event, mode: mode) { [weak self] action in
            self?.handle(action, event: event)
        }
        if shown {
            machine.present()
            outcomes[event.id, default: []].append(.shown(mode))
        } else {
            machine.fail(reason: "No safe display placement")
            outcomes[event.id, default: []].append(.failed(mode))
        }
        phase = machine.phase
    }

    func presentEnabledModes(for event: CoachingEvent) {
        if preferences.cursorHaloEnabled { present(event, mode: .cursorHalo) }
        if preferences.pointerCardEnabled {
            present(event, mode: .pointerCard)
        } else if preferences.compactExpandedShelfEnabled {
            present(event, mode: .compactExpandedShelf)
        } else if preferences.topCenterPresenceEnabled {
            present(event, mode: .topCenterPresence)
        }
    }

    func runShowcase(event: CoachingEvent) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            for mode in PresentationMode.allCases {
                present(event, mode: mode, preview: true)
                try? await Task.sleep(for: .seconds(mode == .cursorHalo ? 1.5 : 4.5))
            }
        }
    }

    private func handle(_ action: CoachingAction, event: CoachingEvent) {
        lastAction = action
        var decision = decisionStates[event.id] ?? CoachingDecisionState()
        decision.apply(action, now: .now)
        decisionStates[event.id] = decision
        switch action {
        case .stopSuggesting:
            dismissShortcut(event.shortcut)
        case .openSettings:
            openSettings()
        case .practiceShortcut, .gotIt, .notNow:
            break
        }
        presenter.dismissPresentationPanels()
        phase = .success
    }
}
