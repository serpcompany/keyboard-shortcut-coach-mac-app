import AppKit
import SwiftUI

enum CoachingShelfStyle {
    case compact
    case expanded
}

struct CoachingShelfView: View {
    let event: CoachingEvent
    let style: CoachingShelfStyle
    let action: (CoachingAction) -> Void

    var body: some View {
        Group {
            if style == .compact {
                HStack(spacing: 10) {
                    Image(systemName: "command.circle.fill")
                        .foregroundStyle(.mint)
                    Text("Shortcut ready")
                        .font(.headline)
                    Text(event.shortcut.display)
                        .presentationKeycap()
                }
                .padding(.horizontal, 16)
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.title2)
                        .foregroundStyle(.mint)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("A quicker route is ready")
                            .font(.headline)
                        Text("\(event.shortcut.title) · \(event.shortcut.menuLocation)")
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(event.shortcut.display)
                        .presentationKeycap()
                    Button("Got It") { action(.gotIt) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.horizontal, 18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThickMaterial, in: .rect(cornerRadius: style == .compact ? 16 : 22))
        .overlay {
            RoundedRectangle(cornerRadius: style == .compact ? 16 : 22)
                .stroke(.mint.opacity(0.42), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(PresentationSemantics.label(for: event, phase: .presenting))
    }
}

struct CursorOpportunityHaloView: View {
    let reduceMotion: Bool
    @State private var active = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(.mint.opacity(0.85), lineWidth: 3)
                .frame(width: active && !reduceMotion ? 68 : 46, height: active && !reduceMotion ? 68 : 46)
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 42, height: 42)
            Image(systemName: "command")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(6)
                .background(.mint, in: Circle())
                .offset(x: 25, y: -25)
        }
        .frame(width: 82, height: 82)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Keyboard shortcut available at the pointer")
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.9)) {
                active = true
            }
        }
    }
}

struct PointerCoachingCardView: View {
    let event: CoachingEvent
    let action: (CoachingAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SourceApplicationIcon(bundleIdentifier: event.shortcut.appBundleIdentifier)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Try the keyboard next time")
                        .font(.headline)
                    Text(event.shortcut.title)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(event.shortcut.display)
                    .presentationKeycap()
            }
            HStack {
                Text("Shown beside the action point")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Not Now") { action(.notNow) }
                    .buttonStyle(.plain)
                Button("Got It") { action(.gotIt) }
                    .buttonStyle(.borderedProminent)
                    .tint(.mint)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thickMaterial, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12)) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(PresentationSemantics.label(for: event, phase: .presenting))
    }
}

struct CoachingStatusView: View {
    let event: CoachingEvent
    let phase: PresentationPhase

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(statusColor.opacity(0.2)).frame(width: 38, height: 38)
                Image(systemName: statusIcon).foregroundStyle(statusColor).font(.headline)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle).font(.headline)
                Text(statusDetail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if phase == .evaluating {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thickMaterial, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(statusColor.opacity(0.35)) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PresentationSemantics.label(for: event, phase: phase))
    }

    private var statusTitle: String { phase == .success ? "Coaching captured" : "Checking this action" }
    private var statusDetail: String { phase == .success ? "\(event.shortcut.display) is ready for next time" : "Looking for a faster keyboard route" }
    private var statusIcon: String { phase == .success ? "checkmark" : "magnifyingglass" }
    private var statusColor: Color { phase == .success ? .green : .mint }
}

struct CoachingDecisionBannerView: View {
    let event: CoachingEvent
    let action: (CoachingAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.title2)
                    .foregroundStyle(.mint)
                    .frame(width: 34, height: 34)
                    .background(.mint.opacity(0.14), in: .rect(cornerRadius: 9))
                    .accessibilityLabel("Coaching app")
                SourceApplicationIcon(bundleIdentifier: event.shortcut.appBundleIdentifier)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Build the habit for \(event.shortcut.title)")
                        .font(.headline)
                        .lineLimit(1)
                    Text("Use \(event.shortcut.display) in \(event.shortcut.appName) to stay in flow.")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityLabel("Use \(event.shortcut.display) in \(event.shortcut.appName) to stay in flow")
                }
                Spacer(minLength: 12)
                Button("Not Now") { action(.notNow) }
                    .buttonStyle(.bordered)
                Button("Got It") { action(.gotIt) }
                    .buttonStyle(.bordered)
                Button("Practice Shortcut") { action(.practiceShortcut) }
                    .buttonStyle(.borderedProminent)
                    .tint(.mint)
                    .keyboardShortcut(.defaultAction)
            }

            HStack(spacing: 8) {
                Text(event.shortcut.display).presentationKeycap()
                Button("Coaching Settings") { action(.openSettings) }.buttonStyle(.bordered)
                Button("Stop Suggesting This Shortcut") { action(.stopSuggesting) }.buttonStyle(.bordered)
                Spacer()
                if event.isLocalPreview {
                    Label("Local preview", systemImage: "testtube.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .controlSize(.small)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThickMaterial, in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(LinearGradient(colors: [.mint.opacity(0.65), .cyan.opacity(0.22)], startPoint: .leading, endPoint: .trailing))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(PresentationSemantics.label(for: event, phase: .presenting))
        .accessibilityHint("Choose whether to practice, defer, dismiss, or change coaching settings")
    }
}

private struct SourceApplicationIcon: View {
    let bundleIdentifier: String

    var body: some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .scaledToFit()
        .frame(width: 34, height: 34)
        .accessibilityLabel("Source application")
    }
}

private extension View {
    func presentationKeycap() -> some View {
        padding(.horizontal, 9)
            .padding(.vertical, 5)
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(.mint)
            .background(.mint.opacity(0.14), in: .rect(cornerRadius: 7))
            .overlay { RoundedRectangle(cornerRadius: 7).stroke(.mint.opacity(0.28)) }
    }
}
