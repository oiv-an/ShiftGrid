import AppKit
import XCTest
@testable import ShiftGrid

final class ScreenLayoutTests: XCTestCase {
    func testAutomaticPolicyUsesThreeColumnsAtThreshold() {
        XCTAssertEqual(
            LayoutPolicy.columnCount(mode: .automatic, displayPixelWidth: 2_999),
            2
        )
        XCTAssertEqual(
            LayoutPolicy.columnCount(mode: .automatic, displayPixelWidth: 3_000),
            3
        )
    }

    func testManualPolicyOverridesDisplayWidth() {
        XCTAssertEqual(LayoutPolicy.columnCount(mode: .three, displayPixelWidth: 1_000), 3)
        XCTAssertEqual(LayoutPolicy.columnCount(mode: .two, displayPixelWidth: 8_000), 2)
    }

    func testThreeColumnFramesUseTinyOuterInsetAndGap() throws {
        let frames = ZoneLayout.frames(
            in: CGRect(x: 0, y: 0, width: 3_040, height: 1_200),
            columnCount: 3,
            outerInset: 2,
            gap: 2,
            backingScaleFactor: 1
        )

        XCTAssertEqual(frames.count, 3)
        let first = try XCTUnwrap(frames.first)
        let last = try XCTUnwrap(frames.last)

        XCTAssertEqual(first.minX, 2, accuracy: 0.001)
        XCTAssertEqual(first.minY, 2, accuracy: 0.001)
        XCTAssertEqual(last.maxX, 3_038, accuracy: 0.001)
        XCTAssertEqual(last.maxY, 1_198, accuracy: 0.001)
        XCTAssertEqual(frames[1].minX - frames[0].maxX, 2, accuracy: 0.001)
        XCTAssertEqual(frames[2].minX - frames[1].maxX, 2, accuracy: 0.001)
    }

    func testPhysicalPixelSpacingConvertsToScreenPoints() {
        XCTAssertEqual(
            ScreenMetrics.points(forPhysicalPixels: 2, backingScaleFactor: 1),
            2,
            accuracy: 0.001
        )
        XCTAssertEqual(
            ScreenMetrics.points(forPhysicalPixels: 2, backingScaleFactor: 2),
            1,
            accuracy: 0.001
        )
    }

    func testHitFramesCoverOuterStripsAndSeams() throws {
        let hitFrames = ZoneLayout.frames(
            in: CGRect(x: 0, y: 0, width: 3_040, height: 1_200),
            columnCount: 3,
            outerInset: 0,
            gap: 0,
            backingScaleFactor: 1
        )

        XCTAssertEqual(try XCTUnwrap(hitFrames.first).minX, 0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(hitFrames.last).maxX, 3_040, accuracy: 0.001)
        XCTAssertEqual(hitFrames[1].minX - hitFrames[0].maxX, 0, accuracy: 0.001)
        XCTAssertEqual(hitFrames[2].minX - hitFrames[1].maxX, 0, accuracy: 0.001)
    }

    func testVisibleDockIsReservedButAutoHiddenDockStripIsIgnored() throws {
        let screen = CGRect(x: 0, y: 0, width: 1_728, height: 1_117)
        let withVisibleDock = ScreenMetrics.usableFrame(
            screenFrame: screen,
            visibleFrame: CGRect(x: 0, y: 74, width: 1_728, height: 1_010)
        )
        let withHiddenDock = ScreenMetrics.usableFrame(
            screenFrame: screen,
            visibleFrame: CGRect(x: 0, y: 4, width: 1_728, height: 1_080)
        )

        XCTAssertEqual(withVisibleDock, CGRect(x: 0, y: 74, width: 1_728, height: 1_010))
        XCTAssertEqual(withHiddenDock, CGRect(x: 0, y: 0, width: 1_728, height: 1_084))

        let framesAboveVisibleDock = ZoneLayout.frames(
            in: withVisibleDock,
            columnCount: 2,
            outerInset: 2,
            gap: 2,
            backingScaleFactor: 1
        )
        XCTAssertEqual(try XCTUnwrap(framesAboveVisibleDock.first).minY, 76, accuracy: 0.001)
    }

    func testVisibleSideDockIsReserved() {
        let usable = ScreenMetrics.usableFrame(
            screenFrame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            visibleFrame: CGRect(x: 80, y: 0, width: 1_648, height: 1_084)
        )

        XCTAssertEqual(usable, CGRect(x: 80, y: 0, width: 1_648, height: 1_084))
    }

    func testAccessibilityCoordinateConversion() {
        let point = AccessibilityCoordinateSpace.topLeftPoint(
            for: CGPoint(x: 1_900, y: -100),
            menuBarScreenTop: 1_117
        )
        let position = AccessibilityCoordinateSpace.topLeftPosition(
            for: CGRect(x: 20, y: 20, width: 980, height: 1_040),
            menuBarScreenTop: 1_080
        )

        XCTAssertEqual(point.x, 1_900, accuracy: 0.001)
        XCTAssertEqual(point.y, 1_217, accuracy: 0.001)
        XCTAssertEqual(position.x, 20, accuracy: 0.001)
        XCTAssertEqual(position.y, 20, accuracy: 0.001)
    }

    func testOverlayUsesCoordinatesRelativeToExternalScreen() throws {
        let externalScreen = CGRect(x: 1_728, y: -256, width: 3_440, height: 1_440)
        let globalZones = [
            CGRect(x: 1_728, y: -256, width: 1_147, height: 1_410),
            CGRect(x: 2_875, y: -256, width: 1_146, height: 1_410),
            CGRect(x: 4_021, y: -256, width: 1_147, height: 1_410)
        ]

        let contentRect = OverlayGeometry.screenRelativeContentRect(for: externalScreen)
        let localZones = OverlayGeometry.localZoneFrames(
            from: globalZones,
            screenFrame: externalScreen
        )
        let localPointer = OverlayGeometry.localPoint(
            from: CGPoint(x: 4_500, y: 500),
            screenFrame: externalScreen
        )

        XCTAssertEqual(contentRect, CGRect(x: 0, y: 0, width: 3_440, height: 1_440))
        XCTAssertEqual(try XCTUnwrap(localZones.first).origin, .zero)
        XCTAssertEqual(try XCTUnwrap(localZones.last).maxX, 3_440, accuracy: 0.001)
        XCTAssertEqual(localPointer, CGPoint(x: 2_772, y: 756))
    }
}
