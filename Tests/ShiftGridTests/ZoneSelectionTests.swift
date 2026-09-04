import CoreGraphics
import XCTest
@testable import ShiftGrid

final class ZoneSelectionTests: XCTestCase {
    private func makeTracker() -> ZoneMergeGestureTracker {
        ZoneMergeGestureTracker(
            requiredUpwardDistance: 50,
            requiredHorizontalDistance: 60,
            verticalStrokeHorizontalTolerance: 30,
            horizontalStrokeVerticalTolerance: 40
        )
    }

    func testUpThenRightJoinsAdjacentZones() {
        var tracker = makeTracker()

        XCTAssertEqual(tracker.update(point: CGPoint(x: 100, y: 100), zoneIndex: 0),
                       ZoneSelection(singleIndex: 0))
        XCTAssertEqual(tracker.update(point: CGPoint(x: 110, y: 160), zoneIndex: 0),
                       ZoneSelection(singleIndex: 0))
        XCTAssertEqual(tracker.update(point: CGPoint(x: 190, y: 165), zoneIndex: 1),
                       ZoneSelection(joining: 0, 1))
    }

    func testUpThenLeftJoinsAdjacentZones() {
        var tracker = makeTracker()

        _ = tracker.update(point: CGPoint(x: 400, y: 100), zoneIndex: 2)
        _ = tracker.update(point: CGPoint(x: 395, y: 160), zoneIndex: 2)

        XCTAssertEqual(tracker.update(point: CGPoint(x: 320, y: 158), zoneIndex: 1),
                       ZoneSelection(joining: 1, 2))
    }

    func testOrdinaryHorizontalTravelRemainsSingleZone() {
        var tracker = makeTracker()

        _ = tracker.update(point: CGPoint(x: 100, y: 100), zoneIndex: 0)

        XCTAssertEqual(tracker.update(point: CGPoint(x: 220, y: 105), zoneIndex: 1),
                       ZoneSelection(singleIndex: 1))
        XCTAssertEqual(tracker.update(point: CGPoint(x: 340, y: 110), zoneIndex: 2),
                       ZoneSelection(singleIndex: 2))
    }

    func testDiagonalAndShortUpwardMovementDoNotJoinZones() {
        var diagonalTracker = makeTracker()
        _ = diagonalTracker.update(point: CGPoint(x: 100, y: 100), zoneIndex: 0)
        _ = diagonalTracker.update(point: CGPoint(x: 145, y: 165), zoneIndex: 0)
        XCTAssertEqual(diagonalTracker.update(point: CGPoint(x: 220, y: 170), zoneIndex: 1),
                       ZoneSelection(singleIndex: 1))

        var shortTracker = makeTracker()
        _ = shortTracker.update(point: CGPoint(x: 100, y: 100), zoneIndex: 0)
        _ = shortTracker.update(point: CGPoint(x: 105, y: 135), zoneIndex: 0)
        XCTAssertEqual(shortTracker.update(point: CGPoint(x: 220, y: 138), zoneIndex: 1),
                       ZoneSelection(singleIndex: 1))
    }

    func testArmedGestureSurvivesGapBetweenZones() {
        var tracker = makeTracker()

        _ = tracker.update(point: CGPoint(x: 100, y: 100), zoneIndex: 0)
        _ = tracker.update(point: CGPoint(x: 100, y: 160), zoneIndex: 0)
        XCTAssertEqual(tracker.update(point: CGPoint(x: 150, y: 162), zoneIndex: nil),
                       ZoneSelection(singleIndex: 0))
        XCTAssertEqual(tracker.update(point: CGPoint(x: 190, y: 164), zoneIndex: 1),
                       ZoneSelection(joining: 0, 1))
    }

    func testArmedGestureCanCrossBoundaryBeforeHorizontalLegIsLongEnough() {
        var tracker = makeTracker()

        _ = tracker.update(point: CGPoint(x: 100, y: 100), zoneIndex: 0)
        _ = tracker.update(point: CGPoint(x: 100, y: 160), zoneIndex: 0)
        XCTAssertEqual(tracker.update(point: CGPoint(x: 130, y: 162), zoneIndex: 1),
                       ZoneSelection(singleIndex: 1))
        XCTAssertEqual(tracker.update(point: CGPoint(x: 175, y: 164), zoneIndex: 1),
                       ZoneSelection(joining: 0, 1))
    }

    func testNonAdjacentZoneCannotBeJoinedAndMergedChoiceIsLatched() {
        var nonAdjacentTracker = makeTracker()
        _ = nonAdjacentTracker.update(point: CGPoint(x: 100, y: 100), zoneIndex: 0)
        _ = nonAdjacentTracker.update(point: CGPoint(x: 100, y: 160), zoneIndex: 0)
        XCTAssertEqual(nonAdjacentTracker.update(point: CGPoint(x: 340, y: 165), zoneIndex: 2),
                       ZoneSelection(singleIndex: 2))

        var mergedTracker = makeTracker()
        _ = mergedTracker.update(point: CGPoint(x: 100, y: 100), zoneIndex: 0)
        _ = mergedTracker.update(point: CGPoint(x: 100, y: 160), zoneIndex: 0)
        let merged = mergedTracker.update(point: CGPoint(x: 190, y: 165), zoneIndex: 1)
        XCTAssertEqual(mergedTracker.update(point: CGPoint(x: 340, y: 170), zoneIndex: 2), merged)
    }

    func testCombinedFrameIncludesGapBetweenAdjacentZones() throws {
        let frames = [
            CGRect(x: 0, y: 20, width: 300, height: 900),
            CGRect(x: 320, y: 20, width: 300, height: 900),
            CGRect(x: 640, y: 20, width: 300, height: 900)
        ]
        let selection = try XCTUnwrap(ZoneSelection(joining: 0, 1))

        XCTAssertEqual(selection.combinedFrame(in: frames),
                       CGRect(x: 0, y: 20, width: 620, height: 900))
        XCTAssertNil(ZoneSelection(joining: 0, 2))
    }

    func testReverseJoiningOrderProducesTheSameWideFrame() throws {
        let frames = [
            CGRect(x: 0, y: 0, width: 300, height: 900),
            CGRect(x: 302, y: 0, width: 300, height: 900),
            CGRect(x: 604, y: 0, width: 300, height: 900)
        ]
        let leftToRight = try XCTUnwrap(ZoneSelection(joining: 1, 2))
        let rightToLeft = try XCTUnwrap(ZoneSelection(joining: 2, 1))

        XCTAssertEqual(rightToLeft, leftToRight)
        XCTAssertEqual(rightToLeft.combinedFrame(in: frames),
                       CGRect(x: 302, y: 0, width: 602, height: 900))
    }
}
