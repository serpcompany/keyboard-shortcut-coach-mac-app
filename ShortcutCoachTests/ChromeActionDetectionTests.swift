import ApplicationServices
import CoreGraphics
import XCTest
@testable import ShortcutCoach

@MainActor
final class ChromeActionDetectionTests: XCTestCase {
    private let adapter = ChromeActionAdapter()

    func testStaticFallbackCatalogIsExplicitlyVersioned() {
        XCTAssertEqual(ChromeShortcutCatalog.characterizedChromeVersion, "153.0.8010.12")
        XCTAssertEqual(ChromeShortcutCatalog.newTab, "⌘T")
        XCTAssertEqual(ChromeShortcutCatalog.closeTab, "⌘W")
        XCTAssertEqual(ChromeShortcutCatalog.selectTab(index: 4), "⌘4")
        XCTAssertEqual(ChromeShortcutCatalog.selectTab(index: 10), "⌘9")
    }

    func testSanitizedCharacterizationFixtureHasNoPrivateBrowserData() throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/evidence/chrome/chrome-153-tab-strip.json")
        let data = try Data(contentsOf: fixture)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["chromeVersion"] as? String, "153.0.8010.12")
        let serialized = String(decoding: data, as: UTF8.self).lowercased()
        for forbidden in ["http://", "https://", "url", "account", "profile", "history", "@"] {
            XCTAssertFalse(serialized.contains(forbidden), "Fixture contains forbidden private-data marker: \(forbidden)")
        }
    }

    func testClassifiesNewTabUsingSemanticConjunction() {
        let snapshot = makeSnapshot(hit: node("new", role: "AXButton", description: "New Tab", actions: ["AXPress"]), tabs: tabs(count: 3))
        XCTAssertEqual(adapter.classify(snapshot, point: .init(x: 10, y: 10))?.kind, .chromeNewTab)

        XCTAssertNil(adapter.classify(makeSnapshot(hit: node("new", role: "AXButton", description: nil, actions: ["AXPress"]), tabs: tabs(count: 3)), point: .zero))
        XCTAssertNil(adapter.classify(makeSnapshot(hit: node("new", role: "AXButton", description: "New Tab", actions: []), tabs: tabs(count: 3)), point: .zero))
        XCTAssertNil(adapter.classify(makeSnapshot(bundle: "com.apple.Safari", hit: node("new", role: "AXButton", description: "New Tab", actions: ["AXPress"]), tabs: tabs(count: 3)), point: .zero))
    }

    func testLocalizedNewTabNameAndAncestorVariationAreAccepted() {
        let hit = node("new", role: "AXButton", description: "Nouvel onglet", actions: ["AXPress"])
        let snapshot = makeSnapshot(hit: hit, ancestors: [node("toolbar", role: "AXGroup")], tabs: tabs(count: 2))
        XCTAssertEqual(adapter.classify(snapshot, point: .zero)?.kind, .chromeNewTab)
    }

    func testCloseOnlyClassifiesSelectedTab() {
        let close = node("close", role: "AXButton", description: "Close", actions: ["AXPress"])
        let active = node("tab-1", role: "AXRadioButton", selected: true)
        let inactive = node("tab-2", role: "AXRadioButton", selected: false)
        let state = ChromeTabState(containerToken: "strip", tabs: [active, inactive])
        XCTAssertEqual(adapter.classify(makeSnapshot(hit: close, ancestors: [active], tabs: state), point: .zero)?.kind,
                       .chromeCloseActiveTab(tabToken: "tab-1"))
        XCTAssertNil(adapter.classify(makeSnapshot(hit: close, ancestors: [inactive], tabs: state), point: .zero))
    }

    func testDirectTabIndexesAndLastTabMapping() {
        let eight = tabs(count: 8)
        let second = eight.tabs[1]
        XCTAssertEqual(adapter.classify(makeSnapshot(hit: second, tabs: eight), point: .zero)?.kind,
                       .chromeSelectTab(tabToken: second.token, index: 2, tabCount: 8))

        let ten = tabs(count: 10)
        XCTAssertNil(adapter.classify(makeSnapshot(hit: ten.tabs[8], tabs: ten), point: .zero))
        XCTAssertEqual(adapter.classify(makeSnapshot(hit: ten.tabs[9], tabs: ten), point: .zero)?.kind,
                       .chromeSelectTab(tabToken: "tab-10", index: 10, tabCount: 10))
    }

    func testNewTabRequiresVerifiedPostcondition() {
        let pre = makeSnapshot(hit: node("new", role: "AXButton", description: "New Tab", actions: ["AXPress"]), tabs: tabs(count: 2))
        var correlator = ActionCorrelator()
        correlator.begin(tryCandidate(pre), at: 1, modifiers: [])
        XCTAssertTrue(correlator.acceptsMouseUp(sample(.up, time: 1.1), hit: pre))
        XCTAssertNil(correlator.verify(post: pre, at: 1.2))

        correlator.begin(tryCandidate(pre), at: 2, modifiers: [])
        XCTAssertTrue(correlator.acceptsMouseUp(sample(.up, time: 2.1), hit: pre))
        let event = correlator.verify(post: makeSnapshot(hit: pre.hit, tabs: tabs(count: 3)), at: 2.2)
        XCTAssertEqual(event?.shortcut, "⌘T")
    }

    func testCloseAndSelectionRequireExactPostconditions() {
        let active = node("tab-1", role: "AXRadioButton", selected: true)
        let other = node("tab-2", role: "AXRadioButton", selected: false)
        let close = node("close", role: "AXButton", description: "Close", actions: ["AXPress"])
        let pre = makeSnapshot(hit: close, ancestors: [active], tabs: ChromeTabState(containerToken: "strip", tabs: [active, other]))
        var correlator = ActionCorrelator()
        correlator.begin(tryCandidate(pre), at: 1, modifiers: [])
        XCTAssertTrue(correlator.acceptsMouseUp(sample(.up, time: 1.1), hit: pre))
        XCTAssertEqual(correlator.verify(post: makeSnapshot(hit: other, tabs: ChromeTabState(containerToken: "strip", tabs: [other])), at: 1.2)?.shortcut, "⌘W")

        let tabPre = makeSnapshot(hit: other, tabs: ChromeTabState(containerToken: "strip", tabs: [active, other]))
        correlator.begin(tryCandidate(tabPre), at: 2, modifiers: [])
        XCTAssertTrue(correlator.acceptsMouseUp(sample(.up, time: 2.1), hit: tabPre))
        let selectedOther = node("tab-2", role: "AXRadioButton", selected: true)
        XCTAssertEqual(correlator.verify(post: makeSnapshot(hit: selectedOther, tabs: ChromeTabState(containerToken: "strip", tabs: [node("tab-1", role: "AXRadioButton", selected: false), selectedOther])), at: 2.2)?.shortcut, "⌘2")
    }

    func testGestureSuppressionsCoverModifiersDragMovedOffDisabledAndExpiry() {
        let pre = makeSnapshot(hit: node("new", role: "AXButton", description: "New Tab", actions: ["AXPress"], frame: AXFrameSnapshot(x: 0, y: 0, width: 20, height: 20)), tabs: tabs(count: 2))
        var correlator = ActionCorrelator()
        correlator.begin(tryCandidate(pre), at: 1, modifiers: .maskCommand)
        XCTAssertNil(correlator.candidate)

        correlator.begin(tryCandidate(pre), at: 2, modifiers: [])
        correlator.markDragged()
        XCTAssertFalse(correlator.acceptsMouseUp(sample(.up, x: 5, y: 5, time: 2.1), hit: pre))

        correlator.begin(tryCandidate(pre), at: 3, modifiers: [])
        XCTAssertFalse(correlator.acceptsMouseUp(sample(.up, x: 50, y: 50, time: 3.1), hit: pre))

        correlator.begin(tryCandidate(pre), at: 4, modifiers: [])
        XCTAssertFalse(correlator.acceptsMouseUp(sample(.up, x: 5, y: 5, time: 6), hit: pre))

        correlator.begin(tryCandidate(pre), at: 7, modifiers: [])
        let modifiedUp = PointerSample(phase: .up, location: CGPoint(x: 5, y: 5), modifiers: .maskShift, timestamp: 7.1)
        XCTAssertFalse(correlator.acceptsMouseUp(modifiedUp, hit: pre))

        correlator.begin(tryCandidate(pre), at: 8, modifiers: [])
        correlator.cancel()
        XCTAssertNil(correlator.candidate)

        let disabled = makeSnapshot(hit: node("new", role: "AXButton", description: "New Tab", enabled: false, actions: ["AXPress"]), tabs: tabs(count: 2))
        XCTAssertNil(adapter.classify(disabled, point: .zero))
    }

    func testOrdinaryPointerJitterDoesNotCancelAChromeClick() {
        let pre = makeSnapshot(
            hit: node(
                "new",
                role: "AXButton",
                description: "New Tab",
                actions: ["AXPress"],
                frame: AXFrameSnapshot(x: 0, y: 0, width: 20, height: 20)
            ),
            tabs: tabs(count: 2)
        )
        var correlator = ActionCorrelator()
        correlator.begin(tryCandidate(pre), at: 1, modifiers: [])
        correlator.observeDrag(to: CGPoint(x: 5.2, y: 5.1))

        XCTAssertTrue(correlator.acceptsMouseUp(sample(.up, x: 5.2, y: 5.1, time: 1.1), hit: pre))
    }

    func testChromeSettingsMenuItemProducesSettingsCandidate() {
        let snapshot = makeSnapshot(
            hit: node("settings", role: "AXMenuItem", title: "Settings", actions: ["AXPress"]),
            tabs: tabs(count: 2)
        )

        XCTAssertEqual(
            adapter.classify(snapshot, point: CGPoint(x: 5, y: 5))?.kind,
            .chromeSettings(initialTabCount: 2)
        )
    }

    func testChromeSettingsRequiresAResultingTabStateChange() {
        let pre = makeSnapshot(
            hit: node("settings", role: "AXMenuItem", title: "Settings", actions: ["AXPress"]),
            tabs: tabs(count: 2)
        )
        var correlator = ActionCorrelator()
        correlator.begin(tryCandidate(pre), at: 1, modifiers: [])
        XCTAssertTrue(correlator.acceptsMouseUp(sample(.up, time: 1.1), hit: pre))
        XCTAssertNil(correlator.verify(post: pre, at: 1.2))

        correlator.begin(tryCandidate(pre), at: 2, modifiers: [])
        XCTAssertTrue(correlator.acceptsMouseUp(sample(.up, time: 2.1), hit: pre))
        let event = correlator.verify(post: makeSnapshot(hit: pre.hit, tabs: tabs(count: 3)), at: 2.2)
        XCTAssertEqual(event?.actionTitle, "Settings")
        XCTAssertEqual(event?.shortcut, "⌘,")
    }

    func testReloadOmniboxAndUnknownButtonsAreSuppressed() {
        for description in ["Reload", "Stop", "Address and search bar", nil] {
            let snapshot = makeSnapshot(hit: node("button", role: "AXButton", description: description, actions: ["AXPress"]), tabs: tabs(count: 2))
            XCTAssertNil(adapter.classify(snapshot, point: .zero))
        }
    }

    func testFallbackDeduplicatesAndTapDisableTypesRecover() {
        let pre = makeSnapshot(hit: node("new", role: "AXButton", description: "New Tab", actions: ["AXPress"]), tabs: tabs(count: 2))
        let post = makeSnapshot(hit: pre.hit, tabs: tabs(count: 3))
        var correlator = ActionCorrelator()
        correlator.begin(tryCandidate(pre), at: 1, modifiers: [])
        XCTAssertTrue(correlator.acceptsMouseUp(sample(.up, time: 1.1), hit: pre))
        XCTAssertNotNil(correlator.verify(post: post, at: 1.2))
        correlator.begin(tryCandidate(pre), at: 1.3, modifiers: [])
        XCTAssertTrue(correlator.acceptsMouseUp(sample(.up, time: 1.4), hit: pre))
        XCTAssertNil(correlator.verify(post: post, at: 1.5))
        XCTAssertTrue(PointerEventMonitor.shouldRecover(from: .tapDisabledByTimeout))
        XCTAssertTrue(PointerEventMonitor.shouldRecover(from: .tapDisabledByUserInput))
        XCTAssertFalse(PointerEventMonitor.shouldRecover(from: .leftMouseDown))
    }

    private func tryCandidate(_ snapshot: AccessibilitySnapshot) -> ManualActionCandidate {
        // Test construction always supplies a fixture that the adapter accepts.
        adapter.classify(snapshot, point: CGPoint(x: 5, y: 5))!
    }

    private func sample(_ phase: PointerSample.Phase, x: Double = 5, y: Double = 5, time: TimeInterval) -> PointerSample {
        PointerSample(phase: phase, location: CGPoint(x: x, y: y), modifiers: [], timestamp: time)
    }

    private func tabs(count: Int) -> ChromeTabState {
        ChromeTabState(containerToken: "strip", tabs: (1...count).map { node("tab-\($0)", role: "AXRadioButton", selected: $0 == 1) })
    }

    private func makeSnapshot(bundle: String = "com.google.Chrome", hit: AXNodeSnapshot,
                              ancestors: [AXNodeSnapshot] = [], tabs: ChromeTabState?) -> AccessibilitySnapshot {
        AccessibilitySnapshot(pid: 123, bundleIdentifier: bundle, applicationName: "Google Chrome",
                              hit: hit, ancestors: ancestors, tabs: tabs)
    }

    private func node(_ token: String, role: String, title: String? = nil, description: String? = nil,
                      selected: Bool? = nil, enabled: Bool? = true,
                      actions: [String] = [], frame: AXFrameSnapshot? = AXFrameSnapshot(x: 0, y: 0, width: 20, height: 20)) -> AXNodeSnapshot {
        AXNodeSnapshot(token: token, role: role, subrole: nil, title: title,
                       elementDescription: description, identifier: nil, value: selected.map { $0 ? "1" : "0" },
                       selected: selected, enabled: enabled, actions: actions, frame: frame, menuShortcut: nil)
    }
}
