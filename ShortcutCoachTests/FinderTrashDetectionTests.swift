import XCTest
@testable import ShortcutCoach

final class FinderTrashDetectionTests: XCTestCase {
    func testVerifiedFinderDragToDockTrashProducesMoveToTrashCoaching() {
        let observation = FinderTrashObservation(
            itemEligibility: .supportedRegularItem,
            releasedOnDockTrash: true,
            meaningfulDrag: true,
            modifiersPresent: false,
            postcondition: .removedFromOriginalParent
        )

        let event = FinderTrashPolicy.event(from: observation)
        XCTAssertEqual(event?.applicationName, "Finder")
        XCTAssertEqual(event?.actionTitle, "Move to Trash")
        XCTAssertEqual(event?.shortcut, "⌘⌫")
    }

    func testEveryUnverifiedOrUnsafeScenarioProducesNoCoaching() {
        let baseline = FinderTrashObservation(
            itemEligibility: .supportedRegularItem,
            releasedOnDockTrash: true,
            meaningfulDrag: true,
            modifiersPresent: false,
            postcondition: .removedFromOriginalParent
        )
        let unsafeItems: [FinderTrashItemEligibility] = [
            .multipleSelection, .volume, .alias, .lockedOrImmutable,
            .externalOrNetwork, .readOnly, .unknown
        ]
        for item in unsafeItems {
            XCTAssertNil(FinderTrashPolicy.event(from: .init(
                itemEligibility: item,
                releasedOnDockTrash: baseline.releasedOnDockTrash,
                meaningfulDrag: baseline.meaningfulDrag,
                modifiersPresent: baseline.modifiersPresent,
                postcondition: baseline.postcondition
            )), "unexpected event for \(item)")
        }

        XCTAssertNil(FinderTrashPolicy.event(from: .init(
            itemEligibility: baseline.itemEligibility,
            releasedOnDockTrash: false,
            meaningfulDrag: baseline.meaningfulDrag,
            modifiersPresent: baseline.modifiersPresent,
            postcondition: baseline.postcondition
        )), "hovering over Trash before releasing elsewhere must suppress")
        XCTAssertNil(FinderTrashPolicy.event(from: .init(
            itemEligibility: baseline.itemEligibility,
            releasedOnDockTrash: baseline.releasedOnDockTrash,
            meaningfulDrag: false,
            modifiersPresent: baseline.modifiersPresent,
            postcondition: baseline.postcondition
        )))
        XCTAssertNil(FinderTrashPolicy.event(from: .init(
            itemEligibility: baseline.itemEligibility,
            releasedOnDockTrash: baseline.releasedOnDockTrash,
            meaningfulDrag: baseline.meaningfulDrag,
            modifiersPresent: true,
            postcondition: baseline.postcondition
        )))
        for postcondition in [FinderTrashPostcondition.stillPresent, .inaccessible] {
            XCTAssertNil(FinderTrashPolicy.event(from: .init(
                itemEligibility: baseline.itemEligibility,
                releasedOnDockTrash: baseline.releasedOnDockTrash,
                meaningfulDrag: baseline.meaningfulDrag,
                modifiersPresent: baseline.modifiersPresent,
                postcondition: postcondition
            )), "unexpected event for \(postcondition)")
        }
    }
}
