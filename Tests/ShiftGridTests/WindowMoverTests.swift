import XCTest
@testable import ShiftGrid

final class WindowMoverTests: XCTestCase {
    func testPreparatorySizeSupportsGrowingShrinkingAndMixedChanges() {
        XCTAssertEqual(
            WindowGeometryPlan.preparatorySize(
                current: CGSize(width: 400, height: 600),
                desired: CGSize(width: 800, height: 600)
            ),
            CGSize(width: 400, height: 600)
        )
        XCTAssertEqual(
            WindowGeometryPlan.preparatorySize(
                current: CGSize(width: 800, height: 600),
                desired: CGSize(width: 400, height: 600)
            ),
            CGSize(width: 400, height: 600)
        )
        XCTAssertEqual(
            WindowGeometryPlan.preparatorySize(
                current: CGSize(width: 900, height: 500),
                desired: CGSize(width: 600, height: 800)
            ),
            CGSize(width: 600, height: 500)
        )
    }

    func testPositionAndSizeVerificationAreIndependent() {
        XCTAssertTrue(WindowGeometryVerification.matches(
            actualPosition: CGPoint(x: 100.5, y: 200.5),
            desiredPosition: CGPoint(x: 100, y: 200)
        ))
        XCTAssertTrue(WindowGeometryVerification.matches(
            actualSize: CGSize(width: 799, height: 600),
            desiredSize: CGSize(width: 800, height: 600)
        ))
        XCTAssertFalse(WindowGeometryVerification.matches(
            actualSize: CGSize(width: 400, height: 600),
            desiredSize: CGSize(width: 800, height: 600)
        ))
    }

    func testGeometryVerificationAllowsPixelRoundingButRejectsOneColumnWidth() {
        XCTAssertTrue(WindowGeometryVerification.matches(
            actualPosition: CGPoint(x: 100.5, y: 40),
            actualSize: CGSize(width: 2_001, height: 900.5),
            desiredPosition: CGPoint(x: 100, y: 40),
            desiredSize: CGSize(width: 2_000, height: 900)
        ))

        XCTAssertFalse(WindowGeometryVerification.matches(
            actualPosition: CGPoint(x: 100, y: 40),
            actualSize: CGSize(width: 1_000, height: 900),
            desiredPosition: CGPoint(x: 100, y: 40),
            desiredSize: CGSize(width: 2_000, height: 900)
        ))
    }
}
