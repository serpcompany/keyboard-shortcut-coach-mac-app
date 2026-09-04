import CoreGraphics
import XCTest
@testable import ShortcutCoach

final class StandardWindowControlTests: XCTestCase {
    func testMinimizeEmitsOnlyAfterTheSameWindowBecomesMinimized() {
        let pre = WindowControlState(present: true, minimized: false, fullScreen: false, frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let unchanged = WindowControlState(present: true, minimized: false, fullScreen: false, frame: pre.frame)
        let minimized = WindowControlState(present: true, minimized: true, fullScreen: false, frame: pre.frame)

        XCTAssertNil(WindowControlPolicy.event(kind: .minimize, applicationName: "Finder", shortcut: "⌘M", pre: pre, post: unchanged, pointer: .zero))
        XCTAssertEqual(WindowControlPolicy.event(kind: .minimize, applicationName: "Finder", shortcut: "⌘M", pre: pre, post: minimized, pointer: .zero)?.shortcut, "⌘M")
    }

    func testCloseWindowRequiresTheCapturedWindowToDisappear() {
        let pre = WindowControlState(present: true, minimized: false, fullScreen: false, frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        XCTAssertNil(WindowControlPolicy.event(kind: .close, applicationName: "Google Chrome", shortcut: "⇧⌘W", pre: pre, post: pre, pointer: .zero))

        let closed = WindowControlState(present: false, minimized: nil, fullScreen: nil, frame: nil)
        let event = WindowControlPolicy.event(kind: .close, applicationName: "Google Chrome", shortcut: "⇧⌘W", pre: pre, post: closed, pointer: .zero)
        XCTAssertEqual(event?.actionTitle, "Close Window")
        XCTAssertEqual(event?.shortcut, "⇧⌘W")
    }

    func testFullScreenRequiresStateToggleAndWindowFrameTransition() {
        let pre = WindowControlState(present: true, minimized: false, fullScreen: false, frame: CGRect(x: 50, y: 50, width: 800, height: 600))
        XCTAssertNil(WindowControlPolicy.event(kind: .fullScreen, applicationName: "Finder", shortcut: "⌃⌘F", pre: pre, post: pre, pointer: .zero))

        let resizedOnly = WindowControlState(present: true, minimized: false, fullScreen: false, frame: CGRect(x: 0, y: 0, width: 1728, height: 1117))
        XCTAssertNil(WindowControlPolicy.event(kind: .fullScreen, applicationName: "Finder", shortcut: "⌃⌘F", pre: pre, post: resizedOnly, pointer: .zero))

        let expanded = WindowControlState(present: true, minimized: false, fullScreen: true, frame: CGRect(x: 0, y: 0, width: 1728, height: 1117))
        XCTAssertEqual(WindowControlPolicy.event(kind: .fullScreen, applicationName: "Finder", shortcut: "⌃⌘F", pre: pre, post: expanded, pointer: .zero)?.shortcut, "⌃⌘F")
    }

    func testExitFullScreenRequiresTheInverseStateAndFrameTransition() {
        let pre = WindowControlState(present: true, minimized: false, fullScreen: true, frame: CGRect(x: 0, y: 0, width: 1728, height: 1117))
        let exited = WindowControlState(present: true, minimized: false, fullScreen: false, frame: CGRect(x: 50, y: 50, width: 800, height: 600))
        let event = WindowControlPolicy.event(kind: .fullScreen, applicationName: "Finder", shortcut: "⌃⌘F", pre: pre, post: exited, pointer: .zero)
        XCTAssertEqual(event?.actionTitle, "Exit Full Screen")
    }

    func testMissingOrAmbiguousLiveShortcutSuppressesAllControls() {
        let pre = WindowControlState(present: true, minimized: false, fullScreen: false, frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let minimized = WindowControlState(present: true, minimized: true, fullScreen: false, frame: pre.frame)
        XCTAssertNil(WindowControlPolicy.event(kind: .minimize, applicationName: "Finder", shortcut: nil, pre: pre, post: minimized, pointer: .zero))
        XCTAssertNil(WindowControlPolicy.event(kind: .minimize, applicationName: "Finder", shortcut: "", pre: pre, post: minimized, pointer: .zero))
        XCTAssertNil(WindowControlPolicy.uniqueShortcut(from: []))
        XCTAssertNil(WindowControlPolicy.uniqueShortcut(from: ["⌘M", "⌘M"]))
        XCTAssertEqual(WindowControlPolicy.uniqueShortcut(from: ["⌘M"]), "⌘M")
    }

    func testModifiedAndUnknownFlagGesturesSuppressButBookkeepingBitDoesNot() {
        XCTAssertTrue(WindowControlPolicy.hasDisallowedModifiers(.maskAlternate))
        XCTAssertTrue(WindowControlPolicy.hasDisallowedModifiers(.maskShift))
        XCTAssertTrue(WindowControlPolicy.hasDisallowedModifiers(CGEventFlags(rawValue: 1 << 40)))
        XCTAssertFalse(WindowControlPolicy.hasDisallowedModifiers([]))
        XCTAssertFalse(WindowControlPolicy.hasDisallowedModifiers(.maskNonCoalesced))
    }

    func testOnlyKnownNonModalStandardWindowsAreAccepted() {
        XCTAssertTrue(WindowControlPolicy.acceptsWindow(isStandard: true, isModal: false))
        XCTAssertFalse(WindowControlPolicy.acceptsWindow(isStandard: false, isModal: false))
        XCTAssertFalse(WindowControlPolicy.acceptsWindow(isStandard: true, isModal: true))
        XCTAssertFalse(WindowControlPolicy.acceptsWindow(isStandard: nil, isModal: false))
        XCTAssertFalse(WindowControlPolicy.acceptsWindow(isStandard: true, isModal: nil))
    }
}
