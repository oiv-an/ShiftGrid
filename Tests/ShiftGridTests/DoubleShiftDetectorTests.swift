import XCTest
@testable import ShiftGrid

final class DoubleShiftDetectorTests: XCTestCase {
    func testSecondPressEmitsBeginAndEnd() {
        var detector = DoubleShiftDetector(maximumGap: 0.4, maximumHold: 0.35)

        XCTAssertEqual(detector.processShiftChange(
            keyCode: 56,
            isDown: true,
            hasConflictingModifiers: false,
            timestamp: 1.00
        ), .none)
        XCTAssertEqual(detector.processShiftChange(
            keyCode: 56,
            isDown: false,
            hasConflictingModifiers: false,
            timestamp: 1.08
        ), .none)
        XCTAssertEqual(detector.processShiftChange(
            keyCode: 56,
            isDown: true,
            hasConflictingModifiers: false,
            timestamp: 1.24
        ), .secondPressBegan)
        let releaseEvent = detector.processShiftChange(
            keyCode: 56,
            isDown: false,
            hasConflictingModifiers: false,
            timestamp: 1.31
        )
        guard case let .secondPressEnded(holdDuration) = releaseEvent else {
            return XCTFail("Expected secondPressEnded, got \(releaseEvent)")
        }
        XCTAssertEqual(holdDuration, 0.07, accuracy: 0.0001)
    }

    func testSlowSecondTapDoesNotTrigger() {
        var detector = DoubleShiftDetector(maximumGap: 0.4, maximumHold: 0.35)

        _ = detector.processShiftChange(
            keyCode: 56,
            isDown: true,
            hasConflictingModifiers: false,
            timestamp: 1.00
        )
        _ = detector.processShiftChange(
            keyCode: 56,
            isDown: false,
            hasConflictingModifiers: false,
            timestamp: 1.08
        )
        _ = detector.processShiftChange(
            keyCode: 56,
            isDown: true,
            hasConflictingModifiers: false,
            timestamp: 1.60
        )

        XCTAssertEqual(detector.processShiftChange(
            keyCode: 56,
            isDown: false,
            hasConflictingModifiers: false,
            timestamp: 1.67
        ), .none)
    }

    func testInterruptionCancelsSequence() {
        var detector = DoubleShiftDetector()

        _ = detector.processShiftChange(
            keyCode: 56,
            isDown: true,
            hasConflictingModifiers: false,
            timestamp: 1.00
        )
        _ = detector.processShiftChange(
            keyCode: 56,
            isDown: false,
            hasConflictingModifiers: false,
            timestamp: 1.06
        )
        detector.interrupt()
        _ = detector.processShiftChange(
            keyCode: 56,
            isDown: true,
            hasConflictingModifiers: false,
            timestamp: 1.18
        )

        XCTAssertEqual(detector.processShiftChange(
            keyCode: 56,
            isDown: false,
            hasConflictingModifiers: false,
            timestamp: 1.24
        ), .none)
    }

    func testLongHoldDoesNotCountAsTap() {
        var detector = DoubleShiftDetector(maximumGap: 0.4, maximumHold: 0.25)

        _ = detector.processShiftChange(
            keyCode: 56,
            isDown: true,
            hasConflictingModifiers: false,
            timestamp: 1.00
        )
        XCTAssertEqual(detector.processShiftChange(
            keyCode: 56,
            isDown: false,
            hasConflictingModifiers: false,
            timestamp: 1.40
        ), .cancelled)
    }

    func testSecondPressCanBeHeldWithoutMaximumDuration() {
        var detector = DoubleShiftDetector(maximumGap: 0.4, maximumHold: 0.35)

        XCTAssertEqual(detector.processShiftChange(
            keyCode: 56,
            isDown: true,
            hasConflictingModifiers: false,
            timestamp: 1.00
        ), .none)
        XCTAssertEqual(detector.processShiftChange(
            keyCode: 56,
            isDown: false,
            hasConflictingModifiers: false,
            timestamp: 1.08
        ), .none)
        XCTAssertEqual(detector.processShiftChange(
            keyCode: 56,
            isDown: true,
            hasConflictingModifiers: false,
            timestamp: 1.20
        ), .secondPressBegan)
        let releaseEvent = detector.processShiftChange(
            keyCode: 56,
            isDown: false,
            hasConflictingModifiers: false,
            timestamp: 4.20
        )
        guard case let .secondPressEnded(holdDuration) = releaseEvent else {
            return XCTFail("Expected secondPressEnded, got \(releaseEvent)")
        }
        XCTAssertEqual(holdDuration, 3.0, accuracy: 0.0001)
    }

    func testRightShiftCancelsLeftShiftSequence() {
        var detector = DoubleShiftDetector()

        XCTAssertEqual(detector.processShiftChange(
            keyCode: 56,
            isDown: true,
            hasConflictingModifiers: false,
            timestamp: 1.00
        ), .none)
        XCTAssertEqual(detector.processShiftChange(
            keyCode: 56,
            isDown: false,
            hasConflictingModifiers: false,
            timestamp: 1.08
        ), .none)
        XCTAssertEqual(detector.processShiftChange(
            keyCode: 60,
            isDown: true,
            hasConflictingModifiers: false,
            timestamp: 1.20
        ), .cancelled)
    }

    func testSelectionGestureReleasePolicies() {
        XCTAssertFalse(SelectionGesturePolicy.shouldCommitHold(duration: 0.08))
        XCTAssertTrue(SelectionGesturePolicy.shouldCommitHold(duration: 0.20))
        XCTAssertTrue(SelectionGesturePolicy.shouldCommitHold(duration: 5.0))

        XCTAssertTrue(SelectionGesturePolicy.shouldOpenClickSelector(
            duration: 0.10,
            maximumTap: 0.35
        ))
        XCTAssertFalse(SelectionGesturePolicy.shouldOpenClickSelector(
            duration: 0.50,
            maximumTap: 0.35
        ))
    }
}
