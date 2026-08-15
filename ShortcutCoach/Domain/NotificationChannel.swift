import Foundation

enum NotificationChannel: String, Codable, CaseIterable, Identifiable, Sendable {
    case nativeBanner
    case topRightToast
    case topCenterShelf
    case cursorHalo
    case pointerCard
    case statusFeedback
    case decisionBanner
    case dockBadge
    case dockBounce
    case sound

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nativeBanner: "Native macOS Banner"
        case .topRightToast: "Top-right Toast"
        case .topCenterShelf: "Top-center Shelf"
        case .cursorHalo: "Cursor Halo"
        case .pointerCard: "Pointer Card"
        case .statusFeedback: "Status Feedback"
        case .decisionBanner: "Decision Banner"
        case .dockBadge: "Dock Badge"
        case .dockBounce: "Dock Bounce"
        case .sound: "Sound"
        }
    }

    var summary: String {
        switch self {
        case .nativeBanner: "A Notification Center alert that remains available to macOS."
        case .topRightToast: "A compact coaching card near the top-right corner."
        case .topCenterShelf: "A prominent expandable shelf centered at the top."
        case .cursorHalo: "A short visual pulse around the action location."
        case .pointerCard: "A coaching card anchored beside the action location."
        case .statusFeedback: "A brief evaluating-to-success progress presentation."
        case .decisionBanner: "A wide prompt with explicit action buttons."
        case .dockBadge: "Updates the Dock icon with the unread count."
        case .dockBounce: "Requests user attention in the Dock."
        case .sound: "Plays the system notification sound."
        }
    }

    var systemImage: String {
        switch self {
        case .nativeBanner: "macwindow.badge.plus"
        case .topRightToast: "rectangle.topthird.inset.filled"
        case .topCenterShelf: "rectangle.tophalf.inset.filled"
        case .cursorHalo: "cursorarrow.rays"
        case .pointerCard: "cursorarrow.motionlines"
        case .statusFeedback: "checkmark.circle"
        case .decisionBanner: "rectangle.and.hand.point.up.left"
        case .dockBadge: "app.badge"
        case .dockBounce: "arrow.up.and.down"
        case .sound: "speaker.wave.2"
        }
    }
}

enum DeliveryOutcome: Equatable, Sendable {
    case delivered
    case failed(String)
}

struct DeliveryReport: Equatable, Sendable {
    let eventID: UUID
    let inboxRecorded: Bool
    let outcomes: [NotificationChannel: DeliveryOutcome]
}

