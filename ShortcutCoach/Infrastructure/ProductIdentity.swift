import AppKit

enum ReleaseLane: String, CaseIterable {
    case full
    case appStoreLite

    #if APP_STORE_LITE
    static let current = ReleaseLane.appStoreLite
    #else
    static let current = ReleaseLane.full
    #endif

    var productName: String {
        switch self {
        case .full: "Shortcut Coach"
        case .appStoreLite: "Shortcut Coach Lite"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .full: "com.serp.shortcutcoach"
        case .appStoreLite: "com.serp.shortcutcoach.lite"
        }
    }

    var supportsManualActionDetection: Bool { self == .full }
    var showsFullVersionCTA: Bool { self == .appStoreLite }

    static let fullVersionURL = URL(string: "https://serpcompany.github.io/keyboard-shortcut-coach-mac-app/")!
}

enum ProductIdentity {
    static let legacyBundleIdentifiers = [
        "com.serpcompany.shortcutcoach",
        "co.serp.shortcutcoach"
    ]
    static let statusItemImageName = "SERPMenuBarMark"
    static let inAppBrandImageName = "SERPArrow"
}

enum StatusItemBranding {
    static func configure(_ button: NSStatusBarButton, target: AnyObject, action: Selector) {
        guard let image = NSImage(named: ProductIdentity.statusItemImageName) else {
            assertionFailure("Missing SERP menu-bar image")
            return
        }
        image.isTemplate = true
        image.size = NSSize(width: 17, height: 17)
        button.image = image
        button.imagePosition = .imageOnly
        button.title = ""
        button.toolTip = ReleaseLane.current.productName
        button.setAccessibilityLabel(ReleaseLane.current.productName)
        button.target = target
        button.action = action
    }
}
