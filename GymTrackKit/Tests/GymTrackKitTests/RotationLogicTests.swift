import XCTest
@testable import GymTrackKit

final class RotationLogicTests: XCTestCase {
    func testDefaultsToAWhenNoHistory() {
        XCTAssertEqual(RotationLogic.nextSessionType(after: nil), .a)
    }

    func testRotatesAToB() {
        XCTAssertEqual(RotationLogic.nextSessionType(after: .a), .b)
    }

    func testRotatesBToC() {
        XCTAssertEqual(RotationLogic.nextSessionType(after: .b), .c)
    }

    func testRotatesCToA() {
        XCTAssertEqual(RotationLogic.nextSessionType(after: .c), .a)
    }
}
