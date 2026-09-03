import AppKit

enum ProductIdentity {
    static let productName = "Shortcut Coach"
    static let accessibilityName = "Shortcut Coach"
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
        button.toolTip = ProductIdentity.productName
        button.setAccessibilityLabel(ProductIdentity.accessibilityName)
        button.target = target
        button.action = action
    }
}
