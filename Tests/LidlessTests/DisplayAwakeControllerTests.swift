import XCTest
import IOKit.pwr_mgt

final class DisplayAwakeControllerTests: XCTestCase {
    private func assertionExists(_ id: IOPMAssertionID) -> Bool {
        IOPMAssertionCopyProperties(id)?.takeRetainedValue() != nil
    }

    func testProtectionIsHeldOnceAndReleasedWhenDisabled() throws {
        let controller = DisplayAwakeController()
        XCTAssertNil(controller.assertionID)
        XCTAssertEqual(controller.setActive(true), kIOReturnSuccess)
        let id = try XCTUnwrap(controller.assertionID)
        XCTAssertTrue(assertionExists(id))
        XCTAssertEqual(controller.setActive(true), kIOReturnSuccess)
        XCTAssertEqual(controller.assertionID, id)
        XCTAssertEqual(controller.setActive(false), kIOReturnSuccess)
        XCTAssertNil(controller.assertionID)
        XCTAssertFalse(assertionExists(id))
        XCTAssertEqual(controller.setActive(false), kIOReturnSuccess)
        XCTAssertEqual(controller.setActive(true), kIOReturnSuccess)
        XCTAssertNotNil(controller.assertionID)
    }

    func testReleasingControllerReleasesSystemAssertion() throws {
        var controller: DisplayAwakeController? = DisplayAwakeController()
        XCTAssertEqual(controller?.setActive(true), kIOReturnSuccess)
        let id = try XCTUnwrap(controller?.assertionID)
        controller = nil
        XCTAssertFalse(assertionExists(id))
    }
}
