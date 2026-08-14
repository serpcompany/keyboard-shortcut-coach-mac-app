import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: activate_app <bundle-id>\n", stderr)
    exit(64)
}

guard let application = NSRunningApplication.runningApplications(withBundleIdentifier: CommandLine.arguments[1]).first else {
    fputs("No running application has that bundle identifier\n", stderr)
    exit(2)
}

guard application.activate() else {
    fputs("Unable to activate application\n", stderr)
    exit(1)
}
