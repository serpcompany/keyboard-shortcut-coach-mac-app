import CoreGraphics
import XCTest
@testable import ShortcutCoach

final class StandardWindowControlTests: XCTestCase {
    func testMinimizeEmitsOnlyAfterTheSameWindowBecomesMinimized() {
        let pre = WindowControlState(present: true, minimized: false, frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let unchanged = WindowControlState(present: true, minimized: false, frame: pre.frame)
        let minimized = WindowControlState(present: true, minimized: true, frame: pre.frame)

        XCTAssertNil(WindowControlPolicy.event(kind: .minimize, applicationName: "Finder", shortcut: "⌘M", pre: pre, post: unchanged, pointer: .zero))
        XCTAssertEqual(WindowControlPolicy.event(kind: .minimize, applicationName: "Finder", shortcut: "⌘M", pre: pre, post: minimized, pointer: .zero)?.shortcut, "⌘M")
    }

    func testCloseWindowRequiresTheCapturedWindowToDisappear() {
        let pre = WindowControlState(present: true, minimized: false, frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        XCTAssertNil(WindowControlPolicy.event(kind: .close, applicationName: "Google Chrome", shortcut: "⇧⌘W", pre: pre, post: pre, pointer: .zero))

        let closed = WindowControlState(present: false, minimized: nil, frame: nil)
        let event = WindowControlPolicy.event(kind: .close, applicationName: "Google Chrome", shortcut: "⇧⌘W", pre: pre, post: closed, pointer: .zero)
        XCTAssertEqual(event?.actionTitle, "Close Window")
        XCTAssertEqual(event?.shortcut, "⇧⌘W")
    }

    func testFullScreenRequiresAWindowFrameTransition() {
        let pre = WindowControlState(present: true, minimized: false, frame: CGRect(x: 50, y: 50, width: 800, height: 600))
        XCTAssertNil(WindowControlPolicy.event(kind: .fullScreen, applicationName: "Finder", shortcut: "⌃⌘F", pre: pre, post: pre, pointer: .zero))

        let expanded = WindowControlState(present: true, minimized: false, frame: CGRect(x: 0, y: 0, width: 1728, height: 1117))
        XCTAssertEqual(WindowControlPolicy.event(kind: .fullScreen, applicationName: "Finder", shortcut: "⌃⌘F", pre: pre, post: expanded, pointer: .zero)?.shortcut, "⌃⌘F")
    }
}
