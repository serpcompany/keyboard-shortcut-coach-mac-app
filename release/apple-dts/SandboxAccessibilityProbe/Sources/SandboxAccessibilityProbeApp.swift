import ApplicationServices
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.serp.shortcutcoach.dtsprobe", category: "Accessibility")

@main
struct SandboxAccessibilityProbeApp: App {
    @State private var isTrusted = AXIsProcessTrusted()

    var body: some Scene {
        WindowGroup("Sandbox Accessibility Probe") {
            VStack(spacing: 18) {
                Text("Sandbox Accessibility Probe")
                    .font(.title.bold())
                Text(isTrusted ? "Accessibility trusted" : "Accessibility not trusted")
                    .foregroundStyle(isTrusted ? .green : .orange)
                Button("Request Accessibility Permission") {
                    let options = [
                        kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
                    ] as CFDictionary
                    let result = AXIsProcessTrustedWithOptions(options)
                    logger.notice("AXIsProcessTrustedWithOptions returned \(result, privacy: .public)")
                    isTrusted = result
                }
                Button("Refresh Status") {
                    isTrusted = AXIsProcessTrusted()
                    logger.notice("AXIsProcessTrusted returned \(isTrusted, privacy: .public)")
                }
            }
            .frame(minWidth: 480, minHeight: 260)
            .padding(32)
        }
    }
}
