import XCTest
@testable import ShortcutCoach

final class FinderTrashDetectionTests: XCTestCase {
    func testVerifiedFinderDragToDockTrashProducesMoveToTrashCoaching() {
        let observation = FinderTrashObservation(
            sourceIsFinderItem: true,
            targetIsDockTrash: true,
            meaningfulDrag: true,
            modifiersPresent: false,
            sourceDisappeared: true
        )

        let event = FinderTrashPolicy.event(from: observation)
        XCTAssertEqual(event?.applicationName, "Finder")
        XCTAssertEqual(event?.actionTitle, "Move to Trash")
        XCTAssertEqual(event?.shortcut, "⌘⌫")
    }

    func testUnverifiedOrModifiedTrashDragProducesNoCoaching() {
        XCTAssertNil(FinderTrashPolicy.event(from: FinderTrashObservation(
            sourceIsFinderItem: true,
            targetIsDockTrash: true,
            meaningfulDrag: true,
            modifiersPresent: false,
            sourceDisappeared: false
        )))
        XCTAssertNil(FinderTrashPolicy.event(from: FinderTrashObservation(
            sourceIsFinderItem: true,
            targetIsDockTrash: true,
            meaningfulDrag: true,
            modifiersPresent: true,
            sourceDisappeared: true
        )))
    }
}
