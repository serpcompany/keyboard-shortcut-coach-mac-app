import CoreGraphics
import Foundation

let options: CGWindowListOption = [.optionAll]
guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    fputs("Unable to read the window list\n", stderr)
    exit(1)
}

let matches = raw.filter { info in
    let owner = info[kCGWindowOwnerName as String] as? String ?? ""
    let name = info[kCGWindowName as String] as? String ?? ""
    return owner.localizedCaseInsensitiveContains("keylume")
        || owner == "SystemUIServer"
        || name.localizedCaseInsensitiveContains("keylume")
}

for info in matches {
    let owner = info[kCGWindowOwnerName as String] as? String ?? "<unknown>"
    let pid = info[kCGWindowOwnerPID as String] as? Int ?? -1
    let number = info[kCGWindowNumber as String] as? Int ?? -1
    let layer = info[kCGWindowLayer as String] as? Int ?? -1
    let name = info[kCGWindowName as String] as? String ?? ""
    let bounds = info[kCGWindowBounds as String] ?? [:]
    let alpha = info[kCGWindowAlpha as String] as? Double ?? -1
    let onscreen = info[kCGWindowIsOnscreen as String] as? Bool ?? false
    print("owner=\(owner) pid=\(pid) number=\(number) layer=\(layer) alpha=\(alpha) onscreen=\(onscreen) name=\(name) bounds=\(bounds)")
}
