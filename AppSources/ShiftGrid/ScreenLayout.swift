import AppKit
import CoreGraphics

enum ScreenMetrics {
    /// macOS keeps a thin activation strip in `visibleFrame` for auto-hidden
    /// system UI. It is not a visible Dock/menu bar and should not shorten a
    /// snapped window.
    static let hiddenSystemUIInsetThreshold: CGFloat = 12

    static func displayPixelWidth(for screen: NSScreen) -> Int {
        if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            let width = CGDisplayPixelsWide(CGDirectDisplayID(screenNumber.uint32Value))
            if width > 0 {
                return width
            }
        }

        return Int((screen.frame.width * screen.backingScaleFactor).rounded())
    }

    static func screenContainingMouse(_ point: NSPoint = NSEvent.mouseLocation) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    static func usableFrame(for screen: NSScreen) -> CGRect {
        usableFrame(screenFrame: screen.frame, visibleFrame: screen.visibleFrame)
    }

    static func points(forPhysicalPixels pixels: CGFloat, backingScaleFactor: CGFloat) -> CGFloat {
        max(0, pixels) / max(1, backingScaleFactor)
    }

    static func usableFrame(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        hiddenInsetThreshold: CGFloat = hiddenSystemUIInsetThreshold
    ) -> CGRect {
        guard screenFrame.width > 0, screenFrame.height > 0 else { return .zero }

        let leftInset = max(0, visibleFrame.minX - screenFrame.minX)
        let rightInset = max(0, screenFrame.maxX - visibleFrame.maxX)
        let bottomInset = max(0, visibleFrame.minY - screenFrame.minY)
        let topInset = max(0, screenFrame.maxY - visibleFrame.maxY)

        let minX = leftInset > hiddenInsetThreshold ? visibleFrame.minX : screenFrame.minX
        let maxX = rightInset > hiddenInsetThreshold ? visibleFrame.maxX : screenFrame.maxX
        let minY = bottomInset > hiddenInsetThreshold ? visibleFrame.minY : screenFrame.minY
        let maxY = topInset > hiddenInsetThreshold ? visibleFrame.maxY : screenFrame.maxY

        return CGRect(
            x: minX,
            y: minY,
            width: max(0, maxX - minX),
            height: max(0, maxY - minY)
        )
    }
}

enum ZoneLayout {
    static func frames(
        in availableFrame: CGRect,
        columnCount: Int,
        outerInset: CGFloat,
        gap: CGFloat,
        backingScaleFactor: CGFloat = 1
    ) -> [CGRect] {
        guard columnCount > 0, availableFrame.width > 0, availableFrame.height > 0 else {
            return []
        }

        let safeOuterInset = max(0, outerInset)
        let layoutFrame = availableFrame.insetBy(dx: safeOuterInset, dy: safeOuterInset)
        let safeGap = max(0, gap)
        let totalGaps = safeGap * CGFloat(max(0, columnCount - 1))

        guard layoutFrame.width > totalGaps, layoutFrame.height > 0 else {
            return []
        }

        let rawWidth = (layoutFrame.width - totalGaps) / CGFloat(columnCount)
        let scale = max(1, backingScaleFactor)

        return (0 ..< columnCount).map { index in
            let rawMinX = layoutFrame.minX + CGFloat(index) * (rawWidth + safeGap)
            let rawMaxX = index == columnCount - 1 ? layoutFrame.maxX : rawMinX + rawWidth
            let minX = pixelAligned(rawMinX, scale: scale)
            let maxX = pixelAligned(rawMaxX, scale: scale)

            return CGRect(
                x: minX,
                y: pixelAligned(layoutFrame.minY, scale: scale),
                width: max(1 / scale, maxX - minX),
                height: max(
                    1 / scale,
                    pixelAligned(layoutFrame.maxY, scale: scale)
                        - pixelAligned(layoutFrame.minY, scale: scale)
                )
            )
        }
    }

    private static func pixelAligned(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        (value * scale).rounded() / scale
    }
}

enum AccessibilityCoordinateSpace {
    static func topLeftPoint(for appKitPoint: CGPoint, menuBarScreenTop: CGFloat) -> CGPoint {
        CGPoint(x: appKitPoint.x, y: menuBarScreenTop - appKitPoint.y)
    }

    static func topLeftPosition(for appKitFrame: CGRect, menuBarScreenTop: CGFloat) -> CGPoint {
        CGPoint(x: appKitFrame.minX, y: menuBarScreenTop - appKitFrame.maxY)
    }
}
