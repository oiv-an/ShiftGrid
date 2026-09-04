import AppKit

enum MenuBarIcon {
    static let size = NSSize(width: 18, height: 18)

    static func make() -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setStroke()

            let outline = NSBezierPath(
                roundedRect: NSRect(x: 1.5, y: 3, width: 15, height: 12),
                xRadius: 2,
                yRadius: 2
            )
            outline.lineWidth = 1.5
            outline.stroke()

            let dividers = NSBezierPath()
            dividers.move(to: NSPoint(x: 6.5, y: 3.75))
            dividers.line(to: NSPoint(x: 6.5, y: 14.25))
            dividers.move(to: NSPoint(x: 11.5, y: 3.75))
            dividers.line(to: NSPoint(x: 11.5, y: 14.25))
            dividers.lineWidth = 1.5
            dividers.stroke()

            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "ShiftGrid"
        return image
    }
}
